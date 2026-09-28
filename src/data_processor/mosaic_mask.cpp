#include "mosaic_mask.h"

#include <QReadWriteLock>
#include <QVector>
#include <QPair>
#include <utility>

namespace {

QReadWriteLock           gLock;
int                      gWipedBefore = -1;   // epochs below this are never painted
QVector<QPair<int, int>> gRanges;             // closed pauses, [from, to)
int                      gPausedFrom  = -1;   // an open pause, or -1

} // namespace

void MosaicMask::reset()
{
    QWriteLocker wl(&gLock);
    gWipedBefore = -1;
    gRanges.clear();
    gPausedFrom = -1;
}

void MosaicMask::wipe(int firstKeptEpoch)
{
    QWriteLocker wl(&gLock);
    gWipedBefore = qMax(gWipedBefore, firstKeptEpoch);
    // Ranges entirely inside the wiped part say nothing any more.
    QVector<QPair<int, int>> kept;
    for (const auto& r : std::as_const(gRanges))
        if (r.second > gWipedBefore)
            kept.append(r);
    gRanges = kept;
    // A pause stays a pause across a wipe: wiping while paused means "throw away what is
    // there, and keep not painting until I resume".
    if (gPausedFrom >= 0)
        gPausedFrom = qMax(gPausedFrom, gWipedBefore);
}

void MosaicMask::pause(int fromEpoch)
{
    QWriteLocker wl(&gLock);
    if (gPausedFrom < 0)
        gPausedFrom = qMax(0, fromEpoch);
}

void MosaicMask::resume(int atEpoch)
{
    QWriteLocker wl(&gLock);
    if (gPausedFrom < 0)
        return;
    if (atEpoch > gPausedFrom)
        gRanges.append(qMakePair(gPausedFrom, atEpoch));
    gPausedFrom = -1;
}

bool MosaicMask::paused()
{
    QReadLocker rl(&gLock);
    return gPausedFrom >= 0;
}

bool MosaicMask::isEmpty()
{
    QReadLocker rl(&gLock);
    return gWipedBefore < 0 && gRanges.isEmpty() && gPausedFrom < 0;
}

bool MosaicMask::excludes(int epochIndex)
{
    QReadLocker rl(&gLock);
    if (epochIndex < gWipedBefore)
        return true;
    if (gPausedFrom >= 0 && epochIndex >= gPausedFrom)
        return true;
    for (const auto& r : std::as_const(gRanges))
        if (epochIndex >= r.first && epochIndex < r.second)
            return true;
    return false;
}

QString MosaicMask::describe()
{
    QReadLocker rl(&gLock);
    return QStringLiteral("wiped before %1 | %2 paused range(s) | %3")
        .arg(gWipedBefore)
        .arg(gRanges.size())
        .arg(gPausedFrom >= 0 ? QStringLiteral("paused since %1").arg(gPausedFrom)
                              : QStringLiteral("painting"));
}
