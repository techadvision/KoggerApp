#include "device_manager_wrapper.h"
#include "device_defs.h"
#include "SettingsBus.h"
#include <QDebug>
#include <QTime>


DeviceManagerWrapper::DeviceManagerWrapper(QObject* parent) :
    QObject(parent),
    averageChartLosses_(0),
    protoBinConsoledState_(false),
    nmeaConsoledState_(true),
    USBLBeaconDirectAskState_(false)
{
    workerObject_ = std::make_unique<DeviceManager>();

#ifdef SEPARATE_READING
    workerThread_ = std::make_unique<QThread>(this);

    auto ct = Qt::AutoConnection;
    deviceManagerConnections_.append(QObject::connect(this,                &DeviceManagerWrapper::sendOpenFile,  workerObject_.get(), &DeviceManager::openFile,                      ct));
    deviceManagerConnections_.append(QObject::connect(this,                &DeviceManagerWrapper::sendCloseFile, workerObject_.get(), &DeviceManager::closeFile,                     ct));
    deviceManagerConnections_.append(QObject::connect(workerObject_.get(), &DeviceManager::devChanged,           this,                &DeviceManagerWrapper::devChanged,             ct));
    deviceManagerConnections_.append(QObject::connect(workerObject_.get(), &DeviceManager::standAvailableChanged, this,                &DeviceManagerWrapper::standAvailableChanged,   ct));
    deviceManagerConnections_.append(QObject::connect(workerObject_.get(), &DeviceManager::streamChanged,        this,                &DeviceManagerWrapper::streamChanged,          ct));
    deviceManagerConnections_.append(QObject::connect(workerObject_.get(), &DeviceManager::vruChanged,           this,                &DeviceManagerWrapper::vruChanged,             ct));
    deviceManagerConnections_.append(QObject::connect(workerObject_.get(), &DeviceManager::chartLossesChanged,   this,                &DeviceManagerWrapper::calcAverageChartLosses, ct));
    deviceManagerConnections_.append(QObject::connect(workerObject_.get(), &DeviceManager::mavlinkWasDetected,   this,                &DeviceManagerWrapper::mavlinkWasDetected,     ct));
    deviceManagerConnections_.append(QObject::connect(workerObject_.get(), &DeviceManager::openProgressChanged,  this,                &DeviceManagerWrapper::openProgressChanged,    ct));
    deviceManagerConnections_.append(QObject::connect(workerObject_.get(), &DeviceManager::openInterrupted,      this,                &DeviceManagerWrapper::openInterrupted,        ct));

    workerObject_->moveToThread(workerThread_.get());
    workerThread_->setObjectName("DevManThread");
#else
    auto ct = Qt::DirectConnection;
    QObject::connect(this,                &DeviceManagerWrapper::sendOpenFile,  workerObject_.get(), &DeviceManager::openFile,                      ct);
    QObject::connect(this,                &DeviceManagerWrapper::sendCloseFile, workerObject_.get(), &DeviceManager::closeFile,                     ct);
    QObject::connect(workerObject_.get(), &DeviceManager::devChanged,           this,                &DeviceManagerWrapper::devChanged,             ct);
    QObject::connect(workerObject_.get(), &DeviceManager::standAvailableChanged, this,                &DeviceManagerWrapper::standAvailableChanged,   ct);
    QObject::connect(workerObject_.get(), &DeviceManager::streamChanged,        this,                &DeviceManagerWrapper::streamChanged,          ct);
    QObject::connect(workerObject_.get(), &DeviceManager::vruChanged,           this,                &DeviceManagerWrapper::vruChanged,             ct);
    QObject::connect(workerObject_.get(), &DeviceManager::chartLossesChanged,   this,                &DeviceManagerWrapper::calcAverageChartLosses, ct);
    QObject::connect(workerObject_.get(), &DeviceManager::mavlinkWasDetected,   this,                &DeviceManagerWrapper::mavlinkWasDetected,     ct);
    QObject::connect(workerObject_.get(), &DeviceManager::openProgressChanged,  this,                &DeviceManagerWrapper::openProgressChanged,    ct);
    QObject::connect(workerObject_.get(), &DeviceManager::openInterrupted,      this,                &DeviceManagerWrapper::openInterrupted,        ct);
#endif

    // PULSE, performance mode step 1: the serial link read-outs, on the GUI thread. Wired
    // here, STARTED in setSettingsBus() - see there.
    linkStatsTimer_.setInterval(1000);
    QObject::connect(&linkStatsTimer_, &QTimer::timeout, this, &DeviceManagerWrapper::sampleLinkStats);
}

// ONE SECOND OF THE SERIAL LINK. The wire rate is measured, not estimated: every KP frame
// from a live link is counted where it arrives. The load is that rate against the
// transducer's own reported baud at 8N1 (10 bits a byte). The loss is the chart samples a
// seqOffset gap said never arrived, over the last 10 s and since the start. A `LINK:` line
// every 10 s while data flows is the record a measurement run is read from.
void DeviceManagerWrapper::sampleLinkStats()
{
    const DeviceManager::LinkStats st = getWorker()->linkStats();

    // The counters only grow; a dataset reset does not touch them. Guard anyway, so a
    // future reset cannot produce a huge unsigned delta.
    const quint64 dWire    = st.wireBytes    >= lastWireBytes_    ? st.wireBytes    - lastWireBytes_    : 0;
    const quint64 dChart   = st.chartBytes   >= lastChartBytes_   ? st.chartBytes   - lastChartBytes_   : 0;
    const quint64 dMissing = st.missingBytes >= lastMissingBytes_ ? st.missingBytes - lastMissingBytes_ : 0;
    lastWireBytes_ = st.wireBytes;
    lastChartBytes_ = st.chartBytes;
    lastMissingBytes_ = st.missingBytes;

    winChart_[winIndex_] = dChart;
    winMissing_[winIndex_] = dMissing;
    winIndex_ = (winIndex_ + 1) % kLossWindow;
    quint64 wc = 0, wm = 0;
    for (int i = 0; i < kLossWindow; ++i) { wc += winChart_[i]; wm += winMissing_[i]; }

    linkBaud_ = st.baud;
    linkBytesPerSecond_ = int(dWire);
    linkLoadPercent_ = (st.baud > 0) ? (double(dWire) * 10.0 * 100.0 / double(st.baud)) : -1.0;
    chartLossPercent_ = (wc + wm) > 0 ? double(wm) * 100.0 / double(wc + wm) : -1.0;
    chartLossPercentTotal_ = (st.chartBytes + st.missingBytes) > 0
                             ? double(st.missingBytes) * 100.0 / double(st.chartBytes + st.missingBytes) : -1.0;
    emit linkStatsChanged();

    if (dWire > 0) {
        if (++secondsWithData_ % 10 == 1) {
            // SELF-DESCRIBING (Olav, 2 Oct: Qt Creator's output has no time stamps): the
            // clock time and what the transducer reports it is set to, so a measurement run
            // can be read from the lines alone. pulse.log stamps every line as well.
            qDebug().noquote() << QStringLiteral("LINK: %6 | %7 samples, %8 mm, %9 ms | %1 B/s on the wire | baud %2 -> %3 | chart samples lost %4 (10 s) %5 (since start)")
                                      .arg(dWire)
                                      .arg(st.baud)
                                      .arg(linkLoadPercent_ >= 0 ? QString::number(linkLoadPercent_, 'f', 1) + "% used" : QStringLiteral("load unknown"))
                                      .arg(chartLossPercent_ >= 0 ? QString::number(chartLossPercent_, 'f', 2) + "%" : QStringLiteral("-"))
                                      .arg(chartLossPercentTotal_ >= 0 ? QString::number(chartLossPercentTotal_, 'f', 2) + "%" : QStringLiteral("-"))
                                      .arg(QTime::currentTime().toString(QStringLiteral("HH:mm:ss")))
                                      .arg(st.samples).arg(st.spacingMm).arg(st.periodMs);
        }
    } else {
        secondsWithData_ = 0;
    }
}

//PULSE
void DeviceManagerWrapper::setSettingsBus(SettingsBus* bus)
{
    // THE LINK READ-OUT'S TIMER STARTS HERE, NOT IN THE CONSTRUCTOR (2 Oct 2026). This
    // wrapper belongs to `Core core`, a global in main.cpp, so the constructor runs during
    // static initialisation - before QGuiApplication exists, with no event dispatcher on the
    // thread. A QTimer started there never fires: on the G30 with a live blue, no LINK: line
    // and no read-out ever appeared. main() calls this after the application is built.
    if (!linkStatsTimer_.isActive()) {
        linkStatsTimer_.start();
        qDebug().noquote() << QStringLiteral("LINK: the serial link read-out is running (once a second)");
    }

#ifdef SEPARATE_READING
    // worker is on its own thread
    QMetaObject::invokeMethod(
        workerObject_.get(),
        [this, bus]{
            workerObject_->setSettingsBus(bus);
        },
        Qt::QueuedConnection);
#else
    workerObject_->setSettingsBus(bus);
#endif
}

bool DeviceManagerWrapper::mavlinkDetected() const {
    return workerObject_->mavlinkDetected();
}

DeviceManagerWrapper::~DeviceManagerWrapper()
{
#ifdef SEPARATE_READING
    if (workerObject_) {
        QMetaObject::invokeMethod(workerObject_.get(), "shutdown", Qt::BlockingQueuedConnection);
        QMetaObject::invokeMethod(workerObject_.get(), "deleteLater", Qt::QueuedConnection);
    }

    for (auto& itm : deviceManagerConnections_)
        QObject::disconnect(itm);
    deviceManagerConnections_.clear();

    if (workerThread_) {
        workerThread_->quit();
        workerThread_->wait();
    }

    workerObject_.release();
#endif
}

DeviceManager* DeviceManagerWrapper::getWorker()
{
    return workerObject_.get();
}

QUuid DeviceManagerWrapper::getFileUuid() const
{
    return QUuid(kFileUuidStr);
}

void DeviceManagerWrapper::startWorkerThread()
{
#ifdef SEPARATE_READING
    if (workerThread_ && !workerThread_->isRunning()) {
        workerThread_->start();
    }
#endif
}

void DeviceManagerWrapper::initStreamList()
{
#ifdef SEPARATE_READING
    QMetaObject::invokeMethod(workerObject_.get(), "initStreamList", Qt::QueuedConnection);
#else
    workerObject_->initStreamList();
#endif
}

void DeviceManagerWrapper::startStreamDownload(int id)
{
#ifdef SEPARATE_READING
    QMetaObject::invokeMethod(workerObject_.get(), "startStreamDownload", Qt::QueuedConnection, Q_ARG(int, id));
#else
    workerObject_->startStreamDownload(id);
#endif
}

void DeviceManagerWrapper::cancelStreamDownload(int id)
{
#ifdef SEPARATE_READING
    QMetaObject::invokeMethod(workerObject_.get(), "cancelStreamDownload", Qt::QueuedConnection, Q_ARG(int, id));
#else
    workerObject_->cancelStreamDownload(id);
#endif
}

void DeviceManagerWrapper::refreshStreamList()
{
#ifdef SEPARATE_READING
    QMetaObject::invokeMethod(workerObject_.get(), "refreshStreamList", Qt::QueuedConnection);
#else
    workerObject_->refreshStreamList();
#endif
}

void DeviceManagerWrapper::calcAverageChartLosses()
{
    averageChartLosses_ = std::max(0, std::min(100, 100 - getWorker()->calcAverageChartLosses()));
    emit this->chartLossesChanged();
}
