// Copyright (c) 2017 Alain Martin, Matthieu Talbot
//
// This file is part of FRUT.
//
// FRUT is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// FRUT is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with FRUT.  If not, see <http://www.gnu.org/licenses/>.

#include "JuceHeader.h"

#include <algorithm>
#include <cstdlib>
#include <fstream>
#include <functional>
#include <iostream>
#include <locale>
#include <map>
#include <string>
#include <tuple>
#include <vector>


#if !defined(USE_CRLF_LINE_ENDINGS)
#error USE_CRLF_LINE_ENDINGS must be defined
#endif
#if USE_CRLF_LINE_ENDINGS
static const auto kNewLine = "\r\n";
#else
static const auto kNewLine = '\n';
#endif


template <class Head>
void writeToStream(std::ostream& stream, Head&& head)
{
  stream << std::forward<Head>(head);
}


template <class Head, class... Tail>
void writeToStream(std::ostream& stream, Head&& head, Tail&&... tail)
{
  stream << std::forward<Head>(head);
  writeToStream(stream, std::forward<Tail>(tail)...);
}


struct LineWriter
{
  explicit LineWriter(std::ostream& stream)
    : mStream(stream){};

  LineWriter(const LineWriter&) = delete;
  LineWriter& operator=(const LineWriter&) = delete;

  template <typename... Args>
  void operator()(Args&&... args)
  {
    writeToStream(mStream, std::forward<Args>(args)..., kNewLine);
  }

private:
  std::ostream& mStream;
};


void printError(const juce::String& error)
{
  std::cerr << "error: " << error << std::endl;
}


juce::String escape(const juce::String& charsToEscape, juce::String value)
{
  auto pos = 0;

  while ((pos = value.indexOfAnyOf(charsToEscape, pos)) != -1)
  {
    value = value.replaceSection(pos, 0, "\\");
    pos += 2;
  }

  return value;
}


juce::ValueTree getChildWithPropertyRecursively(const juce::ValueTree& valueTree,
                                                const juce::Identifier& propertyName,
                                                const juce::var& propertyValue)
{
  const auto child = valueTree.getChildWithProperty(propertyName, propertyValue);

  if (child.isValid())
  {
    return child;
  }

  for (auto i = 0; i < valueTree.getNumChildren(); ++i)
  {
    const auto grandchild =
      getChildWithPropertyRecursively(valueTree.getChild(i), propertyName, propertyValue);

    if (grandchild.isValid())
    {
      return grandchild;
    }
  }

  return {};
}


void writeUserNotes(LineWriter& wLn, const juce::ValueTree& valueTree)
{
  if (valueTree.hasProperty("userNotes"))
  {
    wLn("  # NOTES");
    const auto userNotes = valueTree.getProperty("userNotes").toString();
    for (const auto& line : juce::StringArray::fromLines(userNotes))
    {
      wLn("  #   ", line);
    }
  }
}


int main(int argc, char* argv[])
{
  if (argc != 3)
  {
    std::cerr << "usage: Jucer2Reprojucer"
                 " <jucer_project_file>"
                 " <Reprojucer.cmake_file>"
              << std::endl;
    return 1;
  }

  const auto args = std::vector<juce::String>{argv, argv + argc};

  const auto& jucerFilePath = args.at(1);
  const auto jucerFile =
    juce::File::getCurrentWorkingDirectory().getChildFile(jucerFilePath);

  const auto xml = std::unique_ptr<juce::XmlElement>{juce::XmlDocument::parse(jucerFile)};
  if (xml == nullptr || !xml->hasTagName("JUCERPROJECT"))
  {
    printError(jucerFilePath + " is not a valid Jucer project.");
    return 1;
  }

  const auto jucerProject = juce::ValueTree::fromXml(*xml);
  if (!jucerProject.hasType("JUCERPROJECT"))
  {
    printError(jucerFilePath + " is not a valid Jucer project.");
    return 1;
  }

  const auto jucerVersion = jucerProject.getProperty("jucerVersion").toString();
  const auto jucerVersionTokens = juce::StringArray::fromTokens(jucerVersion, ".", {});
  if (jucerVersionTokens.size() != 3)
  {
    printError(jucerFilePath + " is not a valid Jucer project.");
    return 1;
  }

  using Version = std::tuple<int, int, int>;

  const auto jucerVersionAsTuple = [&jucerVersionTokens, &jucerFilePath]() {
    try
    {
      return Version{std::stoi(jucerVersionTokens[0].toStdString()),
                     std::stoi(jucerVersionTokens[1].toStdString()),
                     std::stoi(jucerVersionTokens[2].toStdString())};
    }
    catch (const std::invalid_argument&)
    {
      printError(jucerFilePath + " is not a valid Jucer project.");
      std::exit(1);
    }
  }();

  std::ofstream out{"CMakeLists.txt", std::ios_base::out | std::ios_base::binary};
  LineWriter wLn{out};

  const auto convertSetting =
    [&wLn](const juce::ValueTree& valueTree, const juce::Identifier& property,
           const juce::String& cmakeKeyword,
           std::function<juce::String(const juce::var&)> converterFn) {

      if (!converterFn)
      {
        converterFn = [](const juce::var& v) { return v.toString(); };
      }

      const auto value = converterFn(valueTree.getProperty(property));

      if (value.isEmpty())
      {
        wLn("  # ", cmakeKeyword);
      }
      else
      {
        wLn("  ", cmakeKeyword, " \"", escape("\\\";", value), "\"");
      }
    };

  const auto convertSettingIfDefined =
    [&convertSetting](const juce::ValueTree& valueTree, const juce::Identifier& property,
                      const juce::String& cmakeKeyword,
                      std::function<juce::String(const juce::var&)> converterFn) {

      if (valueTree.hasProperty(property))
      {
        convertSetting(valueTree, property, cmakeKeyword, std::move(converterFn));
      }
    };

  const auto convertOnOffSetting =
    [&wLn](const juce::ValueTree& valueTree, const juce::Identifier& property,
           const juce::String& cmakeKeyword,
           std::function<juce::String(const juce::var&)> converterFn) {
      if (!converterFn)
      {
        converterFn = [](const juce::var& v) -> juce::String {
          return v.isVoid() ? "" : bool{v} ? "ON" : "OFF";
        };
      }

      const auto value = converterFn(valueTree.getProperty(property));

      if (value.isEmpty())
      {
        wLn("  # ", cmakeKeyword);
      }
      else
      {
        wLn("  ", cmakeKeyword, " ", value);
      }
    };

  const auto convertOnOffSettingIfDefined =
    [&convertOnOffSetting](const juce::ValueTree& valueTree,
                           const juce::Identifier& property,
                           const juce::String& cmakeKeyword,
                           std::function<juce::String(const juce::var&)> converterFn) {

      if (valueTree.hasProperty(property))
      {
        convertOnOffSetting(valueTree, property, cmakeKeyword, std::move(converterFn));
      }
    };

  const auto convertOnOffSettingWithDefault =
    [&convertOnOffSetting](const juce::ValueTree& valueTree,
                           const juce::Identifier& property,
                           const juce::String& cmakeKeyword, bool defaultValue) {
      convertOnOffSetting(valueTree, property, cmakeKeyword,
                          [defaultValue](const juce::var& v) -> juce::String {
                            return v.isVoid() ? juce::String{defaultValue ? "ON" : "OFF"}
                                                  + " # Default"
                                              : (bool{v} ? "ON" : "OFF");
                          });
    };

  const auto convertSettingAsList =
    [&wLn](const juce::ValueTree& valueTree, const juce::Identifier& property,
           const std::string& cmakeKeyword,
           std::function<juce::StringArray(const juce::var&)> converterFn) {

      if (!converterFn)
      {
        converterFn = [](const juce::var& v) {
          return juce::StringArray::fromLines(v.toString());
        };
      }

      auto value = converterFn(valueTree.getProperty(property));
      value.removeEmptyStrings();

      if (value.isEmpty())
      {
        wLn("  # ", cmakeKeyword);
      }
      else
      {
        wLn("  ", cmakeKeyword);

        for (const auto& item : value)
        {
          wLn("    \"", escape("\\\";", item), "\"");
        }
      }
    };

  const auto convertSettingAsListIfDefined =
    [&convertSettingAsList](
      const juce::ValueTree& valueTree, const juce::Identifier& property,
      const std::string& cmakeKeyword,
      std::function<juce::StringArray(const juce::var&)> converterFn) {

      if (valueTree.hasProperty(property))
      {
        convertSettingAsList(valueTree, property, cmakeKeyword, std::move(converterFn));
      }
    };

  const auto jucerFileName = jucerFile.getFileName();
  const auto jucerProjectName = jucerProject.getProperty("name").toString();

  // Preamble
  {
    wLn("# This file was generated by Jucer2Reprojucer from \"", jucerFileName, "\"");
    wLn();
    wLn("cmake_minimum_required(VERSION 3.4)");
    wLn();
    wLn("project(\"", jucerProjectName, "\")");
    wLn();
    wLn();
  }

  // include(Reprojucer)
  {
    const auto& reprojucerFilePath = args.at(2);
    const auto reprojucerFile =
      juce::File::getCurrentWorkingDirectory().getChildFile(reprojucerFilePath);

    if (!reprojucerFile.existsAsFile()
        || !reprojucerFile.getFileName().endsWith("Reprojucer.cmake"))
    {
      printError(reprojucerFilePath + " is not a valid Reprojucer.cmake file.");
      return 1;
    }

    wLn("list(APPEND CMAKE_MODULE_PATH \"${CMAKE_CURRENT_LIST_DIR}/",
        reprojucerFile.getParentDirectory()
          .getRelativePathFrom(juce::File::getCurrentWorkingDirectory())
          .replace("\\", "/"),
        "\")");
    wLn("include(Reprojucer)");
    wLn();
    wLn();
  }

  auto escapedJucerFileName = jucerFileName.toStdString();
  std::replace_if(escapedJucerFileName.begin(), escapedJucerFileName.end(),
                  [](const std::string::value_type& c) {
                    return !(std::isalpha(c, std::locale{"C"})
                             || std::isdigit(c, std::locale{"C"}));
                  },
                  '_');

  // get_filename_component()
  {
    wLn("if(NOT DEFINED ", escapedJucerFileName, "_FILE)");
    wLn("  message(FATAL_ERROR \"", escapedJucerFileName, "_FILE must be defined\")");
    wLn("endif()");
    wLn();
    wLn("get_filename_component(", escapedJucerFileName, "_FILE");
    wLn("  \"${", escapedJucerFileName, "_FILE}\" ABSOLUTE");
    wLn("  BASE_DIR \"${CMAKE_BINARY_DIR}\"");
    wLn(")");
    wLn();
    wLn();
  }

  // jucer_project_begin()
  {
    wLn("jucer_project_begin(");
    wLn("  JUCER_VERSION \"", jucerVersion, "\"");
    wLn("  PROJECT_FILE \"${", escapedJucerFileName, "_FILE}\"");
    convertSetting(jucerProject, "id", "PROJECT_ID", {});
    wLn(")");
    wLn();
  }

  const auto projectType = jucerProject.getProperty("projectType").toString();

  // jucer_project_settings()
  {
    wLn("jucer_project_settings(");
    convertSetting(jucerProject, "name", "PROJECT_NAME", {});
    convertSetting(jucerProject, "version", "PROJECT_VERSION", [](const juce::var& v) {
      return v.isVoid() ? "1.0.0" : v.toString();
    });

    convertSettingIfDefined(jucerProject, "companyName", "COMPANY_NAME", {});
    convertSettingIfDefined(jucerProject, "companyCopyright", "COMPANY_COPYRIGHT", {});
    convertSettingIfDefined(jucerProject, "companyWebsite", "COMPANY_WEBSITE", {});
    convertSettingIfDefined(jucerProject, "companyEmail", "COMPANY_EMAIL", {});

    const auto booleanWithLicenseRequiredTagline = [](const juce::var& v) {
      return juce::String{bool{v} ? "ON" : "OFF"}
             + " # Required for closed source applications without an Indie or Pro JUCE "
               "license";
    };
    convertOnOffSettingIfDefined(jucerProject, "reportAppUsage", "REPORT_JUCE_APP_USAGE",
                                 booleanWithLicenseRequiredTagline);
    convertOnOffSettingIfDefined(jucerProject, "displaySplashScreen",
                                 "DISPLAY_THE_JUCE_SPLASH_SCREEN",
                                 booleanWithLicenseRequiredTagline);
    convertSettingIfDefined(jucerProject, "splashScreenColour", "SPLASH_SCREEN_COLOUR",
                            {});

    const auto projectTypeDescription = [&projectType]() -> juce::String {
      if (projectType == "guiapp")
        return "GUI Application";

      if (projectType == "consoleapp")
        return "Console Application";

      if (projectType == "library")
        return "Static Library";

      if (projectType == "dll")
        return "Dynamic Library";

      if (projectType == "audioplug")
        return "Audio Plug-in";

      return {};
    }();
    wLn("  PROJECT_TYPE \"", projectTypeDescription, "\"");

    convertSetting(jucerProject, "bundleIdentifier", "BUNDLE_IDENTIFIER",
                   [&jucerProjectName](const juce::var& v) {
                     return v.isVoid() ? "com.yourcompany." + jucerProjectName
                                       : v.toString();
                   });

    convertSettingIfDefined(jucerProject, "maxBinaryFileSize", "BINARYDATACPP_SIZE_LIMIT",
                            [](const juce::var& v) -> juce::String {
                              if (v.toString().isEmpty())
                                return "Default";
                              return juce::File::descriptionOfSizeInBytes(int{v});
                            });
    if (jucerProject.hasProperty("includeBinaryInJuceHeader"))
    {
      convertOnOffSetting(jucerProject, "includeBinaryInJuceHeader", "INCLUDE_BINARYDATA",
                          {});
    }
    else
    {
      convertOnOffSettingIfDefined(jucerProject, "includeBinaryInAppConfig",
                                   "INCLUDE_BINARYDATA", {});
    }
    convertSettingIfDefined(jucerProject, "binaryDataNamespace", "BINARYDATA_NAMESPACE",
                            {});

    if (jucerProject.hasProperty("cppLanguageStandard"))
    {
      convertSetting(jucerProject, "cppLanguageStandard", "CXX_LANGUAGE_STANDARD",
                     [](const juce::var& v) -> juce::String {
                       const auto value = v.toString();

                       if (value == "11")
                         return "C++11";

                       if (value == "14")
                         return "C++14";

                       if (value == "latest")
                         return "Use Latest";

                       return {};
                     });
    }
    else if (jucerVersionAsTuple > Version{5, 2, 0})
    {
      wLn("  ", "CXX_LANGUAGE_STANDARD", " \"C++14\"");
    }
    else if (jucerVersionAsTuple > Version{5, 0, 2})
    {
      wLn("  ", "CXX_LANGUAGE_STANDARD", " \"C++11\"");
    }

    convertSettingAsListIfDefined(jucerProject, "defines", "PREPROCESSOR_DEFINITIONS",
                                  {});
    convertSettingAsListIfDefined(
      jucerProject, "headerPath", "HEADER_SEARCH_PATHS", [](const juce::var& v) {
        return juce::StringArray::fromTokens(v.toString(), ";\r\n", {});
      });

    writeUserNotes(wLn, jucerProject);

    wLn(")");
    wLn();

    // jucer_audio_plugin_settings()
    if (projectType == "audioplug")
    {
      wLn("jucer_audio_plugin_settings(");
      convertOnOffSettingWithDefault(jucerProject, "buildVST", "BUILD_VST", true);
      convertOnOffSettingWithDefault(jucerProject, "buildVST3", "BUILD_VST3", false);
      convertOnOffSettingWithDefault(jucerProject, "buildAU", "BUILD_AUDIOUNIT", true);
      convertOnOffSettingWithDefault(jucerProject, "buildAUv3", "BUILD_AUDIOUNIT_V3",
                                     false);
      convertOnOffSettingWithDefault(jucerProject, "buildRTAS", "BUILD_RTAS", false);
      convertOnOffSettingWithDefault(jucerProject, "buildAAX", "BUILD_AAX", false);
      if (jucerVersionAsTuple >= Version{5, 0, 0})
      {
        convertOnOffSettingWithDefault(jucerProject, "buildStandalone",
                                       "BUILD_STANDALONE_PLUGIN", false);
        convertOnOffSettingWithDefault(jucerProject, "enableIAA", "ENABLE_INTERAPP_AUDIO",
                                       false);
      }
      convertSetting(jucerProject, "pluginName", "PLUGIN_NAME", {});
      convertSetting(jucerProject, "pluginDesc", "PLUGIN_DESCRIPTION", {});
      convertSetting(jucerProject, "pluginManufacturer", "PLUGIN_MANUFACTURER", {});
      convertSetting(jucerProject, "pluginManufacturerCode", "PLUGIN_MANUFACTURER_CODE",
                     {});
      convertSetting(jucerProject, "pluginCode", "PLUGIN_CODE", {});
      convertSetting(jucerProject, "pluginChannelConfigs",
                     "PLUGIN_CHANNEL_CONFIGURATIONS", {});
      convertOnOffSettingWithDefault(jucerProject, "pluginIsSynth", "PLUGIN_IS_A_SYNTH",
                                     false);
      convertOnOffSettingWithDefault(jucerProject, "pluginWantsMidiIn",
                                     "PLUGIN_MIDI_INPUT", false);
      convertOnOffSettingWithDefault(jucerProject, "pluginProducesMidiOut",
                                     "PLUGIN_MIDI_OUTPUT", false);
      convertOnOffSettingWithDefault(jucerProject, "pluginIsMidiEffectPlugin",
                                     "MIDI_EFFECT_PLUGIN", false);
      convertOnOffSettingWithDefault(jucerProject, "pluginEditorRequiresKeys",
                                     "KEY_FOCUS", false);
      convertSetting(jucerProject, "pluginAUExportPrefix", "PLUGIN_AU_EXPORT_PREFIX", {});
      convertSetting(jucerProject, "pluginAUMainType", "PLUGIN_AU_MAIN_TYPE", {});
      convertSetting(jucerProject, "pluginVSTCategory", "VST_CATEGORY", {});
      convertSetting(jucerProject, "pluginRTASCategory", "PLUGIN_RTAS_CATEGORY", {});
      convertSetting(jucerProject, "pluginAAXCategory", "PLUGIN_AAX_CATEGORY", {});
      convertSetting(jucerProject, "aaxIdentifier", "PLUGIN_AAX_IDENTIFIER", {});
      wLn(")");
      wLn();
    }
  }

  // jucer_project_files()
  {
    const auto writeFiles =
      [&wLn](const juce::String& fullGroupName,
             const std::vector<std::tuple<bool, bool, bool, juce::String>>& files) {
        if (!files.empty())
        {
          const auto nineSpaces = "         ";

          wLn("jucer_project_files(\"", fullGroupName, "\"");
          wLn("# Compile   Xcode     Binary");
          wLn("#           Resource  Resource");

          for (const auto& file : files)
          {
            const auto compile = std::get<0>(file);
            const auto xcodeResource = std::get<1>(file);
            const auto binaryResource = std::get<2>(file);
            const auto path = std::get<3>(file);

            wLn("  ", (compile ? "x" : "."), nineSpaces, (xcodeResource ? "x" : "."),
                nineSpaces, (binaryResource ? "x" : "."), nineSpaces, "\"", path, "\"");
          }

          wLn(")");
          wLn();
        }
      };

    juce::StringArray groupNames;

    std::function<void(const juce::ValueTree&)> processGroup =
      [&groupNames, &processGroup, &writeFiles](const juce::ValueTree& group) {
        groupNames.add(group.getProperty("name").toString());

        const auto fullGroupName = groupNames.joinIntoString("/");

        std::vector<std::tuple<bool, bool, bool, juce::String>> files;

        for (auto i = 0; i < group.getNumChildren(); ++i)
        {
          const auto fileOrGroup = group.getChild(i);

          if (fileOrGroup.hasType("FILE"))
          {
            const auto& file = fileOrGroup;

            files.emplace_back(int{file.getProperty("compile")} == 1,
                               int{file.getProperty("xcodeResource")} == 1,
                               int{file.getProperty("resource")} == 1,
                               file.getProperty("file").toString());
          }
          else
          {
            writeFiles(fullGroupName, files);
            files.clear();

            processGroup(fileOrGroup);
          }
        }

        writeFiles(fullGroupName, files);

        groupNames.strings.removeLast();
      };

    processGroup(jucerProject.getChildWithName("MAINGROUP"));
  }

  // jucer_project_module()
  {
    juce::StringArray moduleNames;
    const auto modules = jucerProject.getChildWithName("MODULES");
    for (auto i = 0; i < modules.getNumChildren(); ++i)
    {
      const auto module = modules.getChild(i);
      moduleNames.add(module.getProperty("id").toString());
    }

    const auto modulePaths = jucerProject.getChildWithName("EXPORTFORMATS")
                               .getChild(0)
                               .getChildWithName("MODULEPATHS");

    for (const auto& moduleName : moduleNames)
    {
      const auto relativeModulePath =
        modulePaths.getChildWithProperty("id", moduleName).getProperty("path").toString();

      wLn("jucer_project_module(");
      wLn("  ", moduleName);
      wLn("  PATH \"", relativeModulePath, "\"");

      const auto moduleHeader = jucerFile.getParentDirectory()
                                  .getChildFile(relativeModulePath)
                                  .getChildFile(moduleName)
                                  .getChildFile(moduleName + ".h");
      juce::StringArray moduleHeaderLines;
      moduleHeader.readLines(moduleHeaderLines);

      const auto modulesOptions = jucerProject.getChildWithName("JUCEOPTIONS");

      for (const auto& line : moduleHeaderLines)
      {
        if (line.startsWith("/** Config: "))
        {
          const auto moduleOption = line.substring(12);
          const auto optionValue = modulesOptions.getProperty(moduleOption).toString();

          if (optionValue == "1" || optionValue == "enabled")
          {
            wLn("  ", moduleOption, " ON");
          }
          else if (optionValue == "0" || optionValue == "disabled")
          {
            wLn("  ", moduleOption, " OFF");
          }
          else
          {
            wLn("  # ", moduleOption);
          }
        }
      }

      wLn(")");
      wLn();
    }
  }

  // jucer_appconfig_header()
  {
    const auto appConfigFile =
      jucerFile.getSiblingFile("JuceLibraryCode").getChildFile("AppConfig.h");

    juce::StringArray appConfigLines;
    appConfigLines.addLines(appConfigFile.loadFileAsString());

    juce::StringArray userCodeSectionLines;

    for (auto i = 0; i < appConfigLines.size(); ++i)
    {
      if (appConfigLines[i].contains("[BEGIN_USER_CODE_SECTION]"))
      {
        for (auto j = i + 1; j < appConfigLines.size()
                             && !appConfigLines[j].contains("[END_USER_CODE_SECTION]");
             ++j)
        {
          userCodeSectionLines.add(appConfigLines[j]);
        }

        break;
      }
    }

    const auto kDefaultProjucerUserCodeSectionComment = juce::StringArray{
      "",
      "// (You can add your own code in this section, and the Projucer will not "
      "overwrite it)",
      ""};

    if (userCodeSectionLines != kDefaultProjucerUserCodeSectionComment)
    {
      wLn("jucer_appconfig_header(");
      wLn("  USER_CODE_SECTION");
      wLn("\"", escape("\\\"", userCodeSectionLines.joinIntoString("\n")), "\"");
      wLn(")");
      wLn();
    }
  }

  // jucer_export_target() and jucer_export_target_configuration()
  {
    const auto supportedExporters =
      juce::StringArray{"XCODE_MAC", "VS2017", "VS2015", "VS2013", "LINUX_MAKE"};
    const auto exporterNames = std::map<juce::String, const char*>{
      {"XCODE_MAC", "Xcode (MacOSX)"},  {"VS2017", "Visual Studio 2017"},
      {"VS2015", "Visual Studio 2015"}, {"VS2013", "Visual Studio 2013"},
      {"LINUX_MAKE", "Linux Makefile"},
    };

    const auto exportFormats = jucerProject.getChildWithName("EXPORTFORMATS");
    for (auto iExporter = 0; iExporter < exportFormats.getNumChildren(); ++iExporter)
    {
      const auto exporter = exportFormats.getChild(iExporter);
      const auto exporterType = exporter.getType().toString();

      if (!supportedExporters.contains(exporterType))
      {
        continue;
      }

      const auto exporterName = exporterNames.at(exporterType);
      const auto configurations = exporter.getChildWithName("CONFIGURATIONS");

      wLn("jucer_export_target(");
      wLn("  \"", exporterName, "\"");

      if (exporterType == "XCODE_MAC"
          && (exporter.hasProperty("prebuildCommand")
              || exporter.hasProperty("postbuildCommand")))
      {
        wLn("  TARGET_PROJECT_FOLDER \"", exporter.getProperty("targetFolder").toString(),
            "\"  # only used by PREBUILD_SHELL_SCRIPT and POSTBUILD_SHELL_SCRIPT");
      }

      const auto isVSExporter =
        exporterType == "VS2017" || exporterType == "VS2015" || exporterType == "VS2013";

      if (isVSExporter)
      {
        const auto needsTargetFolder = [&configurations]() {
          for (auto i = 0; i < configurations.getNumChildren(); ++i)
          {
            const auto configuration = configurations.getChild(i);

            if (configuration.hasProperty("prebuildCommand")
                || configuration.hasProperty("postbuildCommand"))
            {
              return true;
            }
          }
          return false;
        }();

        if (needsTargetFolder)
        {
          wLn("  TARGET_PROJECT_FOLDER \"",
              exporter.getProperty("targetFolder").toString(),
              "\" # only used by PREBUILD_COMMAND and POSTBUILD_COMMAND");
        }
      }

      const auto isAudioPlugin = projectType == "audioplug";

      const auto hasVst2Interface = jucerVersionAsTuple > Version{4, 2, 3};
      const auto isVstAudioPlugin =
        isAudioPlugin && bool{jucerProject.getProperty("buildVST")};
      const auto isVstPluginHost = jucerProject.getChildWithName("MODULES")
                                     .getChildWithProperty("id", "juce_audio_processors")
                                     .isValid()
                                   && jucerProject.getChildWithName("JUCEOPTIONS")
                                          .getProperty("JUCE_PLUGINHOST_VST")
                                          .toString()
                                        == "enabled";

      if (!hasVst2Interface && (isVstAudioPlugin || isVstPluginHost))
      {
        convertSetting(exporter, "vstFolder", "VST_SDK_FOLDER", {});
      }

      const auto supportsVst3 = exporterType == "XCODE_MAC" || isVSExporter;
      const auto isVst3AudioPlugin =
        isAudioPlugin && bool{jucerProject.getProperty("buildVST3")};
      const auto isVst3PluginHost = jucerProject.getChildWithName("MODULES")
                                      .getChildWithProperty("id", "juce_audio_processors")
                                      .isValid()
                                    && jucerProject.getChildWithName("JUCEOPTIONS")
                                           .getProperty("JUCE_PLUGINHOST_VST3")
                                           .toString()
                                         == "enabled";

      if (supportsVst3 && (isVst3AudioPlugin || isVst3PluginHost))
      {
        convertSetting(exporter, "vst3Folder", "VST3_SDK_FOLDER", {});
      }

      const auto supportsAaxRtas = exporterType == "XCODE_MAC" || isVSExporter;

      if (supportsAaxRtas && isAudioPlugin)
      {
        if (bool{jucerProject.getProperty("buildAAX")})
        {
          convertSetting(exporter, "aaxFolder", "AAX_SDK_FOLDER", {});
        }

        if (bool{jucerProject.getProperty("buildRTAS")})
        {
          convertSetting(exporter, "rtasFolder", "RTAS_SDK_FOLDER", {});
        }
      }

      convertSettingAsListIfDefined(exporter, "extraDefs",
                                    "EXTRA_PREPROCESSOR_DEFINITIONS", {});
      convertSettingAsListIfDefined(
        exporter, "extraCompilerFlags", "EXTRA_COMPILER_FLAGS", [](const juce::var& v) {
          return juce::StringArray::fromTokens(v.toString(), false);
        });
      convertSettingAsListIfDefined(
        exporter, "extraLinkerFlags", "EXTRA_LINKER_FLAGS", [](const juce::var& v) {
          return juce::StringArray::fromTokens(v.toString(), false);
        });
      convertSettingAsListIfDefined(exporter, "externalLibraries",
                                    "EXTERNAL_LIBRARIES_TO_LINK", {});

      convertOnOffSettingIfDefined(exporter, "enableGNUExtensions",
                                   "GNU_COMPILER_EXTENSIONS", {});

      const auto convertIcon = [&jucerProject](const juce::var& v) -> juce::String {
        const auto fileId = v.toString();

        if (!fileId.isEmpty())
        {
          const auto file = getChildWithPropertyRecursively(
            jucerProject.getChildWithName("MAINGROUP"), "id", fileId);

          if (file.isValid())
          {
            return file.getProperty("file").toString();
          }
        }

        return "<None>";
      };

      convertSettingIfDefined(exporter, "smallIcon", "ICON_SMALL", convertIcon);
      convertSettingIfDefined(exporter, "bigIcon", "ICON_LARGE", convertIcon);

      if (exporterType == "XCODE_MAC")
      {
        convertSettingAsListIfDefined(exporter, "customXcodeResourceFolders",
                                      "CUSTOM_XCODE_RESOURCE_FOLDERS", {});

        if (projectType == "guiapp")
        {
          convertSettingAsListIfDefined(
            exporter, "documentExtensions", "DOCUMENT_FILE_EXTENSIONS",
            [](const juce::var& v) {
              return juce::StringArray::fromTokens(v.toString(), ",", {});
            });
        }

        convertSettingIfDefined(exporter, "customPList", "CUSTOM_PLIST", {});
        convertSettingAsListIfDefined(
          exporter, "extraFrameworks", "EXTRA_FRAMEWORKS", [](const juce::var& v) {
            auto frameworks = juce::StringArray::fromTokens(v.toString(), ",;", "\"'");
            frameworks.trim();
            return frameworks;
          });
        convertSettingIfDefined(exporter, "prebuildCommand", "PREBUILD_SHELL_SCRIPT", {});
        convertSettingIfDefined(exporter, "postbuildCommand", "POSTBUILD_SHELL_SCRIPT",
                                {});
        convertSettingIfDefined(exporter, "iosDevelopmentTeamID", "DEVELOPMENT_TEAM_ID",
                                {});
        convertOnOffSettingIfDefined(exporter, "keepCustomXcodeSchemes",
                                     "KEEP_CUSTOM_XCODE_SCHEMES", {});
        convertOnOffSettingIfDefined(exporter, "useHeaderMap", "USE_HEADERMAP", {});
      }

      if (isVSExporter)
      {
        if (exporter.hasProperty("toolset"))
        {
          const auto toolset = exporter.getProperty("toolset").toString();
          if (toolset.isEmpty())
          {
            wLn("  # PLATFORM_TOOLSET \"(default)\"");
          }
          else
          {
            wLn("  # PLATFORM_TOOLSET \"", toolset, "\"");
          }
        }

        convertSettingIfDefined(exporter, "IPPLibrary", "USE_IPP_LIBRARY",
                                [](const juce::var& v) -> juce::String {
                                  const auto value = v.toString();

                                  if (value.isEmpty())
                                    return "No";

                                  if (value == "true")
                                    return "Yes (Default Mode)";

                                  if (value == "Parallel_Static")
                                    return "Multi-Threaded Static Library";

                                  if (value == "Sequential")
                                    return "Single-Threaded Static Library";

                                  if (value == "Parallel_Dynamic")
                                    return "Multi-Threaded DLL";

                                  if (value == "Sequential_Dynamic")
                                    return "Single-Threaded DLL";

                                  return {};
                                });

        if (exporterType == "VS2017")
        {
          convertSettingIfDefined(exporter, "cppLanguageStandard", "CXX_STANDARD_TO_USE",
                                  [](const juce::var& v) -> juce::String {
                                    const auto value = v.toString();

                                    if (value.isEmpty())
                                      return "(default)";
                                    if (value == "stdcpp14")
                                      return "C++14";
                                    if (value == "stdcpplatest")
                                      return "Latest C++ Standard";
                                    return {};
                                  });
        }
      }

      if (exporterType == "LINUX_MAKE")
      {
        convertSettingIfDefined(exporter, "cppLanguageStandard", "CXX_STANDARD_TO_USE",
                                [](const juce::var& v) -> juce::String {
                                  const auto value = v.toString();

                                  if (value == "-std=c++03")
                                    return "C++03";

                                  if (value == "-std=c++11")
                                    return "C++11";

                                  if (value == "-std=c++14")
                                    return "C++14";

                                  return {};
                                });

        convertSettingAsListIfDefined(
          exporter, "linuxExtraPkgConfig", "PKGCONFIG_LIBRARIES", [](const juce::var& v) {
            return juce::StringArray::fromTokens(v.toString(), " ", "\"'");
          });
      }

      writeUserNotes(wLn, exporter);

      wLn(")");
      wLn();

      for (auto i = 0; i < configurations.getNumChildren(); ++i)
      {
        const auto configuration = configurations.getChild(i);

        wLn("jucer_export_target_configuration(");
        wLn("  \"", exporterName, "\"");
        wLn("  NAME \"", configuration.getProperty("name").toString(), "\"");
        wLn("  DEBUG_MODE ", (bool{configuration.getProperty("isDebug")} ? "ON" : "OFF"));

        convertSettingIfDefined(configuration, "targetName", "BINARY_NAME", {});
        convertSettingIfDefined(configuration, "binaryPath", "BINARY_LOCATION", {});

        const auto isAbsolutePath = [](const juce::String& path) {
          return path.startsWithChar('/') || path.startsWithChar('~')
                 || path.startsWithChar('$')
                 || (juce::CharacterFunctions::isLetter(path[0]) && path[1] == ':');
        };

        const auto jucerFileDir = jucerFile.getParentDirectory();
        const auto targetProjectDir =
          jucerFileDir.getChildFile(exporter.getProperty("targetFolder").toString());

        const auto convertSearchPaths =
          [&isAbsolutePath, &jucerFileDir,
           &targetProjectDir](const juce::var& v) -> juce::StringArray {
          const auto searchPaths = v.toString();

          if (searchPaths.isEmpty())
          {
            return {};
          }

          juce::StringArray absOrRelToJucerFileDirPaths;

          for (const auto& path : juce::StringArray::fromTokens(searchPaths, ";\r\n", {}))
          {
            if (path.isEmpty())
            {
              continue;
            }

            if (isAbsolutePath(path))
            {
              absOrRelToJucerFileDirPaths.add(escape("\\", path));
            }
            else
            {
              absOrRelToJucerFileDirPaths.add(escape(
                "\\",
                targetProjectDir.getChildFile(path).getRelativePathFrom(jucerFileDir)));
            }
          }

          return absOrRelToJucerFileDirPaths;
        };

        convertSettingAsListIfDefined(configuration, "headerPath", "HEADER_SEARCH_PATHS",
                                      convertSearchPaths);
        convertSettingAsListIfDefined(configuration, "libraryPath",
                                      "EXTRA_LIBRARY_SEARCH_PATHS", convertSearchPaths);

        convertSettingAsListIfDefined(configuration, "defines",
                                      "PREPROCESSOR_DEFINITIONS", {});

        convertSettingIfDefined(configuration, "optimisation", "OPTIMISATION",
                                [&isVSExporter](const juce::var& v) -> juce::String {
                                  if (v.isVoid())
                                    return {};

                                  if (isVSExporter)
                                  {
                                    switch (int{v})
                                    {
                                    case 1:
                                      return "No optimisation";
                                    case 2:
                                      return "Minimise size";
                                    case 3:
                                      return "Maximise speed";
                                    }

                                    return {};
                                  }

                                  switch (int{v})
                                  {
                                  case 1:
                                    return "-O0 (no optimisation)";
                                  case 2:
                                    return "-Os (minimise code size)";
                                  case 3:
                                    return "-O3 (fastest with safe optimisations)";
                                  case 4:
                                    return "-O1 (fast)";
                                  case 5:
                                    return "-O2 (faster)";
                                  case 6:
                                    return "-Ofast (uses aggressive optimisations)";
                                  }

                                  return {};
                                });

        if (exporterType == "XCODE_MAC")
        {
          convertOnOffSettingIfDefined(configuration, "enablePluginBinaryCopyStep",
                                       "ENABLE_PLUGIN_COPY_STEP", {});

          const auto binaryLocationTuples = {
            std::make_tuple("xcodeVstBinaryLocation", "vstBinaryLocation",
                            "VST_BINARY_LOCATION"),
            std::make_tuple("xcodeVst3BinaryLocation", "vst3BinaryLocation",
                            "VST3_BINARY_LOCATION"),
            std::make_tuple("xcodeAudioUnitBinaryLocation", "auBinaryLocation",
                            "AU_BINARY_LOCATION"),
            std::make_tuple("xcodeRtasBinaryLocation", "rtasBinaryLocation",
                            "RTAS_BINARY_LOCATION"),
            std::make_tuple("xcodeAaxBinaryLocation", "aaxBinaryLocation",
                            "AAX_BINARY_LOCATION"),
          };

          for (const auto& binaryLocationTuple : binaryLocationTuples)
          {
            const auto& oldProperty = std::get<0>(binaryLocationTuple);
            const auto& newProperty = std::get<1>(binaryLocationTuple);
            const auto& cmakeKeyword = std::get<2>(binaryLocationTuple);

            if (configuration.hasProperty(oldProperty))
            {
              convertSetting(configuration, oldProperty, cmakeKeyword, {});
            }
            else
            {
              convertSettingIfDefined(configuration, newProperty, cmakeKeyword, {});
            }
          }

          const auto sdks =
            juce::StringArray{"10.5 SDK", "10.6 SDK",  "10.7 SDK",  "10.8 SDK",
                              "10.9 SDK", "10.10 SDK", "10.11 SDK", "10.12 SDK"};

          convertSettingIfDefined(configuration, "osxSDK", "OSX_BASE_SDK_VERSION",
                                  [&sdks](const juce::var& v) -> juce::String {
                                    const auto value = v.toString();

                                    if (value == "default")
                                      return "Use Default";

                                    if (sdks.contains(value))
                                      return value;

                                    return {};
                                  });

          convertSettingIfDefined(configuration, "osxCompatibility",
                                  "OSX_DEPLOYMENT_TARGET",
                                  [&sdks](const juce::var& v) -> juce::String {
                                    const auto value = v.toString();

                                    if (value == "default")
                                      return "Use Default";

                                    if (sdks.contains(value))
                                      return value.substring(0, value.length() - 4);

                                    return {};
                                  });

          convertSettingIfDefined(configuration, "osxArchitecture", "OSX_ARCHITECTURE",
                                  [](const juce::var& v) -> juce::String {
                                    const auto value = v.toString();

                                    if (value == "default")
                                      return "Use Default";

                                    if (value == "Native")
                                      return "Native architecture of build machine";

                                    if (value == "32BitUniversal")
                                      return "Universal Binary (32-bit)";

                                    if (value == "64BitUniversal")
                                      return "Universal Binary (32/64-bit)";

                                    if (value == "64BitIntel")
                                      return "64-bit Intel";

                                    return {};
                                  });

          convertSettingAsListIfDefined(configuration, "customXcodeFlags",
                                        "CUSTOM_XCODE_FLAGS", [](const juce::var& v) {
                                          return juce::StringArray::fromTokens(
                                            v.toString(), ",", "\"'");
                                        });

          convertSettingIfDefined(configuration, "cppLanguageStandard",
                                  "CXX_LANGUAGE_STANDARD",
                                  [](const juce::var& v) -> juce::String {
                                    const auto value = v.toString();

                                    if (value.isEmpty())
                                      return "Use Default";

                                    if (value == "c++98")
                                      return "C++98";

                                    if (value == "gnu++98")
                                      return "GNU++98";

                                    if (value == "c++11")
                                      return "C++11";

                                    if (value == "gnu++11")
                                      return "GNU++11";

                                    if (value == "c++14")
                                      return "C++14";

                                    if (value == "gnu++14")
                                      return "GNU++14";

                                    return {};
                                  });

          convertSettingIfDefined(configuration, "cppLibType", "CXX_LIBRARY",
                                  [](const juce::var& v) -> juce::String {
                                    const auto value = v.toString();

                                    if (value.isEmpty())
                                      return "Use Default";

                                    if (value == "libc++")
                                      return "LLVM libc++";

                                    if (value == "libstdc++")
                                      return "GNU libstdc++";

                                    return {};
                                  });

          convertSettingIfDefined(configuration, "codeSigningIdentity",
                                  "CODE_SIGNING_IDENTITY", {});
          convertOnOffSettingIfDefined(configuration, "fastMath", "RELAX_IEEE_COMPLIANCE",
                                       {});
          convertOnOffSettingIfDefined(configuration, "linkTimeOptimisation",
                                       "LINK_TIME_OPTIMISATION", {});
          convertOnOffSettingIfDefined(configuration, "stripLocalSymbols",
                                       "STRIP_LOCAL_SYMBOLS", {});
        }

        if (isVSExporter)
        {
          convertOnOffSettingIfDefined(configuration, "enablePluginBinaryCopyStep",
                                       "ENABLE_PLUGIN_COPY_STEP", {});

          convertSettingIfDefined(configuration, "vstBinaryLocation",
                                  "VST_BINARY_LOCATION", {});
          convertSettingIfDefined(configuration, "vst3BinaryLocation",
                                  "VST3_BINARY_LOCATION", {});
          convertSettingIfDefined(configuration, "rtasBinaryLocation",
                                  "RTAS_BINARY_LOCATION", {});
          convertSettingIfDefined(configuration, "aaxBinaryLocation",
                                  "AAX_BINARY_LOCATION", {});

          convertSettingIfDefined(configuration, "winWarningLevel", "WARNING_LEVEL",
                                  [](const juce::var& v) -> juce::String {
                                    switch (int{v})
                                    {
                                    case 2:
                                      return "Low";
                                    case 3:
                                      return "Medium";
                                    case 4:
                                      return "High";
                                    }

                                    return "High";
                                  });

          convertOnOffSettingIfDefined(configuration, "warningsAreErrors",
                                       "TREAT_WARNINGS_AS_ERRORS", {});

          convertSettingIfDefined(configuration, "useRuntimeLibDLL", "RUNTIME_LIBRARY",
                                  [](const juce::var& v) -> juce::String {
                                    const auto value = v.toString();

                                    if (value.isEmpty())
                                      return "(Default)";

                                    if (value == "0")
                                      return "Use static runtime";

                                    if (value == "1")
                                      return "Use DLL runtime";

                                    return {};
                                  });

          convertSettingIfDefined(configuration, "wholeProgramOptimisation",
                                  "WHOLE_PROGRAM_OPTIMISATION",
                                  [](const juce::var& v) -> juce::String {
                                    if (v.toString().isEmpty())
                                      return "Enable when possible";

                                    if (int{v} > 0)
                                      return "Always disable";

                                    return {};
                                  });

          convertOnOffSettingIfDefined(configuration, "enableIncrementalLinking",
                                       "INCREMENTAL_LINKING", {});
          convertSettingIfDefined(configuration, "prebuildCommand", "PREBUILD_COMMAND",
                                  {});
          convertSettingIfDefined(configuration, "postbuildCommand", "POSTBUILD_COMMAND",
                                  {});
          convertOnOffSettingIfDefined(configuration, "generateManifest",
                                       "GENERATE_MANIFEST", {});

          convertSettingIfDefined(configuration, "characterSet", "CHARACTER_SET",
                                  [](const juce::var& v) -> juce::String {
                                    const auto value = v.toString();

                                    if (value.isEmpty())
                                      return "Default";

                                    return value;
                                  });

          if (configuration.hasProperty("winArchitecture"))
          {
            const auto winArchitecture =
              configuration.getProperty("winArchitecture").toString();
            if (winArchitecture.isEmpty())
            {
              wLn("  # ARCHITECTURE");
            }
            else
            {
              wLn("  # ARCHITECTURE \"", winArchitecture, "\"");
            }
          }

          convertOnOffSettingIfDefined(configuration, "fastMath", "RELAX_IEEE_COMPLIANCE",
                                       {});
        }

        if (exporterType == "LINUX_MAKE")
        {
          convertSettingIfDefined(configuration, "linuxArchitecture", "ARCHITECTURE",
                                  [](const juce::var& v) -> juce::String {
                                    if (v.isVoid())
                                      return "(Default)";

                                    const auto value = v.toString();

                                    if (value.isEmpty())
                                      return "<None>";

                                    if (value == "-m32")
                                      return "32-bit (-m32)";

                                    if (value == "-m64")
                                      return "64-bit (-m64)";

                                    if (value == "-march=armv6")
                                      return "ARM v6";

                                    if (value == "-march=armv7")
                                      return "ARM v7";

                                    return {};
                                  });
        }

        writeUserNotes(wLn, configuration);

        wLn(")");
        wLn();
      }
    }
  }

  out << "jucer_project_end()" << kNewLine << std::flush;

  std::cout << juce::File::getCurrentWorkingDirectory()
                 .getChildFile("CMakeLists.txt")
                 .getFullPathName()
            << " has been successfully generated." << std::endl;

  return 0;
}
