# Copyright (c) 2016 Alain Martin
#
# This file is part of FRUT.
#
# FRUT is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# FRUT is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with FRUT.  If not, see <http://www.gnu.org/licenses/>.

if(CMAKE_VERSION VERSION_LESS 3.4)
  message(FATAL_ERROR "Reprojucer requires at least CMake version 3.4")
endif()


set(Reprojucer.cmake_DIR "${CMAKE_CURRENT_LIST_DIR}")
set(Reprojucer_templates_DIR "${Reprojucer.cmake_DIR}/templates")

set(Reprojucer_supported_exporters
  "Xcode (MacOSX)"
  "Visual Studio 2017"
  "Visual Studio 2015"
  "Visual Studio 2013"
  "Linux Makefile"
)
set(Reprojucer_supported_exporters_conditions
  "APPLE"
  "MSVC_VERSION\;GREATER\;1909"
  "MSVC_VERSION\;EQUAL\;1900"
  "MSVC_VERSION\;EQUAL\;1800"
  "CMAKE_HOST_SYSTEM_NAME\;STREQUAL\;Linux"
)


function(jucer_project_begin)

  _FRUT_parse_arguments("JUCER_VERSION;PROJECT_FILE;PROJECT_ID" "" "${ARGN}")

  if(DEFINED _JUCER_VERSION)
    set(JUCER_VERSION "${_JUCER_VERSION}" PARENT_SCOPE)
  endif()

  if(DEFINED _PROJECT_FILE)
    if(NOT EXISTS "${_PROJECT_FILE}")
      message(FATAL_ERROR "No such JUCE project file: ${_PROJECT_FILE}")
    endif()
    get_filename_component(project_dir "${_PROJECT_FILE}" DIRECTORY)
    set(JUCER_PROJECT_DIR "${project_dir}" PARENT_SCOPE)
  endif()

  if(DEFINED _PROJECT_ID)
    set(JUCER_PROJECT_ID "${_PROJECT_ID}" PARENT_SCOPE)
  endif()

endfunction()


function(jucer_project_settings)

  set(single_value_keywords
    "PROJECT_NAME"
    "PROJECT_VERSION"
    "COMPANY_NAME"
    "COMPANY_COPYRIGHT"
    "COMPANY_WEBSITE"
    "COMPANY_EMAIL"
    "REPORT_JUCE_APP_USAGE"
    "DISPLAY_THE_JUCE_SPLASH_SCREEN"
    "SPLASH_SCREEN_COLOUR"
    "PROJECT_TYPE"
    "BUNDLE_IDENTIFIER"
    "BINARYDATACPP_SIZE_LIMIT"
    "INCLUDE_BINARYDATA"
    "BINARYDATA_NAMESPACE"
    "CXX_LANGUAGE_STANDARD"
  )
  set(multi_value_keywords
    "PREPROCESSOR_DEFINITIONS"
    "HEADER_SEARCH_PATHS"
  )

  _FRUT_parse_arguments("${single_value_keywords}" "${multi_value_keywords}" "${ARGN}")

  if(NOT DEFINED _PROJECT_NAME)
    message(FATAL_ERROR "Missing PROJECT_NAME argument")
  endif()

  if(DEFINED _PROJECT_VERSION)
    string(REGEX MATCH ".+\\..+\\..+(\\..+)?" version_match "${_PROJECT_VERSION}")
    if(NOT _PROJECT_VERSION STREQUAL version_match)
      message(WARNING "The PROJECT_VERSION doesn't seem to be in the format "
        "major.minor.point[.point]"
      )
    endif()
    _FRUT_version_to_hex("${_PROJECT_VERSION}" hex_value)
    set(JUCER_PROJECT_VERSION_AS_HEX "${hex_value}" PARENT_SCOPE)
  endif()

  if(NOT DEFINED _PROJECT_TYPE)
    message(FATAL_ERROR "Missing PROJECT_TYPE argument")
  endif()
  set(project_types "GUI Application" "Console Application" "Static Library"
    "Dynamic Library" "Audio Plug-in"
  )
  if(NOT "${_PROJECT_TYPE}" IN_LIST project_types)
    message(FATAL_ERROR "Unsupported project type: \"${_PROJECT_TYPE}\"\n"
      "Supported project types: ${project_types}"
    )
  endif()

  if(DEFINED _BINARYDATACPP_SIZE_LIMIT)
    set(size_limit_descs "Default" "20.0 MB" "10.0 MB" "6.0 MB" "2.0 MB" "1.0 MB"
      "512.0 KB" "256.0 KB" "128.0 KB" "64.0 KB"
    )
    set(size_limits 10240 20480 10240 6144 2048 1024 512 256 128 64)

    list(FIND size_limit_descs "${_BINARYDATACPP_SIZE_LIMIT}" size_limit_index)
    if(size_limit_index EQUAL -1)
      message(FATAL_ERROR "Unsupported value for BINARYDATACPP_SIZE_LIMIT: "
        "\"${_BINARYDATACPP_SIZE_LIMIT}\"\nSupported values: ${size_limit_descs}"
      )
    endif()
    list(GET size_limits ${size_limit_index} _BINARYDATACPP_SIZE_LIMIT)
  endif()

  if(DEFINED _CXX_LANGUAGE_STANDARD)
    set(cxx_lang_standard_descs "C++11" "C++14" "Use Latest")
    set(cxx_lang_standards "11" "14" "latest")

    list(FIND cxx_lang_standard_descs "${_CXX_LANGUAGE_STANDARD}" cxx_lang_standard_index)
    if(cxx_lang_standard_index EQUAL -1)
      message(FATAL_ERROR "Unsupported value for CXX_LANGUAGE_STANDARD: "
        "\"${_CXX_LANGUAGE_STANDARD}\"\nSupported values: ${cxx_lang_standard_descs}"
      )
    endif()
    list(GET cxx_lang_standards ${cxx_lang_standard_index} _CXX_LANGUAGE_STANDARD)
  endif()

  if(DEFINED _HEADER_SEARCH_PATHS)
    unset(header_search_paths)
    foreach(path ${_HEADER_SEARCH_PATHS})
      string(REPLACE "\\" "/" path "${path}")
      _FRUT_abs_path_based_on_jucer_project_dir("${path}" path)
      list(APPEND header_search_paths "${path}")
    endforeach()
    set(_HEADER_SEARCH_PATHS ${header_search_paths})
  endif()

  foreach(keyword ${single_value_keywords} ${multi_value_keywords})
    if(DEFINED _${keyword})
      set(JUCER_${keyword} ${_${keyword}} PARENT_SCOPE)
    endif()
  endforeach()

endfunction()


function(jucer_audio_plugin_settings)

  set(single_value_keywords
    "BUILD_VST"
    "BUILD_VST3"
    "BUILD_AUDIOUNIT"
    "BUILD_AUDIOUNIT_V3"
    "BUILD_RTAS"
    "BUILD_AAX"
    "BUILD_STANDALONE_PLUGIN"
    "ENABLE_INTERAPP_AUDIO"
    "PLUGIN_NAME"
    "PLUGIN_DESCRIPTION"
    "PLUGIN_MANUFACTURER"
    "PLUGIN_MANUFACTURER_CODE"
    "PLUGIN_CODE"
    "PLUGIN_CHANNEL_CONFIGURATIONS"
    "PLUGIN_IS_A_SYNTH"
    "PLUGIN_MIDI_INPUT"
    "PLUGIN_MIDI_OUTPUT"
    "MIDI_EFFECT_PLUGIN"
    "KEY_FOCUS"
    "PLUGIN_AU_EXPORT_PREFIX"
    "PLUGIN_AU_MAIN_TYPE"
    "VST_CATEGORY"
    "PLUGIN_RTAS_CATEGORY"
    "PLUGIN_AAX_CATEGORY"
    "PLUGIN_AAX_IDENTIFIER"
  )

  _FRUT_parse_arguments("${single_value_keywords}" "" "${ARGN}")

  if(_BUILD_RTAS AND (APPLE OR MSVC))
    message(WARNING "Reprojucer.cmake doesn't support building RTAS plugins. If you "
      "would like Reprojucer.cmake to support building RTAS plugins, please leave a "
      "comment on the issue \"Reprojucer.cmake doesn't support building RTAS plugins\" "
      "on GitHub: https://github.com/McMartin/FRUT/issues/266"
    )
  endif()

  if(_BUILD_AAX AND (APPLE OR MSVC))
    message(WARNING "Reprojucer.cmake doesn't support building AAX plugins. If you "
      "would like Reprojucer.cmake to support building AAX plugins, please leave a "
      "comment on the issue \"Reprojucer.cmake doesn't support building AAX plugins\" "
      "on GitHub: https://github.com/McMartin/FRUT/issues/267"
    )
  endif()

  if(DEFINED _BUILD_STANDALONE_PLUGIN
      AND DEFINED JUCER_VERSION AND JUCER_VERSION VERSION_LESS 5.0.0)
    message(WARNING "BUILD_STANDALONE_PLUGIN is a JUCE 5 feature only")
  endif()

  if(DEFINED _ENABLE_INTERAPP_AUDIO
      AND DEFINED JUCER_VERSION AND JUCER_VERSION VERSION_LESS 5.0.0)
    message(WARNING "ENABLE_INTERAPP_AUDIO is a JUCE 5 feature only")
  endif()

  foreach(keyword ${single_value_keywords})
    if(DEFINED _${keyword})
      set(JUCER_${keyword} ${_${keyword}} PARENT_SCOPE)
    endif()
  endforeach()

endfunction()


function(jucer_project_files source_group_name)

  function(__check_input input)
    if(NOT input STREQUAL "x" AND NOT input STREQUAL ".")
      message(FATAL_ERROR "Expected x or . token, got ${input} instead")
    endif()
  endfunction()

  unset(compile)
  unset(xcode_resource)
  unset(binary_resource)
  unset(files)
  foreach(element ${ARGN})
    if(NOT DEFINED compile)
      set(compile ${element})
      __check_input("${compile}")
    elseif(NOT DEFINED xcode_resource)
      set(xcode_resource ${element})
      __check_input("${xcode_resource}")
    elseif(NOT DEFINED binary_resource)
      set(binary_resource ${element})
      __check_input("${binary_resource}")
    else()
      set(path ${element})

      _FRUT_abs_path_based_on_jucer_project_dir("${path}" path)
      list(APPEND files "${path}")

      if(xcode_resource STREQUAL "x")
        list(APPEND JUCER_PROJECT_XCODE_RESOURCES "${path}")
      elseif(binary_resource STREQUAL "x")
        list(APPEND JUCER_PROJECT_RESOURCES "${path}")
      else()
        list(APPEND JUCER_PROJECT_SOURCES "${path}")

        get_filename_component(file_extension "${path}" EXT)

        if(NOT file_extension STREQUAL ".h" AND compile STREQUAL ".")
          set_source_files_properties("${path}" PROPERTIES HEADER_FILE_ONLY TRUE)
        endif()

        if(file_extension STREQUAL ".mm" AND NOT APPLE)
          set_source_files_properties("${path}" PROPERTIES HEADER_FILE_ONLY TRUE)
        endif()
      endif()

      unset(compile)
      unset(xcode_resource)
      unset(binary_resource)
    endif()
  endforeach()

  string(REPLACE "/" "\\" source_group_name ${source_group_name})
  source_group(${source_group_name} FILES ${files})

  set(JUCER_PROJECT_SOURCES ${JUCER_PROJECT_SOURCES} PARENT_SCOPE)
  set(JUCER_PROJECT_RESOURCES ${JUCER_PROJECT_RESOURCES} PARENT_SCOPE)
  set(JUCER_PROJECT_XCODE_RESOURCES ${JUCER_PROJECT_XCODE_RESOURCES} PARENT_SCOPE)

endfunction()


function(jucer_project_module module_name PATH_KEYWORD modules_folder)

  list(APPEND JUCER_PROJECT_MODULES ${module_name})
  set(JUCER_PROJECT_MODULES ${JUCER_PROJECT_MODULES} PARENT_SCOPE)

  _FRUT_abs_path_based_on_jucer_project_dir("${modules_folder}" modules_folder)
  if(NOT IS_DIRECTORY "${modules_folder}")
    message(FATAL_ERROR "No such directory: \"${modules_folder}\"")
  endif()
  list(APPEND JUCER_PROJECT_MODULES_FOLDERS "${modules_folder}")
  set(JUCER_PROJECT_MODULES_FOLDERS ${JUCER_PROJECT_MODULES_FOLDERS} PARENT_SCOPE)

  file(GLOB module_src_files
    "${modules_folder}/${module_name}/*.cpp"
    "${modules_folder}/${module_name}/*.mm"
  )

  if(DEFINED JUCER_VERSION AND JUCER_VERSION VERSION_LESS 5.0.0)
    set(proxy_prefix)
  else()
    set(proxy_prefix "include_")
  endif()

  foreach(src_file ${module_src_files})
    unset(to_compile)

    if(  (src_file MATCHES "_AU[._]"   AND NOT (JUCER_BUILD_AUDIOUNIT    AND APPLE))
      OR (src_file MATCHES "_AUv3[._]" AND NOT (JUCER_BUILD_AUDIOUNIT_V3 AND APPLE))
      OR (src_file MATCHES "_AAX[._]"  AND NOT (JUCER_BUILD_AAX          AND (APPLE OR MSVC)))
      OR (src_file MATCHES "_RTAS[._]" AND NOT (JUCER_BUILD_RTAS         AND (APPLE OR MSVC)))
      OR (src_file MATCHES "_VST2[._]" AND NOT (JUCER_BUILD_VST          AND TRUE))
      OR (src_file MATCHES "_VST3[._]" AND NOT (JUCER_BUILD_VST3         AND (APPLE OR MSVC)))
    )
      set(to_compile FALSE)
    endif()

    if(DEFINED JUCER_VERSION AND JUCER_VERSION VERSION_LESS 5.0.0)
      if(src_file MATCHES "_Standalone[._]" AND NOT (JUCER_BUILD_AUDIOUNIT_V3 AND APPLE))
        set(to_compile FALSE)
      endif()
    else()
      if(src_file MATCHES "_Standalone[._]" AND NOT JUCER_BUILD_STANDALONE_PLUGIN)
        set(to_compile FALSE)
      endif()
    endif()

    if(NOT DEFINED to_compile)
      get_filename_component(src_file_extension "${src_file}" EXT)
      if(src_file_extension STREQUAL ".mm")
        if(APPLE)
          set(to_compile TRUE)
        endif()
      elseif(APPLE)
        string(REGEX REPLACE "${src_file_extension}$" ".mm" objcxx_src_file "${src_file}")
        if(NOT "${objcxx_src_file}" IN_LIST module_src_files)
          set(to_compile TRUE)
        endif()
      else()
        set(to_compile TRUE)
      endif()
    endif()

    if(to_compile)
      get_filename_component(src_file_basename "${src_file}" NAME)
      configure_file("${Reprojucer_templates_DIR}/JuceLibraryCode-Wrapper.cpp"
        "JuceLibraryCode/${proxy_prefix}${src_file_basename}"
      )
      list(APPEND JUCER_PROJECT_SOURCES
        "${CMAKE_CURRENT_BINARY_DIR}/JuceLibraryCode/${proxy_prefix}${src_file_basename}"
      )
    endif()
  endforeach()

  set(JUCER_PROJECT_SOURCES ${JUCER_PROJECT_SOURCES} PARENT_SCOPE)

  set(module_header_file "${modules_folder}/${module_name}/${module_name}.h")

  file(STRINGS "${module_header_file}" config_flags_lines REGEX "/\\*\\* Config: ")
  string(REPLACE "/** Config: " "" module_config_flags "${config_flags_lines}")
  set(JUCER_${module_name}_CONFIG_FLAGS ${module_config_flags} PARENT_SCOPE)

  unset(config_flag)
  foreach(element ${ARGN})
    if(NOT DEFINED config_flag)
      set(config_flag ${element})

      if(NOT "${config_flag}" IN_LIST module_config_flags)
        message(WARNING "Unknown config flag ${config_flag} in module ${module_name}")
      endif()
    else()
      set(JUCER_FLAG_${config_flag} ${element} PARENT_SCOPE)
      unset(config_flag)
    endif()
  endforeach()

  unset(module_info_OSXFrameworks)
  unset(module_info_linuxLibs)
  unset(module_info_linuxPackages)
  unset(module_info_minimumCppStandard)

  file(STRINGS "${module_header_file}" all_lines)
  set(in_module_declaration FALSE)
  foreach(line ${all_lines})
    string(STRIP "${line}" stripped_line)
    if(stripped_line MATCHES "^BEGIN_JUCE_MODULE_DECLARATION")
      set(in_module_declaration TRUE)
      continue()
    elseif(stripped_line MATCHES "^END_JUCE_MODULE_DECLARATION")
      break()
    endif()

    if(in_module_declaration)
      string(FIND "${line}" ":" colon_pos)
      if(NOT colon_pos EQUAL -1)
        string(SUBSTRING "${line}" 0 ${colon_pos} key)
        string(STRIP "${key}" key)
        math(EXPR colon_pos_plus_one "${colon_pos} + 1")
        string(SUBSTRING "${line}" ${colon_pos_plus_one} -1 value)
        string(STRIP "${value}" value)
        set(module_info_${key} ${value})
      endif()
    endif()
  endforeach()

  string(REPLACE " " ";" osx_frameworks "${module_info_OSXFrameworks}")
  string(REPLACE "," ";" osx_frameworks "${osx_frameworks}")
  list(APPEND JUCER_PROJECT_OSX_FRAMEWORKS ${osx_frameworks})
  set(JUCER_PROJECT_OSX_FRAMEWORKS ${JUCER_PROJECT_OSX_FRAMEWORKS} PARENT_SCOPE)

  string(REPLACE " " ";" linux_libs "${module_info_linuxLibs}")
  string(REPLACE "," ";" linux_libs "${linux_libs}")
  list(APPEND JUCER_PROJECT_LINUX_LIBS ${linux_libs})
  set(JUCER_PROJECT_LINUX_LIBS ${JUCER_PROJECT_LINUX_LIBS} PARENT_SCOPE)

  string(REPLACE " " ";" linux_packages "${module_info_linuxPackages}")
  string(REPLACE "," ";" linux_packages "${linux_packages}")
  list(APPEND JUCER_PROJECT_LINUX_PACKAGES ${linux_packages})
  set(JUCER_PROJECT_LINUX_PACKAGES ${JUCER_PROJECT_LINUX_PACKAGES} PARENT_SCOPE)

  if(DEFINED module_info_minimumCppStandard)
    unset(project_cxx_standard)
    if(DEFINED JUCER_CXX_LANGUAGE_STANDARD)
      set(project_cxx_standard ${JUCER_CXX_LANGUAGE_STANDARD})
    elseif(NOT (DEFINED JUCER_VERSION AND JUCER_VERSION VERSION_LESS 5.1.0))
      set(project_cxx_standard 11)
    endif()
    if(DEFINED project_cxx_standard AND NOT ("${project_cxx_standard}" STREQUAL "latest")
        AND ("${module_info_minimumCppStandard}" STREQUAL "latest"
          OR ${module_info_minimumCppStandard} GREATER ${project_cxx_standard}))
      message(WARNING "${module_name} has a higher C++ language standard requirement"
        " (${module_info_minimumCppStandard}) than your project"
        " (${project_cxx_standard}). To use this module you need to increase the C++"
        " language standard of the project."
      )
    endif()
  endif()

  file(GLOB_RECURSE browsable_files "${modules_folder}/${module_name}/*")
  foreach(file_path ${browsable_files})
    get_filename_component(file_dir "${file_path}" DIRECTORY)
    string(REPLACE "${modules_folder}" "" rel_file_dir "${file_dir}")
    string(REPLACE "/" "\\" sub_group_name "${rel_file_dir}")
    source_group("Juce Modules${sub_group_name}" FILES "${file_path}")
  endforeach()
  list(APPEND JUCER_PROJECT_BROWSABLE_FILES ${browsable_files})
  set(JUCER_PROJECT_BROWSABLE_FILES ${JUCER_PROJECT_BROWSABLE_FILES} PARENT_SCOPE)

endfunction()


function(jucer_appconfig_header USER_CODE_SECTION_KEYWORD user_code_section)

  if(NOT USER_CODE_SECTION_KEYWORD STREQUAL "USER_CODE_SECTION")
    message(FATAL_ERROR "Invalid second argument. Expected \"USER_CODE_SECTION\" "
      "keyword, but got \"${USER_CODE_SECTION_KEYWORD}\" instead."
    )
  endif()

  set(JUCER_APPCONFIG_USER_CODE_SECTION "${user_code_section}" PARENT_SCOPE)

endfunction()


function(jucer_export_target exporter)

  if(NOT "${exporter}" IN_LIST Reprojucer_supported_exporters)
    message(FATAL_ERROR "Unsupported exporter: ${exporter}\n"
      "Supported exporters: ${Reprojucer_supported_exporters}"
    )
  endif()
  list(APPEND JUCER_PROJECT_EXPORT_TARGETS "${exporter}")
  set(JUCER_PROJECT_EXPORT_TARGETS ${JUCER_PROJECT_EXPORT_TARGETS} PARENT_SCOPE)

  list(FIND Reprojucer_supported_exporters "${exporter}" exporter_index)
  list(GET Reprojucer_supported_exporters_conditions ${exporter_index} condition)
  if(NOT ${condition})
    return()
  endif()

  set(single_value_keywords
    "TARGET_PROJECT_FOLDER"
    "VST_SDK_FOLDER"
    "ICON_SMALL"
    "ICON_LARGE"
  )
  set(multi_value_keywords
    "EXTRA_PREPROCESSOR_DEFINITIONS"
    "EXTRA_COMPILER_FLAGS"
    "EXTRA_LINKER_FLAGS"
    "EXTERNAL_LIBRARIES_TO_LINK"
  )

  if(exporter STREQUAL "Xcode (MacOSX)")
    list(APPEND single_value_keywords
      "VST3_SDK_FOLDER"
      "AAX_SDK_FOLDER"
      "RTAS_SDK_FOLDER"
      "CUSTOM_PLIST"
      "PREBUILD_SHELL_SCRIPT"
      "POSTBUILD_SHELL_SCRIPT"
      "DEVELOPMENT_TEAM_ID"
      "KEEP_CUSTOM_XCODE_SCHEMES"
      "USE_HEADERMAP"
    )
    list(APPEND multi_value_keywords
      "CUSTOM_XCODE_RESOURCE_FOLDERS"
      "EXTRA_FRAMEWORKS"
    )

    if(JUCER_PROJECT_TYPE STREQUAL "GUI Application")
      list(APPEND multi_value_keywords
        "DOCUMENT_FILE_EXTENSIONS"
      )
    endif()
  endif()

  if(exporter MATCHES "^Visual Studio 201(7|5|3)$")
    list(APPEND single_value_keywords
      "VST3_SDK_FOLDER"
      "AAX_SDK_FOLDER"
      "RTAS_SDK_FOLDER"
      "PLATFORM_TOOLSET"
      "USE_IPP_LIBRARY"
    )

    if(exporter STREQUAL "Visual Studio 2017")
      list(APPEND single_value_keywords "CXX_STANDARD_TO_USE")
    endif()
  else()
    list(APPEND single_value_keywords "GNU_COMPILER_EXTENSIONS")
  endif()

  if(exporter STREQUAL "Linux Makefile")
    list(APPEND single_value_keywords
      "CXX_STANDARD_TO_USE"
    )
    list(APPEND multi_value_keywords
      "PKGCONFIG_LIBRARIES"
    )
  endif()

  _FRUT_parse_arguments("${single_value_keywords}" "${multi_value_keywords}" "${ARGN}")

  if(DEFINED _TARGET_PROJECT_FOLDER)
    string(REPLACE "\\" "/" project_folder "${_TARGET_PROJECT_FOLDER}")
    _FRUT_abs_path_based_on_jucer_project_dir("${project_folder}" project_folder)
    set(JUCER_TARGET_PROJECT_FOLDER ${project_folder} PARENT_SCOPE)
  endif()

  if(DEFINED _VST_SDK_FOLDER)
    string(REPLACE "\\" "/" sdk_folder "${_VST_SDK_FOLDER}")
    _FRUT_abs_path_based_on_jucer_project_dir("${sdk_folder}" sdk_folder)
    set(JUCER_VST_SDK_FOLDER ${sdk_folder} PARENT_SCOPE)
  endif()

  if(DEFINED _VST3_SDK_FOLDER)
    string(REPLACE "\\" "/" sdk_folder "${_VST3_SDK_FOLDER}")
    _FRUT_abs_path_based_on_jucer_project_dir("${sdk_folder}" sdk_folder)
    set(JUCER_VST3_SDK_FOLDER ${sdk_folder} PARENT_SCOPE)
  endif()

  if(DEFINED _AAX_SDK_FOLDER)
    string(REPLACE "\\" "/" sdk_folder "${_AAX_SDK_FOLDER}")
    _FRUT_abs_path_based_on_jucer_project_dir("${sdk_folder}" sdk_folder)
    set(JUCER_AAX_SDK_FOLDER ${sdk_folder} PARENT_SCOPE)
  endif()

  if(DEFINED _RTAS_SDK_FOLDER)
    string(REPLACE "\\" "/" sdk_folder "${_RTAS_SDK_FOLDER}")
    _FRUT_abs_path_based_on_jucer_project_dir("${sdk_folder}" sdk_folder)
    set(JUCER_RTAS_SDK_FOLDER ${sdk_folder} PARENT_SCOPE)
  endif()

  if(DEFINED _EXTRA_PREPROCESSOR_DEFINITIONS)
    set(JUCER_EXTRA_PREPROCESSOR_DEFINITIONS ${_EXTRA_PREPROCESSOR_DEFINITIONS}
      PARENT_SCOPE
    )
  endif()

  if(DEFINED _EXTRA_COMPILER_FLAGS)
    set(JUCER_EXTRA_COMPILER_FLAGS ${_EXTRA_COMPILER_FLAGS} PARENT_SCOPE)
  endif()

  if(DEFINED _EXTRA_LINKER_FLAGS)
    set(JUCER_EXTRA_LINKER_FLAGS ${_EXTRA_LINKER_FLAGS} PARENT_SCOPE)
  endif()

  if(DEFINED _EXTERNAL_LIBRARIES_TO_LINK)
    set(JUCER_EXTERNAL_LIBRARIES_TO_LINK ${_EXTERNAL_LIBRARIES_TO_LINK} PARENT_SCOPE)
  endif()

  if(DEFINED _GNU_COMPILER_EXTENSIONS)
    set(JUCER_GNU_COMPILER_EXTENSIONS ${_GNU_COMPILER_EXTENSIONS} PARENT_SCOPE)
  endif()

  if(DEFINED _ICON_SMALL)
    if(NOT _ICON_SMALL STREQUAL "<None>")
      _FRUT_abs_path_based_on_jucer_project_dir("${_ICON_SMALL}" small_icon)
      set(JUCER_SMALL_ICON ${small_icon} PARENT_SCOPE)
    endif()
  endif()

  if(DEFINED _ICON_LARGE)
    if(NOT _ICON_LARGE STREQUAL "<None>")
      _FRUT_abs_path_based_on_jucer_project_dir("${_ICON_LARGE}" large_icon)
      set(JUCER_LARGE_ICON ${large_icon} PARENT_SCOPE)
    endif()
  endif()

  if(DEFINED _CUSTOM_XCODE_RESOURCE_FOLDERS)
    unset(resource_folders)
    foreach(folder ${_CUSTOM_XCODE_RESOURCE_FOLDERS})
      _FRUT_abs_path_based_on_jucer_project_dir("${folder}" abs_folder)
      list(APPEND resource_folders "${abs_folder}")
    endforeach()
    set(JUCER_CUSTOM_XCODE_RESOURCE_FOLDERS ${resource_folders} PARENT_SCOPE)
  endif()

  if(DEFINED _DOCUMENT_FILE_EXTENSIONS)
    set(JUCER_DOCUMENT_FILE_EXTENSIONS ${_DOCUMENT_FILE_EXTENSIONS} PARENT_SCOPE)
  endif()

  if(DEFINED _EXTRA_FRAMEWORKS)
    set(JUCER_EXTRA_FRAMEWORKS ${_EXTRA_FRAMEWORKS} PARENT_SCOPE)
  endif()

  if(DEFINED _CUSTOM_PLIST)
    set(JUCER_CUSTOM_PLIST "${_CUSTOM_PLIST}" PARENT_SCOPE)
  endif()

  if(DEFINED _PREBUILD_SHELL_SCRIPT)
    set(script_content "${_PREBUILD_SHELL_SCRIPT}")
    configure_file("${Reprojucer_templates_DIR}/script.in" "prebuild.sh" @ONLY)
    set(JUCER_PREBUILD_SHELL_SCRIPT
      "${CMAKE_CURRENT_BINARY_DIR}/prebuild.sh" PARENT_SCOPE
    )
  endif()

  if(DEFINED _POSTBUILD_SHELL_SCRIPT)
    set(script_content "${_POSTBUILD_SHELL_SCRIPT}")
    configure_file("${Reprojucer_templates_DIR}/script.in" "postbuild.sh" @ONLY)
    set(JUCER_POSTBUILD_SHELL_SCRIPT
      "${CMAKE_CURRENT_BINARY_DIR}/postbuild.sh" PARENT_SCOPE
    )
  endif()

  if(DEFINED _DEVELOPMENT_TEAM_ID)
    message(WARNING "Reprojucer.cmake doesn't support the setting "
      "DEVELOPMENT_TEAM_ID (\"Development Team ID\" in Projucer). If you would like "
      "Reprojucer.cmake to support this setting, please leave a comment on the issue "
      "\"Reprojucer.cmake doesn't support the setting DEVELOPMENT_TEAM_ID\" on "
      "GitHub: https://github.com/McMartin/FRUT/issues/251"
    )
  endif()

  if(DEFINED _KEEP_CUSTOM_XCODE_SCHEMES)
    if(_KEEP_CUSTOM_XCODE_SCHEMES AND CMAKE_GENERATOR STREQUAL "Xcode")
      message(WARNING "Reprojucer.cmake won't create any Xcode schemes, so it won't "
        "delete any either."
      )
    endif()
  endif()

  if(DEFINED _USE_HEADERMAP)
    if(_USE_HEADERMAP)
      message(WARNING "USE_HEADERMAP is only supported when using the Xcode "
        "generator. You should call `cmake -G Xcode`."
      )
    endif()
    set(JUCER_USE_HEADERMAP ${_USE_HEADERMAP} PARENT_SCOPE)
  endif()

  if(DEFINED _PLATFORM_TOOLSET)
    set(toolset ${_PLATFORM_TOOLSET})
    if((exporter STREQUAL "Visual Studio 2017"
          AND (toolset STREQUAL "v140" OR toolset STREQUAL "v140_xp"
            OR toolset STREQUAL "v141" OR toolset STREQUAL "v141_xp"))
        OR (exporter STREQUAL "Visual Studio 2015"
          AND (toolset STREQUAL "v140" OR toolset STREQUAL "v140_xp"
            OR toolset STREQUAL "CTP_Nov2013"))
        OR (exporter STREQUAL "Visual Studio 2013"
          AND (toolset STREQUAL "v120" OR toolset STREQUAL "v120_xp"
            OR toolset STREQUAL "Windows7" OR toolset STREQUAL "CTP_Nov2013")))
      if(NOT toolset STREQUAL "${CMAKE_VS_PLATFORM_TOOLSET}")
        message(FATAL_ERROR "You must call `cmake -T ${toolset}` in order to build with"
          " the toolset \"${toolset}\"."
        )
      endif()
    elseif(NOT toolset STREQUAL "(default)")
      message(FATAL_ERROR "Unsupported value for PLATFORM_TOOLSET: \"${toolset}\"")
    endif()
  endif()

  if(DEFINED _USE_IPP_LIBRARY)
    set(ipp_library ${_USE_IPP_LIBRARY})
    set(ipp_library_values
      "Yes (Default Mode)"
      "Multi-Threaded Static Library"
      "Single-Threaded Static Library"
      "Multi-Threaded DLL"
      "Single-Threaded DLL"
    )
    if("${ipp_library}" IN_LIST ipp_library_values)
      message(WARNING "Reprojucer.cmake doesn't support the setting USE_IPP_LIBRARY "
        "(\"Use IPP Library\" in Projucer). If you would like Reprojucer.cmake to "
        "support this setting, please leave a comment on the issue "
        "\"Reprojucer.cmake doesn't support the setting USE_IPP_LIBRARY\" on GitHub: "
        "https://github.com/McMartin/FRUT/issues/252"
      )
    elseif(NOT ipp_library STREQUAL "No")
      message(FATAL_ERROR "Unsupported value for USE_IPP_LIBRARY: \"${ipp_library}\"")
    endif()
  endif()

  if(DEFINED _CXX_STANDARD_TO_USE AND exporter STREQUAL "Visual Studio 2017")
    set(standard ${_CXX_STANDARD_TO_USE})
    if(standard STREQUAL "C++14")
      set(JUCER_CXX_STANDARD_TO_USE "14" PARENT_SCOPE)
    elseif(standard STREQUAL "Latest C++ Standard")
      set(JUCER_CXX_STANDARD_TO_USE "latest" PARENT_SCOPE)
    elseif(NOT standard STREQUAL "(default)")
      message(FATAL_ERROR "Unsupported value for CXX_STANDARD_TO_USE: \"${standard}\"")
    endif()
  endif()

  if(DEFINED _CXX_STANDARD_TO_USE AND exporter STREQUAL "Linux Makefile")
    set(standard ${_CXX_STANDARD_TO_USE})
    if(standard MATCHES "^C\\+\\+(03|11|14)$")
      set(JUCER_CXX_STANDARD_TO_USE ${standard} PARENT_SCOPE)
    else()
      message(FATAL_ERROR "Unsupported value for CXX_STANDARD_TO_USE: \"${standard}\"")
    endif()
  endif()

  if(DEFINED _PKGCONFIG_LIBRARIES)
    set(JUCER_PKGCONFIG_LIBRARIES ${_PKGCONFIG_LIBRARIES} PARENT_SCOPE)
  endif()

endfunction()


function(jucer_export_target_configuration
  exporter NAME_KEYWORD config DEBUG_MODE_KEYWORD is_debug
)

  if(NOT "${exporter}" IN_LIST Reprojucer_supported_exporters)
    message(FATAL_ERROR "Unsupported exporter: ${exporter}\n"
      "Supported exporters: ${Reprojucer_supported_exporters}"
    )
  endif()

  if(NOT "${exporter}" IN_LIST JUCER_PROJECT_EXPORT_TARGETS)
    message(FATAL_ERROR "You must call jucer_export_target(\"${exporter}\") before "
      "calling jucer_export_target_configuration(\"${exporter}\")."
    )
  endif()

  if(NOT NAME_KEYWORD STREQUAL "NAME")
    message(FATAL_ERROR "Invalid second argument. Expected \"NAME\" keyword, "
      "but got \"${NAME_KEYWORD}\" instead."
    )
  endif()

  if(NOT DEBUG_MODE_KEYWORD STREQUAL "DEBUG_MODE")
    message(FATAL_ERROR "Invalid fourth argument. Expected \"DEBUG_MODE\" keyword, "
      "but got \"${DEBUG_MODE_KEYWORD}\" instead."
    )
  endif()

  list(FIND Reprojucer_supported_exporters "${exporter}" exporter_index)
  list(GET Reprojucer_supported_exporters_conditions ${exporter_index} condition)
  if(NOT ${condition})
    return()
  endif()

  if("${config}" IN_LIST JUCER_PROJECT_CONFIGURATIONS)
    message(FATAL_ERROR "You cannot call jucer_export_target_configuration("
      "\"${exporter}\" NAME \"${config}\") twice."
    )
  endif()

  list(APPEND JUCER_PROJECT_CONFIGURATIONS ${config})
  set(JUCER_PROJECT_CONFIGURATIONS ${JUCER_PROJECT_CONFIGURATIONS} PARENT_SCOPE)

  set(JUCER_CONFIGURATION_IS_DEBUG_${config} ${is_debug} PARENT_SCOPE)

  set(single_value_keywords
    "BINARY_NAME"
    "BINARY_LOCATION"
    "OPTIMISATION"
  )
  set(multi_value_keywords
    "HEADER_SEARCH_PATHS"
    "EXTRA_LIBRARY_SEARCH_PATHS"
    "PREPROCESSOR_DEFINITIONS"
  )

  if(exporter STREQUAL "Xcode (MacOSX)")
    list(APPEND single_value_keywords
      "ENABLE_PLUGIN_COPY_STEP"
      "VST_BINARY_LOCATION"
      "VST3_BINARY_LOCATION"
      "AU_BINARY_LOCATION"
      "RTAS_BINARY_LOCATION"
      "AAX_BINARY_LOCATION"
      "OSX_BASE_SDK_VERSION"
      "OSX_DEPLOYMENT_TARGET"
      "OSX_ARCHITECTURE"
      "CXX_LANGUAGE_STANDARD"
      "CXX_LIBRARY"
      "CODE_SIGNING_IDENTITY"
      "RELAX_IEEE_COMPLIANCE"
      "LINK_TIME_OPTIMISATION"
      "STRIP_LOCAL_SYMBOLS"
    )
    list(APPEND multi_value_keywords
      "CUSTOM_XCODE_FLAGS"
    )
  endif()

  if(exporter MATCHES "^Visual Studio 201(7|5|3)$")
    list(APPEND single_value_keywords
      "ENABLE_PLUGIN_COPY_STEP"
      "VST_BINARY_LOCATION"
      "VST3_BINARY_LOCATION"
      "RTAS_BINARY_LOCATION"
      "AAX_BINARY_LOCATION"
      "WARNING_LEVEL"
      "TREAT_WARNINGS_AS_ERRORS"
      "RUNTIME_LIBRARY"
      "WHOLE_PROGRAM_OPTIMISATION"
      "INCREMENTAL_LINKING"
      "PREBUILD_COMMAND"
      "POSTBUILD_COMMAND"
      "GENERATE_MANIFEST"
      "CHARACTER_SET"
      "ARCHITECTURE"
      "RELAX_IEEE_COMPLIANCE"
    )
  endif()

  if(exporter STREQUAL "Linux Makefile")
    list(APPEND single_value_keywords
      "ARCHITECTURE"
    )
  endif()

  _FRUT_parse_arguments("${single_value_keywords}" "${multi_value_keywords}" "${ARGN}")

  if(DEFINED _BINARY_NAME)
    set(JUCER_BINARY_NAME_${config} ${_BINARY_NAME} PARENT_SCOPE)
  endif()

  if(DEFINED _BINARY_LOCATION)
    get_filename_component(abs_path "${_BINARY_LOCATION}" ABSOLUTE)
    set(JUCER_BINARY_LOCATION_${config} ${abs_path} PARENT_SCOPE)
  endif()

  if(DEFINED _HEADER_SEARCH_PATHS)
    unset(header_search_paths)
    foreach(path ${_HEADER_SEARCH_PATHS})
      string(REPLACE "\\" "/" path "${path}")
      _FRUT_abs_path_based_on_jucer_project_dir("${path}" path)
      list(APPEND header_search_paths "${path}")
    endforeach()
    set(JUCER_HEADER_SEARCH_PATHS_${config} ${header_search_paths} PARENT_SCOPE)
  endif()

  if(DEFINED _EXTRA_LIBRARY_SEARCH_PATHS)
    unset(library_search_paths)
    foreach(path ${_EXTRA_LIBRARY_SEARCH_PATHS})
      string(REPLACE "\\" "/" path "${path}")
      _FRUT_abs_path_based_on_jucer_project_dir("${path}" path)
      list(APPEND library_search_paths "${path}")
    endforeach()
    set(JUCER_EXTRA_LIBRARY_SEARCH_PATHS_${config}
      ${library_search_paths} PARENT_SCOPE
    )
  endif()

  if(DEFINED _PREPROCESSOR_DEFINITIONS)
    set(JUCER_PREPROCESSOR_DEFINITIONS_${config} ${_PREPROCESSOR_DEFINITIONS}
      PARENT_SCOPE
    )
  endif()

  if(DEFINED _OPTIMISATION)
    set(optimisation ${_OPTIMISATION})
    if(exporter MATCHES "^Visual Studio 201(7|5|3)$")
      if(optimisation STREQUAL "No optimisation")
        set(optimisation_flag "/Od")
      elseif(optimisation STREQUAL "Minimise size")
        set(optimisation_flag "/O1")
      elseif(optimisation STREQUAL "Maximise speed")
        set(optimisation_flag "/Ox")
      else()
        message(FATAL_ERROR "Unsupported value for OPTIMISATION: \"${optimisation}\"")
      endif()
    else()
      if(optimisation STREQUAL "-O0 (no optimisation)")
        set(optimisation_flag "-O0")
      elseif(optimisation STREQUAL "-Os (minimise code size)")
        set(optimisation_flag "-Os")
      elseif(optimisation STREQUAL "-O3 (fastest with safe optimisations)")
        set(optimisation_flag "-O3")
      elseif(optimisation STREQUAL "-O1 (fast)")
        set(optimisation_flag "-O1")
      elseif(optimisation STREQUAL "-O2 (faster)")
        set(optimisation_flag "-O2")
      elseif(optimisation STREQUAL "-Ofast (uses aggressive optimisations)")
        set(optimisation_flag "-Ofast")
      else()
        message(FATAL_ERROR "Unsupported value for OPTIMISATION: \"${optimisation}\"")
      endif()
    endif()
    set(JUCER_OPTIMISATION_FLAG_${config} ${optimisation_flag} PARENT_SCOPE)
  endif()

  if(DEFINED _ENABLE_PLUGIN_COPY_STEP)
    set(JUCER_ENABLE_PLUGIN_COPY_STEP_${config} ${_ENABLE_PLUGIN_COPY_STEP} PARENT_SCOPE)
  endif()

  if(DEFINED _VST_BINARY_LOCATION)
    set(JUCER_VST_BINARY_LOCATION_${config} ${_VST_BINARY_LOCATION} PARENT_SCOPE)
  endif()

  if(DEFINED _VST3_BINARY_LOCATION)
    set(JUCER_VST3_BINARY_LOCATION_${config} ${_VST3_BINARY_LOCATION} PARENT_SCOPE)
  endif()

  if(DEFINED _AU_BINARY_LOCATION)
    set(JUCER_AU_BINARY_LOCATION_${config} ${_AU_BINARY_LOCATION} PARENT_SCOPE)
  endif()

  if(DEFINED _RTAS_BINARY_LOCATION)
    set(JUCER_RTAS_BINARY_LOCATION_${config} ${_RTAS_BINARY_LOCATION} PARENT_SCOPE)
  endif()

  if(DEFINED _AAX_BINARY_LOCATION)
    set(JUCER_AAX_BINARY_LOCATION_${config} ${_AAX_BINARY_LOCATION} PARENT_SCOPE)
  endif()

  if(DEFINED _OSX_BASE_SDK_VERSION)
    set(version ${_OSX_BASE_SDK_VERSION})
    if(version MATCHES "^10\\.([5-9]|10|11|12) SDK$")
      set(JUCER_OSX_BASE_SDK_VERSION_${config} "10.${CMAKE_MATCH_1}" PARENT_SCOPE)
    elseif(NOT version STREQUAL "Use Default")
      message(FATAL_ERROR "Unsupported value for OSX_BASE_SDK_VERSION: \"${version}\"")
    endif()
  endif()

  if(DEFINED _OSX_DEPLOYMENT_TARGET)
    set(target ${_OSX_DEPLOYMENT_TARGET})
    if(target MATCHES "^10\\.([5-9]|10|11|12)$")
      set(JUCER_OSX_DEPLOYMENT_TARGET_${config} "10.${CMAKE_MATCH_1}" PARENT_SCOPE)
    elseif(NOT target STREQUAL "Use Default")
      message(FATAL_ERROR "Unsupported value for OSX_DEPLOYMENT_TARGET: \"${target}\"")
    endif()
  endif()

  if(DEFINED _OSX_ARCHITECTURE)
    set(architecture ${_OSX_ARCHITECTURE})
    if(architecture STREQUAL "Native architecture of build machine")
      if(CMAKE_GENERATOR STREQUAL "Xcode")
        set(osx_architectures "$(NATIVE_ARCH_ACTUAL)")
      else()
        # Consider as default
        set(osx_architectures)
      endif()
    elseif(architecture STREQUAL "Universal Binary (32-bit)")
      if(CMAKE_GENERATOR STREQUAL "Xcode")
        set(osx_architectures "$(ARCHS_STANDARD_32_BIT)")
      else()
        set(osx_architectures "i386")
      endif()
    elseif(architecture STREQUAL "Universal Binary (32/64-bit)")
      if(CMAKE_GENERATOR STREQUAL "Xcode")
        set(osx_architectures "$(ARCHS_STANDARD_32_64_BIT)")
      else()
        set(osx_architectures "x86_64" "i386")
      endif()
    elseif(architecture STREQUAL "64-bit Intel")
      if(CMAKE_GENERATOR STREQUAL "Xcode")
        set(osx_architectures "$(ARCHS_STANDARD_64_BIT)")
      else()
        set(osx_architectures "x86_64")
      endif()
    elseif(NOT architecture STREQUAL "Use Default")
      message(FATAL_ERROR "Unsupported value for OSX_ARCHITECTURE: \"${architecture}\"")
    endif()
    if(DEFINED osx_architectures)
      set(JUCER_OSX_ARCHITECTURES_${config} "${osx_architectures}" PARENT_SCOPE)
    endif()
  endif()

  if(DEFINED _CUSTOM_XCODE_FLAGS)
    if(NOT CMAKE_GENERATOR STREQUAL "Xcode")
      message(WARNING "CUSTOM_XCODE_FLAGS is only supported when using the Xcode "
        "generator. You should call `cmake -G Xcode`."
      )
    endif()
    set(JUCER_CUSTOM_XCODE_FLAGS_${config} ${_CUSTOM_XCODE_FLAGS} PARENT_SCOPE)
  endif()

  if(DEFINED _CXX_LANGUAGE_STANDARD)
    set(standard ${_CXX_LANGUAGE_STANDARD})
    if(standard MATCHES "^(C|GNU)\\+\\+98$"
        AND DEFINED JUCER_VERSION AND JUCER_VERSION VERSION_LESS 5.0.0)
      set(JUCER_CXX_LANGUAGE_STANDARD_${config} ${standard} PARENT_SCOPE)
    elseif(standard MATCHES "^(C|GNU)\\+\\+(11|14)$")
      set(JUCER_CXX_LANGUAGE_STANDARD_${config} ${standard} PARENT_SCOPE)
    elseif(NOT standard STREQUAL "Use Default")
      message(FATAL_ERROR "Unsupported value for CXX_LANGUAGE_STANDARD: \"${standard}\"")
    endif()
  endif()

  if(DEFINED _CXX_LIBRARY)
    set(cxx_library ${_CXX_LIBRARY})
    if(cxx_library STREQUAL "LLVM libc++")
      set(JUCER_CXX_LIBRARY_${config} "libc++" PARENT_SCOPE)
    elseif(cxx_library STREQUAL "GNU libstdc++")
      set(JUCER_CXX_LIBRARY_${config} "libstdc++" PARENT_SCOPE)
    elseif(NOT cxx_library STREQUAL "Use Default")
      message(FATAL_ERROR "Unsupported value for CXX_LIBRARY: \"${cxx_library}\"")
    endif()
  endif()

  if(DEFINED _CODE_SIGNING_IDENTITY)
    if(NOT CMAKE_GENERATOR STREQUAL "Xcode")
      message(WARNING "CODE_SIGNING_IDENTITY is only supported when using the Xcode "
        "generator. You should call `cmake -G Xcode`."
      )
    endif()
    set(JUCER_CODE_SIGNING_IDENTITY_${config} ${_CODE_SIGNING_IDENTITY} PARENT_SCOPE)
  endif()

  if(DEFINED _RELAX_IEEE_COMPLIANCE)
    set(JUCER_RELAX_IEEE_COMPLIANCE_${config} ${_RELAX_IEEE_COMPLIANCE} PARENT_SCOPE)
  endif()

  if(DEFINED _LINK_TIME_OPTIMISATION)
    set(JUCER_LINK_TIME_OPTIMISATION_${config} ${_LINK_TIME_OPTIMISATION} PARENT_SCOPE)
  endif()

  if(DEFINED _STRIP_LOCAL_SYMBOLS)
    set(JUCER_STRIP_LOCAL_SYMBOLS_${config} ${_STRIP_LOCAL_SYMBOLS} PARENT_SCOPE)
  endif()

  if(DEFINED _WARNING_LEVEL)
    set(warning_level ${_WARNING_LEVEL})
    if(warning_level STREQUAL "Low")
      set(level 2)
    elseif(warning_level STREQUAL "Medium")
      set(level 3)
    elseif(warning_level STREQUAL "High")
      set(level 4)
    else()
      message(FATAL_ERROR "Unsupported value for WARNING_LEVEL: \"${warning_level}\"")
    endif()
    set(JUCER_WARNING_LEVEL_FLAG_${config} "/W${level}" PARENT_SCOPE)
  endif()

  if(DEFINED _TREAT_WARNINGS_AS_ERRORS)
    set(JUCER_TREAT_WARNINGS_AS_ERRORS_${config} ${_TREAT_WARNINGS_AS_ERRORS}
      PARENT_SCOPE
    )
  endif()

  if(DEFINED _RUNTIME_LIBRARY)
    set(library ${_RUNTIME_LIBRARY})
    if(library STREQUAL "Use DLL runtime")
      if(is_debug)
        set(flag "/MDd")
      else()
        set(flag "/MD")
      endif()
    elseif(library STREQUAL "Use static runtime")
      if(is_debug)
        set(flag "/MTd")
      else()
        set(flag "/MT")
      endif()
    elseif(NOT library STREQUAL "(Default)")
      message(FATAL_ERROR "Unsupported value for RUNTIME_LIBRARY: \"${library}\"")
    endif()
    set(JUCER_RUNTIME_LIBRARY_FLAG_${config} ${flag} PARENT_SCOPE)
  endif()

  if(DEFINED _WHOLE_PROGRAM_OPTIMISATION)
    set(optimisation ${_WHOLE_PROGRAM_OPTIMISATION})
    if(optimisation STREQUAL "Always disable")
      set(JUCER_ALWAYS_DISABLE_WPO_${config} TRUE PARENT_SCOPE)
    elseif(NOT optimisation STREQUAL "Enable when possible")
      message(FATAL_ERROR
        "Unsupported value for WHOLE_PROGRAM_OPTIMISATION: \"${optimisation}\""
      )
    endif()
  endif()

  if(DEFINED _INCREMENTAL_LINKING)
    set(JUCER_INCREMENTAL_LINKING_${config} ${_INCREMENTAL_LINKING} PARENT_SCOPE)
  endif()

  if(DEFINED _PREBUILD_COMMAND)
    set(script_content "${_PREBUILD_COMMAND}")
    configure_file("${Reprojucer_templates_DIR}/script.in"
      "prebuild_${config}.cmd" @ONLY
    )
    set(JUCER_PREBUILD_COMMAND_${config}
      "${CMAKE_CURRENT_BINARY_DIR}/prebuild_${config}.cmd" PARENT_SCOPE
    )
  endif()

  if(DEFINED _POSTBUILD_COMMAND)
    set(script_content "${_POSTBUILD_COMMAND}")
    configure_file("${Reprojucer_templates_DIR}/script.in"
      "postbuild_${config}.cmd" @ONLY
    )
    set(JUCER_POSTBUILD_COMMAND_${config}
      "${CMAKE_CURRENT_BINARY_DIR}/postbuild_${config}.cmd" PARENT_SCOPE
    )
  endif()

  if(DEFINED _GENERATE_MANIFEST)
    set(JUCER_GENERATE_MANIFEST_${config} ${_GENERATE_MANIFEST} PARENT_SCOPE)
  endif()

  if(DEFINED _CHARACTER_SET)
    set(character_sets "Default" "MultiByte" "Unicode")
    if("${_CHARACTER_SET}" IN_LIST character_sets)
      set(JUCER_CHARACTER_SET_${config} ${_CHARACTER_SET} PARENT_SCOPE)
    else()
      message(FATAL_ERROR "Unsupported value for CHARACTER_SET: \"${_CHARACTER_SET}\"")
    endif()
  endif()

  if(DEFINED _ARCHITECTURE AND exporter MATCHES "^Visual Studio 201(7|5|3)$")
    if(_ARCHITECTURE STREQUAL "32-bit")
      set(wants_x64 FALSE)
    elseif(_ARCHITECTURE STREQUAL "x64")
      set(wants_x64 TRUE)
    else()
      message(FATAL_ERROR "Unsupported value for ARCHITECTURE: \"${_ARCHITECTURE}\"")
    endif()
    if(CMAKE_GENERATOR_PLATFORM STREQUAL "x64" OR CMAKE_GENERATOR MATCHES "Win64")
      set(is_x64 TRUE)
    else()
      set(is_x64 FALSE)
    endif()
    if(wants_x64 AND NOT is_x64)
      message(FATAL_ERROR "You must call `cmake -G\"${CMAKE_GENERATOR} Win64\"` or "
        "`cmake -G\"${CMAKE_GENERATOR}\" -A x64` in order to build for 64-bit."
      )
    elseif(NOT wants_x64 AND is_x64)
      string(FIND "${CMAKE_GENERATOR}" " Win64" length REVERSE)
      string(SUBSTRING "${CMAKE_GENERATOR}" 0 ${length} 32_bit_generator)
      message(FATAL_ERROR "You must call `cmake -G\"${32_bit_generator}\"` or "
        "`cmake -G\"${32_bit_generator}\" -A Win32` in order to build for 32-bit."
      )
    endif()
  endif()

  if(DEFINED _ARCHITECTURE AND exporter STREQUAL "Linux Makefile")
    set(architecture ${_ARCHITECTURE})
    if(architecture STREQUAL "(Default)")
      set(architecture_flag "-march=native")
    elseif(architecture STREQUAL "32-bit (-m32)")
      set(architecture_flag "-m32")
    elseif(architecture STREQUAL "64-bit (-m64)")
      set(architecture_flag "-m64")
    elseif(architecture STREQUAL "ARM v6")
      set(architecture_flag "-march=armv6")
    elseif(architecture STREQUAL "ARM v7")
      set(architecture_flag "-march=armv7")
    elseif(NOT architecture STREQUAL "<None>")
      message(FATAL_ERROR "Unsupported value for ARCHITECTURE: \"${architecture}\"")
    endif()
    set(JUCER_ARCHITECTURE_FLAG_${config} ${architecture_flag} PARENT_SCOPE)
  endif()

endfunction()


function(jucer_project_end)

  unset(current_exporter)
  foreach(exporter_index RANGE 4)
    list(GET Reprojucer_supported_exporters_conditions ${exporter_index} condition)
    if(${condition})
      if(DEFINED current_exporter)
        message(FATAL_ERROR "There is already a current exporter: ${current_exporter}")
      else()
        list(GET Reprojucer_supported_exporters ${exporter_index} exporter)
        set(current_exporter ${exporter})
      endif()
    endif()
  endforeach()

  if(NOT DEFINED current_exporter)
    unset(exporters_list)
    foreach(exporter ${Reprojucer_supported_exporters})
      string(APPEND exporters_list "\n  - ${exporter}")
    endforeach()
    message(FATAL_ERROR "Reprojucer.cmake doesn't support any export target for your "
      "current platform. It supports the following export targets:${exporters_list}\n"
      "If you think Reprojucer.cmake should support another export target, please create "
      "an issue on GitHub: https://github.com/McMartin/FRUT/issues/new\n"
    )
  endif()

  if(NOT "${current_exporter}" IN_LIST JUCER_PROJECT_EXPORT_TARGETS)
    message(FATAL_ERROR "You must call jucer_export_target(\"${current_exporter}\") "
      "before calling jucer_project_end()."
    )
  endif()

  if(NOT JUCER_PROJECT_CONFIGURATIONS)
    message(FATAL_ERROR "You must call "
      "jucer_export_target_configuration(\"${current_exporter}\") before "
      "calling jucer_project_end()."
    )
  endif()

  if(NOT DEFINED CMAKE_CONFIGURATION_TYPES)
    if("${CMAKE_BUILD_TYPE}" STREQUAL "")
      list(GET JUCER_PROJECT_CONFIGURATIONS 0 first_configuration)
      message(STATUS
        "Setting CMAKE_BUILD_TYPE to \"${first_configuration}\" as it was not specified."
      )
      set(CMAKE_BUILD_TYPE ${first_configuration})
      set(CMAKE_BUILD_TYPE ${first_configuration} PARENT_SCOPE)
    elseif(NOT "${CMAKE_BUILD_TYPE}" IN_LIST JUCER_PROJECT_CONFIGURATIONS)
      message(FATAL_ERROR "Undefined build configuration: ${CMAKE_BUILD_TYPE}\n"
        "Defined build configurations: ${JUCER_PROJECT_CONFIGURATIONS}"
      )
    endif()
  endif()

  set(CMAKE_CONFIGURATION_TYPES ${JUCER_PROJECT_CONFIGURATIONS} PARENT_SCOPE)

  _FRUT_generate_AppConfig_header()
  _FRUT_generate_JuceHeader_header()

  if(DEFINED JUCER_SMALL_ICON OR DEFINED JUCER_LARGE_ICON)
    if(APPLE)
      _FRUT_generate_icon_file("icns" "${CMAKE_CURRENT_BINARY_DIR}" icon_filename)
    elseif(WIN32)
      _FRUT_generate_icon_file("ico" "${CMAKE_CURRENT_BINARY_DIR}" icon_filename)
    endif()

    if(DEFINED icon_filename)
      set(icon_file "${CMAKE_CURRENT_BINARY_DIR}/${icon_filename}")
      source_group("Juce Library Code" FILES "${icon_file}")
      set(JUCER_BUNDLE_ICON_FILE ${icon_filename})
    endif()
  endif()

  if(WIN32 AND NOT JUCER_PROJECT_TYPE STREQUAL "Static Library")
    if(DEFINED JUCER_COMPANY_COPYRIGHT
        OR NOT(DEFINED JUCER_VERSION AND JUCER_VERSION VERSION_LESS 5.2.0))
      set(resources_rc_legal_copyright
        "\n      VALUE \"LegalCopyright\",  \"${JUCER_COMPANY_COPYRIGHT}\\0\""
      )
    endif()
    if(DEFINED icon_filename)
      string(CONCAT resources_rc_icon_settings
        "\nIDI_ICON1 ICON DISCARDABLE \"${icon_filename}\""
        "\nIDI_ICON2 ICON DISCARDABLE \"${icon_filename}\""
      )
    endif()

    string(REPLACE "." "," comma_separated_version_number "${JUCER_PROJECT_VERSION}")
    configure_file("${Reprojucer_templates_DIR}/resources.rc" "resources.rc")
    set(resources_rc_file "${CMAKE_CURRENT_BINARY_DIR}/resources.rc")
    source_group("Juce Library Code" FILES "${CMAKE_CURRENT_BINARY_DIR}/resources.rc")
  endif()

  source_group("Juce Library Code"
    REGULAR_EXPRESSION "${CMAKE_CURRENT_BINARY_DIR}/JuceLibraryCode/*"
  )

  set_source_files_properties(
    ${JUCER_PROJECT_BROWSABLE_FILES}
    ${JUCER_PROJECT_RESOURCES}
    PROPERTIES HEADER_FILE_ONLY TRUE
  )

  if(DEFINED JUCER_COMPANY_COPYRIGHT
      OR NOT(DEFINED JUCER_VERSION AND JUCER_VERSION VERSION_LESS 5.2.0))
    set(ns_human_readable_copyright "${JUCER_COMPANY_COPYRIGHT}")
  else()
    set(ns_human_readable_copyright "${JUCER_COMPANY_NAME}")
  endif()

  set(main_plist_entries "
    <key>CFBundleExecutable</key>
    <string>@bundle_executable@</string>
    <key>CFBundleIconFile</key>
    <string>@JUCER_BUNDLE_ICON_FILE@</string>
    <key>CFBundleIdentifier</key>
    <string>@bundle_identifier@</string>
    <key>CFBundleName</key>
    <string>@JUCER_PROJECT_NAME@</string>
    <key>CFBundleDisplayName</key>
    <string>@JUCER_PROJECT_NAME@</string>
    <key>CFBundlePackageType</key>
    <string>@bundle_package_type@</string>
    <key>CFBundleSignature</key>
    <string>@bundle_signature@</string>
    <key>CFBundleShortVersionString</key>
    <string>@JUCER_PROJECT_VERSION@</string>
    <key>CFBundleVersion</key>
    <string>@JUCER_PROJECT_VERSION@</string>
    <key>NSHumanReadableCopyright</key>
    <string>@ns_human_readable_copyright@</string>
    <key>NSHighResolutionCapable</key>
    <true/>"
  )

  if(JUCER_CUSTOM_PLIST)
    set(PListMerger_version "0.1.0")
    find_program(PListMerger_exe "PListMerger-${PListMerger_version}"
      PATHS "${Reprojucer.cmake_DIR}/bin"
      NO_DEFAULT_PATH
    )
    if(NOT PListMerger_exe)
      message(STATUS "Building PListMerger")
      try_compile(PListMerger
        "${Reprojucer.cmake_DIR}/PListMerger/_build/${CMAKE_GENERATOR}"
        "${Reprojucer.cmake_DIR}/PListMerger"
        PListMerger install
        CMAKE_FLAGS
        "-DJUCE_modules_DIRS=${JUCER_PROJECT_MODULES_FOLDERS}"
        "-DCMAKE_INSTALL_PREFIX=${Reprojucer.cmake_DIR}/bin"
      )
      if(NOT PListMerger)
        message(FATAL_ERROR "Failed to build PListMerger")
      endif()
      message(STATUS "PListMerger has been successfully built")
      find_program(PListMerger_exe "PListMerger-${PListMerger_version}"
        PATHS "${Reprojucer.cmake_DIR}/bin"
        NO_DEFAULT_PATH
      )
      if(NOT PListMerger_exe)
        message(FATAL_ERROR "Could not find PListMerger-${PListMerger_version}")
      endif()
    endif()

    execute_process(
      COMMAND
      "${PListMerger_exe}"
      "${JUCER_CUSTOM_PLIST}"
      "<plist><dict>${main_plist_entries}</dict></plist>"
      OUTPUT_VARIABLE PListMerger_output
      OUTPUT_STRIP_TRAILING_WHITESPACE
      RESULT_VARIABLE PListMerger_return_code
    )
    if(NOT PListMerger_return_code EQUAL 0)
      message(FATAL_ERROR "Error when executing PListMerger")
    endif()

    if(WIN32)
      string(REPLACE "\r\n" "\n" PListMerger_output "${PListMerger_output}")
    endif()
    string(REPLACE "<plist>\n  <dict>" "" PListMerger_output "${PListMerger_output}")
    string(REPLACE "\n  </dict>\n</plist>" "" PListMerger_output "${PListMerger_output}")
    set(main_plist_entries "${PListMerger_output}")
  endif()

  string(REGEX REPLACE "[^A-Za-z0-9_.+-]" "_" target "${JUCER_PROJECT_NAME}")

  if(NOT APPLE)
    unset(JUCER_PROJECT_XCODE_RESOURCES)
  endif()
  set_source_files_properties(${JUCER_PROJECT_XCODE_RESOURCES} ${icon_file}
    PROPERTIES MACOSX_PACKAGE_LOCATION "Resources"
  )

  set(all_sources
    ${JUCER_PROJECT_SOURCES}
    ${JUCER_PROJECT_RESOURCES}
    ${JUCER_PROJECT_BROWSABLE_FILES}
    ${JUCER_PROJECT_XCODE_RESOURCES}
    ${icon_file}
    ${resources_rc_file}
  )

  if(JUCER_PROJECT_TYPE STREQUAL "Console Application")
    add_executable(${target} ${all_sources})
    _FRUT_set_output_directory_properties(${target} "ConsoleApp")
    _FRUT_set_common_target_properties(${target})
    _FRUT_link_osx_frameworks(${target})
    _FRUT_set_custom_xcode_flags(${target})

  elseif(JUCER_PROJECT_TYPE STREQUAL "GUI Application")
    add_executable(${target} WIN32 MACOSX_BUNDLE ${all_sources})

    if(JUCER_DOCUMENT_FILE_EXTENSIONS)
      unset(bundle_type_extensions)
      foreach(type_extension ${JUCER_DOCUMENT_FILE_EXTENSIONS})
        if(type_extension MATCHES "^\\.")
          string(SUBSTRING "${type_extension}" 1 -1 type_extension)
        endif()
        string(APPEND bundle_type_extensions
          "\n          <string>${type_extension}</string>"
        )
      endforeach()
      list(GET JUCER_DOCUMENT_FILE_EXTENSIONS 0 first_type_extension)
      if(first_type_extension MATCHES "^\\.")
        string(SUBSTRING "${first_type_extension}" 1 -1 first_type_extension)
      endif()

      set(bundle_document_types_entries "
    <key>CFBundleDocumentTypes</key>
    <array>
      <dict>
        <key>CFBundleTypeExtensions</key>
        <array>${bundle_type_extensions}
        </array>
        <key>CFBundleTypeName</key>
        <string>${first_type_extension}</string>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleTypeIconFile</key>
        <string>Icon</string>
        <key>NSPersistentStoreTypeKey</key>
        <string>XML</string>
      </dict>
    </array>"
      )
    endif()

    _FRUT_generate_plist_file(${target} "App" "APPL" "????"
      "${main_plist_entries}" "${bundle_document_types_entries}"
    )
    _FRUT_set_output_directory_properties(${target} "App")
    _FRUT_set_common_target_properties(${target})
    _FRUT_link_osx_frameworks(${target})
    _FRUT_add_xcode_resources(${target})
    _FRUT_set_custom_xcode_flags(${target})

  elseif(JUCER_PROJECT_TYPE STREQUAL "Static Library")
    add_library(${target} STATIC ${all_sources})
    _FRUT_set_output_directory_properties(${target} "Static Library")
    _FRUT_set_common_target_properties(${target})
    _FRUT_set_custom_xcode_flags(${target})

  elseif(JUCER_PROJECT_TYPE STREQUAL "Dynamic Library")
    add_library(${target} SHARED ${all_sources})
    _FRUT_set_output_directory_properties(${target} "Dynamic Library")
    _FRUT_set_common_target_properties(${target})
    _FRUT_set_custom_xcode_flags(${target})

  elseif(JUCER_PROJECT_TYPE STREQUAL "Audio Plug-in")
    if(NOT APPLE AND DEFINED JUCER_VERSION AND JUCER_VERSION VERSION_LESS 5.0.0)
      add_library(${target} MODULE ${all_sources})
      set_target_properties(${target} PROPERTIES PREFIX "")
      _FRUT_set_output_directory_properties(${target} "")
      _FRUT_set_common_target_properties(${target})

      if(JUCER_BUILD_VST3 AND MSVC)
        add_custom_command(TARGET ${target} POST_BUILD
          COMMAND
          "${CMAKE_COMMAND}" "-E" "copy_if_different"
          "$<TARGET_FILE:${target}>"
          "$<TARGET_FILE_DIR:${target}>/${target}.vst3"
        )
      endif()
    else()
      unset(AudioUnit_sources)
      unset(AudioUnitv3_sources)
      unset(AAX_sources)
      unset(RTAS_sources)
      unset(VST_sources)
      unset(VST3_sources)
      unset(Standalone_sources)
      unset(SharedCode_sources)
      foreach(src_file ${JUCER_PROJECT_SOURCES})
        # See XCodeProjectExporter::getTargetTypeFromFilePath()
        # in JUCE/extras/Projucer/Source/Project Saving/jucer_ProjectExport_XCode.h
        if(src_file MATCHES "_AU[._]")
          list(APPEND AudioUnit_sources "${src_file}")
        elseif(src_file MATCHES "_AUv3[._]")
          list(APPEND AudioUnitv3_sources "${src_file}")
        elseif(src_file MATCHES "_AAX[._]")
          list(APPEND AAX_sources "${src_file}")
        elseif(src_file MATCHES "_RTAS[._]")
          list(APPEND RTAS_sources "${src_file}")
        elseif(src_file MATCHES "_VST2[._]")
          list(APPEND VST_sources "${src_file}")
        elseif(src_file MATCHES "_VST3[._]")
          list(APPEND VST3_sources "${src_file}")
        elseif(src_file MATCHES "_Standalone[._]")
          list(APPEND Standalone_sources "${src_file}")
        else()
          list(APPEND SharedCode_sources "${src_file}")
        endif()
      endforeach()

      set(shared_code_target ${target}_Shared_Code)
      add_library(${shared_code_target} STATIC
        ${SharedCode_sources}
        ${JUCER_PROJECT_RESOURCES}
        ${JUCER_PROJECT_XCODE_RESOURCES}
        ${JUCER_PROJECT_BROWSABLE_FILES}
        ${icon_file}
        ${resources_rc_file}
      )
      _FRUT_set_output_directory_properties(${shared_code_target} "Shared Code")
      _FRUT_set_common_target_properties(${shared_code_target})
      target_compile_definitions(${shared_code_target} PRIVATE "JUCE_SHARED_CODE=1")
      _FRUT_set_JucePlugin_Build_defines(${shared_code_target} "SharedCodeTarget")
      _FRUT_set_custom_xcode_flags(${shared_code_target})

      if(JUCER_BUILD_VST)
        set(vst_target ${target}_VST)
        add_library(${vst_target} MODULE
          ${VST_sources}
          ${JUCER_PROJECT_XCODE_RESOURCES}
          ${icon_file}
          ${resources_rc_file}
        )
        target_link_libraries(${vst_target} PRIVATE ${shared_code_target})
        _FRUT_generate_plist_file(${vst_target} "VST" "BNDL" "????"
          "${main_plist_entries}" ""
        )
        _FRUT_set_bundle_properties(${vst_target} "vst")
        _FRUT_set_output_directory_properties(${vst_target} "VST")
        _FRUT_set_common_target_properties(${vst_target})
        if(APPLE)
          _FRUT_install_to_plugin_binary_location(${vst_target} "VST"
            "$ENV{HOME}/Library/Audio/Plug-Ins/VST"
          )
        elseif(MSVC)
          if(CMAKE_GENERATOR_PLATFORM STREQUAL "x64" OR CMAKE_GENERATOR MATCHES "Win64")
            set(env_var "ProgramW6432")
          else()
            set(env_var "programfiles(x86)")
          endif()
          _FRUT_install_to_plugin_binary_location(${vst_target} "VST"
            "$ENV{${env_var}}/Steinberg/Vstplugins"
          )
        endif()
        _FRUT_set_JucePlugin_Build_defines(${vst_target} "VSTPlugIn")
        _FRUT_link_osx_frameworks(${vst_target})
        _FRUT_add_xcode_resources(${vst_target})
        _FRUT_set_custom_xcode_flags(${vst_target})
        unset(vst_target)
      endif()

      if(JUCER_BUILD_VST3 AND (APPLE OR MSVC))
        set(vst3_target ${target}_VST3)
        add_library(${vst3_target} MODULE
          ${VST3_sources}
          ${JUCER_PROJECT_XCODE_RESOURCES}
          ${icon_file}
          ${resources_rc_file}
        )
        target_link_libraries(${vst3_target} PRIVATE ${shared_code_target})
        _FRUT_generate_plist_file(${vst3_target} "VST3" "BNDL" "????"
          "${main_plist_entries}" ""
        )
        _FRUT_set_bundle_properties(${vst3_target} "vst3")
        if(MSVC)
          set_property(TARGET ${vst3_target} PROPERTY SUFFIX ".vst3")
        endif()
        _FRUT_set_output_directory_properties(${vst3_target} "VST3")
        _FRUT_set_common_target_properties(${vst3_target})
        if(APPLE)
          _FRUT_install_to_plugin_binary_location(${vst3_target} "VST3"
            "$ENV{HOME}/Library/Audio/Plug-Ins/VST3"
          )
        elseif(MSVC)
          if(CMAKE_GENERATOR_PLATFORM STREQUAL "x64" OR CMAKE_GENERATOR MATCHES "Win64")
            set(env_var "CommonProgramW6432")
          else()
            set(env_var "CommonProgramFiles(x86)")
          endif()
          _FRUT_install_to_plugin_binary_location(${vst3_target} "VST3"
            "$ENV{${env_var}}/VST3"
          )
        endif()
        _FRUT_set_JucePlugin_Build_defines(${vst3_target} "VST3PlugIn")
        _FRUT_link_osx_frameworks(${vst3_target})
        _FRUT_add_xcode_resources(${vst3_target})
        _FRUT_set_custom_xcode_flags(${vst3_target})
        unset(vst3_target)
      endif()

      if(JUCER_BUILD_AUDIOUNIT AND APPLE)
        set(au_target ${target}_AU)
        add_library(${au_target} MODULE
          ${AudioUnit_sources}
          ${JUCER_PROJECT_XCODE_RESOURCES}
          ${icon_file}
        )
        target_link_libraries(${au_target} PRIVATE ${shared_code_target})

        _FRUT_get_au_main_type_code(au_main_type_code)
        _FRUT_version_to_dec("${JUCER_PROJECT_VERSION}" dec_version)

        set(audio_components_entries "
    <key>AudioComponents</key>
    <array>
      <dict>
        <key>name</key>
        <string>@JUCER_PLUGIN_MANUFACTURER@: @JUCER_PLUGIN_NAME@</string>
        <key>description</key>
        <string>@JUCER_PLUGIN_DESCRIPTION@</string>
        <key>factoryFunction</key>
        <string>@JUCER_PLUGIN_AU_EXPORT_PREFIX@Factory</string>
        <key>manufacturer</key>
        <string>@JUCER_PLUGIN_MANUFACTURER_CODE@</string>
        <key>type</key>
        <string>${au_main_type_code}</string>
        <key>subtype</key>
        <string>@JUCER_PLUGIN_CODE@</string>
        <key>version</key>
        <integer>${dec_version}</integer>
      </dict>
    </array>"
        )

        _FRUT_generate_plist_file(${au_target} "AU" "BNDL" "????"
          "${main_plist_entries}" "${audio_components_entries}"
        )
        _FRUT_set_bundle_properties(${au_target} "component")
        _FRUT_set_output_directory_properties(${au_target} "AU")
        _FRUT_set_common_target_properties(${au_target})
        _FRUT_install_to_plugin_binary_location(${au_target} "AU"
          "$ENV{HOME}/Library/Audio/Plug-Ins/Components"
        )
        _FRUT_set_JucePlugin_Build_defines(${au_target} "AudioUnitPlugIn")
        _FRUT_link_osx_frameworks(${au_target} "AudioUnit" "CoreAudioKit")
        _FRUT_add_xcode_resources(${au_target})
        _FRUT_set_custom_xcode_flags(${au_target})
        unset(au_target)
      endif()

      if(JUCER_BUILD_AUDIOUNIT_V3 AND APPLE)
        set(auv3_target ${target}_AUv3_AppExtension)
        add_library(${auv3_target} MODULE
          ${AudioUnitv3_sources}
          ${JUCER_PROJECT_XCODE_RESOURCES}
          ${icon_file}
        )
        target_link_libraries(${auv3_target} PRIVATE ${shared_code_target})

        _FRUT_get_au_main_type_code(au_main_type_code)
        _FRUT_version_to_dec("${JUCER_PROJECT_VERSION}" dec_version)
        if(JUCER_PLUGIN_IS_A_SYNTH)
          set(tag "Synth")
        else()
          set(tag "Effects")
        endif()

        set(ns_extension_entries "
    <key>NSExtension</key>
    <dict>
      <key>NSExtensionPrincipalClass</key>
      <string>@JUCER_PLUGIN_AU_EXPORT_PREFIX@FactoryAUv3</string>
      <key>NSExtensionPointIdentifier</key>
      <string>com.apple.AudioUnit-UI</string>
      <key>NSExtensionAttributes</key>
      <dict>
        <key>AudioComponents</key>
        <array>
          <dict>
            <key>name</key>
            <string>@JUCER_PLUGIN_MANUFACTURER@: @JUCER_PLUGIN_NAME@</string>
            <key>description</key>
            <string>@JUCER_PLUGIN_DESCRIPTION@</string>
            <key>factoryFunction</key>
            <string>@JUCER_PLUGIN_AU_EXPORT_PREFIX@FactoryAUv3</string>
            <key>manufacturer</key>
            <string>@JUCER_PLUGIN_MANUFACTURER_CODE@</string>
            <key>type</key>
            <string>${au_main_type_code}</string>
            <key>subtype</key>
            <string>@JUCER_PLUGIN_CODE@</string>
            <key>version</key>
            <integer>${dec_version}</integer>
            <key>sandboxSafe</key>
            <true/>
            <key>tags</key>
            <array>
              <string>${tag}</string>
            </array>
          </dict>
        </array>
      </dict>
    </dict>"
        )

        _FRUT_generate_plist_file(${auv3_target} "AUv3_AppExtension" "XPC!" "????"
          "${main_plist_entries}" "${ns_extension_entries}"
        )

        # com.yourcompany.NewProject -> com.yourcompany.NewProject.NewProjectAUv3
        string(REPLACE "." ";" bundle_id_parts "${JUCER_BUNDLE_IDENTIFIER}")
        list(LENGTH bundle_id_parts bundle_id_parts_length)
        math(EXPR bundle_id_parts_last_index "${bundle_id_parts_length} - 1")
        list(GET bundle_id_parts ${bundle_id_parts_last_index} bundle_id_last_part)
        list(APPEND bundle_id_parts "${bundle_id_last_part}AUv3")
        string(REPLACE ";" "." bundle_id "${bundle_id_parts}")
        if(CMAKE_GENERATOR STREQUAL "Xcode")
          set_target_properties(${auv3_target} PROPERTIES
            XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "${bundle_id}"
          )
        else()
          set_target_properties(${auv3_target} PROPERTIES
            MACOSX_BUNDLE_GUI_IDENTIFIER "${bundle_id}"
          )
        endif()

        # Cannot use _FRUT_set_bundle_properties() since Projucer sets xcodeIsBundle=false
        # for this target, though it is a bundle...
        set_target_properties(${auv3_target} PROPERTIES
          BUNDLE TRUE
          BUNDLE_EXTENSION "appex"
          XCODE_ATTRIBUTE_WRAPPER_EXTENSION "appex"
        )
        _FRUT_set_output_directory_properties(${auv3_target} "AUv3 AppExtension")
        _FRUT_set_common_target_properties(${auv3_target})
        _FRUT_set_JucePlugin_Build_defines(${auv3_target} "AudioUnitv3PlugIn")
        _FRUT_link_osx_frameworks(
          ${auv3_target} "AudioUnit" "CoreAudioKit" "AVFoundation"
        )
        _FRUT_add_xcode_resources(${auv3_target})
        _FRUT_set_custom_xcode_flags(${auv3_target})
        unset(auv3_target)
      endif()

      if(JUCER_BUILD_AUDIOUNIT_V3
          AND DEFINED JUCER_VERSION AND JUCER_VERSION VERSION_LESS 5.0.0)
        set(juce4_standalone ON)
      endif()

      if(juce4_standalone OR (JUCER_BUILD_STANDALONE_PLUGIN
          AND NOT (DEFINED JUCER_VERSION AND JUCER_VERSION VERSION_LESS 5.0.0)))
        if(juce4_standalone)
          set(standalone_target ${target}_AUv3_Standalone)
        else()
          set(standalone_target ${target}_StandalonePlugin)
        endif()
        add_executable(${standalone_target} WIN32 MACOSX_BUNDLE
          ${Standalone_sources}
          ${JUCER_PROJECT_XCODE_RESOURCES}
          ${icon_file}
          ${resources_rc_file}
        )
        target_link_libraries(${standalone_target} PRIVATE ${shared_code_target})
        if(juce4_standalone)
          _FRUT_generate_plist_file(${standalone_target} "AUv3_Standalone" "APPL" "????"
            "${main_plist_entries}" ""
          )
        else()
          _FRUT_generate_plist_file(${standalone_target} "Standalone_Plugin" "APPL" "????"
            "${main_plist_entries}" ""
          )
        endif()
        _FRUT_set_output_directory_properties(${standalone_target} "Standalone Plugin")
        _FRUT_set_common_target_properties(${standalone_target})
        _FRUT_set_JucePlugin_Build_defines(${standalone_target} "StandalonePlugIn")
        _FRUT_link_osx_frameworks(${standalone_target})
        _FRUT_add_xcode_resources(${standalone_target})
        if(TARGET ${target}_AUv3_AppExtension)
          add_dependencies(${standalone_target} ${target}_AUv3_AppExtension)
          install(TARGETS ${target}_AUv3_AppExtension
            COMPONENT _embed_app_extension_in_standalone_app
            DESTINATION "$<TARGET_FILE_DIR:${standalone_target}>/../PlugIns"
          )
          add_custom_command(TARGET ${standalone_target} POST_BUILD
            COMMAND
            "${CMAKE_COMMAND}"
            "-DCMAKE_INSTALL_CONFIG_NAME=$<CONFIG>"
            "-DCMAKE_INSTALL_COMPONENT=_embed_app_extension_in_standalone_app"
            "-P" "${CMAKE_CURRENT_BINARY_DIR}/cmake_install.cmake"
          )
        endif()
        _FRUT_set_custom_xcode_flags(${standalone_target})
        unset(standalone_target)
      endif()
    endif()

  else()
    message(FATAL_ERROR "Unknown project type: ${JUCER_PROJECT_TYPE}")

  endif()

endfunction()


function(_FRUT_parse_arguments single_value_keywords multi_value_keywords arguments)

  foreach(keyword ${single_value_keywords} ${multi_value_keywords})
    unset(_${keyword})
  endforeach()

  unset(keyword)

  foreach(argument ${arguments})
    list(FIND single_value_keywords "${argument}" single_value_index)
    list(FIND multi_value_keywords "${argument}" multi_value_index)

    if(NOT DEFINED keyword)
      if(NOT single_value_index EQUAL -1)
        set(keyword ${argument})
        set(keyword_type "single")
      elseif(NOT multi_value_index EQUAL -1)
        set(keyword ${argument})
        set(keyword_type "multi")
      else()
        message(FATAL_ERROR "Unknown keyword: \"${keyword}\"")
      endif()
    elseif(keyword_type STREQUAL "single")
      set(_${keyword} ${argument})
      unset(keyword)
    elseif(keyword_type STREQUAL "multi")
      if(DEFINED _${keyword})
        if(NOT single_value_index EQUAL -1)
          set(keyword "${argument}")
          set(keyword_type "single")
        elseif(NOT multi_value_index EQUAL -1)
          set(keyword "${argument}")
          set(keyword_type "multi")
        else()
          list(APPEND _${keyword} ${argument})
        endif()
      else()
        list(APPEND _${keyword} ${argument})
      endif()
    else()
      message(FATAL_ERROR "There is a bug!")
    endif()
  endforeach()

  foreach(keyword ${single_value_keywords} ${multi_value_keywords})
    unset(_${keyword} PARENT_SCOPE)
    if(DEFINED _${keyword})
      set(_${keyword} ${_${keyword}} PARENT_SCOPE)
    endif()
  endforeach()

endfunction()


function(_FRUT_abs_path_based_on_jucer_project_dir in_path out_path)

  if(NOT IS_ABSOLUTE "${in_path}" AND NOT DEFINED JUCER_PROJECT_DIR)
    message(FATAL_ERROR "The path \"${in_path}\" must be absolute, unless you give "
      "PROJECT_FILE when calling jucer_project_begin()."
    )
  endif()

  get_filename_component(in_path "${in_path}" ABSOLUTE BASE_DIR "${JUCER_PROJECT_DIR}")
  set(${out_path} ${in_path} PARENT_SCOPE)

endfunction()


function(_FRUT_generate_AppConfig_header)

  if(DEFINED JUCER_APPCONFIG_USER_CODE_SECTION)
    set(user_code_section "\n${JUCER_APPCONFIG_USER_CODE_SECTION}\n")
    if("${user_code_section}" STREQUAL "\n\n")
      set(user_code_section "\n")
    endif()
  else()
    string(CONCAT user_code_section "\n\n// (You can call jucer_appconfig_header() to "
      "add your own code to this section)\n\n"
    )
  endif()

  if(DEFINED JUCER_DISPLAY_THE_JUCE_SPLASH_SCREEN
      AND NOT JUCER_DISPLAY_THE_JUCE_SPLASH_SCREEN)
    set(display_splash_screen 0)
  else()
    set(display_splash_screen 1)
  endif()
  if(DEFINED JUCER_REPORT_JUCE_APP_USAGE AND NOT JUCER_REPORT_JUCE_APP_USAGE)
    set(report_app_usage 0)
  else()
    set(report_app_usage 1)
  endif()
  if(DEFINED JUCER_SPLASH_SCREEN_COLOUR
      AND NOT JUCER_SPLASH_SCREEN_COLOUR STREQUAL "Dark")
    set(use_dark_splash_screen 0)
  else()
    set(use_dark_splash_screen 1)
  endif()

  set(max_right_padding 0)
  foreach(module_name ${JUCER_PROJECT_MODULES})
    string(LENGTH "${module_name}" module_name_length)
    if(module_name_length GREATER max_right_padding)
      set(max_right_padding ${module_name_length})
    endif()
  endforeach()
  math(EXPR max_right_padding "${max_right_padding} + 5")

  unset(module_available_defines)
  unset(config_flags_defines)
  foreach(module_name ${JUCER_PROJECT_MODULES})
    string(LENGTH "${module_name}" right_padding)
    unset(padding_spaces)
    while(right_padding LESS max_right_padding)
      string(APPEND padding_spaces " ")
      math(EXPR right_padding "${right_padding} + 1")
    endwhile()
    string(APPEND module_available_defines
      "#define JUCE_MODULE_AVAILABLE_${module_name}${padding_spaces} 1\n"
    )

    if(DEFINED JUCER_${module_name}_CONFIG_FLAGS)
      string(APPEND config_flags_defines
        "//=============================================================================="
        "\n// ${module_name} flags:\n\n"
      )
    endif()
    foreach(config_flag ${JUCER_${module_name}_CONFIG_FLAGS})
      string(APPEND config_flags_defines "#ifndef    ${config_flag}\n")
      if(NOT DEFINED JUCER_FLAG_${config_flag})
        string(APPEND config_flags_defines " //#define ${config_flag}\n")
      elseif(JUCER_FLAG_${config_flag})
        string(APPEND config_flags_defines " #define   ${config_flag} 1\n")
      else()
        string(APPEND config_flags_defines " #define   ${config_flag} 0\n")
      endif()
      string(APPEND config_flags_defines "#endif\n\n")
    endforeach()
  endforeach()

  set(is_standalone_application 1)

  if(JUCER_PROJECT_TYPE STREQUAL "Dynamic Library")
    set(is_standalone_application 0)

  elseif(JUCER_PROJECT_TYPE STREQUAL "Audio Plug-in")
    set(is_standalone_application 0)

    # See ProjectSaver::writePluginCharacteristicsFile()
    # in JUCE/extras/Projucer/Source/Project Saving/jucer_ProjectSaver.cpp

    set(audio_plugin_setting_names
      "Build_VST" "Build_VST3" "Build_AU" "Build_AUv3" "Build_RTAS" "Build_AAX"
      "Build_STANDALONE"
      "Name" "Desc" "Manufacturer" "ManufacturerWebsite" "ManufacturerEmail"
      "ManufacturerCode" "PluginCode"
      "IsSynth" "WantsMidiInput" "ProducesMidiOutput" "IsMidiEffect"
      "EditorRequiresKeyboardFocus"
      "Version" "VersionCode" "VersionString"
      "VSTUniqueID" "VSTCategory"
      "AUMainType" "AUSubType" "AUExportPrefix" "AUExportPrefixQuoted"
      "AUManufacturerCode"
      "CFBundleIdentifier"
      "RTASCategory" "RTASManufacturerCode" "RTASProductId" "RTASDisableBypass"
      "RTASDisableMultiMono"
      "AAXIdentifier" "AAXManufacturerCode" "AAXProductId" "AAXCategory"
      "AAXDisableBypass" "AAXDisableMultiMono"
    )

    _FRUT_bool_to_int("${JUCER_BUILD_VST}" Build_VST_value)
    _FRUT_bool_to_int("${JUCER_BUILD_VST3}" Build_VST3_value)
    _FRUT_bool_to_int("${JUCER_BUILD_AUDIOUNIT}" Build_AU_value)
    _FRUT_bool_to_int("${JUCER_BUILD_AUDIOUNIT_V3}" Build_AUv3_value)
    _FRUT_bool_to_int("OFF" Build_RTAS_value) # Not yet supported
    _FRUT_bool_to_int("OFF" Build_AAX_value) # Not yet supported
    if(DEFINED JUCER_VERSION AND JUCER_VERSION VERSION_LESS 5.0.0)
      _FRUT_bool_to_int("${JUCER_BUILD_AUDIOUNIT_V3}" Build_STANDALONE_value)
    else()
      _FRUT_bool_to_int("${JUCER_BUILD_STANDALONE_PLUGIN}" Build_STANDALONE_value)
    endif()

    set(Name_value "\"${JUCER_PLUGIN_NAME}\"")
    set(Desc_value "\"${JUCER_PLUGIN_DESCRIPTION}\"")
    set(Manufacturer_value "\"${JUCER_PLUGIN_MANUFACTURER}\"")
    set(ManufacturerWebsite_value "\"${JUCER_COMPANY_WEBSITE}\"")
    set(ManufacturerEmail_value "\"${JUCER_COMPANY_EMAIL}\"")

    _FRUT_four_chars_to_hex("${JUCER_PLUGIN_MANUFACTURER_CODE}" hex_manufacturer_code)
    set(ManufacturerCode_value
      "${hex_manufacturer_code} // '${JUCER_PLUGIN_MANUFACTURER_CODE}'"
    )
    _FRUT_four_chars_to_hex("${JUCER_PLUGIN_CODE}" hex_plugin_code)
    set(PluginCode_value "${hex_plugin_code} // '${JUCER_PLUGIN_CODE}'")

    _FRUT_bool_to_int("${JUCER_PLUGIN_IS_A_SYNTH}" IsSynth_value)
    _FRUT_bool_to_int("${JUCER_PLUGIN_MIDI_INPUT}" WantsMidiInput_value)
    _FRUT_bool_to_int("${JUCER_PLUGIN_MIDI_OUTPUT}" ProducesMidiOutput_value)
    _FRUT_bool_to_int("${JUCER_MIDI_EFFECT_PLUGIN}" IsMidiEffect_value)
    _FRUT_bool_to_int("${JUCER_KEY_FOCUS}" EditorRequiresKeyboardFocus_value)

    set(Version_value "${JUCER_PROJECT_VERSION}")
    _FRUT_version_to_hex("${JUCER_PROJECT_VERSION}" VersionCode_value)
    set(VersionString_value "\"${JUCER_PROJECT_VERSION}\"")

    set(VSTUniqueID_value "JucePlugin_PluginCode")
    if(NOT DEFINED JUCER_VST_CATEGORY)
      if(JUCER_PLUGIN_IS_A_SYNTH)
        set(VSTCategory_value "kPlugCategSynth")
      else()
        set(VSTCategory_value "kPlugCategEffect")
      endif()
    else()
      set(VSTCategory_value "${JUCER_VST_CATEGORY}")
    endif()

    if(NOT DEFINED JUCER_PLUGIN_AU_MAIN_TYPE)
      if(JUCER_MIDI_EFFECT_PLUGIN)
        set(AUMainType_value "'aumi'")
      elseif(JUCER_PLUGIN_IS_A_SYNTH)
        set(AUMainType_value "kAudioUnitType_MusicDevice")
      elseif(JUCER_PLUGIN_MIDI_INPUT)
        set(AUMainType_value "kAudioUnitType_MusicEffect")
      else()
        set(AUMainType_value "kAudioUnitType_Effect")
      endif()
    else()
      set(AUMainType_value "${JUCER_PLUGIN_AU_MAIN_TYPE}")
    endif()
    set(AUSubType_value "JucePlugin_PluginCode")
    set(AUExportPrefix_value "${JUCER_PLUGIN_AU_EXPORT_PREFIX}")
    set(AUExportPrefixQuoted_value "\"${JUCER_PLUGIN_AU_EXPORT_PREFIX}\"")
    set(AUManufacturerCode_value "JucePlugin_ManufacturerCode")

    set(CFBundleIdentifier_value "${JUCER_BUNDLE_IDENTIFIER}")

    if(JUCER_PLUGIN_IS_A_SYNTH)
      set(RTASCategory_value "ePlugInCategory_SWGenerators")
    elseif(NOT DEFINED JUCER_PLUGIN_RTAS_CATEGORY)
      set(RTASCategory_value "ePlugInCategory_None")
    else()
      set(RTASCategory_value "${JUCER_PLUGIN_RTAS_CATEGORY}")
    endif()
    set(RTASManufacturerCode_value "JucePlugin_ManufacturerCode")
    set(RTASProductId_value "JucePlugin_PluginCode")
    _FRUT_bool_to_int("${JUCER_PLUGIN_RTAS_DISABLE_BYPASS}" RTASDisableBypass_value)
    _FRUT_bool_to_int("${JUCER_PLUGIN_RTAS_DISABLE_MULTI_MONO}"
      RTASDisableMultiMono_value
    )

    set(AAXIdentifier_value "${JUCER_PLUGIN_AAX_IDENTIFIER}")
    set(AAXManufacturerCode_value "JucePlugin_ManufacturerCode")
    set(AAXProductId_value "JucePlugin_PluginCode")
    set(AAXCategory_value "${JUCER_PLUGIN_AAX_CATEGORY}")
    _FRUT_bool_to_int("${JUCER_PLUGIN_AAX_DISABLE_BYPASS}" AAXDisableBypass_value)
    _FRUT_bool_to_int("${JUCER_PLUGIN_AAX_DISABLE_MULTI_MONO}" AAXDisableMultiMono_value)

    string(LENGTH "${JUCER_PLUGIN_CHANNEL_CONFIGURATIONS}" plugin_channel_config_length)
    if(plugin_channel_config_length GREATER 0)
      # See countMaxPluginChannels()
      # in JUCE/extras/Projucer/Source/Project Saving/jucer_ProjectSaver.cpp
      string(REGEX REPLACE "[, {}]" ";" configs "${JUCER_PLUGIN_CHANNEL_CONFIGURATIONS}")
      set(max_num_input 0)
      set(max_num_output 0)
      set(is_input TRUE)
      foreach(element ${configs})
        if(is_input)
          if(element GREATER max_num_input)
            set(max_num_input "${element}")
          endif()
          set(is_input FALSE)
        else()
          if(element GREATER max_num_output)
            set(max_num_output "${element}")
          endif()
          set(is_input TRUE)
        endif()
      endforeach()

      list(APPEND audio_plugin_setting_names
        "MaxNumInputChannels" "MaxNumOutputChannels" "PreferredChannelConfigurations"
      )
      set(MaxNumInputChannels_value "${max_num_input}")
      set(MaxNumOutputChannels_value "${max_num_output}")
      set(PreferredChannelConfigurations_value "${JUCER_PLUGIN_CHANNEL_CONFIGURATIONS}")
    endif()

    string(CONCAT audio_plugin_settings_defines
      "\n"
      "//==============================================================================\n"
      "// Audio plugin settings..\n\n"
    )

    foreach(setting_name ${audio_plugin_setting_names})
      string(LENGTH "JucePlugin_${setting_name}" right_padding)
      unset(padding_spaces)
      while(right_padding LESS 32)
        string(APPEND padding_spaces " ")
        math(EXPR right_padding "${right_padding} + 1")
      endwhile()

      string(APPEND audio_plugin_settings_defines
        "#ifndef  JucePlugin_${setting_name}\n"
        " #define JucePlugin_${setting_name}${padding_spaces}  ${${setting_name}_value}\n"
        "#endif\n"
      )
    endforeach()
  endif()

  if(DEFINED JUCER_VERSION AND JUCER_VERSION VERSION_LESS 5.0.0)
    string(TOUPPER "${JUCER_PROJECT_ID}" upper_project_id)
    set(template_file "${Reprojucer_templates_DIR}/AppConfig-4.h")
  else()
    set(template_file "${Reprojucer_templates_DIR}/AppConfig.h")
  endif()
  configure_file("${template_file}" "JuceLibraryCode/AppConfig.h")
  list(APPEND JUCER_PROJECT_SOURCES
    "${CMAKE_CURRENT_BINARY_DIR}/JuceLibraryCode/AppConfig.h"
  )

  set(JUCER_PROJECT_SOURCES ${JUCER_PROJECT_SOURCES} PARENT_SCOPE)

endfunction()


function(_FRUT_generate_JuceHeader_header)

  list(LENGTH JUCER_PROJECT_RESOURCES resources_count)
  if(resources_count GREATER 0)
    set(BinaryDataBuilder_version "0.1.0")
    find_program(BinaryDataBuilder_exe "BinaryDataBuilder-${BinaryDataBuilder_version}"
      PATHS "${Reprojucer.cmake_DIR}/bin"
      NO_DEFAULT_PATH
    )
    if(NOT BinaryDataBuilder_exe)
      message(STATUS "Building BinaryDataBuilder")
      try_compile(BinaryDataBuilder
        "${Reprojucer.cmake_DIR}/BinaryDataBuilder/_build/${CMAKE_GENERATOR}"
        "${Reprojucer.cmake_DIR}/BinaryDataBuilder"
        BinaryDataBuilder install
        CMAKE_FLAGS
        "-DJUCE_modules_DIRS=${JUCER_PROJECT_MODULES_FOLDERS}"
        "-DCMAKE_INSTALL_PREFIX=${Reprojucer.cmake_DIR}/bin"
      )
      if(NOT BinaryDataBuilder)
        message(FATAL_ERROR "Failed to build BinaryDataBuilder")
      endif()
      message(STATUS "BinaryDataBuilder has been successfully built")
      find_program(BinaryDataBuilder_exe "BinaryDataBuilder-${BinaryDataBuilder_version}"
        PATHS "${Reprojucer.cmake_DIR}/bin"
        NO_DEFAULT_PATH
      )
      if(NOT BinaryDataBuilder_exe)
        message(FATAL_ERROR
          "Could not find BinaryDataBuilder-${BinaryDataBuilder_version}"
        )
      endif()
    endif()

    if(NOT JUCER_PROJECT_ID)
      set(project_uid "FRUT")
    else()
      set(project_uid "${JUCER_PROJECT_ID}")
    endif()
    if(NOT DEFINED JUCER_BINARYDATACPP_SIZE_LIMIT)
      set(JUCER_BINARYDATACPP_SIZE_LIMIT 10240)
    endif()
    math(EXPR size_limit_in_bytes "${JUCER_BINARYDATACPP_SIZE_LIMIT} * 1024")
    if(NOT DEFINED size_limit_in_bytes)
      message(FATAL_ERROR "Error when computing size_limit_in_bytes = "
        "${JUCER_BINARYDATACPP_SIZE_LIMIT} * 1024"
      )
    endif()
    if("${JUCER_BINARYDATA_NAMESPACE}" STREQUAL "")
      set(JUCER_BINARYDATA_NAMESPACE "BinaryData")
    endif()
    set(BinaryDataBuilder_args
      "${CMAKE_CURRENT_BINARY_DIR}/JuceLibraryCode/"
      "${project_uid}"
      ${size_limit_in_bytes}
      "${JUCER_BINARYDATA_NAMESPACE}"
    )
    foreach(resource_path ${JUCER_PROJECT_RESOURCES})
      get_filename_component(resource_abs_path "${resource_path}" ABSOLUTE)
      list(APPEND BinaryDataBuilder_args "${resource_abs_path}")
    endforeach()
    execute_process(
      COMMAND "${BinaryDataBuilder_exe}" ${BinaryDataBuilder_args}
      OUTPUT_VARIABLE binary_data_filenames
      RESULT_VARIABLE BinaryDataBuilder_return_code
    )
    if(NOT BinaryDataBuilder_return_code EQUAL 0)
      message(FATAL_ERROR "Error when executing BinaryDataBuilder")
    endif()

    foreach(filename ${binary_data_filenames})
      list(APPEND JUCER_PROJECT_SOURCES
        "${CMAKE_CURRENT_BINARY_DIR}/JuceLibraryCode/${filename}"
      )
    endforeach()
    if(DEFINED JUCER_INCLUDE_BINARYDATA AND NOT JUCER_INCLUDE_BINARYDATA)
      set(binary_data_include "")
    else()
      set(binary_data_include "\n#include \"BinaryData.h\"")
    endif()
  endif()

  unset(modules_includes)
  foreach(module_name ${JUCER_PROJECT_MODULES})
    string(APPEND modules_includes "#include <${module_name}/${module_name}.h>\n")
  endforeach()

  if(DEFINED JUCER_VERSION AND JUCER_VERSION VERSION_LESS 5.0.0)
    string(TOUPPER "${JUCER_PROJECT_ID}" upper_project_id)
    set(template_file "${Reprojucer_templates_DIR}/JuceHeader-4.h")
  else()
    set(template_file "${Reprojucer_templates_DIR}/JuceHeader.h")
  endif()
  configure_file("${template_file}" "JuceLibraryCode/JuceHeader.h")
  list(APPEND JUCER_PROJECT_SOURCES
    "${CMAKE_CURRENT_BINARY_DIR}/JuceLibraryCode/JuceHeader.h"
  )

  set(JUCER_PROJECT_SOURCES ${JUCER_PROJECT_SOURCES} PARENT_SCOPE)

endfunction()


function(_FRUT_generate_icon_file icon_format icon_file_output_dir out_icon_filename)

  set(IconBuilder_version "0.1.0")
  find_program(IconBuilder_exe "IconBuilder-${IconBuilder_version}"
    PATHS "${Reprojucer.cmake_DIR}/bin"
    NO_DEFAULT_PATH
  )
  if(NOT IconBuilder_exe)
    message(STATUS "Building IconBuilder")
    try_compile(IconBuilder
      "${Reprojucer.cmake_DIR}/IconBuilder/_build/${CMAKE_GENERATOR}"
      "${Reprojucer.cmake_DIR}/IconBuilder"
      IconBuilder install
      CMAKE_FLAGS
      "-DJUCE_modules_DIRS=${JUCER_PROJECT_MODULES_FOLDERS}"
      "-DCMAKE_INSTALL_PREFIX=${Reprojucer.cmake_DIR}/bin"
    )
    if(NOT IconBuilder)
      message(FATAL_ERROR "Failed to build IconBuilder")
    endif()
    message(STATUS "IconBuilder has been successfully built")
    find_program(IconBuilder_exe "IconBuilder-${IconBuilder_version}"
      PATHS "${Reprojucer.cmake_DIR}/bin"
      NO_DEFAULT_PATH
    )
    if(NOT IconBuilder_exe)
      message(FATAL_ERROR "Could not find IconBuilder-${IconBuilder_version}")
    endif()
  endif()

  set(IconBuilder_args "${icon_format}" "${icon_file_output_dir}")
  if(DEFINED JUCER_SMALL_ICON)
    list(APPEND IconBuilder_args "${JUCER_SMALL_ICON}")
  else()
    list(APPEND IconBuilder_args "<None>")
  endif()
  if(DEFINED JUCER_LARGE_ICON)
    list(APPEND IconBuilder_args "${JUCER_LARGE_ICON}")
  else()
    list(APPEND IconBuilder_args "<None>")
  endif()

  execute_process(
    COMMAND "${IconBuilder_exe}" ${IconBuilder_args}
    OUTPUT_VARIABLE icon_filename
    RESULT_VARIABLE IconBuilder_return_code
  )
  if(NOT IconBuilder_return_code EQUAL 0)
    message(FATAL_ERROR "Error when executing IconBuilder")
  endif()

  if(NOT "${icon_filename}" STREQUAL "")
    set(${out_icon_filename} ${icon_filename} PARENT_SCOPE)
  endif()

endfunction()


function(_FRUT_set_output_directory_properties target subfolder)

  foreach(config ${JUCER_PROJECT_CONFIGURATIONS})
    unset(output_directory)
    string(TOUPPER "${config}" upper_config)

    if(MSVC AND NOT "${subfolder}" STREQUAL ""
        AND NOT (DEFINED JUCER_VERSION AND JUCER_VERSION VERSION_LESS 5.0.0))
      if(DEFINED JUCER_BINARY_LOCATION_${config})
        set(output_directory "${JUCER_BINARY_LOCATION_${config}}/${subfolder}")
      else()
        set(output_directory "${CMAKE_CURRENT_BINARY_DIR}/$<CONFIG>/${subfolder}")
      endif()
    elseif(DEFINED JUCER_BINARY_LOCATION_${config})
      set(output_directory "${JUCER_BINARY_LOCATION_${config}}")
    endif()
    if(output_directory)
      set_target_properties(${target} PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY_${upper_config} "${output_directory}"
        LIBRARY_OUTPUT_DIRECTORY_${upper_config} "${output_directory}"
        RUNTIME_OUTPUT_DIRECTORY_${upper_config} "${output_directory}"
      )
    endif()
  endforeach()

endfunction()


function(_FRUT_set_common_target_properties target)

  foreach(config ${JUCER_PROJECT_CONFIGURATIONS})
    string(TOUPPER "${config}" upper_config)

    if(JUCER_BINARY_NAME_${config})
      set(output_name "${JUCER_BINARY_NAME_${config}}")
    else()
      set(output_name "${JUCER_PROJECT_NAME}")
    endif()
    set_target_properties(${target} PROPERTIES
      OUTPUT_NAME_${upper_config} "${output_name}"
    )
  endforeach()

  target_include_directories(${target} PRIVATE
    "${CMAKE_CURRENT_BINARY_DIR}/JuceLibraryCode"
    ${JUCER_PROJECT_MODULES_FOLDERS}
  )
  foreach(config ${JUCER_PROJECT_CONFIGURATIONS})
    set(search_paths ${JUCER_HEADER_SEARCH_PATHS_${config}})
    target_include_directories(${target} PRIVATE $<$<CONFIG:${config}>:${search_paths}>)
  endforeach()
  target_include_directories(${target} PRIVATE ${JUCER_HEADER_SEARCH_PATHS})

  if(JUCER_BUILD_VST OR JUCER_FLAG_JUCE_PLUGINHOST_VST)
    if(DEFINED JUCER_VST_SDK_FOLDER)
      if(NOT IS_DIRECTORY "${JUCER_VST_SDK_FOLDER}")
        message(WARNING
          "JUCER_VST_SDK_FOLDER: no such directory \"${JUCER_VST_SDK_FOLDER}\""
        )
      elseif(NOT EXISTS "${JUCER_VST_SDK_FOLDER}/public.sdk/source/vst2.x/audioeffectx.h")
        message(WARNING "JUCER_VST_SDK_FOLDER: \"${JUCER_VST_SDK_FOLDER}\" doesn't seem "
          "to contain the VST SDK"
        )
      endif()
      target_include_directories(${target} PRIVATE "${JUCER_VST_SDK_FOLDER}")
    elseif(DEFINED JUCER_VERSION AND JUCER_VERSION VERSION_LESS 4.2.4)
      message(WARNING "JUCER_VST_SDK_FOLDER is not defined. You should give "
        "VST_SDK_FOLDER when calling jucer_export_target()."
      )
    endif()
  endif()

  if(JUCER_BUILD_VST3 OR JUCER_FLAG_JUCE_PLUGINHOST_VST3)
    if(DEFINED JUCER_VST3_SDK_FOLDER)
      if(NOT IS_DIRECTORY "${JUCER_VST3_SDK_FOLDER}")
        message(WARNING
          "JUCER_VST3_SDK_FOLDER: no such directory \"${JUCER_VST3_SDK_FOLDER}\""
        )
      elseif(NOT EXISTS "${JUCER_VST3_SDK_FOLDER}/base/source/baseiids.cpp")
        message(WARNING "JUCER_VST3_SDK_FOLDER: \"${JUCER_VST3_SDK_FOLDER}\" doesn't "
          "seem to contain the VST3 SDK"
        )
      endif()
      target_include_directories(${target} PRIVATE "${JUCER_VST3_SDK_FOLDER}")
    elseif(APPLE OR MSVC)
      message(WARNING "JUCER_VST3_SDK_FOLDER is not defined. You should give "
        "VST3_SDK_FOLDER when calling jucer_export_target()."
      )
    endif()
  endif()

  foreach(config ${JUCER_PROJECT_CONFIGURATIONS})
    if(JUCER_OPTIMISATION_FLAG_${config})
      set(optimisation_flag ${JUCER_OPTIMISATION_FLAG_${config}})
      target_compile_options(${target} PRIVATE
        $<$<CONFIG:${config}>:${optimisation_flag}>
      )
    endif()
  endforeach()

  target_compile_definitions(${target} PRIVATE
    ${JUCER_PREPROCESSOR_DEFINITIONS}
    ${JUCER_EXTRA_PREPROCESSOR_DEFINITIONS}
  )
  foreach(config ${JUCER_PROJECT_CONFIGURATIONS})
    set(definitions ${JUCER_PREPROCESSOR_DEFINITIONS_${config}})
    target_compile_definitions(${target} PRIVATE $<$<CONFIG:${config}>:${definitions}>)
  endforeach()

  target_link_libraries(${target} PRIVATE ${JUCER_EXTERNAL_LIBRARIES_TO_LINK})

  _FRUT_set_cxx_language_standard_properties(${target})

  if(APPLE)
    foreach(config ${JUCER_PROJECT_CONFIGURATIONS})
      if(${JUCER_CONFIGURATION_IS_DEBUG_${config}})
        target_compile_definitions(${target} PRIVATE
          $<$<CONFIG:${config}>:_DEBUG=1>
          $<$<CONFIG:${config}>:DEBUG=1>
        )
      else()
        target_compile_definitions(${target} PRIVATE
          $<$<CONFIG:${config}>:_NDEBUG=1>
          $<$<CONFIG:${config}>:NDEBUG=1>
        )
      endif()

      if(DEFINED JUCER_CXX_LIBRARY_${config})
        set(cxx_library ${JUCER_CXX_LIBRARY_${config}})
        target_compile_options(${target} PRIVATE
          $<$<CONFIG:${config}>:-stdlib=${cxx_library}>
        )
      endif()

      if(JUCER_RELAX_IEEE_COMPLIANCE_${config})
        target_compile_options(${target} PRIVATE $<$<CONFIG:${config}>:-ffast-math>)
      endif()

      if(JUCER_LINK_TIME_OPTIMISATION_${config})
        target_compile_options(${target} PRIVATE $<$<CONFIG:${config}>:-flto>)
      endif()

      foreach(path ${JUCER_EXTRA_LIBRARY_SEARCH_PATHS_${config}})
        target_link_libraries(${target} PRIVATE $<$<CONFIG:${config}>:-L${path}>)
      endforeach()
    endforeach()

    if(target MATCHES "_AUv3_AppExtension$")
      if(CMAKE_GENERATOR STREQUAL "Xcode")
        set_target_properties(${target} PROPERTIES
          XCODE_ATTRIBUTE_ARCHS "$(ARCHS_STANDARD_64_BIT)"
        )
      else()
        set_target_properties(${target} PROPERTIES OSX_ARCHITECTURES "x86_64")
      endif()
    else()
      if(CMAKE_GENERATOR STREQUAL "Xcode")
        unset(all_confs_archs)
        foreach(config ${JUCER_PROJECT_CONFIGURATIONS})
          if(DEFINED JUCER_OSX_ARCHITECTURES_${config})
            set(osx_architectures "${JUCER_OSX_ARCHITECTURES_${config}}")
            string(APPEND all_confs_archs "$<$<CONFIG:${config}>:${osx_architectures}>")
          endif()
        endforeach()
        set_target_properties(${target} PROPERTIES
          XCODE_ATTRIBUTE_ARCHS "${all_confs_archs}"
        )
      else()
        foreach(config ${JUCER_PROJECT_CONFIGURATIONS})
          if(DEFINED JUCER_OSX_ARCHITECTURES_${config})
            string(TOUPPER "${config}" upper_config)
            set_target_properties(${target} PROPERTIES
              OSX_ARCHITECTURES_${upper_config} "${JUCER_OSX_ARCHITECTURES_${config}}"
            )
          endif()
        endforeach()
      endif()
    endif()

    if(CMAKE_GENERATOR STREQUAL "Xcode")
      unset(all_confs_osx_deployment_target)
      unset(all_confs_sdkroot)
      foreach(config ${JUCER_PROJECT_CONFIGURATIONS})
        set(osx_deployment_target "10.11")
        if(DEFINED JUCER_OSX_DEPLOYMENT_TARGET_${config})
          set(osx_deployment_target "${JUCER_OSX_DEPLOYMENT_TARGET_${config}}")
        endif()
        if(target MATCHES "_AUv3_AppExtension$"
            AND osx_deployment_target VERSION_LESS 10.11)
          set(osx_deployment_target "10.11")
          message(STATUS "Set OSX Deployment Target to 10.11 for ${target} in ${config}")
        endif()
        string(APPEND all_confs_osx_deployment_target
          "$<$<CONFIG:${config}>:${osx_deployment_target}>"
        )

        if(DEFINED JUCER_OSX_BASE_SDK_VERSION_${config})
          string(APPEND all_confs_sdkroot
            "$<$<CONFIG:${config}>:macosx${JUCER_OSX_BASE_SDK_VERSION_${config}}>"
          )
        endif()
      endforeach()
      set_target_properties(${target} PROPERTIES
        XCODE_ATTRIBUTE_MACOSX_DEPLOYMENT_TARGET "${all_confs_osx_deployment_target}"
        XCODE_ATTRIBUTE_SDKROOT "${all_confs_sdkroot}"
      )
    else()
      set(osx_deployment_target "10.11")
      if(DEFINED ${JUCER_OSX_DEPLOYMENT_TARGET_${CMAKE_BUILD_TYPE}})
        set(osx_deployment_target "${JUCER_OSX_DEPLOYMENT_TARGET_${CMAKE_BUILD_TYPE}}")
      endif()
      if(target MATCHES "_AUv3_AppExtension$"
          AND osx_deployment_target VERSION_LESS 10.11)
        set(osx_deployment_target "10.11")
        message(STATUS "Set OSX Deployment Target to 10.11 for ${target}")
      endif()
      target_compile_options(${target} PRIVATE
        "-mmacosx-version-min=${osx_deployment_target}"
      )

      set(sdkroot "${JUCER_OSX_BASE_SDK_VERSION_${CMAKE_BUILD_TYPE}}")
      if(sdkroot)
        execute_process(
          COMMAND "xcrun" "--sdk" "macosx${sdkroot}" "--show-sdk-path"
          OUTPUT_VARIABLE sysroot
          OUTPUT_STRIP_TRAILING_WHITESPACE
        )
        if(IS_DIRECTORY "${sysroot}")
          target_compile_options(${target} PRIVATE "-isysroot ${sysroot}")
        else()
          message(WARNING "Running `xcrun --sdk macosx${sdkroot} --show-sdk-path` didn't"
            " output a valid directory."
          )
        endif()
      endif()
    endif()

    unset(all_confs_code_sign_identity)
    foreach(config ${JUCER_PROJECT_CONFIGURATIONS})
      if(NOT JUCER_CODE_SIGNING_IDENTITY_${config} STREQUAL "Mac Developer")
        set(code_sign_identity ${JUCER_CODE_SIGNING_IDENTITY_${config}})
        string(APPEND all_confs_code_sign_identity
          $<$<CONFIG:${config}>:${code_sign_identity}>
        )
      endif()
    endforeach()
    if(all_confs_code_sign_identity)
      set_target_properties(${target} PROPERTIES
        XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "${all_confs_code_sign_identity}"
      )
    endif()

    get_target_property(target_type ${target} TYPE)
    unset(all_confs_strip_exe)
    unset(all_confs_strip_opt)
    unset(all_confs_strip_arg)
    foreach(config ${JUCER_PROJECT_CONFIGURATIONS})
      if(target_type STREQUAL "EXECUTABLE" OR target_type STREQUAL "MODULE_LIBRARY")
        if(${JUCER_STRIP_LOCAL_SYMBOLS_${config}})
          find_program(strip_exe "strip")
          if(NOT strip_exe)
            message(FATAL_ERROR "Could not find strip program")
          endif()
          string(APPEND all_confs_strip_exe $<$<CONFIG:${config}>:${strip_exe}>)
          string(APPEND all_confs_strip_opt $<$<CONFIG:${config}>:-x>)
          string(APPEND all_confs_strip_arg
            $<$<CONFIG:${config}>:$<TARGET_FILE:${target}>>
          )
        endif()
      endif()
    endforeach()
    if(all_confs_strip_exe)
      add_custom_command(TARGET ${target} POST_BUILD
        COMMAND ${all_confs_strip_exe} ${all_confs_strip_opt} ${all_confs_strip_arg}
      )
    endif()

    if(DEFINED JUCER_PREBUILD_SHELL_SCRIPT)
      if(NOT DEFINED JUCER_TARGET_PROJECT_FOLDER)
        message(FATAL_ERROR "JUCER_TARGET_PROJECT_FOLDER must be defined. Give "
          "TARGET_PROJECT_FOLDER when calling jucer_export_target(\"Xcode (MacOSX)\")."
        )
      endif()
      if(NOT IS_DIRECTORY "${JUCER_TARGET_PROJECT_FOLDER}")
        file(MAKE_DIRECTORY "${JUCER_TARGET_PROJECT_FOLDER}")
      endif()
      add_custom_command(TARGET ${target} PRE_BUILD
        COMMAND "/bin/sh" "${JUCER_PREBUILD_SHELL_SCRIPT}"
        WORKING_DIRECTORY "${JUCER_TARGET_PROJECT_FOLDER}"
      )
    endif()

    if(DEFINED JUCER_POSTBUILD_SHELL_SCRIPT)
      if(NOT DEFINED JUCER_TARGET_PROJECT_FOLDER)
        message(FATAL_ERROR "JUCER_TARGET_PROJECT_FOLDER must be defined. Give "
          "TARGET_PROJECT_FOLDER when calling jucer_export_target(\"Xcode (MacOSX)\")."
        )
      endif()
      if(NOT IS_DIRECTORY "${JUCER_TARGET_PROJECT_FOLDER}")
        file(MAKE_DIRECTORY "${JUCER_TARGET_PROJECT_FOLDER}")
      endif()
      add_custom_command(TARGET ${target} POST_BUILD
        COMMAND "/bin/sh" "${JUCER_POSTBUILD_SHELL_SCRIPT}"
        WORKING_DIRECTORY "${JUCER_TARGET_PROJECT_FOLDER}"
      )
    endif()

    if(CMAKE_GENERATOR STREQUAL "Xcode" AND DEFINED JUCER_USE_HEADERMAP)
      if(JUCER_USE_HEADERMAP)
        set_target_properties(${target} PROPERTIES XCODE_ATTRIBUTE_USE_HEADERMAP "YES")
      else()
        set_target_properties(${target} PROPERTIES XCODE_ATTRIBUTE_USE_HEADERMAP "NO")
      endif()
    endif()

  elseif(MSVC)
    target_compile_definitions(${target} PRIVATE "_CRT_SECURE_NO_WARNINGS")
    target_compile_options(${target} PRIVATE "/MP")

    foreach(config ${JUCER_PROJECT_CONFIGURATIONS})
      if(${JUCER_CONFIGURATION_IS_DEBUG_${config}})
        target_compile_definitions(${target} PRIVATE
          $<$<CONFIG:${config}>:DEBUG>
          $<$<CONFIG:${config}>:_DEBUG>
        )
      else()
        target_compile_definitions(${target} PRIVATE
          $<$<CONFIG:${config}>:NDEBUG>
        )

        if(NOT JUCER_ALWAYS_DISABLE_WPO_${config})
          target_compile_options(${target} PRIVATE
            $<$<CONFIG:${config}>:/GL>
          )
        endif()
      endif()

      if(NOT DEFINED JUCER_CHARACTER_SET_${config}
          OR JUCER_CHARACTER_SET_${config} STREQUAL "Default")
        target_compile_definitions(${target} PRIVATE
          $<$<CONFIG:${config}>:_SBCS>
        )
      elseif(JUCER_CHARACTER_SET_${config} STREQUAL "MultiByte")
        # Nothing to do, this is CMake's default
      elseif(JUCER_CHARACTER_SET_${config} STREQUAL "Unicode")
        target_compile_definitions(${target} PRIVATE
          $<$<CONFIG:${config}>:_UNICODE>
          $<$<CONFIG:${config}>:UNICODE>
        )
      endif()

      if(DEFINED JUCER_RUNTIME_LIBRARY_FLAG_${config})
        set(runtime_library_flag ${JUCER_RUNTIME_LIBRARY_FLAG_${config}})
      elseif(JUCER_BUILD_VST OR JUCER_BUILD_VST3)
        if(JUCER_CONFIGURATION_IS_DEBUG_${config})
          set(runtime_library_flag "/MDd")
        else()
          set(runtime_library_flag "/MD")
        endif()
      else()
        if(JUCER_CONFIGURATION_IS_DEBUG_${config})
          set(runtime_library_flag "/MTd")
        else()
          set(runtime_library_flag "/MT")
        endif()
      endif()
      target_compile_options(${target} PRIVATE
        $<$<CONFIG:${config}>:${runtime_library_flag}>
      )

      if(DEFINED JUCER_WARNING_LEVEL_FLAG_${config})
        set(warning_level_flag ${JUCER_WARNING_LEVEL_FLAG_${config}})
      else()
        set(warning_level_flag "/W4")
      endif()
      target_compile_options(${target} PRIVATE
        $<$<CONFIG:${config}>:${warning_level_flag}>
      )

      if(JUCER_TREAT_WARNINGS_AS_ERRORS_${config})
        target_compile_options(${target} PRIVATE $<$<CONFIG:${config}>:/WX>)
      endif()

      if(JUCER_RELAX_IEEE_COMPLIANCE_${config})
        target_compile_options(${target} PRIVATE $<$<CONFIG:${config}>:/fp:fast>)
      endif()

      foreach(path ${JUCER_EXTRA_LIBRARY_SEARCH_PATHS_${config}})
        target_link_libraries(${target} PRIVATE $<$<CONFIG:${config}>:-LIBPATH:${path}>)
      endforeach()

      if(DEFINED JUCER_INCREMENTAL_LINKING_${config})
        if(JUCER_INCREMENTAL_LINKING_${config})
          string(TOUPPER "${config}" upper_config)
          set_property(TARGET ${target}
            APPEND PROPERTY LINK_FLAGS_${upper_config} "/INCREMENTAL"
          )
        endif()
      endif()

      if(DEFINED JUCER_GENERATE_MANIFEST_${config})
        if(NOT JUCER_GENERATE_MANIFEST_${config})
          string(TOUPPER "${config}" upper_config)
          set_property(TARGET ${target}
            APPEND PROPERTY LINK_FLAGS_${upper_config} "/MANIFEST:NO"
          )
        endif()
      endif()
    endforeach()

    unset(all_confs_prebuild_command)
    foreach(config ${JUCER_PROJECT_CONFIGURATIONS})
      if(DEFINED JUCER_PREBUILD_COMMAND_${config})
        set(prebuild_command ${JUCER_PREBUILD_COMMAND_${config}})
        string(APPEND all_confs_prebuild_command
          $<$<CONFIG:${config}>:${prebuild_command}>
        )
      endif()
    endforeach()
    if(all_confs_prebuild_command)
      if(NOT DEFINED JUCER_TARGET_PROJECT_FOLDER)
        message(FATAL_ERROR "JUCER_TARGET_PROJECT_FOLDER must be defined. Give "
          "TARGET_PROJECT_FOLDER when calling jucer_export_target()."
        )
      endif()
      if(NOT IS_DIRECTORY "${JUCER_TARGET_PROJECT_FOLDER}")
        file(MAKE_DIRECTORY "${JUCER_TARGET_PROJECT_FOLDER}")
      endif()
      add_custom_command(TARGET ${target} PRE_BUILD
        COMMAND ${all_confs_prebuild_command}
        WORKING_DIRECTORY "${JUCER_TARGET_PROJECT_FOLDER}"
      )
    endif()

    unset(all_confs_postbuild_command)
    foreach(config ${JUCER_PROJECT_CONFIGURATIONS})
      if(DEFINED JUCER_POSTBUILD_COMMAND_${config})
        set(postbuild_command ${JUCER_POSTBUILD_COMMAND_${config}})
        string(APPEND all_confs_postbuild_command
          $<$<CONFIG:${config}>:${postbuild_command}>
        )
      endif()
    endforeach()
    if(all_confs_postbuild_command)
      if(NOT DEFINED JUCER_TARGET_PROJECT_FOLDER)
        message(FATAL_ERROR "JUCER_TARGET_PROJECT_FOLDER must be defined. Give "
          "TARGET_PROJECT_FOLDER when calling jucer_export_target()."
        )
      endif()
      if(NOT IS_DIRECTORY "${JUCER_TARGET_PROJECT_FOLDER}")
        file(MAKE_DIRECTORY "${JUCER_TARGET_PROJECT_FOLDER}")
      endif()
      add_custom_command(TARGET ${target} POST_BUILD
        COMMAND ${all_confs_postbuild_command}
        WORKING_DIRECTORY "${JUCER_TARGET_PROJECT_FOLDER}"
      )
    endif()

  elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
    foreach(config ${JUCER_PROJECT_CONFIGURATIONS})
      if(${JUCER_CONFIGURATION_IS_DEBUG_${config}})
        target_compile_definitions(${target} PRIVATE
          $<$<CONFIG:${config}>:DEBUG=1>
          $<$<CONFIG:${config}>:_DEBUG=1>
        )
      else()
        target_compile_definitions(${target} PRIVATE
          $<$<CONFIG:${config}>:NDEBUG=1>
        )
      endif()

      if(DEFINED JUCER_ARCHITECTURE_FLAG_${config})
        set(architecture_flag ${JUCER_ARCHITECTURE_FLAG_${config}})
      else()
        set(architecture_flag "-march=native")
      endif()
      target_compile_options(${target} PRIVATE
        $<$<CONFIG:${config}>:${architecture_flag}>
      )

      foreach(path ${JUCER_EXTRA_LIBRARY_SEARCH_PATHS_${config}})
        target_link_libraries(${target} PRIVATE $<$<CONFIG:${config}>:-L${path}>)
      endforeach()
    endforeach()

    set(linux_packages ${JUCER_PROJECT_LINUX_PACKAGES} ${JUCER_PKGCONFIG_LIBRARIES})
    if(linux_packages)
      find_package(PkgConfig REQUIRED)
      list(SORT linux_packages)
      list(REMOVE_DUPLICATES linux_packages)
      foreach(pkg ${linux_packages})
        pkg_check_modules(${pkg} "${pkg}")
        if(NOT ${pkg}_FOUND)
          message(FATAL_ERROR "pkg-config could not find ${pkg}")
        endif()
        target_compile_options(${target} PRIVATE ${${pkg}_CFLAGS})
        target_link_libraries(${target} PRIVATE ${${pkg}_LIBRARIES})
      endforeach()
    else()
      if("juce_graphics" IN_LIST JUCER_PROJECT_MODULES)
        target_include_directories(${target} PRIVATE "/usr/include/freetype2")
      endif()
      if(JUCER_FLAG_JUCE_USE_CURL)
        target_link_libraries(${target} PRIVATE "-lcurl")
      endif()
    endif()

    set(linux_libs ${JUCER_PROJECT_LINUX_LIBS})
    if(linux_libs)
      list(SORT linux_libs)
      list(REMOVE_DUPLICATES linux_libs)
      foreach(item ${linux_libs})
        if(item STREQUAL "pthread")
          target_compile_options(${target} PRIVATE "-pthread")
        endif()
        target_link_libraries(${target} PRIVATE "-l${item}")
      endforeach()
    endif()
  endif()

  target_compile_options(${target} PRIVATE ${JUCER_EXTRA_COMPILER_FLAGS})
  target_link_libraries(${target} PRIVATE ${JUCER_EXTRA_LINKER_FLAGS})

endfunction()


function(_FRUT_set_cxx_language_standard_properties target)

  if(DEFINED JUCER_CXX_LANGUAGE_STANDARD)
    set(cxx_language_standard "${JUCER_CXX_LANGUAGE_STANDARD}")

    if(CMAKE_GENERATOR STREQUAL "Xcode")
      if(cxx_language_standard STREQUAL "latest")
        set(cxx_language_standard "1z")
      endif()
      if(JUCER_GNU_COMPILER_EXTENSIONS)
        set(cxx_language_standard "gnu++${cxx_language_standard}")
      else()
        set(cxx_language_standard "c++${cxx_language_standard}")
      endif()
      set_target_properties(${target} PROPERTIES
        XCODE_ATTRIBUTE_CLANG_CXX_LANGUAGE_STANDARD "${cxx_language_standard}"
      )

    elseif(MSVC)
      if(MSVC_VERSION EQUAL 1900 OR MSVC_VERSION GREATER 1900) # VS2015 and later
        if(NOT cxx_language_standard STREQUAL "11")
          target_compile_options(${target} PRIVATE "-std:c++${cxx_language_standard}")
        endif()
      endif()

    else()
      if(GNU_COMPILER_EXTENSIONS)
        set_target_properties(${target} PROPERTIES CXX_EXTENSIONS ON)
      else()
        set_target_properties(${target} PROPERTIES CXX_EXTENSIONS OFF)
      endif()
      if(cxx_language_standard STREQUAL "latest")
        set(cxx_language_standard "17")
      endif()
      set_target_properties(${target} PROPERTIES CXX_STANDARD ${cxx_language_standard})

    endif()
  else()
    if(APPLE)
      if(CMAKE_GENERATOR STREQUAL "Xcode")
        unset(all_confs_cxx_language_standard)
        foreach(config ${JUCER_PROJECT_CONFIGURATIONS})
          set(cxx_language_standard "c++0x")
          if(DEFINED JUCER_CXX_LANGUAGE_STANDARD_${config})
            string(TOLOWER cxx_language_standard
              "${JUCER_CXX_LANGUAGE_STANDARD_${config}}"
            )
          endif()
          string(APPEND all_confs_cxx_language_standard
            "$<$<CONFIG:${config}>:${cxx_language_standard}>"
          )
        endforeach()
        set_target_properties(${target} PROPERTIES
          XCODE_ATTRIBUTE_CLANG_CXX_LANGUAGE_STANDARD "${all_confs_cxx_language_standard}"
        )
      else()
        set_target_properties(${target} PROPERTIES CXX_EXTENSIONS OFF)
        set_target_properties(${target} PROPERTIES CXX_STANDARD 11)

        set(cxx_language_standard "${JUCER_CXX_LANGUAGE_STANDARD_${CMAKE_BUILD_TYPE}}")
        if(cxx_language_standard)
          if(cxx_language_standard MATCHES "^GNU\\+\\+")
            set_target_properties(${target} PROPERTIES CXX_EXTENSIONS ON)
          endif()
          if(cxx_language_standard MATCHES "98$")
            set_target_properties(${target} PROPERTIES CXX_STANDARD 98)
          elseif(cxx_language_standard MATCHES "14$")
            set_target_properties(${target} PROPERTIES CXX_STANDARD 14)
          endif()
        endif()
      endif()

    elseif(MSVC)
      if(MSVC_VERSION EQUAL 1900 OR MSVC_VERSION GREATER 1900) # VS2015 and later
        if(JUCER_CXX_STANDARD_TO_USE STREQUAL "14")
          target_compile_options(${target} PRIVATE "-std:c++14")
        elseif(JUCER_CXX_STANDARD_TO_USE STREQUAL "latest")
          target_compile_options(${target} PRIVATE "-std:c++latest")
        endif()
      endif()

    elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
      set_target_properties(${target} PROPERTIES CXX_EXTENSIONS OFF)
      set_target_properties(${target} PROPERTIES CXX_STANDARD 11)

      if(DEFINED JUCER_CXX_STANDARD_TO_USE)
        if(JUCER_CXX_STANDARD_TO_USE MATCHES "03$")
          set_target_properties(${target} PROPERTIES CXX_STANDARD 98)
        elseif(JUCER_CXX_STANDARD_TO_USE MATCHES "14$")
          set_target_properties(${target} PROPERTIES CXX_STANDARD 14)
        endif()
      endif()

    endif()
  endif()

endfunction()


function(_FRUT_generate_plist_file
  target plist_suffix
  bundle_package_type bundle_signature
  main_plist_entries extra_plist_entries
)

  set(plist_filename "Info-${plist_suffix}.plist")
  if(CMAKE_GENERATOR STREQUAL "Xcode")
    set(bundle_executable "\${EXECUTABLE_NAME}")
    set(bundle_identifier "\$(PRODUCT_BUNDLE_IDENTIFIER)")
    set_target_properties(${target} PROPERTIES
      XCODE_ATTRIBUTE_INFOPLIST_FILE "${CMAKE_CURRENT_BINARY_DIR}/${plist_filename}"
      XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "${JUCER_BUNDLE_IDENTIFIER}"
    )
  else()
    set(bundle_executable "\${MACOSX_BUNDLE_BUNDLE_NAME}")
    set(bundle_identifier "\${MACOSX_BUNDLE_GUI_IDENTIFIER}")
    set_target_properties(${target} PROPERTIES
      MACOSX_BUNDLE_BUNDLE_NAME "${JUCER_PROJECT_NAME}"
      MACOSX_BUNDLE_GUI_IDENTIFIER "${JUCER_BUNDLE_IDENTIFIER}"
      MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_BINARY_DIR}/${plist_filename}"
    )
  endif()

  string(CONFIGURE "${main_plist_entries}" main_plist_entries @ONLY)
  string(CONFIGURE "${extra_plist_entries}" extra_plist_entries @ONLY)
  configure_file("${Reprojucer_templates_DIR}/Info.plist" "${plist_filename}" @ONLY)

endfunction()


function(_FRUT_set_bundle_properties target extension)

  if(APPLE)
    set_target_properties(${target} PROPERTIES
      BUNDLE TRUE
      BUNDLE_EXTENSION "${extension}"
      XCODE_ATTRIBUTE_WRAPPER_EXTENSION "${extension}"
    )

    add_custom_command(TARGET ${target} PRE_BUILD
      COMMAND
      "${CMAKE_COMMAND}" "-E" "copy_if_different"
      "${Reprojucer_templates_DIR}/PkgInfo"
      "$<TARGET_FILE_DIR:${target}>/.."
    )
  endif()

endfunction()


function(_FRUT_install_to_plugin_binary_location target plugin_type default_destination)

  unset(all_confs_destination)
  foreach(config ${JUCER_PROJECT_CONFIGURATIONS})
    if(DEFINED JUCER_${plugin_type}_BINARY_LOCATION_${config})
      set(destination ${JUCER_${plugin_type}_BINARY_LOCATION_${config}})
    else()
      set(destination ${default_destination})
    endif()
    if(DEFINED JUCER_ENABLE_PLUGIN_COPY_STEP_${config})
      if(JUCER_ENABLE_PLUGIN_COPY_STEP_${config})
        string(APPEND all_confs_destination $<$<CONFIG:${config}>:${destination}>)
      endif()
    elseif(APPLE)
      string(APPEND all_confs_destination $<$<CONFIG:${config}>:${destination}>)
    endif()
  endforeach()

  if("${all_confs_destination}" STREQUAL "")
    return()
  endif()

  set(component "_install_${target}_to_${plugin_type}_binary_location")

  install(TARGETS ${target} COMPONENT ${component}
    DESTINATION ${all_confs_destination}
  )

  add_custom_command(TARGET ${target} POST_BUILD
    COMMAND
    "${CMAKE_COMMAND}"
    "-DCMAKE_INSTALL_CONFIG_NAME=$<CONFIG>"
    "-DCMAKE_INSTALL_COMPONENT=${component}"
    "-P" "${CMAKE_CURRENT_BINARY_DIR}/cmake_install.cmake"
  )

endfunction()


function(_FRUT_set_JucePlugin_Build_defines target target_type)

  if(JUCER_BUILD_AUDIOUNIT_V3
      AND DEFINED JUCER_VERSION AND JUCER_VERSION VERSION_LESS 5.0.0)
    set(JUCER_BUILD_STANDALONE_PLUGIN ON)
  endif()

  set(plugin_types     VST VST3 AudioUnit AudioUnitv3  RTAS AAX Standalone       )
  set(setting_suffixes VST VST3 AUDIOUNIT AUDIOUNIT_V3 RTAS AAX STANDALONE_PLUGIN)
  set(define_suffixes  VST VST3 AU        AUv3         RTAS AAX Standalone       )

  foreach(index RANGE 6)
    list(GET setting_suffixes ${index} setting_suffix)
    list(GET plugin_types ${index} plugin_type)
    list(GET define_suffixes ${index} define_suffix)

    if(target_type STREQUAL "${plugin_type}PlugIn"
        OR (target_type STREQUAL "SharedCodeTarget" AND JUCER_BUILD_${setting_suffix}))
      target_compile_definitions(${target} PRIVATE
        "JucePlugin_Build_${define_suffix}=1"
      )
    else()
      target_compile_definitions(${target} PRIVATE
        "JucePlugin_Build_${define_suffix}=0"
      )
    endif()
  endforeach()

endfunction()


function(_FRUT_link_osx_frameworks target)

  set(osx_frameworks ${JUCER_PROJECT_OSX_FRAMEWORKS} ${JUCER_EXTRA_FRAMEWORKS} ${ARGN})

  if(APPLE)
    if(JUCER_FLAG_JUCE_PLUGINHOST_AU)
      list(APPEND osx_frameworks "AudioUnit" "CoreAudioKit")
    endif()
    list(SORT osx_frameworks)
    list(REMOVE_DUPLICATES osx_frameworks)
    foreach(framework_name ${osx_frameworks})
      find_library(${framework_name}_framework ${framework_name})
      target_link_libraries(${target} PRIVATE "${${framework_name}_framework}")
    endforeach()
  endif()

endfunction()


function(_FRUT_add_xcode_resources target)

  if(APPLE)
    foreach(folder ${JUCER_CUSTOM_XCODE_RESOURCE_FOLDERS})
      add_custom_command(TARGET ${target} PRE_BUILD
        COMMAND rsync -r "${folder}" "$<TARGET_FILE_DIR:${target}>/../Resources"
      )
    endforeach()
  endif()

endfunction()


function(_FRUT_set_custom_xcode_flags target)

  unset(all_flags)
  foreach(config ${JUCER_PROJECT_CONFIGURATIONS})
    if(DEFINED JUCER_CUSTOM_XCODE_FLAGS_${config})
      foreach(xcode_flag ${JUCER_CUSTOM_XCODE_FLAGS_${config}})
        string(REGEX MATCH "^([^= ]+) *= *(.+)" m "${xcode_flag}")
        if(NOT CMAKE_MATCH_0)
          message(FATAL_ERROR "Invalid Xcode flag: \"${xcode_flag}\"")
        endif()
        list(APPEND all_flags "${CMAKE_MATCH_1}")
        set(value "${CMAKE_MATCH_2}")
        string(APPEND all_confs_${CMAKE_MATCH_1} "$<$<CONFIG:${config}>:${value}>")
      endforeach()
    endif()
  endforeach()

  if(all_flags)
    list(SORT all_flags)
    list(REMOVE_DUPLICATES all_flags)
    foreach(flag ${all_flags})
      set_target_properties(${target} PROPERTIES
        XCODE_ATTRIBUTE_${flag} "${all_confs_${flag}}"
      )
    endforeach()
  endif()

endfunction()


function(_FRUT_bool_to_int bool_value out_int_value)

  if(bool_value)
    set(${out_int_value} 1 PARENT_SCOPE)
  else()
    set(${out_int_value} 0 PARENT_SCOPE)
  endif()

endfunction()


function(_FRUT_dec_to_hex dec_value out_hex_value)

  if(dec_value EQUAL 0)
    set(${out_hex_value} "0x0" PARENT_SCOPE)
    return()
  endif()

  if(dec_value LESS 0)
    math(EXPR dec_value "2147483647 ${dec_value} + 1")
  endif()

  while(dec_value GREATER 0)
    math(EXPR hex_unit "${dec_value} & 15")
    if(hex_unit LESS 10)
      set(hex_char ${hex_unit})
    else()
      math(EXPR hex_unit "${hex_unit} + 87")
      string(ASCII ${hex_unit} hex_char)
    endif()
    set(hex_value "${hex_char}${hex_value}")
    math(EXPR dec_value "${dec_value} >> 4")
  endwhile()

  set(${out_hex_value} "0x${hex_value}" PARENT_SCOPE)

endfunction()


function(_FRUT_version_to_dec version out_dec_value)

  string(REPLACE "." ";" segments "${version}")
  list(LENGTH segments segments_size)
  while(segments_size LESS 3)
    list(APPEND segments 0)
    math(EXPR segments_size "${segments_size} + 1")
  endwhile()
  list(GET segments 0 major)
  list(GET segments 1 minor)
  list(GET segments 2 patch)
  math(EXPR dec_value "(${major} << 16) + (${minor} << 8) + ${patch}")
  if(segments_size GREATER 3)
    list(GET segments 3 revision)
    math(EXPR dec_value "${dec_value} << 8 + ${revision}")
  endif()

  set(${out_dec_value} "${dec_value}" PARENT_SCOPE)

endfunction()


function(_FRUT_version_to_hex version out_hex_value)

  _FRUT_version_to_dec("${version}" dec_value)
  _FRUT_dec_to_hex("${dec_value}" hex_value)
  set(${out_hex_value} "${hex_value}" PARENT_SCOPE)

endfunction()


function(_FRUT_four_chars_to_hex value out_hex_value)

  unset(all_ascii_codes)
  foreach(ascii_code RANGE 1 127)
    list(APPEND all_ascii_codes ${ascii_code})
  endforeach()
  string(ASCII ${all_ascii_codes} all_ascii_chars)

  string(STRIP "${value}" four_chars)
  string(SUBSTRING "${four_chars}" 0 4 four_chars)
  set(dec_value 0)
  foreach(index 0 1 2 3)
    string(SUBSTRING "${four_chars}" ${index} 1 ascii_char)
    string(FIND "${all_ascii_chars}" "${ascii_char}" ascii_code)
    if(ascii_code EQUAL -1)
      message(FATAL_ERROR "${value} cannot contain non-ASCII characters")
    endif()
    math(EXPR dec_value "(${dec_value} << 8) | ((${ascii_code} + 1) & 255)")
  endforeach()

  _FRUT_dec_to_hex("${dec_value}" hex_value)
  set(${out_hex_value} "${hex_value}" PARENT_SCOPE)

endfunction()


function(_FRUT_get_au_main_type_code out_value)

  if(NOT DEFINED JUCER_PLUGIN_AU_MAIN_TYPE)
    if(JUCER_MIDI_EFFECT_PLUGIN)
      set(code "aumi")
    elseif(JUCER_PLUGIN_IS_A_SYNTH)
      set(code "aumu")
    elseif(JUCER_PLUGIN_MIDI_INPUT)
      set(code "aumf")
    else()
      set(code "aufx")
    endif()
  else()
    set(code "${JUCER_PLUGIN_AU_MAIN_TYPE}")
  endif()

  set(${out_value} "${code}" PARENT_SCOPE)

endfunction()
