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
#if defined(Q_OS_WIN)
#include <windows.h>
#endif
#include "qPlot2D.h"
#include "core.h"
#include "themes.h"
#include "scene_object.h"
#include "bottom_track.h"

#if defined(Q_OS_ANDROID)
#include <QCoreApplication>          // brings in QNativeInterface::QAndroidApplication
#include <QtCore/qnativeinterface.h> // robust include (works even if <QNativeInterface> is missing)
#include <QtCore/qjniobject.h>       // QJniObject (Qt 6)
#include <QVariant>
#include "InsetsHelper.h"
#endif
#include "installtoken.h"
#include "UiMetrics.h"

Core core;
Themes theme;
QTranslator translator;
QVector<QString> availableLanguages{"en", "ru", "pl"};
//QObject* g_pulseRuntimeSettings = nullptr;
//QObject* g_pulseSettings = nullptr;

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

    int savedLanguageIndex = settings.value("appLanguage", -1).toInt();

    if (savedLanguageIndex == -1) {
        currentLanguage = QLocale::system().name().split('_').first();
        if (auto indx = availableLanguages.indexOf(currentLanguage); indx == -1) {
            currentLanguage = availableLanguages.front();
        }
        else {
            settings.setValue("appLanguage", indx);
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
void applyWindowsFullscreenBorderWorkaround(QWindow* window)
{
    if (!window) {
        return;
    }

    auto applyBorder = [window]() {
        HWND handle = reinterpret_cast<HWND>(window->winId());
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
#endif


int main(int argc, char *argv[])
{
#ifdef Q_OS_ANDROID
    qputenv("QT_AUTO_SCREEN_SCALE_FACTOR", "0");  // TODO: use qt scaling!
    qputenv("QT_SCALE_FACTOR", "0.5");            //
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

#if defined(Q_OS_WIN)
    //QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QGuiApplication::setHighDpiScaleFactorRoundingPolicy(Qt::HighDpiScaleFactorRoundingPolicy::Round);
#endif

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

    //qDebug() << "Lib paths:" << QCoreApplication::libraryPaths();
    //qDebug() << "SQL drivers:" << QSqlDatabase::drivers();

    QCoreApplication::addLibraryPath(QStringLiteral("assets:/qt/plugins"));
    QCoreApplication::addLibraryPath(QStringLiteral(":/android_rcc_bundle/plugins"));
    //qputenv("QT_DEBUG_PLUGINS", "1");
    //qDebug() << "libraryPaths =" << QCoreApplication::libraryPaths();
    loadLanguage(app);
    core.initStreamList();

    QQuickStyle::setStyle("Basic");

    setApplicationDisplayName(app);
    QQmlApplicationEngine engine;
    engine.addImportPath("qrc:/");

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

    //TODO: here 14.1 changed the emitted event to lastDepthChanged
    //This is a trial, we need to properly test with all types of echo sounders
    QObject::connect(dataset, &Dataset::lastDepthChanged,
                     nmeaSender,
                     [dataset, nmeaSender]() {
                         const float depth = dataset->getLastDepth();

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

    engine.rootContext()->setContextProperty("logViewer", core.getConsolePtr());

    QObject::connect(&theme, &Themes::interfaceChanged, &core, []() {
        core.setConsoleOutputEnabled(theme.consoleVisible());
    });
    core.setConsoleOutputEnabled(theme.consoleVisible());

    core.consoleInfo("Run...");
    core.setEngine(&engine);
    //qDebug() << "SQL drivers =" << QSqlDatabase::drivers(); // тут должен появиться QSQLITE
    const QUrl url(QStringLiteral("qrc:/main.qml"));
    QPointer<QQuickWindow> mainWindow;
    QObject::connect(&engine,   &QQmlApplicationEngine::objectCreated,
                     &app,      [url](QObject *obj, const QUrl &objUrl) {
                                    if (!obj && url == objUrl)
                                        QCoreApplication::exit(-1);
                                }, Qt::QueuedConnection);

// file opening on startup
#ifdef Q_OS_ANDROID
    //checkAndroidWritePermission();
    //tryOpenFileAndroid(engine);
    makeStatusBarTransparent();
#endif

#ifndef Q_OS_ANDROID
    if (argc > 1) {
        QObject::connect(&engine,   &QQmlApplicationEngine::objectCreated,
                         &core,     [&argv]() {
                                        core.openLogFile(argv[1], false, true);
                                    }, Qt::QueuedConnection);
    }
#endif

    QObject::connect(&app,  &QGuiApplication::aboutToQuit,
                     &core, [&]() {
                                core.shutdownDataProcessor();
                                core.saveLLARefToSettings();
                                core.removeLinkManagerConnections();
                                core.stopLinkManagerTimer();
#ifdef SEPARATE_READING
                                void removeDeviceManagerConnections();
                                core.stopDeviceManagerThread();
#endif
                            });

    qputenv("QML_XHR_ALLOW_FILE_READ", QByteArray("1")); //Read the version.txt

    engine.load(url);
    const auto rootObjects = engine.rootObjects();
    if (!rootObjects.isEmpty()) {
        QObject* rootObject = rootObjects.constFirst();
        mainWindow = qobject_cast<QQuickWindow*>(rootObject);
#if defined(Q_OS_WIN)
        if (auto* window = qobject_cast<QWindow*>(rootObject)) {
            applyWindowsFullscreenBorderWorkaround(window);
        }
#endif
    }
    qCritical() << "App is created";

    return app.exec();
}
