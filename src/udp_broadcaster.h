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
    explicit UdpBroadcaster(QObject* parent=nullptr)
        : QObject(parent)
    {
        // TTL 1 keeps it on the LAN; harmless if the platform ignores it.
        //socket_.setSocketOption(QAbstractSocket::BroadcastTtlOption, 1);
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
        return broadcast(payload, port);
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
        qDebug() << "AddWaypoint: udp_broadcaster sendJsonPoint completed";
        return broadcast(payload, port);
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
    QUdpSocket socket_;

    static void toNmeaLat(double lat, QByteArray& field, QByteArray& hem) {
        hem = (lat < 0) ? "S" : "N";
        double alat = std::abs(lat);
        int deg = int(alat);
        double minutes = (alat - deg) * 60.0;
        field = QString::asprintf("%02d%06.3f", deg, minutes).toUtf8(); // ddmm.mmm
    }

    static void toNmeaLon(double lon, QByteArray& field, QByteArray& hem) {
        hem = (lon < 0) ? "W" : "E";
        double alon = std::abs(lon);
        int deg = int(alon);
        double minutes = (alon - deg) * 60.0;
        field = QString::asprintf("%02d%06.3f", deg, minutes).toUtf8(); // ddmm.mmm
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
