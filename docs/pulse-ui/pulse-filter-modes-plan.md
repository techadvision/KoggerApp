# Plan: the filter as a user choice - Off / Water body / Whole picture

Written 7 Nov 2026 after P5/P5b of the motor-noise plan (`pulse-motor-noise-plan.md`), Olav's device check of the
noise floor (`testlogs/Screenshots of noise floor with knee`) and his hardware partner's note that customers lose the
thermocline to the water body filter and that he himself needs the unfiltered return level to test every echo sounder
he builds. Nothing applied yet; the implementation is its own chat. Branch: a new one off `feature/pulse-depth-source`
once that set is pushed.

## What the user has today, and why it is the wrong shape

The rail's Filter button opens one slider, 0-20, labelled "Water body filter". What the slider DOES depends on an
expert switch two screens away (`echogramWaterBodyFilterEnabled`, runtime, default on): with it on, the slider is the
water body filter's strength and the upstream global low cut is pinned to 0; with it off, the slider is the low cut
and the water body filter is 0 (`main.qml applyWaterBodyFilter`). A hint under the slider says which ("water column
only" / "whole picture"). The noise floor from P5 is a third thing again, an expert stepper in the TVG 2D group,
runtime, not persisted, one value for both pictures.

So the user who wants "a filter over the whole echogram" has it already and cannot find it; the partner who wants
the filter OFF has to know that slider 0 under the expert switch is not quite off (the water body strength is floored
at `echogramWaterBodyMinRealValue` 5 - a guard against testers arriving with the slider at 0 under a switch that reads
"on"); and the one filter that Olav's own test showed to give the cleanest water column on a noisy boat - the floor
with the water body filter off - is a combination of two expert settings. Three mechanisms, one slider, no choice on
screen.

## Olav's two proposals, and where I push back

**Split "Screen & echogram" into Screen and Echogram.** Agreed, and overdue regardless of the filter: the group holds
twelve rows today and two of them (speed of sound, second echo) are measurement choices that have nothing to do with
units. The split as Olav listed it is right - Screen keeps interface size, depth in, display temperature, temperature
in, display boat speed, speed in; Echogram takes speed of sound (and its back-to-profile row), optimise for a second
echo, and, because they are picture rows and already sit there, side scan width, side scan TVG and far-field gain.

**Put the filter's settings in Settings too, with the Filter panel as "quick access".** Here I push back. The filter is
not a setting you make once and forget, like units or speed of sound; it is something the user reaches for when the
picture is wrong - fog from the motor, a thermocline that is not there, a second echo that will not show. That is
exactly when the rail panel is open and the settings list is not. v2's rule for tier 1 is that a control reports and
nothing stores, so a second copy of the same choice in Settings would be harmless technically (same binding, same
writer) - but it would give the choice two homes, and a user who changes it in one place and later finds it in the
other will wonder which one wins. Olav's own instinct in the last sentence of his message is the right one: "if there
are any settings that apply to the filter, here is where I will find them." So: the choice lives in the Filter panel
and ONLY there; Settings > Echogram does not mention it. The expert "Water body filter" group stays as the place for
the expert-only numbers (the bottom margin), renamed "Filter".

The thing Olav called "quick access" is therefore not quick access to settings held elsewhere - it IS the control.

## The control

The Filter panel gets a segment row above the slider, three choices, the slider under it as the strength of whatever
is chosen:

- **Off** - the picture as measured, TVG still applied (TVG is a gain law, not a filter; the partner's return-level
  test is a comparison at one range, where a range-dependent gain is a constant). The slider is hidden.
- **Water body** - today's water body filter, slider 0-20 as today. Hint, Olav's words to confirm: "dims the water
  column, never the bottom - keeps the second echo for reading hardness".
- **Whole picture** - the P5 noise floor with its knee: slider 0-20 maps to strength 0..1 (the same 0-1 the expert
  stepper takes today), the water body filter at 0, the low cut at 0. Hint: "removes the noise floor everywhere -
  thermoclines and weak echoes stay; for motor noise". On a side scan picture the same choice drives the side scan
  TVG's own noise floor (`EchogramSideScanTvg::setNoiseFloorStrength`), which has had the identical step since August,
  so the control means the same thing on both pictures.

One mode at a time. Olav's screenshots are the evidence: filter 10 + floor 0.75 and filter off + floor 0.4-0.5 both
clean Andy's water column, and the second is the one without the green fringe above the contour, so the combination
buys nothing a user needs. If the combination is ever wanted it is one expert switch later ("keep the water body
filter under Whole picture"), not a fourth mode now.

Why the noise floor and not the old global low cut as "Whole picture": the low cut is a fixed level - everything under
it goes black whatever the boat - so on a quiet boat it eats the thermocline the partner wants to see just as the water
body filter does, and on a noisy boat it has to be set so high that weak echoes go with the noise. The floor is per
ping and relative to that ping's own noise, with the knee leaving everything above three times the floor untouched:
on a quiet boat (floor 5-10 raw) a 30-40 raw thermocline survives any slider position; on Andy's boat (floor ~50) the
fog goes and the bottom stays red (the P5b screenshots). The low cut does not disappear: an expert switch in the
Filter group, "Whole picture uses the fixed low cut", keeps it reachable for a side-by-side on the water, the pattern
the TVG group already uses for the upstream ramp. If nobody switches it on in a season it goes.

What the partner gets: Off is his test picture. What the thermocline customers get: Whole picture at a low setting,
or Off. What Andy gets: Whole picture at 8-10 (0.4-0.5). What nobody loses: Water body is the default and the default
strength is today's, so a user who never opens the panel sees the picture they have now.

## The data model (one binding, one writer)

- A persistent preference per picture, like the display values: `filterMode2D` / `filterModeSideScan` in
  PulseSettings, values "off" / "water" / "whole", default "water"; `pulseRuntimeSettings.displayFilterMode` resolves
  the key from `displayIs2DTransducer` the way `displayFilterKey` does, and `storeDisplayFilterMode(v)` is its one
  writer with the same no-picture guard. The slider keeps `filterDisplayValue2D/SideScan` untouched - a user who
  switches mode and back finds the strength where they left it.
- `applyWaterBodyFilter()` in main.qml becomes `applyFilter()`: Off -> water body 0, low cut 0, floor 0 (both laws);
  Water -> water body real/50 (the `echogramWaterBodyMinRealValue` floor is dropped - the mode is the switch now, and
  slider 0 under Water means "no dimming", which is honest), low cut 0, floor 0; Whole -> water body 0, floor
  display/20 on both `setTvgNoiseFloor` and `setSsTvgNoiseFloor`, low cut 0 - or, with the expert compare switch,
  floor 0 and low cut real. One applier, one log line (`FILTER: mode water | 2D | display 8 -> wbf 0.40 floor 0 cut 0`).
- The expert switch `echogramWaterBodyFilterEnabled` is retired: its two states are now Water and Whole-with-low-cut.
  Migration on first run: switch off -> mode "whole" with the compare switch on, so a tester who had the low cut keeps
  the low cut; switch on -> "water". PulseAppClassic keeps reading the old switch; classic is retired and not
  retested, so it is left alone, not ported.
- The expert "Noise floor" stepper in TVG 2D (P5) and the side scan one in TVG side scan are retired as controls - the
  slider is the control now - and `echogramTvgNoiseFloor` / `sideScanTvgNoiseFloor` become what the applier writes.
  The C++ (`EchogramTvg::setNoiseFloorStrength`, the knee, the percentile) is untouched.
- The mosaic: the side scan floor sits inside the SS TVG, which the mosaic renders from when the mosaic switch is on,
  so Whole picture reaches the map where Water body never did. That is right (noise on the map is noise), but it is
  a visible change to say in the row's hint on a blue.

## Strings (Olav's, as always)

Rail button and panel title: "Filter" instead of "Water body filter" (`PulseRail.qml`, `PulsePanel.qml:159/357`).
Segment: "Off" / "Water body" / "Whole picture". The three hints above. Expert group title "Filter" with "Bottom
margin" and the compare switch. Settings groups "Screen" and "Echogram".

## Order

1. The Screen / Echogram split - mechanical, QML only, its own commit, no behaviour change.
2. The mode: PulseSettings keys + migration, `displayFilterMode` + writer, `applyFilter()`, the retired switch and
   steppers, the panel's segment row and hints, the rail label. One commit if it tests as one idea on the device; the
   migration is the part to check first (a tester's existing switch state must land in the right mode).
3. The compare switch for the low cut - its own commit, so it can go alone when it goes.
4. `tools/pulse-profile-check.js` and the QML checkers after every step; a device pass with the two Andy logs
   (11:28, 11:42) and Olav's 15:42 (second echo on): Water at 10 = today's picture; Whole at 8-10 on Andy = the P5b
   filter-off screenshots; Off = raw + TVG with the depth readout unchanged (the filter is display-only, the bottom
   track never sees it - worth one look at the `BT:` lines all the same).

Open for Olav: whether the default mode on a NEW install should stay Water body (my recommendation: yes, it is the
known picture and the second-echo users' picture) and whether the Filter rail button's icon should change with the
mode.
