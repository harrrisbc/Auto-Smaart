# Auto-Smaart Ring Out design

Date: 2026-11-04

UI revised 2026-11-05: Ring Out is one page, with fewer surfaces than Calibration.

Auto-Smaart Ring Out is a later mode of the same Mac app that owns system calibration. The operator uses it for a pre-show microphone ring-out so mic level can be pushed higher before the show. This document is the behavior spec for that mode only. It does not replace or edit the calibration design.

Calibration remains the earlier mode, specified in [docs/superpowers/specs/2026-11-04-auto-calibration-design.md](./2026-11-04-auto-calibration-design.md). Ring Out is a separate mode: one page, separate controller, separate write path. The two modes share the DiGiCo Quantum 225 OSC console connection, the official Smaart API session, and one cross-mode **Stop** safety rule defined below. They do not share EQ fit, delay write, confirm-before-write, curve bank, or Matrix-only targeting.

This change adds the Ring Out behavior spec only. It does not add application code.

## Purpose

One pass rings out one selected strip so the operator can raise that mic (or bus) higher without the first sustained feedback tone. The app raises the strip fader until a sustained RTA peak appears, pulls the fader to −∞, writes one notch, then raises again. The pass ends when the fader is +5.0 dB above the first-feedback level, or when 8 EQ bands are in use.

Ring Out is not show-time continuous feedback chasing. After the pass ends, the app does not keep measuring or writing.

## Prior art / design choices

Public product behavior and common practice informed the numbers below. This section does not copy proprietary algorithms or claim patent detail. It records why this mode’s approved workflow uses FIXED-only ring-out, narrow notches, −3 dB steps, and a +5 dB stop.

| Source (public behavior) | Lesson taken |
| --- | --- |
| dbx AFS2, Sabine FBX, Shure DFR | Dedicated feedback hardware splits **FIXED** (setup / ring-out before the show) from **LIVE** (during the show). Auto-Smaart Ring Out is FIXED-only. Fixed filters stay until the operator resets or undoes them. Hardware often uses very narrow notches (dbx publicly claims on the order of Q ≈ 116 / 1/80 octave); a console parametric cannot match that width, so this mode picks the highest practical narrow Q inside Quantum 225 EQ limits. |
| Manual ring-out practice | Raise until the system rings, cut a few dB (commonly 3–6), repeat a few times, then leave headroom. Matches this mode’s −3.0 dB cuts per step and stop at +5.0 dB above first feedback. After that stop, the operator may back the fader off slightly by hand for extra safety margin; the app does not auto-back-off. |
| Smaart (RTA + spectrograph) | Engineers identify feedback as a persistent narrow vertical line on RTA / spectrograph. Smaart does not auto-write console EQ. This mode uses the official RTA/spectrum API for the same kind of sustained-peak ID, then writes notches itself. Sound Design Live’s podium method (transfer function with the mic as the measurement point) is optional later, not v1. |
| SonaVyx Feedback Finder (public) | Spectral peak detection with high-Q preference, suggested freq / Q / depth, focus roughly 100 Hz–8 kHz, several peaks. Typical ring-out suggestions sit around Q 10–30, cuts 3–6 dB, a handful of repeats. Aligns with this mode’s 100 Hz–8 kHz v1 focus, high program Q, −3 dB steps, and ≤8 bands. |
| Community ring-out notes (e.g. Feedback Ferret / Smaart practice) | Stacking deeper cut on the same frequency beats opening a second band beside it; a move of about 30–40 Hz is treated as a new tone. This mode deepens a match within 50 cents (about 29 Hz at 1 kHz) instead of adding a band. |

Design choices locked by that reading:

1. **FIXED only** — no live round-robin, no during-show filter rotation. Show-time chasing stays out of scope.
2. **Detection** — require a sustained **narrow** peak (high effective Q), not merely loud broadband energy.
3. **Frequency focus** — v1 peak picking uses 100 Hz through 8 kHz. Full-band picking is not v1.
4. **Q** — program default for each new notch is **Q = 16.00** (narrow FIXED cut, inside the console’s 0.10–20.00 Q range). Deepening keeps that band’s Q.
5. **Depth and stop** — −3.0 dB per write, deepen by another −3.0 dB on the same frequency down to −18.0 dB, stop the raise at +5.0 dB above first feedback or at 8 bands. Optional manual back-off after the +5 dB stop is operator judgment only.

## Out of scope

- Show-time continuous chasing, LIVE / round-robin filter rotation, timers after the pass ends, or a measure-and-write loop that runs during a performance
- Yamaha PM10 or any console other than the DiGiCo Quantum 225 for this mode’s first version
- Calibration EQ fit, calibration delay write, curve bank, Pick / Delay / EQ / Compare screens, and confirm-before-write (those stay in the calibration spec)
- AI suggestions, model calls, or any non-deterministic step in detection or notch placement
- Screen capture, UI scraping, or screenshot parsing
- Application code in the change that adds this spec

## Mode boundary

| Concern | Calibration | Ring Out |
| --- | --- | --- |
| When | Pre-show / install tune of one Matrix zone | Pre-show mic ring-out of one strip |
| Smaart read | Transfer / magnitude + delay suggestion | RTA / spectrum sustained peaks |
| Console target | One Matrix output per pass | One input channel or one bus per pass |
| Write style | Confirm-before-write | Auto-write notches, with undo |
| EQ purpose | Match a curve-bank preset | Cut feedback peaks with notches |
| Stop | Same mute-all Stop (cross-mode) | Same mute-all Stop (cross-mode) |

The app presents Calibration and Ring Out as separate modes. Opening Ring Out does not unlock calibration steps. Opening Calibration does not run the ring-out loop. Only one mode’s write loop may be active at a time.

## Screen

Ring Out is one page inside the same Auto-Smaart window. It is smaller than Calibration. Calibration keeps Pick / Delay / EQ / Compare. Ring Out does not add those steps, and it does not use a Setup → Running → Notch → Done sequence. The whole pass stays on this page. Visual tokens follow the approved design system used by calibration. This spec owns Ring Out behavior; draft captions that disagree with this spec lose.

The page has four regions:

**Top bar.** Smaart status and **Stop**. Status is `Smaart live` while the official API session is open, an RTA stream is available, and no notice is active. Otherwise the bar shows the notice from the Errors table, including `No RTA` when there is no stream. **Stop** is always available. It mutes all mics and all outputs.

**Left.** A fader showing the current level in dB. The caption is that level to one decimal, or −∞. The fader graphic tracks the same level. It is a readout of the strip the loop is raising. The operator does not drag it. Start fader, first-feedback level, and the +5.0 dB stop level stay in the controller. They are not extra readouts on the page.

**Top right.** The current channel or bus, which is the fader target. A click opens a popup to pick that channel or bus and where the EQ is written. Each pick is one row from Target lists: Input channel, or a Group, Aux, or Matrix bus, plus an index. The two picks may be the same strip or different strips. When they differ, the closed control shows the fader target and the EQ destination. The popup confirm is **Start ring-out**. Confirm stays disabled until the shared console host and OSC port are non-empty and an RTA stream is available, and while the loop is running. **Undo notches** is in that same popup, only while the loop is idle and a notch snapshot exists. Host and OSC port belong to the shared console connection. They are not fields on this page.

**Bottom.** The RTA from 100 Hz to 8 kHz. The trace is the live official-API magnitude for bins in that span. Bins outside the span are not drawn. The trace uses the design-system live color. Each written cut is a mark in a second color, the design-system gold, at that notch’s frequency. A deeper cut on the same frequency stays one mark. There is no notch table on the page.

While the loop is running, the top-right control is locked and the popup cannot change the target or the EQ destination. When the loop is idle, that same popup can return to Calibration. Returning is refused while the loop runs, and until Stop has finished muting.

## Inputs

The app reads Rational Acoustics Smaart through the official API. It opens the local API session. There is no Smaart host field. The app does not screen-capture.

Ring Out uses RTA / spectrum magnitude only. It does not use transfer-function delay finder, impulse peak, phase, or curve-bank presets.

### Sustained peak

A frame is one RTA magnitude vector from the official API, with the API’s own frequencies.

On each frame the app keeps bins from 100 Hz through 8 kHz inclusive (v1 feedback focus). Outside that span is ignored for peak picking. Full-band picking is not part of this version.

For a frame:

1. Let `M` be the median magnitude of the kept bins, in dB.
2. Let the candidate be the kept bin with the greatest magnitude. Ties go to the lower frequency.
3. That candidate is loud enough when its magnitude is at least 10.0 dB above `M`.
4. Around that candidate, take the contiguous run of kept bins whose magnitude is within 3.0 dB of the candidate. Let `f_lo` and `f_hi` be the outer frequencies of that run. If `f_lo` and `f_hi` are the same, the lobe is a single bin and counts as narrow. Otherwise `N = log2(f_hi / f_lo)` and the lobe’s effective Q is `sqrt(2^N) / (2^N − 1)`. The candidate is **narrow** only when it is a single bin or that effective Q is at least 10.0.
5. A **peak frame** requires both loud enough and narrow. Loud broadband energy fails step 4 and is not a peak frame.

A sustained peak is declared when eight consecutive peak frames share the same bin index. The sustained-peak frequency is that bin’s frequency in Hz. The sustained-peak magnitude is the mean of those eight candidate magnitudes.

If the API session is closed, or a read returns no RTA magnitude, there is no peak and the fader must not rise.

## Console

DiGiCo Quantum 225 only, over OSC, using the QLab DiGiCo dictionary. Same console family as calibration.

The shared console connection holds the console IP and the OSC port. Those fields are not on the Ring Out page. Start stays disabled until both are non-empty and an RTA stream is available.

### Target lists

The app does not query the console for channel or bus counts. Fixed local lists:

| Type | Indices |
| --- | --- |
| Input channel | 1 through 72 |
| Group bus | Group Outputs 1 through 24 |
| Aux bus | Aux Outputs 1 through 24 |
| Matrix bus | Matrix Outputs 1 through 12 |

**Bus** in the popup means the operator first picks Group, Aux, or Matrix, then an index from that row. Fader target and EQ destination each use one row from these lists. They may be the same strip or different strips. A common pass raises an input-channel fader and writes notches on that same channel; another pass raises an input-channel fader and writes notches on a Group or Matrix bus.

`<kind>` and `<n>` below are the selected type and index. Address prefixes:

| Type | Prefix |
| --- | --- |
| Input channel | `/sd/Input_Channels/<n>` |
| Group bus | `/sd/Group_Outputs/<n>` |
| Aux bus | `/sd/Aux_Outputs/<n>` |
| Matrix bus | `/sd/Matrix_Outputs/<n>` |

Names are case-sensitive.

### Fader addresses

For the fader target prefix `P`:

- Read and write: `P/fader`

The argument is the QLab DiGiCo dictionary float for that address. The app converts that float to a fader level in dB with the Digico published fader law for Quantum 225 before any comparison. Start level, first-feedback level, the +5.0 dB stop level, and the slow raise step are all in that dB domain. Writing −∞ means writing the dictionary value that Digico documents as fader −∞ for that address. The app never uses the mute button address to stand in for −∞ during the ring-out loop.

### Notch EQ addresses

For the EQ destination prefix `E`, and band `b` from 1 through 8, the only EQ parameters this mode may send are:

- `E/EQ/eq_freq_<b>`
- `E/EQ/eq_gain_<b>`
- `E/EQ/eq_Q_<b>`
- `E/EQ/eq_on_<b>`

A used band is turned on by sending `eq_on_<b>` as `1`. Unused bands are left untouched: no message of any kind.

Ring Out writes peaking notches only. It does not write filter-type, dynamic-EQ, graphic EQ, delay, or any address outside the fader target, the EQ destination bands above, and the Stop mute set below.

### Mute-all addresses (Stop)

**Stop** sends mute on for every strip in the fixed lists:

- `/sd/Input_Channels/<i>/mute` for `i` = 1 through 72
- `/sd/Group_Outputs/<g>/mute` for `g` = 1 through 24
- `/sd/Aux_Outputs/<a>/mute` for `a` = 1 through 24
- `/sd/Matrix_Outputs/<m>/mute` for `m` = 1 through 12
- `/sd/Master_Outputs/1/mute` (LR master)

Each mute argument is `1` (muted). Stop does not unmute. Stop does not clear notches. Order is Input Channels 1→72, then Group 1→24, Aux 1→24, Matrix 1→12, then Master. Within that order the sends are consecutive; the loop does not wait for RTA between mutes.

## Flow

1. The operator clicks the current channel or bus, picks the fader target (channel or bus) and where the EQ is written (channel or bus), and confirms with **Start ring-out**. Host and port are already set on the shared console connection.
2. The app reads the current fader target value and stores it as **start fader**. It does not yet know first feedback.
3. The app slowly raises the fader target: +0.5 dB every 200 ms, writing `P/fader` each step, while reading RTA. It does not raise while RTA is unavailable.
4. On the first sustained peak, the app stores the current fader dB as **first-feedback fader** `F0`, and stores the stop level `F0 + 5.0` dB. It then writes the fader target to −∞ (fader write, not mute).
5. The app writes one notch for that peak on the EQ destination, following Notch rules. The write is automatic; there is no confirm step.
6. After a successful notch write, the app raises the fader again from −∞ using the same +0.5 dB / 200 ms step, looking for the next sustained peak.
7. On each later sustained peak: pull fader to −∞, write or deepen one notch, then raise again.
8. After every successful raise step, if the fader level is at least `F0 + 5.0` dB, the loop stops as complete. If a sustained peak is declared before that level, go to step 7 instead. If a new peak needs a ninth band while 8 bands are already in use, the loop stops on the 8-band limit.

When the +5.0 dB stop fires, the app leaves the fader at the step that crossed `F0 + 5.0` dB, leaves notches as written, and the top bar shows "Ring-out complete (+5 dB)." The page does not change. The operator may then back the fader off slightly by hand for extra safety margin. The app does not auto-back-off.

When the 8-band stop fires, the app leaves the fader at −∞, leaves the 8 notches as written, and the top bar shows "8 bands used before +5 dB headroom." The page does not change.

## Notch rules

Notches are deterministic. The same sustained-peak frequency and the same current notch table always produce the same write.

### New band

When the sustained-peak frequency is not a match for any used band:

- Use the lowest free band index from 1 through 8.
- Frequency is the sustained-peak frequency in Hz, unrounded on the wire. The RTA draws that notch at this frequency. Any frequency text on the mark or on the RTA axis shows hertz rounded half away from zero to 1 Hz below 1000 Hz, and kilohertz to two decimal places at 1000 Hz and above.
- Gain is −3.0 dB.
- Q is **16.00** for every new band. That is the program’s FIXED ring-out default: narrow enough for setup notches, inside the console Q range 0.10 through 20.00. The app does not widen Q to chase broadband energy.
- Send freq, gain, Q, on for that band, in that order. Do not touch other bands.

### Same frequency deepens

A sustained-peak frequency **matches** a used band when the absolute difference in cents is at most 50 (one quarter-tone): `1200 * |log2(f_peak / f_band)| ≤ 50`. If several bands match, pick the closest in cents; ties go to the lower band index.

On a match:

- Do not open a new band.
- Deepen that band’s gain by another −3.0 dB (add −3.0 to the stored gain).
- Frequency and Q stay as already stored for that band.
- Stop deepening when the stored gain would go below −18.0 dB. The floor is −18.0 dB. If a matched band is already at −18.0 dB, leave gain unchanged, leave the fader at −∞, stop the loop, and show that the notch floor was reached on that frequency.

### Band cap

At most 8 bands. A new peak that matches no used band while 8 bands are already used ends the loop under the 8-band stop. Deepening an existing match is still allowed when 8 bands are in use, until the −18.0 dB floor.

### Write sequence for one notch attempt

1. Read the four EQ parameters of every band this attempt will change (new band: none yet on console for that index; deepen: that band’s four parameters).
2. Hold that read as this attempt’s restore copy.
3. Write the new values (freq, gain, Q, on).
4. On full success, merge the written band into the mode’s notch snapshot used for undo.
5. On any write failure, restore only the parameters already written in this attempt, stop the ring-out loop, leave the fader at −∞, and show the OSC failure copy below.

## Undo

Ring Out auto-writes. Undo is how the operator backs out notches.

After at least one successful notch write in the current pass, **Undo notches** is available in the channel/bus popup while the loop is idle. It writes, band for band, the restore snapshot taken before the first notch write of this pass (the destination EQ as it was at Start). Bands that were unused at Start and written during the pass are turned off only by restoring the snapshot values read at Start for those indices; if Start had no read for an unused band, Undo sends nothing for that unused index and the operator clears it on the console.

Undo does not change faders. Undo does not unmute. Undo is disabled while the loop is running.

## Stop safety (cross-mode)

**Stop** is always in the Ring Out top bar. Pressing it mutes all mics and all outputs. The same mute-all behavior is required on the calibration mode screens as a shared safety control. This page does not rename Calibration’s control.

When Stop is pressed in either mode:

1. Cancel the active raise / measure / write loop immediately. No further fader raise steps. No further notch or calibration writes.
2. Send the mute-all sequence defined in Mute-all addresses.
3. Keep every notch or calibration write that already succeeded. Stop does not undo.
4. Show that the system is muted and the mode is idle.

Stop is the emergency path. It prefers mute over tidy state. A mute send failure still ends the loop and shows that mute-all did not fully complete; the operator treats the console as unsafe until checked.

This Ring Out spec records the cross-mode rule. It does not edit the calibration design file in the same change. Calibration implementation must still honor this Stop behavior.

## Errors

| Condition | Result |
| --- | --- |
| No RTA / spectrum from the official API | Do not raise the fader. Show "No RTA". Start stays disabled or the running loop pauses raises until RTA returns; after 2.0 s still without RTA, end the loop, leave the fader where it is, keep notches already written. |
| Stop pressed | Keep notches already written. Mute all mics and all outputs. Loop idle. |
| OSC notch write fails | Restore the attempt’s restore copy for parameters already written. Stop the loop. Fader stays at −∞. Show "Notch write failed. Previous EQ restored." If restore fails: "Notch write failed. Console EQ may not match the previous value." |
| OSC fader raise or −∞ write fails | Stop the loop. Do not write a notch for that step. Show "Fader write failed." |
| 8 bands used before +5.0 dB headroom | Stop the loop. Fader at −∞. Keep the 8 notches. Show "8 bands used before +5 dB headroom." |
| Matched notch already at −18.0 dB floor | Stop the loop. Fader at −∞. Show "Notch floor reached." |
| +5.0 dB above first feedback reached | Stop the loop. Keep notches. Show "Ring-out complete (+5 dB)." |
| OSC host or port empty | Start disabled. No OSC. |
| Mute-all incompletely sent on Stop | Loop idle. Notches kept. Show "Stop: mute-all incomplete. Check the console." |

## Tests

Four test groups are required for Ring Out.

**Fake RTA.** A scripted spectrum source, no console. It must cover:

- eight consecutive narrow peak frames at one bin declare a sustained peak at that frequency
- fewer than eight frames do not declare a sustained peak
- a loud broadband lobe (effective Q below 10.0) is not a peak frame
- no RTA payload means no raise is requested by the controller
- same-frequency match within 50 cents deepens gain by −3.0 dB and leaves Q at 16.00
- a peak more than 50 cents from every used band opens the next free band at −3.0 dB with Q 16.00

**Fake console.** An OSC receiver for this Quantum 225 driver. It must cover:

- Start records a fader read before any raise
- raise steps write only `P/fader`
- on sustained peak, the next fader write is −∞, then only the allowed EQ band messages
- Stop sends mute `1` to every Input Channel 1–72, Group 1–24, Aux 1–24, Matrix 1–12, and Master LR, and sends no further raise after cancel
- a failed notch write is followed by restore of written parameters and no further loop steps

**Stop cases in the controller (fake RTA + fake console).**

- first-feedback at level `F0`, then a clean raise to `F0 + 5.0` with no new peak ends the pass as +5 dB complete
- eight distinct-band writes before that headroom ends the pass as 8-band stop

**One real-hardware pass.** One microphone into one Quantum 225 input, RTA live from Smaart through the official API, notches written to a chosen Matrix (or input) EQ, Stop proven to mute all listed strips. Skipped unless the hardware environment is set.

The Ring Out page is one view for the whole pass. A UI test must show the current-level fader, the channel/bus popup (fader target and EQ destination), the 100 Hz–8 kHz RTA with cut marks in a second color, and top-bar Smaart status and Stop. It must not require Setup, Running, Notch, or Done screens.

## Units that implement this

An implementation plan for this spec splits along these boundaries. Each one can be tested without the others.

| Unit | Does | Depends on |
| --- | --- | --- |
| RTA reader | Official Smaart API session, RTA / spectrum frames, sustained-peak detection | Official Smaart API |
| Fader driver | Read / slow raise / −∞ write for one target strip | Quantum 225 OSC fader address |
| Notch writer | New band, deepen match, floor, restore, undo snapshot | Quantum 225 OSC EQ addresses |
| Ring-out controller | Start, loop, +5 dB and 8-band stops, errors, Stop cancel | The three units above |
| Ring Out page | One page: current-level fader, channel/bus popup, RTA 100 Hz–8 kHz with cut notches in a second color, Smaart status, Stop | Ring-out controller |

The fader driver and notch writer are the only writers during the loop. Stop mute-all may run from the shared safety path used by calibration. The RTA reader does not send OSC. The Ring Out page sends nothing by itself.
