#include <QGuiApplication>
#include <QQmlContext>
#include <QQmlApplicationEngine>
#include <QTranslator>
#include <QLocale>
#include <QSettings>
#include <QVector>
#include <QString>

#include <QThread>
#include <QResource>
#include <QFile>
#include <QByteArray>
#include <QQuickWindow>

#include "NMEASender.h"

#include <QPointer>

#include <QSql>
#include <QSqlDatabase>
#include <QQuickStyle>
#include <QWindow>
#include <QStyleHints>
#include <QLoggingCategory>
#if defined(Q_OS_WIN)
#include <windows.h>
#endif
#include "qPlot2D.h"
#include "core.h"
#include "themes.h"
#include "ui_probe.h"
#include "ui_state_serializer.h"
#include "echogram_state_serializer.h"
#include "notifications.h"
#include "scene_object.h"
#include "bottom_track.h"
#include "input_device_tracker.h"
#ifndef Q_OS_ANDROID
#include "instance_lock.h"
#endif
#include "system_battery.h"
#include "mosaic_db.h"
#include "language_controller.h"
#include "app_utils.h"
#include "app_log.h"
#include "settings_migration.h"
//NOTE: upstream's RTSP video module (src/video, VideoStreamPool) is deliberately NOT
//merged. video_stream.cpp includes libavcodec/libavformat directly and upstream's
//CMakeLists has no ffmpeg find or link at all, so it cannot survive the Android
//multi-ABI build - and streaming video belongs to Seascape, not the sounder.

#if defined(Q_OS_ANDROID)
#include <QCoreApplication>          // brings in QNativeInterface::QAndroidApplication
#include <QtCore/qnativeinterface.h> // robust include (works even if <QNativeInterface> is missing)
#include <QtCore/qjniobject.h>       // QJniObject (Qt 6)
#include <QVariant>
#include "InsetsHelper.h"
#endif
#include "installtoken.h"
#include "UiMetrics.h"

// NOLINTBEGIN(bugprone-throwing-static-initialization): application-lifetime singletons; a throw here is a fatal startup failure with nothing to catch
Core core;
AppUtils appUtils;
Themes theme;
UIStateSerializer uiStateSerializer;
EchogramStateSerializer echogramStateSerializer;
Notifications notifications;
QTranslator translator;
QVector<QString> availableLanguages{"en", "ru", "pl"};
//QObject* g_pulseRuntimeSettings = nullptr;
//QObject* g_pulseSettings = nullptr;
// NOLINTEND(bugprone-throwing-static-initialization)

#ifndef Q_OS_ANDROID
InstanceLock instanceLock;
#endif

constexpr int FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS = 0x80000000;
constexpr int FLAG_TRANSLUCENT_STATUS           = 0x04000000;


static void makeStatusBarTransparent()
{
#if defined(Q_OS_ANDROID)
    QNativeInterface::QAndroidApplication::runOnAndroidMainThread([]() -> QVariant {
        constexpr int FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS = 0x80000000;
        constexpr int FLAG_TRANSLUCENT_STATUS           = 0x04000000;

        QJniObject activity = QNativeInterface::QAndroidApplication::context();
        if (!activity.isValid())
            return {};

        QJniObject window = activity.callObjectMethod("getWindow", "()Landroid/view/Window;");
        if (!window.isValid())
            return {};

        window.callMethod<void>("addFlags",   "(I)V", FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
        window.callMethod<void>("clearFlags", "(I)V", FLAG_TRANSLUCENT_STATUS);

        const jint transparent = QJniObject::getStaticField<jint>(
            "android/graphics/Color", "TRANSPARENT");
        window.callMethod<void>("setStatusBarColor", "(I)V", transparent);

        return {};
    });
#endif
}

/*
static void makeStatusBarTransparent()
{
    #if defined(Q_OS_ANDROID)
    const int FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS = 0x80000000;
    const int FLAG_TRANSLUCENT_STATUS        = 0x04000000;

    QtAndroid::runOnAndroidThread([=]() {
        QAndroidJniObject activity =
            QAndroidJniObject::callStaticObjectMethod(
                "org/qtproject/qt5/android/QtNative",
                "activity", "()Landroid/app/Activity;");
        QAndroidJniObject window = activity.callObjectMethod(
            "getWindow", "()Landroid/view/Window;");

        // allow the window to draw system bar backgrounds
        window.callMethod<void>("addFlags", "(I)V", FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
        // clear the old translucent flag (so color takes effect)
        window.callMethod<void>("clearFlags", "(I)V", FLAG_TRANSLUCENT_STATUS);
        // set status bar color to transparent
        window.callMethod<void>("setStatusBarColor", "(I)V",
                                QAndroidJniObject::getStaticField<jint>(
                                    "android/graphics/Color", "TRANSPARENT"));
    });
    #endif
}
*/

void loadLanguage(QGuiApplication &app)
{
    QSettings settings;
    QString currentLanguage;

    int savedLanguageIndex = settings.value("main/appLanguage", -1).toInt();

    if (savedLanguageIndex == -1) {
        currentLanguage = QLocale::system().name().split('_').first();
        if (auto indx = availableLanguages.indexOf(currentLanguage); indx == -1) {
            currentLanguage = availableLanguages.front();
        }
        else {
            settings.setValue("main/appLanguage", indx);
        }
    }
    else {
        if (savedLanguageIndex >= 0 && savedLanguageIndex < availableLanguages.count()) {
            currentLanguage = availableLanguages.at(savedLanguageIndex);
        }
        else {
            currentLanguage = availableLanguages.front();
        }
    }


    QString translationFile = ":/translations/translation_" + currentLanguage + ".qm";

    if (translator.load(translationFile)) {
        app.installTranslator(&translator);
    }
}

void messageHandler(QtMsgType type, const QMessageLogContext& context, const QString& msg)
{
    Q_UNUSED(type);
    Q_UNUSED(context);
    core.consoleInfo(msg);
}


QtMessageHandler previousMessageHandler = nullptr;

static bool isVideoLogMessage(const QMessageLogContext& context, const QString& msg)
{
    if (context.category && QByteArray(context.category).startsWith("qt.multimedia")) {
        return true;
    }
    return msg.startsWith(QStringLiteral("VIDEO:"));
}

void videoLogHandler(QtMsgType type, const QMessageLogContext& context, const QString& msg)
{
    static thread_local bool forwarding = false;

    if (!isVideoLogMessage(context, msg)) {
        AppLog::instance().write(type, context, msg);
    }

    if (!forwarding && isVideoLogMessage(context, msg)) {
        forwarding = true;
        const QString line = msg.startsWith(QStringLiteral("VIDEO:"))
                                 ? msg
                                 : QStringLiteral("VIDEO: ") + msg;
        if (type == QtWarningMsg || type == QtCriticalMsg || type == QtFatalMsg) {
            core.consoleWarning(line);
        }
        else {
            core.consoleInfo(line);
        }
        forwarding = false;
    }

    if (previousMessageHandler && !isVideoLogMessage(context, msg)) {
        previousMessageHandler(type, context, msg);
    }
}

void setApplicationDisplayName(QGuiApplication& app)
{
    QResource resource(":/version.txt");
    if (resource.isValid()) {
        QFile file(":/version.txt");
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QByteArray data = file.readAll();
            app.setApplicationDisplayName(QString::fromUtf8(data));
            file.close();
        }
    }
}

void registerQmlMetaTypes()
{
    qmlRegisterType<GraphicsScene3dView>("SceneGraphRendering", 1, 0,"GraphicsScene3dView");
    qmlRegisterType<qPlot2D>( "WaterFall", 1, 0, "WaterFall");
    qmlRegisterType<BottomTrack>("BottomTrack", 1, 0, "BottomTrack");
    qmlRegisterType<NMEASender>("NMEASender", 1, 0, "NMEASender");
    qRegisterMetaType<BottomTrack::ActionEvent>("BottomTrack::ActionEvent");
    qmlRegisterType<GraphicsScene3dView>("SceneGraphRendering", 1, 0,"GraphicsScene3dView");
    qRegisterMetaType<LinkAttribute>("LinkAttribute");
}

#if defined(Q_OS_WIN)
constexpr DWORD kDwmwaUseImmersiveDarkMode = 20;
constexpr DWORD kDwmwaUseImmersiveDarkModeLegacy = 19;
constexpr DWORD kDwmwaCaptionColor = 35;
constexpr DWORD kDwmwaTextColor = 36;

void applyWindowsSystemTitleBarTheme(QWindow* window)
{
    if (!window) {
        return;
    }

    const HWND handle = reinterpret_cast<HWND>(window->winId()); // NOLINT(performance-no-int-to-ptr): WId is integer, HWND is a pointer; Win32 interop requires the cast
    if (!handle) {
        return;
    }

    const HMODULE dwmApi = LoadLibraryW(L"dwmapi.dll");
    if (!dwmApi) {
        return;
    }

    using DwmSetWindowAttributeFn = HRESULT (WINAPI*)(HWND, DWORD, LPCVOID, DWORD);
    auto* setWindowAttribute = reinterpret_cast<DwmSetWindowAttributeFn>(GetProcAddress(dwmApi, "DwmSetWindowAttribute"));
    if (!setWindowAttribute) {
        FreeLibrary(dwmApi);
        return;
    }

    const QColor captionColor = theme.controlBackColor().darker(108);
    const QColor captionTextColor = theme.textColor();
    const qreal captionLuminance = captionColor.redF() * 0.299 + captionColor.greenF() * 0.587 + captionColor.blueF() * 0.114;

    const BOOL useDarkCaption = captionLuminance < 0.5 ? TRUE : FALSE;
    HRESULT hr = setWindowAttribute(handle,
                                    kDwmwaUseImmersiveDarkMode,
                                    &useDarkCaption,
                                    sizeof(useDarkCaption));
    if (FAILED(hr)) {
        setWindowAttribute(handle,
                           kDwmwaUseImmersiveDarkModeLegacy,
                           &useDarkCaption,
                           sizeof(useDarkCaption));
    }

    const COLORREF captionRef = RGB(captionColor.red(), captionColor.green(), captionColor.blue());
    setWindowAttribute(handle, kDwmwaCaptionColor, &captionRef, sizeof(captionRef));

    const COLORREF captionTextRef = RGB(captionTextColor.red(), captionTextColor.green(), captionTextColor.blue());
    setWindowAttribute(handle, kDwmwaTextColor, &captionTextRef, sizeof(captionTextRef));

    FreeLibrary(dwmApi);
}

void applyWindowsFullscreenBorderWorkaround(QWindow* window)
{
    if (!window) {
        return;
    }

    auto applyBorder = [window]() {
        HWND handle = reinterpret_cast<HWND>(window->winId()); // NOLINT(performance-no-int-to-ptr): WId is integer, HWND is a pointer; Win32 interop requires the cast
        if (!handle) {
            return;
        }

        const LONG_PTR style = GetWindowLongPtr(handle, GWL_STYLE);
        if ((style & WS_BORDER) == 0) {
            SetWindowLongPtr(handle, GWL_STYLE, style | WS_BORDER);
            SetWindowPos(handle, nullptr, 0, 0, 0, 0,
                         SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
        }
    };

    QObject::connect(window, &QWindow::visibilityChanged, window, [applyBorder](QWindow::Visibility visibility) {
        if (visibility == QWindow::FullScreen) {
            applyBorder();
        }
    });

    applyBorder();
}

void bringWindowToFront(QWindow* window)
{
    if (!window || !instanceLock.isPrimary()) {
        return;
    }

    window->raise();
    window->requestActivate();

    const HWND handle = reinterpret_cast<HWND>(window->winId()); // NOLINT(performance-no-int-to-ptr): WId is integer, HWND is a pointer; Win32 interop requires the cast
    if (!handle) {
        return;
    }

    if (IsIconic(handle)) {
        ShowWindow(handle, SW_RESTORE);
    }

    const HWND foreground = GetForegroundWindow();
    const DWORD foregroundThread = foreground ? GetWindowThreadProcessId(foreground, nullptr) : 0;
    const DWORD thisThread = GetCurrentThreadId();
    const bool attach = foregroundThread && foregroundThread != thisThread;

    DWORD savedLockTimeout = 0;
    SystemParametersInfoW(SPI_GETFOREGROUNDLOCKTIMEOUT, 0, &savedLockTimeout, 0);
    SystemParametersInfoW(SPI_SETFOREGROUNDLOCKTIMEOUT, 0, reinterpret_cast<PVOID>(static_cast<UINT_PTR>(0)), SPIF_SENDCHANGE); // NOLINT(performance-no-int-to-ptr): Win32 passes an integer value through the pvParam pointer

    if (attach) {
        AttachThreadInput(foregroundThread, thisThread, TRUE);
    }
    AllowSetForegroundWindow(ASFW_ANY);
    SetForegroundWindow(handle);
    BringWindowToTop(handle);
    if (attach) {
        AttachThreadInput(foregroundThread, thisThread, FALSE);
    }

    SystemParametersInfoW(SPI_SETFOREGROUNDLOCKTIMEOUT, 0,
                          reinterpret_cast<PVOID>(static_cast<UINT_PTR>(savedLockTimeout)), SPIF_SENDCHANGE); // NOLINT(performance-no-int-to-ptr): Win32 passes an integer value through the pvParam pointer

    // flash taskbar button
    FLASHWINFO flash = {};
    flash.cbSize = sizeof(flash);
    flash.hwnd = handle;
    flash.dwFlags = FLASHW_TRAY | FLASHW_TIMERNOFG;
    FlashWindowEx(&flash);
}
#endif


int main(int argc, char *argv[])
{
#ifdef Q_OS_ANDROID
    // Disable Qt's automatic per-screen scaling: we drive our own DPI-aware
    // UI sizing via Themes::resCoeff (see themes.h). QT_SCALE_FACTOR=0.5
    // halves Qt's internal coordinate system so a high-density tablet
    // doesn't render at the device's full pixel grid (physical px is what
    // we then scale up via resCoeff = physicalDPI / logicalDPI). Net effect
    // on a typical tablet (~2× density): UI sizes match the Desktop 100%
    // baseline at manualScale=1.0.
    qputenv("QT_AUTO_SCREEN_SCALE_FACTOR", "0");
    qputenv("QT_SCALE_FACTOR", "0.5");
#endif

#if defined(Q_OS_LINUX)
    QCoreApplication::setAttribute(Qt::AA_ForceRasterWidgets, false);
    ::qputenv("QT_SUPPORT_GL_CHILD_WIDGETS", "1");
#ifdef LINUX_ES
    ::qputenv("QT_OPENGL", "es2");
#endif
#endif

    QCoreApplication::setOrganizationName("TechAdVision");
    QCoreApplication::setOrganizationDomain("techadvision.com");
    QCoreApplication::setApplicationName("Pulse Echo Sounder");
    QCoreApplication::setApplicationVersion("1-1-1");

    migrateSettingsSchema();

#if defined(Q_OS_WIN)
    //QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QGuiApplication::setHighDpiScaleFactorRoundingPolicy(Qt::HighDpiScaleFactorRoundingPolicy::Round);
#endif

    QString loggingRules;
#if defined(Q_OS_WIN)
    loggingRules += QStringLiteral("qt.network.info.netlistmanager.warning=false\n"
                                   "qt.qpa.mime=false\n");
#endif
    QLoggingCategory::setFilterRules(loggingRules);

#if defined(Q_OS_ANDROID)
    AppLog::instance().start(AppLog::fallbackDirectory(), QStringLiteral("kogger"), 4 * 1024 * 1024, 3);
#else
    AppLog::instance().start(AppLog::defaultDirectory(), QStringLiteral("kogger"), 8 * 1024 * 1024, 5);
#endif

    previousMessageHandler = qInstallMessageHandler(videoLogHandler);

    QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGLRhi);

    QSurfaceFormat format;
#if defined(Q_OS_ANDROID) || defined(LINUX_ES)
    format.setRenderableType(QSurfaceFormat::OpenGLES);
#else
    format.setRenderableType(QSurfaceFormat::OpenGL);
#endif
    format.setSwapInterval(0);

    QSurfaceFormat::setDefaultFormat(format);

    QGuiApplication app(argc, argv);

    app.styleHints()->setMouseDoubleClickInterval(320);

    // Themes global was constructed before QGuiApplication + org name — now
    // safe to read QSettings and primaryScreen() for DPI-aware resCoeff.
    theme.initSettings();

    QQuickStyle::setStyle("Basic");

#ifndef Q_OS_ANDROID
    instanceLock.acquire();
    appUtils.setInstanceIndex(instanceLock.index());
    MosaicDB::setInstanceIndex(instanceLock.index());
#endif

    LanguageController langController;
    InputDeviceTracker inputDeviceTracker;
    SystemBattery systemBattery;
    core.initAfterApp();

    //qDebug() << "Lib paths:" << QCoreApplication::libraryPaths();
    //qDebug() << "SQL drivers:" << QSqlDatabase::drivers();

    QCoreApplication::addLibraryPath(QStringLiteral("assets:/qt/plugins"));
    QCoreApplication::addLibraryPath(QStringLiteral(":/android_rcc_bundle/plugins"));
    //qputenv("QT_DEBUG_PLUGINS", "1");
    //qDebug() << "libraryPaths =" << QCoreApplication::libraryPaths();
    loadLanguage(app);
    langController.setStartupTranslator(&translator);
    core.initStreamList();

    setApplicationDisplayName(app);
    QQmlApplicationEngine engine;
    engine.addImportPath("qrc:/");
    engine.addImportPath("qrc:/qml");

#if defined(Q_OS_ANDROID)
    // PULSE Make the singleton available in QML as "Insets"
    auto *ih = InsetsHelper::instance();
    // make sure it's owned by the GUI/QML thread
    if (ih->thread() != qApp->thread())
        ih->moveToThread(qApp->thread());

    // now expose it to QML as "Insets"
    engine.rootContext()->setContextProperty("Insets", ih);
#endif

    // Register as QML singleton: Ui in module Echo.UI 1.0
    UiMetrics uiMetrics;
    UiMetrics::setInstance(&uiMetrics);
    qmlRegisterSingletonInstance<UiMetrics>("Echo.UI", 1, 0, "Ui", &uiMetrics);

    SceneObject::qmlDeclare();

    //qInstallMessageHandler(messageHandler); // TODO: comment this

    registerQmlMetaTypes();

    engine.rootContext()->setContextProperty("dataset", core.getDatasetPtr());
    engine.rootContext()->setContextProperty("core", &core);
    engine.rootContext()->setContextProperty("theme", &theme);
    engine.rootContext()->setContextProperty("linkManagerWrapper", core.getLinkManagerWrapperPtr());
    engine.rootContext()->setContextProperty("deviceManagerWrapper", core.getDeviceManagerWrapperPtr());

    //Pulse additions
    auto grid = new Plot2DGrid();
    engine.rootContext()->setContextProperty("plot2DGrid", grid);
    auto* bus = new SettingsBus(&engine);

    engine.rootContext()->setContextProperty("settingsBus", bus);
    core.getDeviceManagerWrapperPtr()->setSettingsBus(bus);
    core.getLinkManagerWrapperPtr()->setSettingsBus(bus);
    if (auto* dp = core.getDataProcessorPtr()) {
        dp->setSettingsBus(bus);
    } else {
        qWarning() << "Core::getDataProcessorPtr() returned null; cannot wire SettingsBus yet.";
    }

    auto publish = [&](const char* name, QObject* obj) {
        // Ensure GUI thread affinity and a sane owner
        if (obj->thread() != qApp->thread())
            obj->moveToThread(qApp->thread());

        obj->setParent(&engine);                            // tie lifetime to engine
        QQmlEngine::setObjectOwnership(obj, QQmlEngine::CppOwnership); // never GC
        engine.rootContext()->setContextProperty(name, obj);
    };

    // PulseRuntimeSettings
    QQmlComponent rtComp(&engine, QUrl("qrc:/PulseRuntimeSettings.qml"));
    QObject* rt = rtComp.create(engine.rootContext());
    if (!rt) { qCritical() << rtComp.errors(); return -1; }
    publish("pulseRuntimeSettings", rt);
    //g_pulseRuntimeSettings = rt;

    // PulseSettings
    QQmlComponent stComp(&engine, QUrl("qrc:/PulseSettings.qml"));
    QObject* ps = stComp.create(engine.rootContext());
    if (!ps) { qCritical() << stComp.errors(); return -1; }
    publish("pulseSettings", ps);
    //g_pulseSettings = ps;

    //Hit the link manager in time to get the proper values avalable for testers and experts
    {
        QVariantMap p;
        p["udpGateway"]   = ps->property("udpGateway");
        p["udpPort"]      = ps->property("udpPort");
        p["isBetaTester"] = ps->property("isBetaTester");
        p["isExpert"]     = ps->property("isExpert");
        bus->updatePersistent(p);
    }

    //Installtoken
    auto* installToken = new InstallToken(&engine);
    engine.rootContext()->setContextProperty("installToken", installToken);

    //PulseAppSettings::initializeCache();

    NMEASender* nmeaSender = new NMEASender(&core);  // Use an appropriate parent
    nmeaSender->setSettingsBus(bus);
    Dataset* dataset = core.getDatasetPtr();

    // NMEA depth must broadcast the SAME value shown on screen: the filtered,
    // offset-corrected depth. dataset.dist() (rangefinder) and dataset.bottomTrackDepth()
    // (bottom track) are both filterDepthRecords(raw + transducerOffsetMount + fake),
    // i.e. already filtered AND offset-corrected.
    //
    // Both signals can fire at once (e.g. side scan keeps the bottom-track processor running
    // while the rangefinder is the chosen source), so each lambda is GUARDED by the active
    // depth-source selector getProcessBottomTrack(): send rangefinder only when bottom track
    // is NOT selected, and bottom track only when it IS. This guarantees NMEA matches the
    // selected source and never flickers between the two.
    QObject::connect(dataset, &Dataset::distChanged,
                     nmeaSender,
                     [dataset, nmeaSender]() {
                         if (dataset->getProcessBottomTrack()) {
                             return; // bottom track is the active source; ignore rangefinder
                         }
                         const float depth = dataset->dist();

                         if (!std::isfinite(depth) || qFuzzyIsNull(depth)) {
                             return;
                         }

                         nmeaSender->setLatestDepth(depth);
                     },
                     Qt::QueuedConnection);

    QObject::connect(dataset, &Dataset::bottomTrackDepthChanged,
                     nmeaSender,
                     [dataset, nmeaSender]() {
                         if (!dataset->getProcessBottomTrack()) {
                             return; // rangefinder is the active source; ignore bottom track
                         }
                         const float depth = dataset->bottomTrackDepth();

                         if (!std::isfinite(depth) || qFuzzyIsNull(depth)) {
                             return;
                         }

                         nmeaSender->setLatestDepth(depth);
                     },
                     Qt::QueuedConnection);

    QObject::connect(dataset, &Dataset::tempChanged,
                     nmeaSender,
                     [dataset, nmeaSender]() {
                         const float temp = dataset->temp();

                         if (!std::isfinite(temp)) {
                             return;
                         }

                         nmeaSender->setLatestTemp(temp);
                     },
                     Qt::QueuedConnection);
    /*
    QObject::connect(core.getDatasetPtr(), &Dataset::distChanged, [=]() {
        nmeaSender->setLatestDepth(core.getDatasetPtr()->dist());
    });
    QObject::connect(core.getDatasetPtr(), &Dataset::bottomTrackDepthChanged, [=]() {
        nmeaSender->setLatestDepth(core.getDatasetPtr()->bottomTrackDepth());
    });
    */
    /* Recommended to be changed to the above solution
    QObject::connect(core.getDatasetPtr(), &Dataset::tempChanged, [=]() {
        nmeaSender->setLatestTemp(core.getDatasetPtr()->temp());
    });
    */


    //************


#ifdef FLASHER
    engine.rootContext()->setContextProperty("flasher", &core.getFlasherPtr);
#endif

    engine.rootContext()->setContextProperty("deviceTopology", core.getDeviceTopologyModelPtr());
    engine.rootContext()->setContextProperty("logViewer", core.getConsolePtr());
    engine.rootContext()->setContextProperty("uiStateSerializer", &uiStateSerializer);
    engine.rootContext()->setContextProperty("echogramStateSerializer", &echogramStateSerializer);
    engine.rootContext()->setContextProperty("notifications", &notifications);
    engine.rootContext()->setContextProperty("inputDeviceTracker", &inputDeviceTracker);
    engine.rootContext()->setContextProperty("systemBattery", &systemBattery);
    engine.rootContext()->setContextProperty("langController", &langController);
    engine.rootContext()->setContextProperty("appUtils", &appUtils);

    // Machine-readable UI verification. Costs nothing unless KOGGER_UI_PROBE names an
    // output directory; exposed to QML so an interaction test can dump at a chosen
    // moment instead of on a timer.
    UiProbe uiProbe;
    engine.rootContext()->setContextProperty("uiProbe", &uiProbe);

    // Expose compile-time MANUAL_TESTING flag to QML — the Settings panel
    // shows a "Test" group (with developer-only knobs) only when this is true.
#ifdef MANUAL_TESTING
    engine.rootContext()->setContextProperty("manualTesting", true);
#else
    engine.rootContext()->setContextProperty("manualTesting", false);
#endif

    uiStateSerializer.setLinkManagerWrapper(core.getLinkManagerWrapperPtr());

    QObject::connect(&langController, &LanguageController::currentIndexChanged, &engine, [&engine, &app, &langController, &inputDeviceTracker]() {
        emit langController.aboutToRetranslate();
        engine.retranslate();
        setApplicationDisplayName(app);
        emit core.languageChanged();
        emit inputDeviceTracker.currentModeChanged();
        emit langController.retranslated();
    });

    QObject::connect(&theme, &Themes::interfaceChanged, &core, []() {
        core.setConsoleOutputEnabled(theme.consoleVisible());
    });
    core.setConsoleOutputEnabled(theme.consoleVisible());

    core.consoleInfo("Run...");
    core.setEngine(&engine);
    //qDebug() << "SQL drivers =" << QSqlDatabase::drivers(); // тут должен появиться QSQLITE
    //PULSE: our qml.qrc uses prefix "/" so main.qml is at qrc:/main.qml. Upstream moved
    //theirs to qrc:/qml/main.qml when they split the QML into modules - a path that does
    //not exist here. Loading it failed silently, objectCreated then fired with a null
    //object, and Core::UILoad dereferenced it.
    const QUrl url(QStringLiteral("qrc:/main.qml"));
    QPointer<QQuickWindow> mainWindow;
    QObject::connect(&engine,   &QQmlApplicationEngine::objectCreated,
                     &app,      [url](QObject *obj, const QUrl &objUrl) {
                                    if (!obj && url == objUrl)
                                        QCoreApplication::exit(-1);
                                }, Qt::QueuedConnection);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &uiStateSerializer, [url](QObject* obj, const QUrl& objUrl) {
        if (obj && url == objUrl) {
            uiStateSerializer.setQmlRootObject(obj);
        }
    }, Qt::QueuedConnection);

// file opening on startup
#ifdef Q_OS_ANDROID
    //checkAndroidWritePermission();
    //tryOpenFileAndroid(engine);
    makeStatusBarTransparent();
#endif

#ifndef Q_OS_ANDROID
    {
        const QStringList appArgs = app.arguments();
        if (appArgs.size() > 1) {
            const QString& startupFilePath = appArgs.at(1);
            auto* startupConn = new QMetaObject::Connection;
            *startupConn = QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                                            &core, [startupFilePath, startupConn, url](QObject* obj, const QUrl& objUrl) {
                                                if (!obj || url != objUrl) return;
                                                QObject::disconnect(*startupConn);
                                                delete startupConn;
                                                core.deferStartupFileOpen(startupFilePath);
                                            }, Qt::QueuedConnection);
        }
    }
#endif

    qputenv("QML_XHR_ALLOW_FILE_READ", QByteArray("1")); //Read the version.txt

    engine.load(url);
    const auto rootObjects = engine.rootObjects();
    if (!rootObjects.isEmpty()) {
        QObject* rootObject = rootObjects.constFirst();
        mainWindow = qobject_cast<QQuickWindow*>(rootObject);
        if (mainWindow && UiProbe::isEnabled()) {
            uiProbe.setWindow(mainWindow);
            uiProbe.armFromEnvironment();
        }
#if defined(Q_OS_WIN)
        if (auto* window = qobject_cast<QWindow*>(rootObject)) {
            applyWindowsSystemTitleBarTheme(window);
            applyWindowsFullscreenBorderWorkaround(window);
            bringWindowToFront(window);
        }
        QObject::connect(&core, &Core::bringWindowToFrontRequested, &app, [mainWindow]() { // runtime requests, next event-loop tick
            if (mainWindow) {
                bringWindowToFront(mainWindow);
            }
        }, Qt::QueuedConnection);
        // Same dark titlebar + fullscreen border workaround for the secondary window.
        if (auto* secondary = rootObject->findChild<QWindow*>(QStringLiteral("secondaryAppWindow"))) {
            applyWindowsSystemTitleBarTheme(secondary);
            applyWindowsFullscreenBorderWorkaround(secondary);
        }
        QObject::connect(&theme, &Themes::changed, &app, [mainWindow]() {
            if (!mainWindow) {
                return;
            }
            applyWindowsSystemTitleBarTheme(mainWindow);
            if (auto* secondary = mainWindow->findChild<QWindow*>(QStringLiteral("secondaryAppWindow"))) {
                applyWindowsSystemTitleBarTheme(secondary);
            }
        });
#endif
    }
    qInfo() << "App is created";
    const int retCode = app.exec();

    core.shutdownBackgroundWorkers();
    core.saveLLARefToSettings();
    core.removeLinkManagerConnections();
#ifdef SEPARATE_READING
    core.stopDeviceManagerThread();
#endif

    AppLog::instance().stop();

    return retCode;
}
