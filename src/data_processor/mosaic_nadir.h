#pragma once

// PULSE addition - P3, step 3: the nadir band in the side scan mosaic.
//
// WHAT THE BAND IS. A side scan transducer has no useful return directly
// beneath it, and upstream paints that wedge anyway, near black - which is why
// it reads as a strip of water body laid into the map. Our geometry is not at
// fault and was checked end to end: the mosaic's sample lookup is honest slant
// range, so a ground point at horizontal offset x reads the sample at
// sqrt(x^2 + depth^2). There is no slant-range error to find.
//
// TWO DEGRADATIONS STACK THERE, AND ONLY ONE OF THEM IS THE BEAM.
//   1. Beam pattern: a transducer aimed below the horizontal is far down its
//      pattern at vertical incidence.
//   2. Slant-to-ground compression: ground sample spacing is dr * r/x. At
//      x = 1.0 * depth that is 1.41 slant samples; at 0.5, 2.24; at 0.25, 4.1.
//      The picture loses resolution SMOOTHLY, not at a line.
//
// So a hard cut at any single width leaves a seam, and the conventional 45
// degree (1 x altitude) blanking also throws away usable data between about
// 0.6 and 1.0 x depth where the spacing is still under twice the resolution.
// Hence a FEATHER: fully interpolated inside innerFactor x depth, fully real
// outside outerFactor x depth, smoothstepped between.
//
// AND THE FILL IS AN INTERPOLATION ACROSS THE TRACK, WITH THE NADIR DATA
// EXCLUDED. The blended down scan trace cannot rescue this wedge - inside it
// both channels sit in the null and the ground-to-slant mapping collapses, so
// blending two nulls gives a null. What is interpolated is the pair of TRUSTED
// EDGE values, one per side, read at outerFactor x depth. Both edges are read
// off the same Epoch, so the two half-strips meet continuously at the track
// with no cross-quad state and no ordering dependency.
//
// THE WEDGE IS INVENTED DATA AND IS NOT A MEASUREMENT. Nothing in the bottom
// track, the depth readout or the surface reads any of it; this is the tile
// colour and only the tile colour.

class MosaicNadir
{
public:
    static void  setEnabled(bool enabled);
    static bool  enabled();

    // Both are multiples of the epoch's own depth. inner is where the fill is
    // total, outer is where the real data has fully taken over.
    static void  setInnerFactor(float factor);
    static float innerFactor();
    static void  setOuterFactor(float factor);
    static float outerFactor();

    // 1 inside inner, 0 at and outside outer, smoothstep between. Both
    // arguments in metres; answers 0 for a disabled fill or a depth that is not
    // positive, so the caller needs no second guard.
    static float weightAt(float groundOffsetM, float depthM);

private:
    MosaicNadir() = delete;
};
