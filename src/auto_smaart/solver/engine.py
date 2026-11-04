"""Heuristic parametric EQ + delay proposals vs a flat target (v0)."""

from __future__ import annotations

import numpy as np

from auto_smaart.config import SafetyConfig, SolverConfig
from auto_smaart.models import (
    DelayProposal,
    EqProposal,
    ParametricBand,
    SolverResult,
    SpectrumFrame,
)


def _clamp_gain(gain_db: float, safety: SafetyConfig) -> float:
    return float(np.clip(gain_db, -safety.max_eq_cut_db, safety.max_eq_boost_db))


def propose_corrections(
    frame: SpectrumFrame,
    *,
    solver: SolverConfig,
    safety: SafetyConfig,
    channel_ids: list[str],
) -> SolverResult:
    """
    Suggest corrections only — caller must commit via OSC writer explicitly.

    v0: estimate broadband delay from phase proxy (not available in mock mag-only
    data); use fixed 0 ms delay proposal with note. EQ: pick worst deviations in
    log-spaced bands up to max_bands.
    """
    freqs = np.array(frame.frequencies_hz)
    mags = np.array(frame.magnitude_db)
    if solver.target_curve == "flat":
        error = mags  # target 0 dB relative
    else:
        error = mags

    # Coarse band centers (1 octave-ish steps in log domain)
    band_edges = np.logspace(np.log10(freqs.min()), np.log10(freqs.max()), solver.max_bands + 1)
    bands: list[ParametricBand] = []
    for i in range(solver.max_bands):
        f_lo, f_hi = band_edges[i], band_edges[i + 1]
        mask = (freqs >= f_lo) & (freqs < f_hi)
        if not np.any(mask):
            continue
        mean_err = float(np.mean(error[mask]))
        center = float(np.sqrt(f_lo * f_hi))
        gain = _clamp_gain(-mean_err, safety)
        if abs(gain) < 0.3:
            continue
        bands.append(
            ParametricBand(
                frequency_hz=center,
                gain_db=gain,
                q=solver.band_q_default,
            )
        )

    result = SolverResult()
    for cid in channel_ids or ["main"]:
        result.eq.append(
            EqProposal(
                channel_id=cid,
                bands=tuple(bands[: solver.max_bands]),
                rationale=f"Mean deviation correction from {frame.label}",
            )
        )
        # TODO(SDK): derive delay_ms from Smaart delay finder / phase TF when available
        result.delays.append(
            DelayProposal(
                channel_id=cid,
                delay_ms=0.0,
                rationale="Phase/delay from TF not wired in v0 mock (mag-only)",
            )
        )
    return result
