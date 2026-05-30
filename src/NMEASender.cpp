#include "NMEASender.h"
#include <QHostAddress>
#include <QDebug>
#include <cmath>
#include "SettingsBus.h"

NMEASender::NMEASender(QObject *parent)
    : QObject(parent)
{
    udpSocket = new QUdpSocket(this);

    if (!udpSocket->bind(QHostAddress::AnyIPv4, 0, QUdpSocket::DefaultForPlatform)) {
        qWarning() << "NMEA Failed to bind UDP socket:" << udpSocket->errorString();
    } else {
        qDebug() << "NMEA UDP socket successfully bound.";
    }

    // timers
    depthTimer = new QTimer(this);
    tempTimer  = new QTimer(this);

    // initial load from QSettings (will be overridden live by SettingsBus if attached)
    updateSettings();

    // wire ticks
    connect(depthTimer, &QTimer::timeout, this, &NMEASender::onDepthTick);
    connect(tempTimer,  &QTimer::timeout, this, &NMEASender::onTempTick);

    // start timers; they self-check enable flags inside the tick
    depthTimer->start(depthIntervalMs);
    tempTimer->start(tempIntervalMs);
}

void NMEASender::setSettingsBus(SettingsBus* bus)
{
    if (bus_ == bus) return;
    if (bus_) disconnect(bus_, nullptr, this, nullptr);
    bus_ = bus;
    if (!bus_) return;

    // react only to persistent settings changes we care about
    connect(bus_, &SettingsBus::persistentChanged, this,
            [this](const QVariantMap& m){ applyPersistent(m); },
            Qt::QueuedConnection);
}

void NMEASender::applyPersistent(const QVariantMap& m)
{
    bool changedDepthTick = false;
    bool changedTempTick  = false;

    if (m.contains("nmeaPort")) {
        port = static_cast<quint16>(m.value("nmeaPort").toInt());
    }
    if (m.contains("nmeaSendPerMilliSec")) {
        depthIntervalMs = m.value("nmeaSendPerMilliSec").toInt();
        if (depthIntervalMs <= 0) depthIntervalMs = 250;
        changedDepthTick = true;
    }
    if (m.contains("nmeaBroadcastAddress")) {
        broadcastAddress = m.value("nmeaBroadcastAddress").toString();
        if (broadcastAddress.isEmpty()) broadcastAddress = "255.255.255.255";
    }
    if (m.contains("enableNmeaDbt")) {
        enableDbt = m.value("enableNmeaDbt").toBool();
    }
    if (m.contains("enableNmeaMtw")) {
        enableMtw = m.value("enableNmeaMtw").toBool();
    }
    if (m.contains("nmeaTempPeriodMs")) {
        tempIntervalMs = m.value("nmeaTempPeriodMs").toInt();
        if (tempIntervalMs <= 0) tempIntervalMs = 1000;
        changedTempTick = true;
    }

    if (changedDepthTick && depthTimer) depthTimer->start(depthIntervalMs);
    if (changedTempTick  && tempTimer)  tempTimer->start(tempIntervalMs);
}

void NMEASender::updateSettings()
{
    // one-shot bootstrap from QSettings; live updates come via SettingsBus
    /*
    port            = static_cast<quint16>(persistent<int>("nmeaPort", 3500));
    depthIntervalMs = persistent<int>("nmeaSendPerMilliSec", 250);
    tempIntervalMs  = persistent<int>("nmeaTempPeriodMs",     1000);
    broadcastAddress= persistent<QString>("nmeaBroadcastAddress", "255.255.255.255");
    enableDbt       = persistent<bool>("enableNmeaDbt", false);
    enableMtw       = persistent<bool>("enableNmeaMtw", false);
    */

    if (depthIntervalMs <= 0) depthIntervalMs = 250;
    if (tempIntervalMs  <= 0) tempIntervalMs  = 1000;

    if (depthTimer) depthTimer->setInterval(depthIntervalMs);
    if (tempTimer)  tempTimer->setInterval(tempIntervalMs);

    qDebug() << "NMEA bootstrap:"
             << "port=" << port
             << "depthIntervalMs=" << depthIntervalMs
             << "tempIntervalMs="  << tempIntervalMs
             << "broadcast=" << broadcastAddress
             << "enableDbt=" << enableDbt
             << "enableMtw=" << enableMtw;
}

int NMEASender::staleMsForDepth() const { return qMax(1000, depthIntervalMs * 2); }
int NMEASender::staleMsForTemp()  const { return qMax(1000, tempIntervalMs  * 2); }

void NMEASender::setLatestDepth(float d)
{
    latestDepth = d;
    haveDepth   = true;
    lastDepthTick.start();
}

void NMEASender::setLatestTemp(float t)
{
    latestTemp = t;
    haveTemp   = true;
    lastTempTick.start();
}

void NMEASender::onDepthTick()
{
    if (!enableDbt) return;

    const bool fresh = haveDepth && lastDepthTick.isValid() &&
                       lastDepthTick.elapsed() <= staleMsForDepth();

    const QByteArray sentence = createDBTSentence(latestDepth, fresh);

    QHostAddress target(broadcastAddress);
    if (target.isNull()) target = QHostAddress::Broadcast;

    const qint64 n = udpSocket->writeDatagram(sentence, target, port);
    if (n == -1) {
        //qWarning() << "NMEA DBT write failed:" << udpSocket->errorString();
    }
}

void NMEASender::onTempTick()
{
    if (!enableMtw) return;

    const bool fresh = haveTemp && lastTempTick.isValid() &&
                       lastTempTick.elapsed() <= staleMsForTemp();

    const QByteArray sentence = createMTWSentence(latestTemp, fresh);

    QHostAddress target(broadcastAddress);
    if (target.isNull()) target = QHostAddress::Broadcast;

    const qint64 n = udpSocket->writeDatagram(sentence, target, port);
    if (n == -1) {
        //qWarning() << "NMEA MTW write failed:" << udpSocket->errorString();
    }
}

static inline QString hexChecksum(const QByteArray& body)
{
    quint8 cs = 0;
    // XOR of chars after '$' (we provide body *without* the '$' below)
    for (char c : body) cs ^= static_cast<quint8>(c);
    return QString("*%1").arg(cs, 2, 16, QLatin1Char('0')).toUpper();
}

QByteArray NMEASender::createDBTSentence(float depthMeters, bool valid)
{
    // Empty fields when !valid
    QString feet   = valid ? QString::number(depthMeters * 3.28084f, 'f', 2) : "";
    QString meters = valid ? QString::number(depthMeters,               'f', 2) : "";
    QString fathom = valid ? QString::number(depthMeters * 0.546807f,   'f', 2) : "";

    // Keep your talker/sentence prefix
    const QString payload = QStringLiteral("PUDBT,%1,f,%2,M,%3,F")
                                .arg(feet, meters, fathom);

    QByteArray body = payload.toUtf8();   // no leading '$' here
    QByteArray out  = "$" + body + hexChecksum(body).toUtf8();
    return out;
}

QByteArray NMEASender::createMTWSentence(float tempC, bool valid)
{
    // MTW: water temperature in C
    QString t = valid ? QString::number(tempC, 'f', 1) : "";
    const QString payload = QStringLiteral("PUMTW,%1,C").arg(t);

    QByteArray body = payload.toUtf8();
    QByteArray out  = "$" + body + hexChecksum(body).toUtf8();
    return out;
}
