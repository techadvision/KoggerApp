#ifndef UDP_BROADCASTER_H
#define UDP_BROADCASTER_H

#pragma once
#include <QObject>
#include <QUdpSocket>
#include <QHostAddress>
#include <QNetworkInterface>
#include <QDateTime>
#include <algorithm>  // sort, unique
#include <cmath>      // abs, isfinite

class UdpBroadcaster : public QObject {
    Q_OBJECT
public:
    static UdpBroadcaster& instance() {
        static UdpBroadcaster inst; // lives for the app lifetime
        return inst;
    }

    UdpBroadcaster(const UdpBroadcaster&) = delete;
    UdpBroadcaster& operator=(const UdpBroadcaster&) = delete;

    void setMavlinkPeer(const QString& ip, qint64 seenMs)
    {
        QHostAddress a;
        const bool valid = !ip.isEmpty() && a.setAddress(ip) && a.protocol() == QAbstractSocket::IPv4Protocol;
        const QHostAddress next = valid ? a : QHostAddress();

        // PULSE: log only on an ACTUAL peer change. setMavlinkPeer is invoked ~1 Hz per proxy via the
        // periodic timestamp refresh in Link::updateMavlinkPeer; logging every call is what "bombed"
        // the console. The freshness timestamp (mavPeerSeenMs_) is still updated every call below — only
        // the logging is gated. If this is still spamming after the link_manager idempotency fix, a
        // stale/orphaned proxy link is still alive.
        if (next != mavPeerAddr_) {
            qDebug() << "AddWaypoint: setMavlinkPeer change:" << mavPeerAddr_ << "->" << next;
        }

        if (valid) {
            mavPeerAddr_ = a;
            mavPeerSeenMs_ = seenMs;
        } else {
            mavPeerAddr_.clear();
            mavPeerSeenMs_ = 0;
        }
    }

    bool sendJsonPointWithSnapshot(double lat, double lon, double depth_m,
                                   const QString& model,
                                   const QString& name,
                                   const QByteArray& snapshotPngBase64,
                                   quint16 port = 14570)
    {
        QByteArray payload = "{";
        payload += "\"type\":\"echosounder_target\"";
        payload += ",\"lat\":" + QByteArray::number(lat, 'f', 6);
        payload += ",\"lon\":" + QByteArray::number(lon, 'f', 6);
        if (std::isfinite(depth_m)) {
            payload += ",\"depth_m\":" + QByteArray::number(depth_m, 'f', 2);
        } else {
            payload += ",\"depth_m\":null";
        }
        if (!model.isEmpty()) {
            payload += ",\"model\":\"" + model.toUtf8() + "\"";
        }
        if (!name.isEmpty()) {
            payload += ",\"name\":\"" + name.toUtf8() + "\"";
        }
        payload += ",\"latlong\":\"" +
                   QByteArray::number(lat, 'f', 6) + "," +
                   QByteArray::number(lon, 'f', 6) + "\"";
        payload += ",\"ts_unix_ms\":" + QByteArray::number(QDateTime::currentMSecsSinceEpoch());

        if (!snapshotPngBase64.isEmpty()) {
            payload += ",\"snapshot_png_b64\":\"";
            payload += snapshotPngBase64;   // base64 has no quotes, safe in JSON string
            payload += "\"";
        }

        payload += "}";
        return broadcastWaypoint(payload, port);
    }


    // Send a JSON point: {"lat":12.34,"lon":56.78,"name":"Pulse"}
    bool sendJsonPoint(double lat, double lon, double depth_m,
                       const QString& model = QString(),
                       const QString& name = QString(),
                       quint16 port = 14570)
    {
        qDebug() << "AddWaypoint: udp_broadcaster sendJsonPoint triggered";
        QByteArray payload = "{";
        payload += "\"type\":\"echosounder_target\"";
        payload += ",\"lat\":" + QByteArray::number(lat, 'f', 6);
        payload += ",\"lon\":" + QByteArray::number(lon, 'f', 6);
        if (std::isfinite(depth_m)) {
            payload += ",\"depth_m\":" + QByteArray::number(depth_m, 'f', 2);
        } else {
            payload += ",\"depth_m\":null";
        }
        if (!model.isEmpty()) {
            payload += ",\"model\":\"" + model.toUtf8() + "\"";
        }
        if (!name.isEmpty()) {
            payload += ",\"name\":\"" + name.toUtf8() + "\"";
        }
        payload += ",\"latlong\":\"" +
                   QByteArray::number(lat, 'f', 6) + "," +
                   QByteArray::number(lon, 'f', 6) + "\"";
        payload += ",\"ts_unix_ms\":" + QByteArray::number(QDateTime::currentMSecsSinceEpoch());
        payload += "}";
        qDebug() << "AddWaypoint: udp_broadcaster sendJsonPoint completed. lat:" <<lat << "lng;" <<lon;
        return broadcastWaypoint(payload, port);
    }


    // Send an NMEA 0183 WPL (Waypoint Location) sentence.
    // Example: $GPWPL,llll.ll,a,yyyyy.yy,a,NAME*hh<CR><LF>
    // Many apps accept "ECWPL" / "GPWPL". We default to "ECWPL" (Echosounder).
    bool sendNmeaWpl(double lat, double lon,
                     const QString& name = "TARGET",
                     quint16 port = 14570,
                     const QByteArray& talker = "EC") // or "GP"
    {
        QByteArray latField, latHem, lonField, lonHem;
        toNmeaLat(lat, latField, latHem);
        toNmeaLon(lon, lonField, lonHem);

        QByteArray frame = "$" + talker + "WPL,";
        frame += latField + "," + latHem + ",";
        frame += lonField + "," + lonHem + ",";
        frame += name.toUtf8();

        appendChecksum(frame);  // adds *hh\r\n
        return broadcast(frame, port);
    }

    // Optional: also emit a GLL (present position) with UTC time.
    bool sendNmeaGll(double lat, double lon,
                     quint16 port = 14570,
                     const QByteArray& talker = "EC")
    {
        QByteArray latField, latHem, lonField, lonHem;
        toNmeaLat(lat, latField, latHem);
        toNmeaLon(lon, lonField, lonHem);

        const auto utc = QDateTime::currentDateTimeUtc().time();
        const QByteArray hhmmss =
            QString::asprintf("%02d%02d%02d.00", utc.hour(), utc.minute(), utc.second()).toUtf8();
            //QByteArray().sprintf("%02d%02d%02d.00", utc.hour(), utc.minute(), utc.second());

        QByteArray frame = "$" + talker + "GLL,";
        frame += latField + "," + latHem + ",";
        frame += lonField + "," + lonHem + ",";
        frame += hhmmss + ",A";    // A = data valid

        appendChecksum(frame);
        return broadcast(frame, port);
    }

private:
    explicit UdpBroadcaster(QObject* parent=nullptr) : QObject(parent) {}
    //Data
    QUdpSocket socket_;
    QHostAddress mavPeerAddr_;
    qint64 mavPeerSeenMs_ = 0;

    //Methods
    static void toNmeaLat(double lat, QByteArray& field, QByteArray& hem) {
        hem = (lat < 0) ? "S" : "N";
        double alat = std::abs(lat);
        int deg = int(alat);
        double minutes = (alat - deg) * 60.0;
        field = QString::asprintf("%03d%06.3f", deg, minutes).toUtf8();
    }

    static void toNmeaLon(double lon, QByteArray& field, QByteArray& hem) {
        hem = (lon < 0) ? "W" : "E";
        double alon = std::abs(lon);
        int deg = int(alon);
        double minutes = (alon - deg) * 60.0;
        field = QString::asprintf("%03d%06.3f", deg, minutes).toUtf8();
    }

    static void appendChecksum(QByteArray& sentence) {
        // sentence starts with '$'; checksum is XOR of chars between '$' and end
        quint8 sum = 0;
        for (int i = 1; i < sentence.size(); ++i) sum ^= quint8(sentence.at(i));
        sentence += QString::asprintf("*%02X\r\n", sum).toUtf8();
    }

    static QList<QHostAddress> selfUnicastIPv4s() {
        QList<QHostAddress> out;
        for (const auto& iface : QNetworkInterface::allInterfaces()) {
            if (!(iface.flags() & QNetworkInterface::IsUp)) continue;
            if (!(iface.flags() & QNetworkInterface::IsRunning)) continue;
            if (iface.flags() & QNetworkInterface::IsLoopBack) continue;
            for (const auto& e : iface.addressEntries()) {
                if (e.ip().protocol() == QAbstractSocket::IPv4Protocol)
                    out << e.ip();
            }
        }
        return out;
    }

    static bool isUsableInterface(const QNetworkInterface& iface) {
        const auto f = iface.flags();
        if (!(f & QNetworkInterface::IsUp)) return false;
        if (!(f & QNetworkInterface::IsRunning)) return false;
        if (f & QNetworkInterface::IsLoopBack) return false;
        return true;
    }

    // Pick a single target:
    // 1) directed broadcast of a usable IPv4 interface (preferred)
    // 2) 255.255.255.255 if we have IPv4 but no broadcast (fallback)
    // 3) 127.0.0.1 if we have no usable IPv4 interface
    static QHostAddress pickSingleTarget() {
        bool sawUsableIpv4 = false;

        const auto ifaces = QNetworkInterface::allInterfaces();
        for (const auto& iface : ifaces) {
            if (!isUsableInterface(iface)) continue;

            for (const auto& entry : iface.addressEntries()) {
                if (entry.ip().protocol() != QAbstractSocket::IPv4Protocol) continue;
                // Skip link-local 169.254.x.x (usually not helpful here)
                if (entry.ip().isInSubnet(QHostAddress("169.254.0.0"), 16)) continue;

                sawUsableIpv4 = true;

                // Prefer directed broadcast if available
                const QHostAddress bc = entry.broadcast();
                if (!bc.isNull() && bc.protocol() == QAbstractSocket::IPv4Protocol) {
                    return bc;
                }
            }
        }

        if (sawUsableIpv4) {
            // We have IPv4, but no directed broadcast found (rare, but happens).
            return QHostAddress::Broadcast; // 255.255.255.255
        }

        // No usable IPv4 network -> same-device only
        return QHostAddress::LocalHost; // 127.0.0.1
    }

    bool broadcastWaypoint(const QByteArray& payload, quint16 port)
    {
        if (payload.isEmpty()) return false;

        const qint64 now = QDateTime::currentMSecsSinceEpoch();
        const bool peerFresh = !mavPeerAddr_.isNull() && (now - mavPeerSeenMs_) < 15000; // 15s
        qDebug () << "AddWaypoint: broadcastWaypoint: mavPeerAddr_ is" << mavPeerAddr_ << "and mavPeerSeenMs_ is" << mavPeerSeenMs_ << "while now - mavPeerSeenMs_=" << now - mavPeerSeenMs_;

        QHostAddress dst;

        if (peerFresh) {
            // If peer is this device, localhost is the most reliable path for split screen.
            const auto selfIps = selfUnicastIPv4s();
            const bool isSelf = selfIps.contains(mavPeerAddr_);
            dst = isSelf ? QHostAddress::LocalHost : mavPeerAddr_;
        } else {
            // Fallback: one destination only.
            const auto bcasts = collectBroadcasts();
            if (!bcasts.isEmpty()) dst = bcasts.first();          // e.g. 192.168.x.255
            else dst = QHostAddress::LocalHost;                   // no network -> same-device
            // If you really prefer 255.255.255.255 when network exists, swap first() with QHostAddress::Broadcast.
        }

        const qint64 sent = socket_.writeDatagram(payload, dst, port);
        const bool ok = (sent == payload.size());

        if (!ok) {
            qDebug() << "AddWaypoint: UDP send failed to" << dst.toString() << ":" << port
                     << "sent=" << sent << "of" << payload.size()
                     << "err=" << socket_.errorString();
        } else {
            qDebug() << "AddWaypoint: dst =" << dst.toString() << "peerFresh=" << peerFresh;
        }

        // Same-device delivery guarantee (e.g. Skydroid G30 split-screen with NO wifi):
        // the chosen dst above can be a remote unicast (the MAVLink peer is the serial-to-IP
        // adapter at 192.168.144.31 reached over the radio link, NOT this device) or a broadcast
        // that has no egress when only cellular is up. In those cases it never reaches Carp Pilot
        // Pro running on THIS device. 127.0.0.1 is always reachable regardless of network state.
        // UdpWaypointListener listens on 127.0.0.1:port and de-duplicates, so this extra loopback
        // copy is harmless when dst already reached the local app.
        if (dst != QHostAddress::LocalHost) {
            socket_.writeDatagram(payload, QHostAddress::LocalHost, port);
        }

        return ok;
    }



    // Broadcast the payload to all IPv4 broadcast addresses + 255.255.255.255.
    bool broadcast(const QByteArray& payload, quint16 port) {
        if (payload.isEmpty()) {
            qDebug() << "AddWaypoint: broadcast - payload empty";
            return false;
        }

        QList<QHostAddress> targets = collectBroadcasts();
        //if (targets.isEmpty())
        targets << QHostAddress::Broadcast; // 255.255.255.255 fallback
        targets << QHostAddress::LocalHost;
#if QT_VERSION >= QT_VERSION_CHECK(5, 9, 0)
        targets << QHostAddress::LocalHostIPv6;  // optional
#endif
        targets << selfUnicastIPv4s();           // device’s own IP(s)

        QSet<quint32> seen;
        QList<QHostAddress> uniq;
        for (const auto& addr : targets) {
            if (addr.protocol() != QAbstractSocket::IPv4Protocol) continue;
            auto ip = addr.toIPv4Address();
            if (seen.contains(ip)) continue;
            seen.insert(ip);
            uniq << addr;
        }

        //targets << QHostAddress::Broadcast;
        bool anyOk = false;
        for (const auto& addr : uniq) {
        //for (const auto& addr : targets) {
            const qint64 sent = socket_.writeDatagram(payload, addr, port);
            if (sent == payload.size()) anyOk = true;
            qDebug() << "AddWaypoint: broadcast - anyOk =" << anyOk;
            qDebug() << "AddWaypoint: UDP send" << sent << "bytes to" << addr.toString() << ":" << port;
            // If it fails (no network / blocked), we just ignore — fire & forget
        }
        return anyOk;
    }

    static QList<QHostAddress> collectBroadcasts() {
        QList<QHostAddress> list;
        const auto ifaces = QNetworkInterface::allInterfaces();
        for (const auto& iface : ifaces) {
            if (!(iface.flags() & QNetworkInterface::IsUp)) continue;
            if (!(iface.flags() & QNetworkInterface::IsRunning)) continue;
            if (iface.flags() & QNetworkInterface::IsLoopBack) continue;

            for (const auto& entry : iface.addressEntries()) {
                if (entry.ip().protocol() != QAbstractSocket::IPv4Protocol) continue;
                if (!entry.broadcast().isNull()) list << entry.broadcast();
            }
        }
        // dedupe
        std::sort(list.begin(), list.end(), [](auto a, auto b){ return a.toIPv4Address() < b.toIPv4Address(); });
        list.erase(std::unique(list.begin(), list.end(),
                               [](auto a, auto b){ return a.toIPv4Address() == b.toIPv4Address(); }),
                   list.end());
        return list;
    }
};


#endif // UDP_BROADCASTER_H
