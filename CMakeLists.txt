cmake_minimum_required(VERSION 3.21)

project(KoggerApp VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC OFF)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Matches optional qmake CONFIG flags.
option(FLASHER "Enable flasher support" OFF)
option(SEPARATE_READING "Data reception in a separate thread" OFF)
option(SCENE_TESTING "Enable 3D scene testing" OFF)
option(KOGGER_BUNDLE_ANDROID_OPENSSL "Bundle Android OpenSSL shared libraries" ON)

# Important for Qt Android multi-ABI sub-builds: forward project options.
set(KOGGER_ANDROID_ABIS "arm64-v8a;armeabi-v7a" CACHE STRING "Android ABIs to build/package")
if(ANDROID)
    list(APPEND QT_ANDROID_MULTI_ABI_FORWARD_VARS
        FLASHER
        SEPARATE_READING
        SCENE_TESTING
        KOGGER_BUNDLE_ANDROID_OPENSSL
        KOGGER_ANDROID_ABIS
    )
endif()

set(KOGGER_QT_MODULES
    Core
    Gui
    Quick
    Network
    Qml
    Sql
    Concurrent
    Positioning
    QuickControls2
    Svg
)

if(NOT ANDROID)
    list(APPEND KOGGER_QT_MODULES Widgets SerialPort)
endif()

find_package(Qt6 REQUIRED COMPONENTS ${KOGGER_QT_MODULES})

qt_standard_project_setup()

set(APP_HEADERS
    src/InsetsHelper.h
    src/SettingsBus.h
    src/UiMetrics.h
    src/black_stripes_processor.h
    src/console.h
    src/console_list_model.h
    src/converter_xtf.h
    src/core.h
    src/internet_manager.h
    src/dataset.h
    src/dataset_defs.h
    src/data_interpolator.h
    src/data_horizon.h
    src/dsp_defs.h
    src/epoch.h
    src/hotkeys_manager.h
    src/hotkeys_controller.h
    src/id_binnary.h
    src/delaunay.h
    src/delaunay_defs.h
    src/installtoken.h
    src/logger.h
    src/map_defs.h
    src/isobaths_defs.h
    src/math_defs.h
    src/mav_link_conf.h
    src/proto_binnary.h
    src/stream_list.h
    src/stream_list_model.h
    src/ui_state_serializer.h
    src/themes.h
    src/udp_broadcaster.h
    src/xtf_conf.h
    src/NMEASender.h
    src/SlidingWindowMedian.h
    src/location_reader.h
    src/mosaic_index_provider.h
)

set(APP_SOURCES
    src/SettingsBus.cpp
    src/UiMetrics.cpp
    src/black_stripes_processor.cpp
    src/console.cpp
    src/console_list_model.cpp
    src/core.cpp
    src/internet_manager.cpp
    src/dataset.cpp
    src/data_interpolator.cpp
    src/data_horizon.cpp
    src/epoch.cpp
    src/hotkeys_manager.cpp
    src/hotkeys_controller.cpp
    src/id_binnary.cpp
    src/installtoken.cpp
    src/logger.cpp
    src/main.cpp
    src/map_defs.cpp
    src/stream_list.cpp
    src/stream_list_model.cpp
    src/ui_state_serializer.cpp
    src/NMEASender.cpp
    src/location_reader.cpp
    src/mosaic_index_provider.cpp
)

set(APP_RESOURCES
    images.qrc
    qml/qml.qrc
    resources/icons.qrc
    resources/resources.qrc
)

set(APP_INCLUDE_DIRS
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/qml
    ${CMAKE_CURRENT_SOURCE_DIR}/third_party/freetype/include
)

# Keep this as an include-only path. Do not compile/moc files from
# src/scene3d/processors here. The uploaded qmake scene3d.pri does not add
# that folder as a source group, and compiling it exposes a global
# SurfaceProcessor name collision with src/data_processor/surface_processor.h.
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/src/scene3d/processors")
    list(APPEND APP_INCLUDE_DIRS
        ${CMAKE_CURRENT_SOURCE_DIR}/src/scene3d/processors
    )
endif()

# ---- src/data_processor/data_processor.pri ----
list(APPEND APP_INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/src/data_processor)
list(APPEND APP_HEADERS
    src/data_processor/bottom_track_processor.h
    src/data_processor/data_processor.h
    src/data_processor/data_processor_defs.h
    src/data_processor/isobaths_processor.h
    src/data_processor/mosaic_processor.h
    src/data_processor/surface_processor.h
    src/data_processor/surface_mesh.h
    src/data_processor/surface_tile.h
    src/data_processor/compute_worker.h
    src/data_processor/mosaic_db.h
    src/data_processor/hot_tile_cache.h
)
list(APPEND APP_SOURCES
    src/data_processor/bottom_track_processor.cpp
    src/data_processor/data_processor.cpp
    src/data_processor/isobaths_processor.cpp
    src/data_processor/mosaic_processor.cpp
    src/data_processor/surface_processor.cpp
    src/data_processor/surface_mesh.cpp
    src/data_processor/surface_tile.cpp
    src/data_processor/compute_worker.cpp
    src/data_processor/mosaic_db.cpp
    src/data_processor/hot_tile_cache.cpp
)

# ---- src/scene2d/scene2d.pri ----
list(APPEND APP_INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/src/scene2d)
list(APPEND APP_HEADERS
    src/scene2d/plot2D.h
    src/scene2d/plot2D_aim.h
    src/scene2d/plot2D_attitude.h
    src/scene2d/plot2D_bottom_processing.h
    src/scene2d/plot2D_contact.h
    src/scene2d/plot2D_defs.h
    src/scene2d/plot2D_dvl_beam_velocity.h
    src/scene2d/plot2D_dvl_solution.h
    src/scene2d/plot2D_echogram.h
    src/scene2d/plot2D_encoder.h
    src/scene2d/plot2D_gnss.h
    src/scene2d/plot2D_grid.h
    src/scene2d/plot2D_temperature.h
    src/scene2d/plot2D_line.h
    src/scene2d/plot2D_plot_layer.h
    src/scene2d/plot2D_quadrature.h
    src/scene2d/plot2D_rangefinder.h
    src/scene2d/plot2D_usbl_solution.h
    src/scene2d/plot2D_depth.h
    src/scene2d/plot2D_zoom.h
    src/scene2d/echogram_sidescan_tvg.h
    src/scene2d/echogram_tvg.h
    src/scene2d/echogram_watercolumn.h
    src/scene2d/qPlot2D.h
)
list(APPEND APP_SOURCES
    src/scene2d/plot2D.cpp
    src/scene2d/plot2D_aim.cpp
    src/scene2d/plot2D_attitude.cpp
    src/scene2d/plot2D_bottom_processing.cpp
    src/scene2d/plot2D_contact.cpp
    src/scene2d/plot2D_dvl_beam_velocity.cpp
    src/scene2d/plot2D_dvl_solution.cpp
    src/scene2d/plot2D_echogram.cpp
    src/scene2d/plot2D_encoder.cpp
    src/scene2d/plot2D_gnss.cpp
    src/scene2d/plot2D_grid.cpp
    src/scene2d/plot2D_temperature.cpp
    src/scene2d/plot2D_line.cpp
    src/scene2d/plot2D_quadrature.cpp
    src/scene2d/plot2D_rangefinder.cpp
    src/scene2d/plot2D_usbl_solution.cpp
    src/scene2d/plot2D_depth.cpp
    src/scene2d/plot2D_zoom.cpp
    src/scene2d/echogram_sidescan_tvg.cpp
    src/scene2d/echogram_tvg.cpp
    src/scene2d/echogram_watercolumn.cpp
    src/scene2d/qPlot2D.cpp
)

# ---- src/scene3d/scene3d.pri ----
list(APPEND APP_INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/src/scene3d)
list(APPEND APP_HEADERS
    src/scene3d/scene3d_renderer.h
    src/scene3d/scene3d_view.h
)
list(APPEND APP_SOURCES
    src/scene3d/scene3d_renderer.cpp
    src/scene3d/scene3d_view.cpp
)

# scene3d.pri also includes controllers/core/domain/events/utils .pri files.
# Those nested .pri files were not included in the upload, so this safely adds
# the usual .cpp/.h files from those subdirectories. Replace with explicit lists
# later if you prefer no GLOBs.
foreach(_scene3d_subdir controllers core domain events utils)
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/src/scene3d/${_scene3d_subdir}")
        list(APPEND APP_INCLUDE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/src/scene3d/${_scene3d_subdir}")
        file(GLOB_RECURSE _scene3d_headers CONFIGURE_DEPENDS
            "${CMAKE_CURRENT_SOURCE_DIR}/src/scene3d/${_scene3d_subdir}/*.h"
            "${CMAKE_CURRENT_SOURCE_DIR}/src/scene3d/${_scene3d_subdir}/*.hpp"
        )
        file(GLOB_RECURSE _scene3d_sources CONFIGURE_DEPENDS
            "${CMAKE_CURRENT_SOURCE_DIR}/src/scene3d/${_scene3d_subdir}/*.cpp"
            "${CMAKE_CURRENT_SOURCE_DIR}/src/scene3d/${_scene3d_subdir}/*.cxx"
            "${CMAKE_CURRENT_SOURCE_DIR}/src/scene3d/${_scene3d_subdir}/*.cc"
        )
        list(APPEND APP_HEADERS ${_scene3d_headers})
        list(APPEND APP_SOURCES ${_scene3d_sources})
    endif()
endforeach()

# ---- src/device/device.pri ----
list(APPEND APP_INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/src/device)
list(APPEND APP_HEADERS
    src/device/dev_driver.h
    src/device/dev_q_property.h
    src/device/device_defs.h
    src/device/device_manager.h
    src/device/device_manager_wrapper.h
)
list(APPEND APP_SOURCES
    src/device/dev_driver.cpp
    src/device/device_manager.cpp
    src/device/device_manager_wrapper.cpp
)

# ---- src/link/link.pri ----
list(APPEND APP_INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/src/link)
list(APPEND APP_HEADERS
    src/link/link.h
    src/link/link_defs.h
    src/link/link_list_model.h
    src/link/link_manager.h
    src/link/link_manager_wrapper.h
)
list(APPEND APP_SOURCES
    src/link/link.cpp
    src/link/link_list_model.cpp
    src/link/link_manager.cpp
    src/link/link_manager_wrapper.cpp
)

# ---- src/tile_engine/tile_engine.pri ----
list(APPEND APP_INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/src/tile_engine)
list(APPEND APP_HEADERS
    src/tile_engine/tile_db.h
    src/tile_engine/tile_downloader.h
    src/tile_engine/tile_google_provider.h
    src/tile_engine/tile_osm_provider.h
    src/tile_engine/tile_manager.h
    src/tile_engine/tile_provider.h
    src/tile_engine/tile_provider_ids.h
    src/tile_engine/tile_set.h
)
list(APPEND APP_SOURCES
    src/tile_engine/tile_db.cpp
    src/tile_engine/tile_downloader.cpp
    src/tile_engine/tile_google_provider.cpp
    src/tile_engine/tile_osm_provider.cpp
    src/tile_engine/tile_manager.cpp
    src/tile_engine/tile_provider.cpp
    src/tile_engine/tile_set.cpp
)

# ---- platform/android/src/android.pri ----
if(ANDROID)
    list(APPEND APP_INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/platform/android/src)
    list(APPEND APP_HEADERS
        platform/android/src/android_interface.h
        platform/android/src/android_serial.h
        platform/android/src/kogger_logging_category.h
        platform/android/src/qml_object_list_model.h
    )
    list(APPEND APP_SOURCES
        platform/android/src/android_init.cpp
        platform/android/src/android_interface.cpp
        platform/android/src/android_serial.cpp
        platform/android/src/kogger_logging_category.cpp
        platform/android/src/qml_object_list_model.cpp
    )

    # android.pri includes platform/android/src/qtandroidserialport/qtandroidserialport.pri.
    # The nested .pri was not included in the upload, so this adds the common C/C++ files.
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/platform/android/src/qtandroidserialport")
        list(APPEND APP_INCLUDE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/platform/android/src/qtandroidserialport")
        file(GLOB_RECURSE _android_serial_headers CONFIGURE_DEPENDS
            "${CMAKE_CURRENT_SOURCE_DIR}/platform/android/src/qtandroidserialport/*.h"
            "${CMAKE_CURRENT_SOURCE_DIR}/platform/android/src/qtandroidserialport/*.hpp"
        )
        file(GLOB_RECURSE _android_serial_sources CONFIGURE_DEPENDS
            "${CMAKE_CURRENT_SOURCE_DIR}/platform/android/src/qtandroidserialport/*.cpp"
            "${CMAKE_CURRENT_SOURCE_DIR}/platform/android/src/qtandroidserialport/*.c"
            "${CMAKE_CURRENT_SOURCE_DIR}/platform/android/src/qtandroidserialport/*.cc"
            "${CMAKE_CURRENT_SOURCE_DIR}/platform/android/src/qtandroidserialport/*.cxx"
        )
        list(APPEND APP_HEADERS ${_android_serial_headers})
        list(APPEND APP_SOURCES ${_android_serial_sources})
    endif()
endif()

if(FLASHER)
    list(APPEND APP_HEADERS
        src/flasher/flasher.h
        src/flasher/deviceflasher.h
    )
    list(APPEND APP_SOURCES
        src/flasher/flasher.cpp
        src/flasher/deviceflasher.cpp
    )
endif()

if(ANDROID)
    list(APPEND APP_RESOURCES platform/android/shaders.qrc)
elseif(WIN32)
    list(APPEND APP_RESOURCES resources/shaders.qrc)
elseif(UNIX AND NOT APPLE)
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
        list(APPEND APP_RESOURCES platform/android/shaders.qrc)
    else()
        list(APPEND APP_RESOURCES resources/shaders.qrc)
    endif()
endif()

# ---- Remove files that the broad fallback GLOBs may pull in but qmake did not build ----
# The nested scene3d .pri files were not available, so the initial CMake file
# used directory GLOBs for controllers/domain/etc. Those GLOBs can include
# incomplete/disabled upstream surface UI files. qmake is the source of truth:
# do not build those files unless the real nested .pri files say so.
#
# Important: file(GLOB_RECURSE ...) returns absolute paths because the patterns
# above are absolute. Therefore list(REMOVE_ITEM ... "src/...") is not enough.
# Use list(FILTER ... EXCLUDE REGEX ...) so both absolute and relative paths are
# removed reliably.
set(KOGGER_EXCLUDED_GLOB_REGEXES
    "(^|.*/)src/scene3d/controllers/surface_control_menu_controller\.(h|hpp|cpp|cc|cxx)$"
    "(^|.*/)src/scene3d/domain/surface\.(h|hpp|cpp|cc|cxx)$"
    "(^|.*/)src/scene3d/domain/surface_grid\.(h|hpp|cpp|cc|cxx)$"
)
foreach(_kogger_excluded_regex IN LISTS KOGGER_EXCLUDED_GLOB_REGEXES)
    list(FILTER APP_HEADERS EXCLUDE REGEX "${_kogger_excluded_regex}")
    list(FILTER APP_SOURCES EXCLUDE REGEX "${_kogger_excluded_regex}")
endforeach()

qt_add_executable(Pulse
    MANUAL_FINALIZATION
    ${APP_HEADERS}
    ${APP_SOURCES}
    ${APP_RESOURCES}
)

target_include_directories(Pulse PRIVATE ${APP_INCLUDE_DIRS})


# qmake handled Qt private header include paths via core-private. The Qt Android
# CMake package may not ship a Qt6::CorePrivate target, so add only the include
# paths that the copied Android serial-port sources require.
if(ANDROID)
    if(DEFINED Qt6Core_VERSION AND NOT "${Qt6Core_VERSION}" STREQUAL "")
        set(KOGGER_QTCORE_PRIVATE_VERSION "${Qt6Core_VERSION}")
    elseif(DEFINED Qt6_VERSION AND NOT "${Qt6_VERSION}" STREQUAL "")
        set(KOGGER_QTCORE_PRIVATE_VERSION "${Qt6_VERSION}")
    else()
        message(FATAL_ERROR "Could not determine Qt version for QtCore private headers.")
    endif()

    set(KOGGER_QT_PREFIX_CANDIDATES ${CMAKE_PREFIX_PATH})
    set(KOGGER_QT_PREFIX "")

    foreach(_qt_prefix IN LISTS KOGGER_QT_PREFIX_CANDIDATES)
        if(EXISTS "${_qt_prefix}/include/QtCore/${KOGGER_QTCORE_PRIVATE_VERSION}/QtCore/private/qglobal_p.h")
            set(KOGGER_QT_PREFIX "${_qt_prefix}")
            break()
        endif()
    endforeach()

    if(NOT KOGGER_QT_PREFIX AND DEFINED Qt6_DIR)
        get_filename_component(_qt_prefix_from_qt6_dir "${Qt6_DIR}/../../.." ABSOLUTE)
        if(EXISTS "${_qt_prefix_from_qt6_dir}/include/QtCore/${KOGGER_QTCORE_PRIVATE_VERSION}/QtCore/private/qglobal_p.h")
            set(KOGGER_QT_PREFIX "${_qt_prefix_from_qt6_dir}")
        endif()
    endif()

    if(NOT KOGGER_QT_PREFIX)
        message(FATAL_ERROR
            "Missing QtCore private headers for Qt ${KOGGER_QTCORE_PRIVATE_VERSION}. "
            "Expected qglobal_p.h under <Qt prefix>/include/QtCore/${KOGGER_QTCORE_PRIVATE_VERSION}/QtCore/private."
        )
    endif()

    target_include_directories(Pulse PRIVATE
        "${KOGGER_QT_PREFIX}/include/QtCore/${KOGGER_QTCORE_PRIVATE_VERSION}"
        "${KOGGER_QT_PREFIX}/include/QtCore/${KOGGER_QTCORE_PRIVATE_VERSION}/QtCore"
    )
    set_target_properties(Pulse PROPERTIES
        QT_ANDROID_ABIS "${KOGGER_ANDROID_ABIS}"
    )
endif()

# CMake AUTOMOC generates one aggregate mocs_compilation.cpp. This project has
# two unrelated global classes named SurfaceProcessor in different folders, so
# that aggregate translation unit includes both headers and fails with a
# redefinition. qmake builds the generated moc files separately; reproduce that
# behavior here by disabling AUTOMOC for the target and adding separate moc
# sources explicitly.
set_target_properties(Pulse PROPERTIES AUTOMOC OFF)

target_compile_definitions(Pulse PRIVATE QT_DEPRECATED_WARNINGS)

if(FLASHER)
    target_compile_definitions(Pulse PRIVATE FLASHER)
endif()
if(SEPARATE_READING)
    target_compile_definitions(Pulse PRIVATE SEPARATE_READING)
endif()
if(SCENE_TESTING)
    target_compile_definitions(Pulse PRIVATE SCENE_TESTING)
endif()

# Manual MOC generation. Only feed headers that actually contain Qt meta-object
# macros, and compile each generated moc source as its own translation unit.
set(KOGGER_MOC_HEADERS)
foreach(_kogger_header IN LISTS APP_HEADERS)
    if(IS_ABSOLUTE "${_kogger_header}")
        set(_kogger_header_abs "${_kogger_header}")
    else()
        set(_kogger_header_abs "${CMAKE_CURRENT_SOURCE_DIR}/${_kogger_header}")
    endif()

    if(EXISTS "${_kogger_header_abs}")
        file(STRINGS "${_kogger_header_abs}" _kogger_moc_markers
            REGEX "^[ \t]*(Q_OBJECT|Q_GADGET|Q_NAMESPACE|Q_NAMESPACE_EXPORT)"
        )
        if(_kogger_moc_markers)
            list(APPEND KOGGER_MOC_HEADERS "${_kogger_header_abs}")
        endif()
        unset(_kogger_moc_markers)
    endif()
endforeach()
list(REMOVE_DUPLICATES KOGGER_MOC_HEADERS)

if(KOGGER_MOC_HEADERS)
    qt_wrap_cpp(KOGGER_MOC_SOURCES
        ${KOGGER_MOC_HEADERS}
        TARGET Pulse
    )

    # qserialport.cpp includes "moc_qserialport.cpp" manually.
    # Therefore:
    #   1. Generate moc_qserialport.cpp.
    #   2. Add its generated directory to the include path.
    #   3. Make qserialport.cpp depend on it.
    #   4. Do NOT compile moc_qserialport.cpp as a separate source.
    if(ANDROID)
        set(KOGGER_QSERIALPORT_CPP
            "${CMAKE_CURRENT_SOURCE_DIR}/platform/android/src/qtandroidserialport/qserialport.cpp"
        )

        set(KOGGER_QSERIALPORT_MOC)

        foreach(_kogger_moc_src IN LISTS KOGGER_MOC_SOURCES)
            if("${_kogger_moc_src}" MATCHES "platform/android/src/qtandroidserialport/moc_qserialport\\.cpp$")
                set(KOGGER_QSERIALPORT_MOC "${_kogger_moc_src}")
            endif()
        endforeach()

        if(KOGGER_QSERIALPORT_MOC)
            list(REMOVE_ITEM KOGGER_MOC_SOURCES "${KOGGER_QSERIALPORT_MOC}")

            get_filename_component(
                KOGGER_QSERIALPORT_MOC_DIR
                "${KOGGER_QSERIALPORT_MOC}"
                DIRECTORY
            )

            target_include_directories(Pulse PRIVATE
                "${KOGGER_QSERIALPORT_MOC_DIR}"
            )

            set_source_files_properties(
                "${KOGGER_QSERIALPORT_CPP}"
                PROPERTIES OBJECT_DEPENDS "${KOGGER_QSERIALPORT_MOC}"
            )
        endif()
    endif()

    target_sources(Pulse PRIVATE ${KOGGER_MOC_SOURCES})
endif()

target_link_libraries(Pulse PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::Network
    Qt6::Qml
    Qt6::Sql
    Qt6::Concurrent
    Qt6::Positioning
    Qt6::QuickControls2
    Qt6::Svg
)

if(NOT ANDROID)
    target_link_libraries(Pulse PRIVATE Qt6::Widgets Qt6::SerialPort)
endif()

if(WIN32)
    target_link_libraries(Pulse PRIVATE opengl32)
elseif(UNIX AND NOT APPLE AND NOT ANDROID)
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
        target_compile_definitions(Pulse PRIVATE LINUX_ES)
        target_link_libraries(Pulse PRIVATE GLESv2)
    else()
        target_compile_definitions(Pulse PRIVATE LINUX_DESKTOP)
        target_link_libraries(Pulse PRIVATE GL)
    endif()
endif()

# ---- FreeType ----
if(ANDROID)
    if(DEFINED ANDROID_ABI AND NOT "${ANDROID_ABI}" STREQUAL "")
        set(KOGGER_CURRENT_ANDROID_ABI "${ANDROID_ABI}")
    elseif(DEFINED CMAKE_ANDROID_ARCH_ABI AND NOT "${CMAKE_ANDROID_ARCH_ABI}" STREQUAL "")
        set(KOGGER_CURRENT_ANDROID_ABI "${CMAKE_ANDROID_ARCH_ABI}")
    else()
        message(FATAL_ERROR "Could not determine current Android ABI. ANDROID_ABI and CMAKE_ANDROID_ARCH_ABI are empty.")
    endif()

    set(KOGGER_FREETYPE_CURRENT_LIB
        "${CMAKE_CURRENT_SOURCE_DIR}/third_party/freetype/lib/${KOGGER_CURRENT_ANDROID_ABI}/libfreetype.a"
    )

    if(NOT EXISTS "${KOGGER_FREETYPE_CURRENT_LIB}")
        message(FATAL_ERROR "Missing FreeType static library for ${KOGGER_CURRENT_ANDROID_ABI}: ${KOGGER_FREETYPE_CURRENT_LIB}")
    endif()

    add_library(kogger_freetype STATIC IMPORTED GLOBAL)
    set_target_properties(kogger_freetype PROPERTIES
        IMPORTED_LOCATION "${KOGGER_FREETYPE_CURRENT_LIB}"
    )

    target_link_libraries(Pulse PRIVATE
        kogger_freetype
        z
    )

elseif(WIN32)
    target_link_directories(Pulse PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/third_party/freetype/lib/mingw-x64")
    target_link_libraries(Pulse PRIVATE freetype)

elseif(UNIX AND NOT APPLE)
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
        target_link_directories(Pulse PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/third_party/freetype/lib/aarch64")
        target_link_libraries(Pulse PRIVATE freetype png brotlidec)
    else()
        target_link_directories(Pulse PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/third_party/freetype/lib/gcc")
        target_link_libraries(Pulse PRIVATE freetype)
    endif()
endif()

# ---- Android deployment/template/OpenSSL ----
if(ANDROID)
    set_target_properties(Pulse PROPERTIES
        QT_ANDROID_ABIS "${KOGGER_ANDROID_ABIS}"
        QT_ANDROID_MIN_SDK_VERSION 28
        QT_ANDROID_TARGET_SDK_VERSION 36
        QT_ANDROID_SDK_BUILD_TOOLS_REVISION "36.1.0"
        QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/platform/android"
        QT_QML_IMPORT_PATH "${CMAKE_CURRENT_SOURCE_DIR}/qml"
    )

    # Keep this unset here while testing. Set it in Qt Creator instead:
    #   QT_ANDROID_ABIS:STRING=arm64-v8a
    #   QT_ANDROID_ABIS:STRING=armeabi-v7a
    #   QT_ANDROID_ABIS:STRING=arm64-v8a;armeabi-v7a

    target_link_options(Pulse PRIVATE
        "-Wl,-z,max-page-size=16384"
        "-Wl,-z,common-page-size=16384"
    )

    qt_import_plugins(Pulse
        INCLUDE_BY_TYPE sqldrivers Qt6::QSQLiteDriverPlugin
    )

    # Extra Android shared libraries to deploy.
    # For a multi-ABI build, Qt docs recommend listing all per-ABI paths explicitly.
    if(ANDROID AND DEFINED KOGGER_ANDROID_ABIS AND NOT "${KOGGER_ANDROID_ABIS}" STREQUAL "")
        set(KOGGER_DEPLOY_ANDROID_ABIS ${KOGGER_ANDROID_ABIS})
    elseif(DEFINED QT_ANDROID_ABIS AND NOT "${QT_ANDROID_ABIS}" STREQUAL "")
        set(KOGGER_DEPLOY_ANDROID_ABIS ${QT_ANDROID_ABIS})
    else()
        set(KOGGER_DEPLOY_ANDROID_ABIS ${KOGGER_CURRENT_ANDROID_ABI})
    endif()

    set(KOGGER_ANDROID_EXTRA_LIBS)

    if(KOGGER_BUNDLE_ANDROID_OPENSSL)
        if(CMAKE_BUILD_TYPE STREQUAL "Release")
            set(KOGGER_ANDROID_OPENSSL_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/third_party/android_openssl")
        else()
            set(KOGGER_ANDROID_OPENSSL_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/third_party/android_openssl/no-asm")
        endif()

        foreach(_abi IN LISTS KOGGER_DEPLOY_ANDROID_ABIS)
            set(_crypto_lib "${KOGGER_ANDROID_OPENSSL_ROOT}/ssl_3/${_abi}/libcrypto_3.so")
            set(_ssl_lib    "${KOGGER_ANDROID_OPENSSL_ROOT}/ssl_3/${_abi}/libssl_3.so")
            if(NOT EXISTS "${_crypto_lib}")
                message(FATAL_ERROR "Missing OpenSSL crypto library for ${_abi}: ${_crypto_lib}")
            endif()
            if(NOT EXISTS "${_ssl_lib}")
                message(FATAL_ERROR "Missing OpenSSL ssl library for ${_abi}: ${_ssl_lib}")
            endif()
            list(APPEND KOGGER_ANDROID_EXTRA_LIBS "${_crypto_lib}" "${_ssl_lib}")
        endforeach()
    endif()

    if(KOGGER_ANDROID_EXTRA_LIBS)
        set_target_properties(Pulse PROPERTIES
            QT_ANDROID_EXTRA_LIBS "${KOGGER_ANDROID_EXTRA_LIBS}"
        )
    endif()
endif()

qt_finalize_executable(Pulse)
