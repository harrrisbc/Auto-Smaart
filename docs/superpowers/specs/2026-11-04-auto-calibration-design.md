# Auto-Smaart calibration design

Date: 2026-11-04

Auto-Smaart is a Mac app that calibrates one live-sound zone at a time. The operator uses it for pre-show tuning, and for installed systems that are tuned once and then left alone. This document is the behavior spec for that app. The scope is one implementation plan. It does not add a second product, a second console, or a later phase.

Visual layout and tokens are already approved. This spec owns behavior. If a draft caption disagrees with this spec, follow this spec.

- Design system: https://github.com/harrrisbc/Auto-Smaart/pull/2 (`.superdesign/design-system.md` on that branch)
- Canvas: https://superdesign.dev/teams/f77670ec-41df-47ac-bdbd-f094b1fae47c/projects/a36aa012-7624-4dc3-90d1-a282bfc35ec3?live=1
- Pick: https://p.superdesign.dev/draft/7fe90f16-6e82-40b4-9935-f03666de5f79
- Delay: https://p.superdesign.dev/draft/853a83c9-0044-4384-889b-88b99ab5decb
- EQ: https://p.superdesign.dev/draft/895083de-2195-47d4-9e06-583e16fddf73
- Compare: https://p.superdesign.dev/draft/e0bc6efd-7a4c-4109-9667-bc73fed51fab

Numbers in those drafts (18.6 ms, Matrix 1, three example bands) are sample content. They are not required results.

## Purpose

One pass tunes one zone. A zone is one DiGiCo Quantum 225 Matrix output plus one curve-bank preset. The operator runs the pass, checks the result, and stops. The app does not keep chasing the system during a show, and it does not send a console lock command. "Locked after tuning" describes how an installed system is used after the pass, not a command this app sends.

## Out of scope

- Show-time continuous chasing, timers, or a measure-and-write loop after Compare
- Yamaha PM10 or any console other than the DiGiCo Quantum 225
- More than one Matrix output in one pass
- AI suggestions, model calls, or any non-deterministic step in the read, fit, or write path
- Screen capture, UI scraping, or screenshot parsing
- Application code in the change that adds this spec

## Screens

One window, four steps, in this order: Pick, Delay, EQ, Compare. The step rail shows that order. A future step cannot be opened until this spec says it is unlocked. Back and the step rail send no OSC.

The Pick screen is where the operator sets the console host and port (see Console). The status line follows the design system: Smaart API is live only while the official API session is open; OSC is "OSC armed" only on Delay or EQ when a confirm press is allowed to send; otherwise "OSC idle".

## Inputs

The app reads Rational Acoustics Smaart through the official API. It opens the local API session. There is no Smaart host field.

Each read that returns a magnitude stores that magnitude, in dB at the trace's own frequencies, and the phase at those frequencies. It also stores a delay suggestion when the rule below produces one. A magnitude with no suggestion is kept for Store trace, and it does not unlock Delay.

The app does not screen-capture.

Delay suggestion, in this order:

1. If the official API returns a numeric delay-finder result, use that value. Do not also scan the impulse.
2. If the API does not expose a delay-finder value, and it returns an impulse with a sample rate, the suggestion is the time of the impulse peak. The peak is the earliest sample with the greatest absolute amplitude. Time in milliseconds is `sampleIndex / sampleRate * 1000`.
3. If neither a finder value nor an impulse-with-sample-rate exists, there is no suggestion. Stay on Pick and show "No delay suggestion."

Phase is stored with the trace. The EQ fit does not use phase. Compare does not plot phase.

## Curve bank

One list of presets, stored locally in the app, shared by every pass, still there after relaunch.

A preset is one magnitude curve plus a name and a type:

- **Target** — a target curve read from Smaart through the official API
- **Reference** — a magnitude trace captured from Smaart (the example name in the drafts is Main)

Both types are fit the same way: the post-delay measurement should match that magnitude. Preset phase is ignored.

On Pick:

- The operator selects one preset for the pass. Recall reads that row from the bank and makes it the pass preset. If that row is already the pass preset, Recall changes nothing.
- **Store target** reads Smaart's current target curve through the API and saves it as a Target. If the API returns no target curve, the app shows "No Smaart target curve." and does not add a row.
- **Store trace** saves the latest successful magnitude read as a Reference. If there is no successful read yet, it shows "No Smaart trace." and does not add a row.
- The operator types a name before either store. A blank name is refused. A name already in the list replaces that preset's curve and type. There is no separate delete command.

The pass preset is chosen on Pick and is not changed on later steps of the same pass.

## Console

DiGiCo Quantum 225 only, over OSC, using the QLab DiGiCo dictionary.

The operator types the console IP and the OSC port on Pick. The app does not fill in a default address or port. Confirm stays disabled until both are non-empty.

One Matrix output per pass. A Quantum 225 has 12 Matrix outputs. The Pulse upgrade does not change that count. The Pick list is Matrix 1 through Matrix 12. The app does not query the console for the list. Each row has a local display name stored in the app, initially blank, and the last successful write this app made to that output ("not written" until then). The operator selects exactly one row. The six rows in the Pick draft are sample content, not the list length.

`<n>` below is that selected index.

### EQ addresses

For band `b` from 1 through 8, the only EQ parameters this app may send are:

- `/sd/Matrix_Outputs/<n>/EQ/eq_freq_<b>`
- `/sd/Matrix_Outputs/<n>/EQ/eq_gain_<b>`
- `/sd/Matrix_Outputs/<n>/EQ/eq_Q_<b>`
- `/sd/Matrix_Outputs/<n>/EQ/eq_on_<b>`

Names are case-sensitive. The app writes at most those four values for a band it uses. It does not write filter-type, dynamic-EQ, or any other EQ parameter. It does not write input channels, graphic EQ, or any other output.

A used band is turned on by sending `eq_on_<b>` as `1`. Unused bands are left untouched: no message of any kind, including no zero frequency, no 0 dB, no Q 0, and no off switch.

### Open item: Matrix delay OSC path

The delay write uses the Matrix output delay address in the same QLab DiGiCo dictionary that supplies the EQ addresses above. That exact path is not confirmed in this spec.

Until a confirmed path is recorded here, the app must not guess one. Third-party command lists are not confirmation. While the path is unconfirmed:

- Delay confirm sends no OSC, including no read.
- The Delay screen shows the Smaart suggestion and the words "Matrix delay OSC path".
- EQ stays locked.
- Undo cannot send a delay value.

When the path is confirmed, this spec is updated with the exact address string and the unit. This app sends a delay only if that confirmed parameter is in milliseconds. The value sent is the confirmed suggestion in milliseconds. If the confirmed parameter is in any other unit, the app still must not guess a conversion, and delay writes stay disabled. That limit is part of this same open item, not a second one.

## Flow

1. On Pick, the operator selects one Matrix output and one preset, then presses **Read trace**.
2. The app reads the current Smaart trace. With a magnitude trace and a delay suggestion, Delay unlocks and the app opens it. The suggestion is the Smaart delay from Inputs, not a value derived from the preset. The Delay supporting line says that. It must not say the suggestion came from the target or the reference.
3. Delay shows the suggestion in milliseconds to one decimal place, rounded half away from zero. That rounded value is what a later write sends. If it is below 0.0 ms or above 1300.0 ms, confirm sends nothing, EQ stays locked, and Delay shows "Delay is outside 0.0–1300.0 ms." That bound is the Quantum 225 variable-delay range. Delay also shows the saved delay snapshot for this output, or "No previous value yet". It does not read the console to fill that line. It shows "Nothing is sent until you confirm." The operator presses **Confirm delay write** to accept. **Back** returns to Pick and sends nothing.
4. After a successful delay write, the app remeasures immediately. EQ is calculated only from that new measurement, and only when the remeasure succeeds.
5. EQ shows each used band's frequency, gain, and Q, and an em dash for every unused band through band 8. Before confirm it does not read the console. If an EQ snapshot already exists, the screen labels it "Last undo snapshot"; otherwise it says the previous bands are read on confirm. The operator presses **Confirm EQ write**. Nothing is sent until that press.
6. If that confirm sent one or more EQ messages and the write succeeded, the app remeasures and opens Compare. If the confirm sent no EQ messages (zero bands), it does not remeasure; Compare opens on the post-delay magnitude.

Delay must be confirmed with a successful write before any EQ calculation. There is no skip, even when the suggestion matches the previous value.

Another output is another pass, started again from Pick.

### What a confirm sends

No OSC of any kind is sent before the confirm press. The fake-console test asserts an empty receive buffer up to that press.

A zero-band EQ confirm, an out-of-range delay, and an unconfirmed delay path do not enter this sequence. They send no OSC. A zero-band confirm still opens Compare and does not replace the EQ snapshot.

Every other confirm does this, in order:

1. Read the parameters this confirm will replace.
2. Hold that read as this attempt's restore copy. Do not replace the saved snapshot yet.
3. Write the new values.
4. Mark success only if every read and every write in that confirm is accepted. On success, replace the saved snapshot with the restore copy.

Delay confirm reads and writes only the confirmed Matrix delay parameter. EQ confirm reads and writes only the used bands, four parameters each. It does not read or write unused bands, and it does not read or write delay. Write order is band 1 upward, and within a band: freq, gain, Q, on.

If step 1 fails, the app writes nothing, shows "Write failed. Previous value kept.", and stays on that confirm screen. The saved snapshot is unchanged. The confirm button retries the same action.

If a later write fails, the confirm is not a success. The app writes the restore copy back for every parameter it already wrote in this attempt, and for no other parameter. It does not send zeros to fill gaps. If that restore is accepted, it shows "Write failed. Previous value kept." If the restore is not accepted, it shows "Write failed. Console may not match the previous value." The saved snapshot either way stays unchanged. The operator can retry.

Each output keeps two saved snapshots:

- The delay snapshot is the restore copy from the last successful delay write.
- The EQ snapshot is the restore copy of only the bands written by the last successful EQ write.

Pick's last-write line changes only when Compare opens. The text is `<delay ms> · <count> bands`, or `<delay ms> · no EQ` when no band was written. It records the completed pass. Undo does not change it, and it is not a live console read.

### Undo

- Delay, after a successful delay write, has a quiet **Undo delay** control. It writes the delay snapshot only. It does not write EQ.
- EQ shows the previous bands from the EQ snapshot and does not itself send undo.
- Compare's **Undo last write** writes the delay snapshot and, band for band, the EQ snapshot. Bands absent from the EQ snapshot are not sent.

A control that has no snapshot yet is absent, not filled with zero. If the delay path is unconfirmed, delay undo is not sent. The app never invents a previous value.

## EQ fit

The fit is deterministic. The same measurement and the same preset always produce the same bands. No AI and no randomness are used.

Run the fit on the post-delay remeasure only.

1. Keep measurement bins from 20 Hz through 20 kHz.
2. Interpolate the preset onto those bins. Sort preset points by frequency. At a measurement frequency equal to a preset frequency, use that dB value. Between two preset points, interpolate dB linearly against the natural log of frequency. Drop measurement bins outside the preset's frequency span. Do not extrapolate.
3. If no bins remain, show "Preset does not overlap the trace." on Delay, do not open EQ, and do not write EQ.
4. Deviation is measurement dB minus preset dB.
5. If the greatest absolute deviation is 1.0 dB or less, the result is zero bands.
6. Otherwise place up to 8 peaking bands:

- Choose the bin with the greatest absolute deviation. Ties go to the lower frequency. The same bin may be chosen again after the subtraction below.
- Stop when that absolute deviation is 1.0 dB or less, or 8 bands are placed.
- Gain is the deviation multiplied by −1, clamped to −18.0 dB through +18.0 dB, then rounded half away from zero to 0.1 dB.
- The lobe is the contiguous run of bins around the chosen bin whose absolute deviation is at least half the chosen bin's absolute deviation. Let `f_lo` and `f_hi` be the outer bin frequencies of that run.
- If `f_lo` and `f_hi` are the same, Q is 4.00. Otherwise `N = log2(f_hi / f_lo)` and `Q = sqrt(2^N) / (2^N − 1)`, clamped to 0.10 through 20.00, then rounded half away from zero to 0.01.
- Frequency is that bin's frequency in Hz, unrounded on the wire. The screen shows hertz rounded half away from zero to 1 Hz below 1000 Hz, and kilohertz to two decimal places at 1000 Hz and above.
- Subtract the magnitude of a peaking biquad at 48 kHz from the deviation at every remaining bin, using the rounded gain and Q. This 48 kHz figure is only the fit model. It is not read from the console and is not the impulse sample rate. Use the RBJ peaking coefficients: `A = 10^(gain/40)`, `ω = 2π f / 48000`, `α = sin(ω) / (2Q)`, `b0 = 1 + αA`, `b1 = −2 cos(ω)`, `b2 = 1 − αA`, `a0 = 1 + α/A`, `a1 = −2 cos(ω)`, `a2 = 1 − α/A`. At each bin, subtract `20 log10(|b0 + b1 e^{−iω} + b2 e^{−i2ω}| / |a0 + a1 e^{−iω} + a2 e^{−i2ω}|)`.

Bands occupy indices 1 upward. The model is a peaking bell. The app does not send a filter-type parameter, so the operator leaves those Matrix bands as bells before the pass.

Zero bands means the EQ screen says "No EQ is needed." Every band row is an em dash. **Confirm EQ write** sends no OSC and does not remeasure. Compare opens on the post-delay magnitude, states that no EQ was written, and plots that curve as both before and after.

## Errors

| Condition | Result |
| --- | --- |
| No Smaart trace on Read trace | Stay on Pick. No delay suggestion. No OSC. Show "No Smaart trace." |
| Magnitude with no delay suggestion | Stay on Pick. Show "No delay suggestion." No OSC. Do not calculate EQ. |
| Delay path unconfirmed | Suggestion may be shown. Confirm sends nothing. EQ stays locked. |
| Delay not confirmed | Do not calculate EQ. EQ stays locked. |
| OSC write or pre-write read fails | Not a success. Previous snapshot kept. Stay on the confirm screen. Operator can retry. |
| Remeasure fails after a successful delay write | The delay write stays a success. Do not calculate EQ. Stay on Delay. Show "Could not remeasure." A quiet **Retry remeasure** reads Smaart again and does not write the console. |
| Remeasure fails after a successful EQ write | The EQ write stays a success. Open Compare. Show "Could not remeasure." The before curve is the post-delay magnitude. The after curve is absent. |
| Deviation at or below 1.0 dB | Zero EQ bands. Tell the operator no EQ is needed. Send no EQ OSC. |
| Preset and trace do not overlap | Stay on Delay. No EQ write. Show "Preset does not overlap the trace." |

A failed remeasure never rolls back a write that already succeeded.

## Compare

Compare plots magnitude from 20 Hz to 20 kHz. Before is the post-delay measurement used for the fit (`#a78b71` at 70% opacity in the design system). After is the post-EQ remeasure (`#e8d5b7`), present only when that remeasure succeeded.

The readout shows the previous delay and the written delay, how many bands were written, and how many of the 8 were left empty. When no EQ was written, it says so. There is no confirm button. The only console action on this screen is Undo last write.

## Tests

Three test groups are required. No extra console family is part of the tests.

**Recorded Smaart traces.** Checked-in traces, no console. They must cover:

- a finder value is used even when an impulse is also present
- a missing finder falls back to the earliest maximum-absolute impulse sample
- a trace with neither finder nor impulse produces no suggestion and stays on Pick
- a missing magnitude stays on Pick and produces no suggestion
- EQ matches this fit exactly, including frequency bin, gain to 0.1 dB, and Q to 0.01
- absolute deviation at or below 1.0 dB produces zero bands
- EQ is not calculated when delay has not been confirmed

**Fake console.** An OSC receiver for this Quantum 225 driver, not a second console. It must observe zero messages before confirm. After confirm it must see the read, then only the allowed writes. It must also show a failed write marked as not a success, with the previous snapshot unchanged when the restore succeeds.

**One real-hardware test.** A DiGiCo Quantum 225, one Matrix output, a delay write, then an EQ write of at least one band, then a remeasure. This test runs only after **Matrix delay OSC path** is confirmed in this spec, because the app must not guess the path. It is still part of this plan.

## Units that implement this

An implementation plan for this spec splits along these boundaries. Each one can be tested without the others.

| Unit | Does | Depends on |
| --- | --- | --- |
| Smaart reader | API session, magnitude, phase, finder-then-impulse delay | Official Smaart API |
| Curve bank | One persistent list, store target, store trace, recall | Smaart reader for captures |
| Fit | The deterministic band list above | A magnitude trace and one preset |
| Console | Quantum 225 OSC read and write, silence before confirm | QLab dictionary addresses, operator IP and port |
| Pass UI | Four screens, unlock rules, confirm, undo, errors | The four units above |

The console unit is the only writer. The fit unit does not send OSC. The UI does not invent a delay address.
