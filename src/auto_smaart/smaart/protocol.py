"""
Documented Smaart API message patterns (placeholders).

Rational Acoustics provides a free SDK on request with exact JSON schemas for
Smaart v8/v9 WebSocket control and live data. This module centralizes TODOs
so implementation can be filled from SDK docs without reverse-engineering the UI.

Reference pattern (illustrative only — verify against your SDK):
  - Connect: ws://host:26000 (default port may vary by install)
  - Requests/responses are JSON objects with type/command fields

See: https://www.rationalacoustics.com/ (contact for SMAART API SDK)
"""

from __future__ import annotations

from typing import Any


def build_subscribe_spectrum_request(measurement_id: str | None = None) -> dict[str, Any]:
    """
    TODO(SDK): Replace with exact subscribe message from Rational SDK docs.
    """
    return {
        "type": "request",
        "command": "SubscribeSpectrum",  # placeholder name
        "measurementId": measurement_id or "default",
    }


def build_generator_on_request(enabled: bool) -> dict[str, Any]:
    """TODO(SDK): Generator control when API exposes it."""
    return {
        "type": "request",
        "command": "SetGeneratorState",
        "enabled": enabled,
    }


def build_delay_finder_start() -> dict[str, Any]:
    """TODO(SDK): Delay finder capture/start when API exposes it."""
    return {
        "type": "request",
        "command": "StartDelayFinder",
    }


def parse_spectrum_response(payload: dict[str, Any]) -> tuple[tuple[float, ...], tuple[float, ...]] | None:
    """
    TODO(SDK): Parse live spectrum / transfer function magnitude from API payload.

    Expected eventual shape (example):
      { "frequencies": [...], "magnitudeDb": [...] }
    """
    freqs = payload.get("frequencies") or payload.get("freqHz")
    mags = payload.get("magnitudeDb") or payload.get("magnitude_db")
    if not freqs or not mags or len(freqs) != len(mags):
        return None
    return tuple(float(f) for f in freqs), tuple(float(m) for m in mags)
