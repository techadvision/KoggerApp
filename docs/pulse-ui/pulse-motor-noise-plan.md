# Plan: depth loss past 4 m, the resolution-change artefacts, and noise relief for the 2D echogram

Follows `claude/pulse-motor-noise-depth-loss-analysis.md` (Andy's 3 Nov logs, sections 1-9). Branch: `feature/pulse-depth-source`. Written 6 Nov 2026, nothing applied yet. Six steps, P1-P6; P1 and P5 are the ones that change what a user sees, P2-P4 are belts that only matter once P1 is in, P6 is a conversation with Andy before it is code.

## What the plan has to achieve

A real bottom must never be stored as "no bottom" because of the range the app itself chose. The readout must not lap between a value and a dash in calm water of any depth the device can reach, and when the range does change the picture must not show a dark column or a missing bottom-track segment at the switch. Under motor noise the 2D chain must offer the same relief the side scan chain already has - a floor subtraction - without forcing the user to give up TVG, the water-body filter, the second echo and hardness. And a link that cannot carry the plan must be planned around, not fought.

Two things stay as they are: gate A's purpose (the shore and the far end stay rejected; the 18 Oct bench numbers - 94% of shore pings removed, under 0.3% of water pings lost - are the floor every step is measured against), and the second-echo preference, which remains a sampling/display choice and must not become the thing that makes depth correct.

## P1 - the planner keeps the bottom under the gate

Where: `qml/PulseDepthEngine.qml`, `calculateDynamicResolution` and `updateDynamicResolutionWithStep`.

What: the range the scheme asks for is the larger of today's `depth + margin` and `depth / targetFraction`, with `targetFraction` a runtime expert value defaulting to 0.6. Gate A's ceiling is 0.675 of the acquired range, so 0.6 leaves the bottom a tenth of the range under it in both branches (shallowing and the +1 m deepening step). The `2 x depth + margin` branch (second echo optimize on) is already under 0.5 and is left alone. The deepening +1 m is kept on top. Nothing else in the step logic (metre levels, `requiredStableReading`, the link-fit plan) changes.

What it costs: resolution in deeper water. A 4 m bottom gets 6.7 m instead of 6.0 (11 mm instead of 10 at 600 samples), an 8 m bottom 13.3 m instead of 10 (22 mm instead of 17). The display auto level still follows the depth, so the picture on screen is the same height; the samples per metre are what drop. Past 18 m the 600 x 50 mm cap (30 m) returns the ceiling - that is the `updateDynamicSamplesAndPeriod` branch and is out of scope here, to be noted in the row's hint.

Gate B is the thing to watch: it judges only bottoms beyond 0.5 of the reach (0.45 of the range), and at 0.6 the bottom is inside that zone, so a weak echo under motor noise could now meet gate B's contrast test. Andy's logs show `gate B rejected 0` throughout with bottoms at 0.68-0.80, which says contrast was fine even in his noise, but P1 ships with the bench check below rather than that observation.

Check: the arithmetic in a small JS test beside `tools/pulse-*-check.js` (depth in, range out, ratio asserted under 0.675 at 0.5 m steps from 0.3 to 18 m, both branches, with and without the deepening step). Gate B's exposure on the bench: `tools/pulse-bt-bench/gates.py` over Andy's 11:42 plog and Olav's 2-6 m plog, reporting gate B's verdict on every water epoch whose bottom sits at 0.45-0.68 of its range - the count must stay at zero on both. On the water: a calm 5-7 m stretch with second echo optimize off, `BT: last 10 s` lines with `gate A rejected 0`, no `DYNAMIC: search` lap, and the readout steady; then the same with the motor running.

## P1b - the water-body filter's bottom reference is never a blanked value

Where: `src/scene2d/echogram_watercolumn.cpp` (`apply`, the `t_lastBottomM` fallback), `src/epoch.h` (`chartFrom`, the `bottomProcessing.getDistance()` argument).

Why (analysis section 10, Olav's 6 Nov test): the filter dims above the epoch's stored bottom and, for an epoch stored as NaN, above the last finite bottom the render thread saw. Gate A stores whole stretches as NaN, so a downward slope is filtered against a bottom shallower than the real one (a bright strip on top of the contour, growing through the stretch) and an upward slope against a deeper one (a dark strip under the contour). The stairs Olav photographed are those stretches, one step per search lap.

What: the filter takes a display reference that the gates never blank - the raw bottom-track value kept beside the gated one in the epoch, or, when that is NaN too, the previous epoch's reference held for at most the readout's 2 s and then released to "no filtering". The thread-local fallback is kept only for the black-stripe-patched epochs it was written for, bounded to one epoch. With P1 in place the long NaN stretches vanish and this is a belt; it also fixes the same stairs on a real shore approach, where the gates are right to blank the value and the filter still needs a sane boundary.

Check: the 16:06 built-in-red replay with the filter on, before and after - no strips along the contour at the steps; the 18 Oct shore recordings, where the filter must release rather than dim against a stale deep bottom.

## P2 - two belts under P1

Where: `src/dataset.cpp` (`gateBottomTrackLocked`), `src/depth_gates.h`, `qml/PulseDepthEngine.qml` (`autoLevelCalculate`, the "search found a bottom" branch).

Belt one, the reach is the plan's: `v.rangeM` becomes the larger of the epoch's acquired range and the range the scheme asked for (samples x spacing of the live plan, passed down the way the bottom-track parameters already are). A truncated epoch - 400 of 600 samples on Andy's link - then cannot reject a bottom the plan covers, and the gate does not depend on the black-stripes repair having run first. In a file replay the acquired range is the plan, so nothing changes there.

Belt two, the search result sticks: when `search found a bottom`, the engine re-plans from the found depth with P1's rule and the deepening step, and sets `lastStableDepth` to it, instead of returning to the pre-search range. With P1 in place this is rarely reached; it is here so a search can never hand the planner a range the gate will reject.

Check: `gates.py` mirrors `depth_gates.h` - belt one changes the reach, so the mirror takes the planned range as an input and the 18 Oct numbers are re-run and must hold. Belt two is a log check on the water: no `plan shallow` with a range under the found depth / 0.6 after a `search found` line.

## P3 - the black-stripes reference survives a resolution change

Where: `src/black_stripes_processor.cpp`, `src/dataset.cpp` (the `clearEthalonData` calls at 418-447).

What: instead of clearing the reference whenever the resolution or offset differs from the previous epoch, rescale it - each kept sample moves to the index that holds the same depth in metres under the new spacing (nearest sample, the step counts carried over), and samples that fall outside the new range are dropped. The repair then works through the first pings after a switch, which is where Andy's dark "long line down" sits. The clear stays for an offset change (a different window start is a different trace).

Check: an instrument first - a `STRIPES:` line per 10 s counting epochs that still held a gap or a short length after the forward pass, with a separate count for the first three epochs after a resolution change. On the replay of Andy's 11:42 plog that count must drop to what the step limits allow (a run of more than forward + backward damaged pings is not repairable and stays dark); on Olav's plogs it must stay at zero. The renderer's cache rule holds: a repair that changes the length goes through `invalidateDerived`, as today.

## P4 - the bottom track's threshold after a window reset

Where: `src/data_processor/bottom_track_processor.cpp` (the reset at 278-302, the threshold at the search).

What: after a resolution change the window is empty and the first epochs are judged against `threshold_int x windowSize` while the sum holds one to four epochs. The threshold scales with the epochs actually in the sum (`threshold_int x min(epoch_counter, windowSize)`), so the first epoch after a switch is judged like a single-epoch search, not against five. The `btIndex` placement for a partial window is unchanged.

Check: `tools/pulse-bt-bench/bt.py` is the port and takes the same change; its `realtime()` on Andy's plog counts "no bottom" epochs in the three epochs after each of the 36 resolution changes before and after. The app's own `BT: epoch N | bottom track - m raw` line 0.3 s after every `DYNAMIC: plan` is the device-side check - it should mostly stop. The 18 Oct validation (bench vs app to 0.01 m on 81 of 93 red lines) is re-run so the port still matches.

## P5 - a noise floor for the 2D TVG

Where: `src/scene2d/echogram_tvg.h/.cpp`, `src/epoch.h` (the version guard already covers it), `qml/PulseSettingsList.qml` (TVG 2D group), `qml/PulseRuntimeSettings.qml`, `qml/Plot2D.qml` (the setter calls beside `setTvgDbPerMeter`).

What: the side scan law's step 1, ported. Before the gain, a per-ping floor is estimated on the raw trace and `strength x floor` is subtracted, clamped at `kNoiseFloorMax` (80, as side scan). The estimate differs from side scan because a 2D trace has a bottom in it and the water column can be short: the median of the raw samples from `kSurfBandMaxM` (1.0 m, below the ring-down) to the end of the trace. A median is robust to the bottom peak and the second echo, which together are a small fraction of the samples, and it needs no bottom-track input, so the per-epoch cache stays bottom-independent and the existing `tvgVersion` guard is enough (the strength bumps the version like the constant does). A motor floor that is range-flat is removed before the gain multiplies it, so the fog no longer brightens with depth and the band under the bottom goes with it; echoes keep their level law.

UI: one stepper "Noise floor" in the TVG 2D group, 0 to 1 in the side scan's steps, default 0 (release behaviour unchanged, as the side scan default is), persisted as a runtime expert value like `echogramTvgDbPerMeter`. Hint: "subtracts the per-ping noise floor before the gain - for motor noise". No change to the water-body filter or to the "filter" slider's role; the floor is what the slider used to be able to do, now available with the filter on.

Check: offline first, the way the side scan law was validated - the three Andy plogs and one Olav plog through a Python copy of the law (`tools/pulse-tvg-presets/` has the extraction scaffold), strips at strength 0 / 0.3 / 0.6 / 1.0, judged on the band under the bottom (mean amplitude 0.5-1.5 m below the bottom track relative to the water column) and on a weak-echo case (bottom-hugging fish or the shoulder) that must not disappear. Then on the water with the motor at throttle, the same four strengths. Default stays 0 until Olav has seen the strips.

## P6 - the link that cannot carry the plan

Where: a conversation with Andy before any code; then `applyRedPlan` in `qml/PulseDepthEngine.qml` and `PerfMath.redPlan`.

What to learn: what bridges the Black's UART to the tablet, its own baud and buffer, and whether every one of Andy's `LINK:` lines shows the 6.4-7.1 kB/s cap seen in the 3 Nov log. His loss is flat across quiet and noisy stretches, with zero checksum failures, so it is capacity, not interference; if his bridge can be set to pass the full 115200 the problem is his to fix and nothing in the app changes.

If it cannot: the plan takes the measured wire rate as a second input beside the reported baud. When the 10 s loss figure is over 10% for 30 s, `applyRedPlan` plans against an effective capacity (the measured rate less a tenth) instead of the baud, which drops the samples or lengthens the period until the pings complete; when the loss stays under 2% for a minute the full baud returns. One `DYNAMIC:` line says which it planned against. This reuses the link-fit plan from the performance-mode work and adds no new setting.

Check: on Andy's boat, `chart samples lost` under 2% in the `LINK:` lines after the plan adapts, and the black stripes gone with the repair off; on Olav's boat, no change at all (his loss is near zero and the full baud is never left).

## Order and what each step buys

P1 first and alone, because it removes the laps, and with them most of the resolution changes that expose P3 and P4; it is also the smallest change. Olav's 6 Nov test (analysis section 10) puts both of his "must fix" effects - the second echo in the deep columns and the stairs along the contour - on P1 as well; P1b follows it directly. P5 second, independent of the rest and the one Andy will see as relief. P2 and P4 together as the belts, P3 after them because its instrument needs the laps gone to read the residual. P6 runs beside all of it as a question to Andy and becomes code only if his bridge is fixed in capacity.

Each step is its own commit on `feature/pulse-depth-source`, with the bench mirror changed in the same commit where a gate or the tracker changes (`gates.py`, `bt.py` and `depth_gates.h` stay one thing), and the status block of the depth-source analysis updated at the end of the set. The field check for the set is one run: a calm 5-7 m stretch, second echo optimize off, motor off then on - no `gate A rejected` lines, no `DYNAMIC: search`, a steady readout, no dark columns at the switches, and the band under the bottom gone at the chosen floor strength.

## Status, 7 Nov 2026 (afternoon)

All on `feature/pulse-depth-source`, one step per commit, in Olav's order P1, P1b, P4, P3, P3b; P5 next, P2 and P6 not started.

- P1 `5b73226e` - `plannedRangeRes()` in PulseDepthEngine.qml, `dynamicResolutionTargetFraction` (0.6) with the "Bottom in range" expert stepper, `tools/pulse-depth-plan-check.js`, gates.py's 0.45-0.68 zone report and `fill` flag. The half-metre grid rounded up gives 4 m -> 7.0 m wanted (7.2 acquired), 8 m -> 13.5. Gate B in the zone: 0 of 2958 on Olav's 16:06 plog; 8 of 2840 on Andy's 11:42 with the fill, all on doubly damaged pings or the tracker's own non-bottoms at 11:49:46-11:50:17. NOT VISIBLE ON A REPLAY - the planner is skipped in demo mode, so a recording made under the old rule keeps its gate-A stretches, search bursts and dashes whatever build replays it. Verified only live: a calm 5-7 m stretch, second echo optimize off, `DYNAMIC: plan` with "range wanted" at depth / 0.6, `gate A rejected 0`, no `DYNAMIC: search`, a steady readout; bring the app log (pulse.log) with the plog, the bench needs it for its clock and labels.
- P1b `cfb1dc13` + `56a9ba55` - `displayReference` / `rawDistance` / `trackerVisited` beside the gated value, written by `Dataset::displayReferenceLocked` (stored, else raw, else the nearest earlier own value within 2 s, else none); the render-thread fallback borrows a neighbour's bottom only for epochs the tracker has not reached (always) and black-stripes-patched traces (once). Olav: "successful on playback"; the leading-edge strip the first cut produced is fixed ("really good").
- P4 `4cc84568` - NOT the plan's threshold scaling (both profiles run threshold 0, so that is a no-op, though it is in): the "no bottom" epochs at a resolution change were the last W/2 epochs of the old resolution, which never reached their publication point because the reset clears the counter. The tracker now drains its old window at the change (bt.py the same, same commit). Bench: Andy 11:42 70 -> 0 within 3 of a change, Olav 16:06 236 -> 0, red 18 Oct 52 -> 0, blue 18 Oct 9 -> 0, no epoch that had a value changed; the 18 Oct gates unchanged; match.py identical before and after (42 of 98 red, 25 of 131 blue - lower than the README's 18 Oct figure for reasons predating this set, to revisit).
- STRIPES: instrument `4f723926` + `6d39cfbd` - per 10 s, live and replay: epochs, damaged on arrival (short / gaps), still damaged after the forward pass (gaps left / short of the setup count, with the setup count and trace lengths), of those in the first 3 epochs after a resolution change, step counts. Reads as expected on both files.
- P3 `be612b9e` - the black-stripes reference is rescaled across a resolution change (offset change still clears), forward and backward. With the app's steps 3/5 Andy's residual is the step limit (runs of 4+ damaged pings at 43% loss), ~0.3 per change at the switches instead of ~0.8 (bench).
- P3b `062b926e` - THE LARGER FIND: `IDBinChart::parsePayload` detected a ping boundary against the last COMPLETED ping's resolution, so every resolution change produced a 200-sample stub and a ping with a zero-filled first third - two malformed pings per change on every transducer, on a perfect link (Olav's 16:06 file: 119 stubs for 118 changes; the file holds 79 real damaged pings). Now against the previous frame, flush only with a ping in progress. Olav's replay confirms: damaged on arrival 1-3 per 10 s (the file's own lost tails), 0 of 24 changes, trace lengths 600-600. This, more than P3, is the dark column at the resolution step.

Open from the set: the black-stripes expert setters (forward/backward steps) are not reliable in a replay - 0 steps plus stop/restart sometimes shows the raw stripes and sometimes not - a todo before they are used for analysis again. The bench's match.py figure. The depth-source analysis status block, to update at the end of the set.

P5 next: offline strips first (Andy's three plogs and Olav's 16:06 at strengths 0 / 0.3 / 0.6 / 1.0, `tools/pulse-tvg-presets/` has the extraction scaffold), shown before anything is wired; the water-body filter's effect below the bottom (Olav's filter-on/off screenshots of 7 Nov: with the filter off the rail's slider is the upstream global low cut) is the acceptance picture.
