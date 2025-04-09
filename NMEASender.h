#ifndef NMEA_SENDER_H
#define NMEA_SENDER_H

#include <QObject>
#include <QUdpSocket>
#include <QTimer>

// Forward declaration of external settings object.
extern QObject* g_pulseSettings;
extern QObject* g_pulseRuntimeSettings;

class NMEASender : public QObject {
    Q_OBJECT
public:
    explicit NMEASender(QObject *parent = nullptr);

    // This method is no longer called directly on every signal.
    // Instead, we use a timer to send the latest depth.
    void sendDepthData(float depthMeters);
    void setLatestDepth(float depth);

public slots:
    // Slot to update the latest depth when the dataset changes.
    void updateDepth();

private:
    // Helper to create the DBT NMEA sentence with depth in feet, meters, and fathoms.
    QByteArray createDBTSentence(float depthMeters);

    // Timer callback slot for throttled sending.
    void onTimeout();

    QUdpSocket* udpSocket;
    QTimer* sendTimer;
    quint16 port;
    QString broadcastAddress;

    // Store the latest depth value from the dataset.
    float latestDepth;
};

#endif // NMEA_SENDER_H

