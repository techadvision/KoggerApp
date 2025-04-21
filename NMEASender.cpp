#include "NMEASender.h"
#include <QHostAddress>
#include <QDebug>
#include <cmath>

NMEASender::NMEASender(QObject *parent)
    : QObject(parent),
    port(3500),
    broadcastAddress("255.255.255.255"),
    latestDepth(0.0f)
{
    udpSocket = new QUdpSocket(this);

    // Bind the socket to any available IPv4 address.
    if (!udpSocket->bind(QHostAddress::AnyIPv4, static_cast<quint16>(0), QUdpSocket::DefaultForPlatform)) {
        qWarning() << "Failed to bind UDP socket:" << udpSocket->errorString();
    } else {
        qDebug() << "UDP socket successfully bound.";
    }

    sendTimer = new QTimer(this);
    connect(sendTimer, &QTimer::timeout, this, &NMEASender::onTimeout);

    if (g_pulseSettings) {
        qDebug() << "Found g_pulseSettings";
        updateSettings();
        connect(g_pulseSettings, SIGNAL(settingsChanged()), this, SLOT(updateSettings()));
    } else {
        sendTimer->setInterval(250);
        qDebug() << "Did not find g_pulseSettings";
    }
    sendTimer->start();

}

void NMEASender::updateSettings()
{
    if (g_pulseSettings) {
        int prefPort = g_pulseSettings->property("nmeaPort").toInt();
        if (prefPort > 0) {
            port = static_cast<quint16>(prefPort);
        }

        int interval = g_pulseSettings->property("nmeaSendPerMilliSec").toInt();
        if (interval <= 0) {
            interval = 250; // Default interval if invalid.
        }
        sendTimer->setInterval(interval);

        qDebug() << "Updated NMEASender settings:"
                 << " port =" << port
                 << ", send interval =" << interval << "ms";
    } else {
        qDebug() << "Did not find g_pulseSettings";
    }
}

void NMEASender::sendDepthData(float depthMeters)
{
    if (g_pulseSettings) {
        bool enabled = g_pulseSettings->property("enableNmeaDbt").toBool();
        if (!enabled) {
            qDebug() << "NMEA sending is disabled by preference: enableNmeaDbt=" << enabled;
            return;
        }
    }

    QByteArray sentence = createDBTSentence(depthMeters);
    //qDebug() << "Sending NMEA sentence:" << sentence;

#ifdef Q_OS_WINDOWS
    QHostAddress target("255.255.255.255");
#else
    QHostAddress target = QHostAddress::Broadcast;
#endif

    qint64 bytesWritten = udpSocket->writeDatagram(sentence, target, port);
    if (bytesWritten == -1) {
        qWarning() << "Failed to write datagram:" << udpSocket->errorString();
    }
}

QByteArray NMEASender::createDBTSentence(float depthMeters)
{
    float depthFeet = depthMeters * 3.28084f;
    float depthFathoms = depthMeters * 0.546807f;

    QString payload = QString("PUDBT,%1,f,%2,M,%3,F")
                          .arg(depthFeet, 0, 'f', 2)
                          .arg(depthMeters, 0, 'f', 2)
                          .arg(depthFathoms, 0, 'f', 2);

    QByteArray sentence = "$" + payload.toUtf8();

    quint8 checksum = 0;
    for (int i = 1; i < sentence.size(); ++i) {
        checksum ^= static_cast<quint8>(sentence.at(i));
    }

    QString checksumStr = QString("*%1").arg(checksum, 2, 16, QChar('0')).toUpper();
    sentence.append(checksumStr.toUtf8());

    return sentence;
}

void NMEASender::onTimeout()
{
    if (g_pulseSettings) {
        bool enabled = g_pulseSettings->property("enableNmeaDbt").toBool();
        if (!enabled) {
            //qDebug() << "NMEA sending is disabled by preference.";
            return;
        }
    } else {
        qDebug() << "g_pulseSettings is not set yet; skipping sending.";
        return;
    }

    sendDepthData(latestDepth);
}

void NMEASender::setLatestDepth(float depth)
{
    latestDepth = depth;
}


void NMEASender::updateDepth()
{

}
