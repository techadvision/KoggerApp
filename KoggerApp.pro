QT += core gui quick widgets network qml sql concurrent positioning quickcontrols2

CONFIG += c++23

#CONFIG += FLASHER

CONFIG += c++17 qmltypes
QML_IMPORT_NAME = SceneGraphRendering
QML_IMPORT_MAJOR_VERSION = 1

TEMPLATE = app
TARGET   = Pulse

DEFINES += QT_DEPRECATED_WARNINGS
#DEFINES += SEPARATE_READING # data reception in a separate thread
#DEFINES += SCENE_TESTING # testing 3d scene

### HEADERS
HEADERS += \
    src/InsetsHelper.h \
    src/SettingsBus.h \
    src/UiMetrics.h \
    src/black_stripes_processor.h \
    src/console.h \
    src/console_list_model.h \
    src/converter_xtf.h \
    src/core.h \
    src/internet_manager.h \
    src/dataset.h \
    src/dataset_defs.h \
    src/data_interpolator.h \
    src/data_horizon.h \
    src/dsp_defs.h \
    src/epoch.h \
    src/hotkeys_manager.h \
    src/id_binnary.h \
    src/delaunay.h \
    src/delaunay_defs.h \
    src/installtoken.h \
    src/logger.h \
    src/map_defs.h \
    src/isobaths_defs.h \
    src/math_defs.h \
    src/mav_link_conf.h \
    src/proto_binnary.h \
    src/stream_list.h \
    src/stream_list_model.h \
    src/themes.h \
    src/udp_broadcaster.h \
    src/xtf_conf.h \
    src/NMEASender.h \
    src/SlidingWindowMedian.h \
    src/xtf_conf.h \
    src/location_reader.h \
    src/mosaic_index_provider.h


### SOURCES
SOURCES += \
    src/SettingsBus.cpp \
    src/UiMetrics.cpp \
    src/black_stripes_processor.cpp \
    src/console.cpp \
    src/console_list_model.cpp \
    src/core.cpp \
    src/internet_manager.cpp \
    src/dataset.cpp \
    src/data_interpolator.cpp \
    src/data_horizon.cpp \
    src/epoch.cpp \
    src/hotkeys_manager.cpp \
    src/id_binnary.cpp \
    src/installtoken.cpp \
    src/logger.cpp \
    src/main.cpp \
    src/map_defs.cpp \
    src/stream_list.cpp \
    src/stream_list_model.cpp \
    src/NMEASender.cpp \
    src/location_reader.cpp \
    src/mosaic_index_provider.cpp

FLASHER {
    DEFINES += FLASHER
    HEADERS += \
        src/flasher/flasher.h \
        src/flasher/deviceflasher.h
    SOURCES += \
        src/flasher/flasher.cpp \
        src/flasher/deviceflasher.cpp
}

TRANSLATIONS += \
    translations/translation_en.ts \
    translations/translation_ru.ts \
    translations/translation_pl.ts

RESOURCES += \
    images.qrc \
    qml/qml.qrc \
    resources/icons.qrc \
    resources/resources.qrc

windows {
    message("Building for Windows with full OpenGL")
    LIBS += -lopengl32
    RESOURCES += resources/shaders.qrc
}
linux:!android {
    PLATFORM_ARCH = $$system(uname -m)
    equals(PLATFORM_ARCH, aarch64) {
        message("Building for Raspberry Pi (ARM) with OpenGL ES")
        DEFINES += LINUX_ES
        LIBS += -lGLESv2
        RESOURCES += platform/android/shaders.qrc
    } else {
        message("Building for Ubuntu Desktop with full OpenGL")
        DEFINES += LINUX_DESKTOP
        LIBS += -lGL
        RESOURCES += resources/shaders.qrc
    }
}

# QML import paths
QML_IMPORT_PATH = $$PWD/qml
QML_DESIGNER_IMPORT_PATH = $$PWD/qml

# Deployment paths
qnx: target.path = /tmp/$${TARGET}/bin
else: unix:!android: target.path = /opt/$${TARGET}/bin
!isEmpty(target.path): INSTALLS += target

### DISTFILES
DISTFILES += \
    platform/android/res/drawable-hdpi/icon.png \
    platform/android/res/drawable-mdpi/icon.png \
    platform/android/res/drawable-xhdpi/icon.png \
    platform/android/res/drawable-xxhdpi/icon.png \
    platform/android/res/drawable-xxxhdpi/icon.png \
    platform/android/res/drawable/logo_icon.png \
    platform/android/res/values/styles.xml \
    qml/Common/MenuBlockEx.qml \
    qml/Scene3DToolbar.qml \
    qml/SceneObjectsControlBar/ActiveObjectParams.qml \
    qml/SceneObjectsControlBar/BottomTrackParams.qml \
    qml/SceneObjectsControlBar/SceneObjectsControlBar.qml \
    qml/SceneObjectsControlBar/SceneObjectsList.qml \
    qml/SceneObjectsControlBar/SceneObjectsListDelegate.qml \
    qml/SceneObjectsList.qml \
    qml/SceneObjectsListDelegate.qml \
    qml/AdjBox.qml \
    qml/AdjBoxBack.qml \
    qml/BackStyle.qml \
    qml/CButton.qml \
    qml/CCombo.qml \
    qml/CComboBox.qml \
    qml/CSlider.qml \
    qml/ComboBackStyle.qml \
    qml/ConnectionViewer.qml \
    qml/Console.qml \
    qml/CustomGroupBox.qml \
    qml/DeviceSettingsViewer.qml \
    qml/MenuBar.qml \
    qml/MenuFrame.qml \
    qml/MenuButton.qml \
    qml/MenuViewer.qml \
    qml/TabBackStyle.qml \
    qml/UpgradeBox.qml \
    qml/FlashBox.qml \
    qml/main.qml

win32:RC_FILE = resources/file.rc

# Freetype configuration per platform
linux:!android {
    contains(QMAKE_HOST.arch, arm) {
        message("Using freetype for Raspberry Pi 4 (aarch64)")
        LIBS += -L$$PWD/third_party/freetype/lib/aarch64 -lfreetype
        LIBS += -lpng -lbrotlidec
    }
    else {
        LIBS += -L$$PWD/third_party/freetype/lib/gcc/ -lfreetype
    }
}

win32:CONFIG(release, debug|release): LIBS += -L$$PWD/third_party/freetype/lib/mingw-x64/ -lfreetype
else:win32:CONFIG(debug, debug|release): LIBS += -L$$PWD/third_party/freetype/lib/mingw-x64/ -lfreetype

# --- macOS (arm64/x64) ---
# Let us remove the mac for now
#macx {
#
#    INCLUDEPATH += /opt/homebrew/include/freetype2
#    LIBS += -L/opt/homebrew/lib -lfreetype
#    QMAKE_RPATHDIR += /opt/homebrew/lib
#}

#INCLUDEPATH += $$PWD/src

# If you still vendor headers for non-mac:
#!macx {
#    INCLUDEPATH += $$PWD/third_party/freetype/include
#    DEPENDPATH  += $$PWD/third_party/freetype/include
#}

INCLUDEPATH += $$PWD/third_party/freetype/include
DEPENDPATH += $$PWD/third_party/freetype/include

#win32:CONFIG(release, debug|release): LIBS += -L$$PWD/third_party/freetype/lib/llvm-mingw-x64/ -lfreetype
#else:win32:CONFIG(debug, debug|release): LIBS += -L$$PWD/third_party/freetype/lib/llvm-mingw-x64/ -lfreetype
#INCLUDEPATH += $$PWD/third_party/freetype/include
#DEPENDPATH += $$PWD/third_party/freetype/include


# Module includes
INCLUDEPATH += $$PWD/src
include($$PWD/src/data_processor/data_processor.pri)
include($$PWD/src/scene2d/scene2d.pri)
include($$PWD/src/scene3d/scene3d.pri)
include($$PWD/src/device/device.pri)
include($$PWD/src/link/link.pri)
include($$PWD/src/tile_engine/tile_engine.pri)

android {
    # 16 KB page size - Pulse: We MAY need to revert back to this should we not be able to build ith 16 KB page support
    # Commented out for now
    #QMAKE_LFLAGS += -Wl,-z,max-page-size=16384
    #QMAKE_LFLAGS += -Wl,-z,common-page-size=16384
    #ANDROID_EXTRA_LIBS += \
    #    $$PWD/third_party/android-libs/$${ANDROID_TARGET_ARCH}/libc++_shared.so \
    #    $$PWD/third_party/android-libs/$${ANDROID_TARGET_ARCH}/libc++abi.so \
    #    $$PWD/third_party/android-libs/$${ANDROID_TARGET_ARCH}/libunwind.so \
    #    $$PWD/third_party/android-libs/$${ANDROID_TARGET_ARCH}/libcrypto_1_1.so \
    #    $$PWD/third_party/android-libs/$${ANDROID_TARGET_ARCH}/libssl_1_1.so
    # -------
    #ANDROID_TARGET_SDK_VERSION = 35
    ANDROID_MIN_SDK_VERSION = 23
    include($$PWD/platform/android/src/android.pri) # activity, serialport
    QT -= widgets
    QT += svg
    QTPLUGIN += qsqlite
    # Commented out multi ABI, but we MUST revert here and fix it
    #ANDROID_ABIS = armeabi-v7a arm64-v8a
    ANDROID_ABIS = arm64-v8a

    ANDROID_PACKAGE_SOURCE_DIR = $$PWD/platform/android
    ANDROID_EXTRA_PLUGINS += \
        $$[QT_INSTALL_PLUGINS]/sqldrivers
    CONFIG += mobility

    QMAKE_CXXFLAGS_DEBUG -= -O2
    QMAKE_CXXFLAGS_DEBUG -= -O3
    QMAKE_CXXFLAGS_DEBUG += -O0

    DISTFILES += \
        platform/android/AndroidManifest.xml \
        platform/android/build.gradle \
        platform/android/gradle/wrapper/gradle-wrapper.jar \
        platform/android/gradle/wrapper/gradle-wrapper.properties \
        platform/android/gradlew \
        platform/android/gradlew.bat \
        platform/android/res/values/libs.xml

    equals(ANDROID_TARGET_ARCH, arm64-v8a) {
        message("Adding FreeType Lib for arm64-v8a arch")
        LIBS += -L$$PWD/third_party/freetype/lib/arm64-v8a -lfreetype
    } else:equals(ANDROID_TARGET_ARCH, armeabi-v7a) {
        message("Adding FreeType Lib for armeabi-v7a arch")
        LIBS += -L$$PWD/third_party/freetype/lib/armeabi-v7a -lfreetype
    }

    #OPENSSL_PATH = $$ANDROID_SDK_ROOT/android_openssl/openssl.pri
    OPENSSL_PATH = third_party/android_openssl/openssl.pri
    include($$OPENSSL_PATH)

    #OPENSSL_PATH = $$ANDROID_SDK_ROOT/android_openssl/openssl.pri
    #OPENSSL_PATH = $$PWD/third_party/android_openssl/openssl.pri
    #ENABLE_OPENSSL_BUNDLING = no
    #include($$OPENSSL_PATH)
    #message(Final ANDROID_EXTRA_LIBS = $$ANDROID_EXTRA_LIBS)

    # Commented out
    # ANDROID_EXTRA_LIBS = $$unique(ANDROID_EXTRA_LIBS)

    message("Building for Android (ARM) with OpenGL ES")
    RESOURCES += platform/android/shaders.qrc
}
else {
    QT += serialport
}
