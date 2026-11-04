"""Offline mock Smaart spectrum stream for demo and tests."""

from __future__ import annotations

import asyncio
import math
from collections.abc import AsyncIterator

import numpy as np

from auto_smaart.models import SpectrumFrame


def _mock_spectrum_frame(tick: int) -> SpectrumFrame:
    """Synthetic tilt + humps to exercise the solver."""
    freqs = np.logspace(np.log10(31.5), np.log10(16000), 120)
    base = 2.0 * math.sin(tick * 0.05)  # slow drift
    tilt = 3.0 * np.log10(freqs / 1000.0)  # rising HF
    bump = 4.0 * np.exp(-((np.log10(freqs) - np.log10(250.0)) ** 2) / 0.08)
    dip = -3.5 * np.exp(-((np.log10(freqs) - np.log10(4000.0)) ** 2) / 0.05)
    mag = base + tilt + bump + dip
    return SpectrumFrame(
        frequencies_hz=tuple(float(f) for f in freqs),
        magnitude_db=tuple(float(m) for m in mag),
        label=f"mock_tick_{tick}",
    )


async def mock_spectrum_stream(
    *,
    interval_s: float = 0.5,
    max_frames: int | None = 3,
) -> AsyncIterator[SpectrumFrame]:
    """Yield synthetic spectrum frames (async generator)."""
    tick = 0
    while max_frames is None or tick < max_frames:
        yield _mock_spectrum_frame(tick)
        tick += 1
        await asyncio.sleep(interval_s)
