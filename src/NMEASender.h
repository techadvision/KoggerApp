#ifndef NMEA_SENDER_H
#define NMEA_SENDER_H

#include <QObject>
#include <QUdpSocket>
#include <QTimer>

extern QObject* g_pulseSettings;

class NMEASender : public QObject {
    Q_OBJECT
public:
    explicit NMEASender(QObject *parent = nullptr);

    void sendDepthData(float depthMeters);
    void setLatestDepth(float depth);
    void sendTempData(float tempCelsius);
    void setLatestTemp(float temp);

public slots:
    void updateDepth();
    void updateSettings();

private:
    QByteArray createDBTSentence(float depthMeters);
    QByteArray createMTWSentence(float tempCelsius);
    void onTimeout();
    QUdpSocket* udpSocket;
    QTimer* sendTimer;
    QTimer* tempTimer;
    quint16 port;
    QString broadcastAddress;

    float latestDepth;
    float latestTemp;
};

#endif // NMEA_SENDER_H

