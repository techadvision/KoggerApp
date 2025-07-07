#include <QGuiApplication>
#include <QQmlContext>
#include <QApplication>
#include <QQmlApplicationEngine>
#include <waterfall.h>
#include <plotcash.h>
#include <connection.h>
#include <console.h>
#include <core.h>
#include <Themes.h>
#include <QThread>
#include <QResource>
#include <QFile>
#include <QByteArray>
#include "3Plot.h"
#include <sceneobject.h>
#include "Plot2D.h"
#include "QQuickWindow"
#include "bottomtrack.h"
#if defined(Q_OS_ANDROID)
#include "android.h"
#endif
#include <QTranslator>
#include <QLocale>
#include <QSettings>
#include <QVector>
#include <QString>
#include <DevDriver.h>

#include "DevQProperty.h"
#include "NMEASender.h"

Core core;
Themes theme;
QTranslator translator;
QVector<QString> availableLanguages{"en", "ru", "pl"};
QObject* g_pulseRuntimeSettings = nullptr;
QObject* g_pulseSettings = nullptr;


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


    QString translationFile = ":/languages/translation_" + currentLanguage + ".qm";

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
    qmlRegisterType<qPlot2D>( "WaterFall", 1, 0, "WaterFall");
    qmlRegisterType<BottomTrack>("BottomTrack", 1, 0, "BottomTrack");
    qmlRegisterType<NMEASender>("NMEASender", 1, 0, "NMEASender");
    qRegisterMetaType<BottomTrack::ActionEvent>("BottomTrack::ActionEvent");
}


int main(int argc, char *argv[])
{
#if defined(Q_OS_LINUX)
    QApplication::setAttribute(Qt::AA_ForceRasterWidgets, false);
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
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QGuiApplication::setHighDpiScaleFactorRoundingPolicy(Qt::HighDpiScaleFactorRoundingPolicy::Round);
#endif

    // Register the singleton type
    qmlRegisterSingletonType(QUrl("qrc:/PulseSettings.qml"), "org.techadvision.settings", 1, 0, "PulseSettings");
    qmlRegisterSingletonType(QUrl("qrc:/PulseRuntimeSettings.qml"), "org.techadvision.runtime", 1, 0, "PulseRuntimeSettings");

    qmlRegisterType<Plot2DEchogram>("Pulse.Plot", 1, 0, "Plot2DEchogram");

    QQuickWindow::setSceneGraphBackend(QSGRendererInterface::OpenGLRhi);

    QSurfaceFormat format;
#if defined(Q_OS_ANDROID) || defined(LINUX_ES)
    format.setRenderableType(QSurfaceFormat::OpenGLES);
#else
    format.setRenderableType(QSurfaceFormat::OpenGL);
#endif
    format.setSwapInterval(0);

    QSurfaceFormat::setDefaultFormat(format);

    QGuiApplication app(argc, argv);
    loadLanguage(app);

    setApplicationDisplayName(app);
    QQmlApplicationEngine engine;
    engine.addImportPath("qrc:/");

    SceneObject::qmlDeclare();

    //qInstallMessageHandler(messageHandler); // TODO: comment this

    registerQmlMetaTypes();

    engine.rootContext()->setContextProperty("dataset", core.getDatasetPtr());
    engine.rootContext()->setContextProperty("core", &core);
    engine.rootContext()->setContextProperty("theme", &theme);
    engine.rootContext()->setContextProperty("linkManagerWrapper", core.getLinkManagerWrapperPtr());
    engine.rootContext()->setContextProperty("deviceManagerWrapper", core.getDeviceManagerWrapperPtr());

    QQmlComponent component(&engine, QUrl("qrc:/PulseRuntimeSettings.qml"));
    QObject *runtimeSettingsInstance = component.create();
    if (!runtimeSettingsInstance) {
        qWarning() << "Failed to create PulseRuntimeSettings instance!";
    } else {
        runtimeSettingsInstance->setObjectName("pulseRuntimeSettings");
        engine.rootContext()->setContextProperty("pulseRuntimeSettings", runtimeSettingsInstance);
        g_pulseRuntimeSettings = runtimeSettingsInstance;
    }

    QQmlComponent component2(&engine, QUrl("qrc:/PulseSettings.qml"));
    QObject *settingsInstance = component2.create();
    if (!settingsInstance) {
        qWarning() << "Failed to create PulseSettings instance!";
    } else {
        settingsInstance->setObjectName("pulseSettings");
        engine.rootContext()->setContextProperty("pulseSettings", settingsInstance);
        g_pulseSettings = settingsInstance;
    }

    NMEASender* nmeaSender = new NMEASender(&core);  // Use an appropriate parent
    QObject::connect(core.getDatasetPtr(), &Dataset::distChanged, [=]() {
        nmeaSender->setLatestDepth(core.getDatasetPtr()->dist());
    });
    QObject::connect(core.getDatasetPtr(), &Dataset::tempChanged, [=]() {
        nmeaSender->setLatestTemp(core.getDatasetPtr()->temp());
    });


#ifdef FLASHER
    engine.rootContext()->setContextProperty("flasher", &core.getFlasherPtr);
#endif
    engine.rootContext()->setContextProperty("logViewer", core.getConsolePtr());

    core.consoleInfo("Run...");
    core.setEngine(&engine);

    const QUrl url(QStringLiteral("qrc:/main.qml"));
    QObject::connect(&engine,   &QQmlApplicationEngine::objectCreated,
                     &app,      [url](QObject *obj, const QUrl &objUrl) {
                                    if (!obj && url == objUrl)
                                        QCoreApplication::exit(-1);
                                }, Qt::QueuedConnection);

// file opening on startup
#ifdef Q_OS_ANDROID
    checkAndroidWritePermission();
    tryOpenFileAndroid(engine);
#else
    if (argc > 1) {
        QObject::connect(&engine,   &QQmlApplicationEngine::objectCreated,
                         &core,     [&argv]() {
                                        core.openLogFile(argv[1], false, true);
                                    }, Qt::QueuedConnection);
    }
#endif

    QObject::connect(&app,  &QGuiApplication::aboutToQuit,
                     &core, [&]() {
                                core.saveLLARefToSettings();
                                core.removeLinkManagerConnections();
                                core.stopLinkManagerTimer();
#ifdef SEPARATE_READING
                                void removeDeviceManagerConnections();
                                core.stopDeviceManagerThread();
#endif
                            });

    engine.load(url);
    qCritical() << "App is created";

    if (g_pulseRuntimeSettings) {
        qDebug() << "pulseRuntimeSettings instance found!";
    } else {
        qWarning() << "pulseRuntimeSettings instance not found!";
    }

    return app.exec();
}
