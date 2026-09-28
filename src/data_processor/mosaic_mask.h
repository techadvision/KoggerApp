#pragma once

#include <QString>

// THE MOSAIC'S WIPE AND PAUSE (28 Sept 2026) - which epochs the mosaic may paint.
//
// Olav: "If I could wipe, start, pause then the resulting render could become amazing."
// The boat is powered on ashore, slid in and driven out, and all of that is painted; a 90
// degree turn smears about 35 m either side of the boat over what was already captured.
//
// WHY A MASK AND NOT A CLEAR. The mosaic is not a picture that is only ever added to: tiles
// are rebuilt from the dataset's epochs whenever the view needs them again (a re-trace, the
// update action, a zoom). A clear alone would bring the wiped area straight back. So what
// the user chose is kept as DATA - epoch index ranges - and MosaicProcessor::updateData
// refuses those epochs on every path, first paint or re-trace alike.
//
//   wipe(n)    - nothing before epoch n is painted again. The tiles are cleared by the caller.
//   pause(n)   - nothing from epoch n on is painted, until
//   resume(n)  - which closes the range [pausedFrom, n).
//   reset()    - a new source: epoch indices start again from 0, so the old ranges mean
//                nothing. Called from Core::resetRealtimeSessionState, which every route to
//                a new source (open, stream, demo start and loop, close) goes through.
//
// Thread-safe: written from the GUI thread (Core), read per epoch from the compute worker.
class MosaicMask
{
public:
    static void reset();
    static void wipe(int firstKeptEpoch);
    static void pause(int fromEpoch);
    static void resume(int atEpoch);

    static bool paused();
    static bool isEmpty();     // no wipe, no pause, no range: the mosaic paints everything
    static bool excludes(int epochIndex);

    // For the log: "wiped before 1234 | 2 paused ranges | paused since 1500".
    static QString describe();

private:
    MosaicMask() = delete;
};
