#pragma once

#include <stdint.h>
#include <QVector>

// PULSE addition - P3, step 1: the two SIDE SCAN channels blended into one
// down scan trace.
//
// SCOPE. Port and starboard of the SAME side scan device, and nothing else.
// The 2D transducer is not involved at any point in this file; on a red there
// is no second channel and none of this is reachable.
//
// WHY THERE IS A BLEND TO MAKE. Both side scan channels start AT THE
// TRANSDUCER, so the samples from 0 to the first bottom return are the water
// column directly beneath the boat - a down scan, one per channel. Today's
// down pane draws channel 2 alone, and not by choice: the pane's range is
// 0..R, so in plot2D_echogram.cpp the negative half is zero pixels wide and
// channel 1 is never drawn. Port and starboard are two INDEPENDENT looks at
// the same vertical return, so combining them is ordinary multi-look
// processing rather than an invention.
//
// THE LAW, AND WHY RMS IS THE DEFAULT.
//   Seabed backscatter is speckled: envelope amplitude is Rayleigh
//   distributed, intensity is exponential, and a single look has a
//   coefficient of variation of 1.0. Averaging N INDEPENDENT looks IN THE
//   INTENSITY DOMAIN takes that to 1/sqrt(N). Here N = 2, so CV goes 1.00 ->
//   0.71: about 1.5 dB of speckle suppression, for one pass over the trace.
//
//   Intensity is amplitude squared, so the two-look mean intensity mapped
//   back into the amplitude domain the renderer works in is
//
//       out = sqrt((a*a + b*b) / 2)          the quadratic mean, RMS
//
//   An arithmetic mean of AMPLITUDES is a biased-low estimate of mean
//   intensity and suppresses less speckle; averaging log-compressed values
//   computes a geometric mean and is worse again. The raw byte here IS linear
//   envelope amplitude - imageType 3's own comment calls its side scan TVG a
//   "log-law", so the log is applied downstream and is not already in the
//   sample.
//
//   Mean and Max exist as expert options so the claim above can be falsified
//   on the water, NOT because either is a better estimator. Max is biased
//   high and takes the louder noise of the two channels at every sample.
//   Single is today's behaviour, kept as the A/B reference.
//
// WHERE IN THE CHAIN, AND WHY Raw IS THE DEFAULT.
//   Multi-look averaging is defined on the raw intensity. The AGC
//   (Echogram::compensated) is an ADAPTIVE running normaliser along the
//   trace, so two channels each normalised against their own trace and then
//   averaged have no defined level law. Blending first and gain-shaping the
//   blend ONCE gives the down pane exactly the signal chain a real down scan
//   channel would have. AfterGain is kept for comparison and costs nothing.
//
// NOT HERE, DELIBERATELY: channel balance. Port and starboard transducers do
// differ in sensitivity and equalising before combining is correct practice,
// but the honest estimator is a slowly varying ratio of each channel's
// seabed-region intensity over a few hundred pings. A per-ping ratio chases
// speckle and makes the picture worse, so this waits until the blend has been
// seen on the water rather than shipping as a switch that guesses.
//
// Display-only, like every other module in this directory: stored amplitudes
// and logs are never touched.

class EchogramBlend
{
public:
    enum Mode : int {
        Single = 0, // no blend - the half is drawn from the channel that owns it
        Rms    = 1, // two-look mean INTENSITY, mapped back to amplitude
        Mean   = 2, // arithmetic mean of amplitudes
        Max    = 3  // brighter of the two
    };

    enum Domain : int {
        Raw       = 0, // blend the raw amplitudes, then apply the gain law once
        AfterGain = 1  // blend the two gain-shaped buffers
    };

    static void setMode(int mode);
    static int  mode();

    static void setDomain(int domain);
    static int  domain();

    // out[i] = blend(a[i], b[i]) for i < n. out is resized to n. Mode::Single
    // never reaches here - the caller does not blend at all in that case.
    static void apply(const uint8_t* a, const uint8_t* b, int n, QVector<uint8_t>& out);

private:
    EchogramBlend() = delete;
};
