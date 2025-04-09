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
    // This is particularly important on Windows.
    if (!udpSocket->bind(QHostAddress::AnyIPv4, static_cast<quint16>(0), QUdpSocket::DefaultForPlatform)) {
        qWarning() << "Failed to bind UDP socket:" << udpSocket->errorString();
    } else {
        qDebug() << "UDP socket successfully bound.";
    }


    // If g_pulseSettings is available, override default values.
    if (g_pulseSettings) {
        // Retrieve the preferred port.
        int prefPort = g_pulseSettings->property("nmeaPort").toInt();
        if (prefPort > 0) {
            port = static_cast<quint16>(prefPort);
        }

        // Retrieve the preferred send interval.
        int interval = g_pulseSettings->property("nmeaSendPerMilliSec").toInt();
        if (interval <= 0) {
            interval = 250; // Use default if an invalid interval is provided.
        }
        qDebug() << "NMEASender settings: port =" << port << ", send interval =" << interval << "ms";

        // Create the timer using the preferred interval.
        sendTimer = new QTimer(this);
        sendTimer->setInterval(interval);
    } else {
        qDebug() << "g_pulseSettings not available";
        // Otherwise, use the default interval.
        sendTimer = new QTimer(this);
        sendTimer->setInterval(250);
    }

    connect(sendTimer, &QTimer::timeout, this, &NMEASender::onTimeout);
    sendTimer->start();
}

// This method still sends a sentence immediately, if needed.
void NMEASender::sendDepthData(float depthMeters) {
    // Check if sending is enabled.
    if (g_pulseSettings) {
        bool enabled = g_pulseSettings->property("enableNmeaDbt").toBool();
        if (!enabled) {
            qDebug() << "NMEA sending is disabled by preference: enableNmeaDbt=" << enabled;
            return;
        }
    }

    QByteArray sentence = createDBTSentence(depthMeters);
    qDebug() << "Sending NMEA sentence:" << sentence;

#ifdef Q_OS_WINDOWS
    // Explicitly construct the broadcast address on Windows.
    QHostAddress target("255.255.255.255");
#else
    QHostAddress target = QHostAddress::Broadcast;
#endif

    qint64 bytesWritten = udpSocket->writeDatagram(sentence, target, port);
    if (bytesWritten == -1) {
        qWarning() << "Failed to write datagram:" << udpSocket->errorString();
    }
}

// This helper creates the DBT sentence with rounded values.
QByteArray NMEASender::createDBTSentence(float depthMeters) {
    // Calculate values.
    float depthFeet = depthMeters * 3.28084f;
    float depthFathoms = depthMeters * 0.546807f;

    // Format the DBT sentence using two-decimal rounding.
    QString payload = QString("PUDBT,%1,f,%2,M,%3,F")
                          .arg(depthFeet, 0, 'f', 2)
                          .arg(depthMeters, 0, 'f', 2)
                          .arg(depthFathoms, 0, 'f', 2);

    // Start with '$'
    QByteArray sentence = "$" + payload.toUtf8();

    // Calculate the NMEA checksum (XOR all characters between '$' and the end).
    quint8 checksum = 0;
    for (int i = 1; i < sentence.size(); ++i) {
        checksum ^= static_cast<quint8>(sentence.at(i));
    }

    // Append the checksum in the format "*hh"
    QString checksumStr = QString("*%1").arg(checksum, 2, 16, QChar('0')).toUpper();
    sentence.append(checksumStr.toUtf8());

    return sentence;
}

// onTimeout() is called every 250ms and sends the latest depth.
void NMEASender::onTimeout() {
    if (g_pulseSettings) {
        bool enabled = g_pulseSettings->property("enableNmeaDbt").toBool();
        if (!enabled) {
            qDebug() << "NMEA sending is disabled by preference.";
            return;
        }
    } else {
        // If the runtime settings are not yet available, don't send.
        qDebug() << "g_pulseRuntimeSettings is not set yet; skipping sending.";
        return;
    }

    sendDepthData(latestDepth);
}

void NMEASender::setLatestDepth(float depth) {
    latestDepth = depth;
}

// Slot to update the cached depth value.
// This slot can be connected to your Dataset::distChanged signal.
void NMEASender::updateDepth() {
    // Here you would get the latest depth from your dataset.
    // For example, if your dataset is accessible via a global or passed pointer:
    // latestDepth = dataset->dist();
    // In our example, you will update this value in the lambda connected in main.cpp.
    // (The lambda can call something like: nmeaSender->latestDepth = dataset->dist(); )
    // This function is left empty if you choose to update latestDepth directly from the connection.
}
