# Auto-Smaart design system

Visual source: Superdesign library prompt `neural-noir-interface-style` (Neural Noir). Tokens below are that style, adapted to a dense macOS live-sound tool. This is not a marketing site. Do not use the library prompt's landing-page hero, pricing, team, footer, satellite cards, or neural bezier decoration.

## Product

Auto-Smaart is a Mac app for tuning a live-sound system before a show, and for installed systems that get locked after tuning.

- Reads Smaart through the official API: magnitude, phase, and delay. No screen capture.
- Writes one DiGiCo Quantum 225 Matrix output at a time over OSC. QLab-style addresses the user named: `/sd/Matrix_Outputs/<n>/EQ/eq_freq_1` through `eq_freq_8`, and `eq_gain_1` through `eq_gain_8`, plus the matching delay address for that same output.
- Up to 8 EQ bands. Unused bands stay empty. Never fill all 8 with placeholder zeros.
- Flow: pick one Matrix output and one curve-bank preset, read the trace, suggest delay, user confirms, OSC write, remeasure, suggest EQ (frequency, gain, Q), user confirms, OSC write, remeasure, before/after magnitude compare.
- Curve bank stores Smaart target curves and captured reference traces (example name: Main). User can store and recall.
- Calculation is deterministic. Do not present suggestions as AI.
- Nothing is written to the console until the user confirms. Previous values stay available for undo.

## Screens (one app, four steps)

Same window chrome on every screen. A left step rail marks the current step. Content changes; the shell does not.

1. Pick — choose one Matrix output and one curve preset, then read the trace.
2. Delay — show the suggested delay against the current console value. Confirm writes. Undo remembers the previous value.
3. EQ — show only the bands in use (0–8). Empty rows stay blank. Confirm writes. Undo remembers the previous bands.
4. Compare — after the confirmed write and remeasure, overlay before and after magnitude.

## Window

- One macOS app window, 1440×900. Traffic-light buttons, title “Auto-Smaart”, subtitle “Quantum 225”.
- No browser chrome, no website nav, no hero, no pricing, no marketing footer, no giant display headline.
- Regions: 56px title bar, 220px left step rail, remaining canvas, 64px bottom action bar.
- Left rail steps, in order: Pick, Delay, EQ, Compare. Current step uses a gold 2px left bar and light-gold label. Future steps are dim. Completed steps show a small gold check.
- Bottom bar is the only place for the primary action. Primary action is a white pill, black text. Destructive or “do not write” state is a quiet text line, not a second hero button.

## Color

Use only these colors.

- App background: `#0a0a0a`
- Raised surface: `rgba(255,255,255,0.03)` with `backdrop-filter: blur(10px)` and `1px solid rgba(255,255,255,0.1)`
- Primary text: `#ffffff`
- Secondary text: `#a3a3a3` (gray-400)
- Dim text: `rgba(255,255,255,0.45)`
- Gold: `#a78b71`
- Light gold: `#c9b8a0`
- Hover gold: `#e8d5b7`
- Live connection dot only: `#4ade80` (the style’s live pill). Do not use green for traces, buttons, or EQ.
- Do not use blue, purple, neon, cream pages, or rainbow gradients.

Plot colors, still inside the gold spectrum:

- After / suggested trace: `#e8d5b7`
- Before / reference trace: `#a78b71` at 70% opacity
- Axis and grid: `rgba(255,255,255,0.12)`
- Selected row: `rgba(167,139,113,0.16)` with a `#a78b71` 2px left edge

## Type

- Wordmark only: Playfair Display, italic, 18px, white. Nowhere else.
- All UI, labels, and numbers: Inter 300–700.
- Numbers that are Hz, dB, ms, or Q: Inter 500, `font-variant-numeric: tabular-nums`.
- Section titles: Inter 600, 18px, white. Not serif. Not larger than 22px.
- Body: Inter 400, 13px, gray-400.
- Labels: Inter 500, 11px, uppercase, letter-spacing 0.08em, light gold.
- Do not introduce any other font.

## Density and components

- Base unit 4px. Row height 36px. Page padding 20px. Gap between groups 16px.
- Cards, when a group needs a boundary: radius 12px, glass surface above. Do not use 24–48px radii on data tables.
- Pills (status, primary button): fully rounded.
- Tables are the default for Matrix outputs, curve presets, and EQ bands. One selected row. No card grid of features.
- Empty EQ bands: em dash in freq, gain, and Q. Do not show 0 Hz, 0 dB, or Q 0.
- Status line in the title bar: “Smaart API” with the green live dot when connected, and “OSC idle” or “OSC armed” in gray. OSC armed only on confirm screens, before the write.
- Copy tone: short, technical, calm. Example: “Nothing is sent until you confirm.” No slogans, no “unlock your mix”, no AI wording.
- Motion: color and border transitions 160ms `cubic-bezier(0.4, 0, 0.2, 1)`. No entrance reveals, no pulsing network lines, no floating satellite cards. The live dot may pulse.

## Screen content

### 1. Pick Matrix output and curve preset

Title: “Pick output”. Supporting line: “One Matrix output. One curve. The console is not written on this step.”

Two tables side by side.

Matrix outputs (single select). Rows:

| Output | Name | Last write |
| --- | --- | --- |
| Matrix 1 | Main | not written |
| Matrix 2 | Sub | 14.2 ms · 3 bands |
| Matrix 3 | Front fill | not written |
| Matrix 4 | Delay | 42.0 ms · 2 bands |
| Matrix 5 | Side | not written |
| Matrix 6 | — | not written |

Matrix 1 is selected.

Curve bank (single select). A type chip says Target or Reference.

| Preset | Type | Source |
| --- | --- | --- |
| Main target | Target | Smaart target |
| Main | Reference | Captured trace |
| Sub target | Target | Smaart target |
| Front fill | Reference | Captured trace |

Main target is selected. Text buttons under the table: “Store trace” and “Recall”. Recall is quiet because Main target is already the active preset.

Bottom bar primary: “Read trace”. Left of it: “Matrix 1 · Main target”.

### 2. Delay suggestion with confirm

Title: “Delay”. Supporting line: “Suggested from the Main target. Deterministic. Not sent yet.”

Left: a compact magnitude plot, log frequency, gold suggested alignment marker, axis labels only. Caption: “Smaart delay read”.

Right, a confirmation sheet, not a hero:

- Suggested delay: 18.6 ms
- On console now: 0.0 ms
- Will write: 18.6 ms
- Undo memory: previous 0.0 ms
- Target line in monospace, 12px: matching delay address for Matrix 1
- Warning line: “Nothing is sent until you confirm.”

Bottom bar primary: “Confirm delay write”. Secondary text button: “Back”. Do not show a success state. The write has not happened.

### 3. EQ bands with confirm

Title: “EQ”. Supporting line: “After delay write and remeasure. 3 of 8 bands used. Unused bands stay empty.”

Table columns: Band, Frequency, Gain, Q, OSC.

Used rows:

| Band | Frequency | Gain | Q | OSC |
| --- | --- | --- | --- | --- |
| 1 | 80 Hz | +2.5 dB | 1.4 | eq_freq_1 · eq_gain_1 |
| 2 | 250 Hz | −3.0 dB | 2.0 | eq_freq_2 · eq_gain_2 |
| 3 | 3.15 kHz | −1.5 dB | 4.0 | eq_freq_3 · eq_gain_3 |

Bands 4–8: band number visible, every other cell an em dash, row dimmed. Do not invent frequencies for them.

Side note: “Undo keeps the previous EQ on Matrix 1: all bands empty.” Address prefix in monospace: `/sd/Matrix_Outputs/1/EQ/`.

Bottom bar primary: “Confirm EQ write”. Line above the button: “Nothing is sent until you confirm.”

### 4. Before / after magnitude

Title: “Compare”. Supporting line: “Matrix 1 written. Delay 18.6 ms. EQ bands 1–3. This is the remeasure.”

One large magnitude plot. Log frequency from 20 Hz to 20 kHz. Vertical axis dB. Two traces: Before `#a78b71`, After `#e8d5b7`. Legend sits on the plot, not in a marketing card.

A slim readout under the plot:

- Before delay 0.0 ms → after 18.6 ms
- Bands written: 3. Bands left empty: 5
- Undo: restore previous delay and previous EQ

No confirm button. The write already happened. Bottom bar primary is absent. Quiet button: “Undo last write”.

## Fidelity

Use only the fonts, colors, spacing, and component styles in this file. Do not add fonts, colors, gradients, illustrations, or visual styles that are not defined here. Do not turn any screen into a landing page.
