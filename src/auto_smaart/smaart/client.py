"""Async WebSocket client for Smaart JSON API."""

from __future__ import annotations

import json
import logging
from collections.abc import AsyncIterator

import websockets
from websockets.asyncio.client import connect

from auto_smaart.config import SmaartConfig
from auto_smaart.models import SpectrumFrame
from auto_smaart.smaart import protocol
from auto_smaart.smaart.mock import mock_spectrum_stream

logger = logging.getLogger(__name__)


class SmaartClient:
    """
    Connects to Smaart via official JSON WebSocket API.

    When ``use_mock`` is True (or connection fails in demo mode), falls back
    to :func:`mock_spectrum_stream` — never claims unofficial protocol access.
    """

    def __init__(self, config: SmaartConfig) -> None:
        self._config = config

    @property
    def ws_url(self) -> str:
        return f"ws://{self._config.host}:{self._config.port}"

    async def iter_spectrum(
        self,
        *,
        max_frames: int | None = 1,
        mock_on_failure: bool = False,
    ) -> AsyncIterator[SpectrumFrame]:
        if self._config.use_mock:
            async for frame in mock_spectrum_stream(max_frames=max_frames):
                yield frame
            return

        try:
            async for frame in self._live_iter(max_frames=max_frames):
                yield frame
        except (OSError, websockets.exceptions.WebSocketException) as exc:
            if mock_on_failure:
                logger.warning("Smaart connection failed (%s); using mock stream", exc)
                async for frame in mock_spectrum_stream(max_frames=max_frames):
                    yield frame
            else:
                raise

    async def _live_iter(self, *, max_frames: int | None) -> AsyncIterator[SpectrumFrame]:
        subscribe = protocol.build_subscribe_spectrum_request()
        count = 0
        async with connect(self.ws_url, open_timeout=5) as ws:
            await ws.send(json.dumps(subscribe))
            logger.info("Sent subscribe (schema TODO — verify with Rational SDK): %s", subscribe)
            async for raw in ws:
                if isinstance(raw, bytes):
                    raw = raw.decode("utf-8")
                try:
                    payload = json.loads(raw)
                except json.JSONDecodeError:
                    continue
                parsed = protocol.parse_spectrum_response(payload)
                if parsed is None:
                    continue
                freqs, mags = parsed
                yield SpectrumFrame(frequencies_hz=freqs, magnitude_db=mags, label="live")
                count += 1
                if max_frames is not None and count >= max_frames:
                    break

    async def send_command(self, message: dict) -> None:
        """TODO(SDK): Send control commands (generator, delay finder, capture)."""
        if self._config.use_mock:
            logger.info("Mock Smaart: would send %s", message)
            return
        async with connect(self.ws_url, open_timeout=5) as ws:
            await ws.send(json.dumps(message))
