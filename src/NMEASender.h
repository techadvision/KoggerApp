#ifndef NMEA_SENDER_H
#define NMEA_SENDER_H


#include <QObject>
#include <QUdpSocket>
#include <QTimer>
#include <QElapsedTimer>

// forward-declare to avoid header coupling
class SettingsBus;

class NMEASender : public QObject {
    Q_OBJECT
public:
    explicit NMEASender(QObject *parent = nullptr);

    // SettingsBus hookup
    void setSettingsBus(SettingsBus* bus);

    // data feeds
    void setLatestDepth(float depthMeters);
    void setLatestTemp(float tempCelsius);

public slots:
    void updateSettings();   // still available if you want to force-refresh

private:
    // NMEA builders (when valid==false, fields are empty)
    QByteArray createDBTSentence(float depthMeters, bool valid);
    QByteArray createMTWSentence(float tempCelsius, bool valid);

    // timers
    void onDepthTick();
    void onTempTick();

    // helpers
    void applyPersistent(const QVariantMap& m);
    int  staleMsForDepth() const;
    int  staleMsForTemp() const;

    // socket + timers
    QUdpSocket* udpSocket {nullptr};
    QTimer*     depthTimer {nullptr};
    QTimer*     tempTimer  {nullptr};

    // config (kept in RAM; updated via SettingsBus or updateSettings())
    quint16 port {3500};
    QString broadcastAddress {"255.255.255.255"};
    int     depthIntervalMs {250};
    int     tempIntervalMs  {1000};
    bool    enableDbt {false};
    bool    enableMtw {false};

    // freshness / last values
    float          latestDepth {0.0f};
    float          latestTemp  {0.0f};
    bool           haveDepth {false};
    bool           haveTemp  {false};
    QElapsedTimer  lastDepthTick;
    QElapsedTimer  lastTempTick;

    // bus
    SettingsBus* bus_ {nullptr};
};

#endif // NMEA_SENDER_H

