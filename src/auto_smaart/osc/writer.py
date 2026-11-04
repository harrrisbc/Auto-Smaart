"""OSC writer with dry-run default and safety clamping."""

from __future__ import annotations

import logging

from pythonosc import udp_client

from auto_smaart.config import AppConfig, ChannelMapEntry, OscConfig, SafetyConfig
from auto_smaart.models import ApplyReport, DelayProposal, EqProposal, SolverResult
from auto_smaart.osc.console_map import ConsoleMap, GenericConsoleMap, X32StubConsoleMap

logger = logging.getLogger(__name__)


def build_writer(config: AppConfig) -> "OscConsoleWriter":
    if config.osc.console == "x32_stub":
        console_map: ConsoleMap = X32StubConsoleMap()
    else:
        console_map = GenericConsoleMap()
    return OscConsoleWriter(
        osc=config.osc,
        safety=config.safety,
        channels=config.channels,
        console_map=console_map,
    )


class OscConsoleWriter:
    def __init__(
        self,
        *,
        osc: OscConfig,
        safety: SafetyConfig,
        channels: list[ChannelMapEntry],
        console_map: ConsoleMap,
    ) -> None:
        self._osc = osc
        self._safety = safety
        self._channels = {c.id: c for c in channels}
        self._map = console_map
        self._client: udp_client.SimpleUDPClient | None = None

    def _udp(self) -> udp_client.SimpleUDPClient:
        if self._client is None:
            self._client = udp_client.SimpleUDPClient(self._osc.host, self._osc.port)
        return self._client

    def _channel(self, channel_id: str) -> ChannelMapEntry:
        if channel_id in self._channels:
            return self._channels[channel_id]
        return ChannelMapEntry(id=channel_id)

    def _clamp_delay(self, delay_ms: float) -> float:
        return min(max(0.0, delay_ms), self._safety.max_delay_ms)

    def apply_proposals(
        self,
        result: SolverResult,
        *,
        commit: bool = False,
    ) -> ApplyReport:
        """
        Apply EQ/delay to console.

        ``commit=True`` sends UDP OSC only when ``safety.dry_run`` is False.
        Default path logs proposed messages without sending.
        """
        dry_run = self._safety.dry_run or not commit
        report = ApplyReport(dry_run=dry_run, committed=False)
        msgs: list[tuple[str, float | str]] = []

        for eq in result.eq:
            ch = self._channel(eq.channel_id)
            for i, band in enumerate(eq.bands):
                band_idx = (
                    ch.eq_band_indices[i]
                    if i < len(ch.eq_band_indices)
                    else i + 1
                )
                msgs.append((self._map.eq_band_address(ch, band_idx, "freq"), band.frequency_hz))
                msgs.append((self._map.eq_band_address(ch, band_idx, "gain"), band.gain_db))
                msgs.append((self._map.eq_band_address(ch, band_idx, "q"), band.q))

        for d in result.delays:
            ch = self._channel(d.channel_id)
            delay = self._clamp_delay(d.delay_ms)
            msgs.append((self._map.delay_address(ch), delay))

        for addr, val in msgs:
            line = f"OSC {'[dry-run]' if dry_run else '[SEND]'} {addr} {val}"
            report.messages.append(line)
            logger.info(line)

        if not dry_run:
            client = self._udp()
            for addr, val in msgs:
                if isinstance(val, str):
                    client.send_message(addr, val)
                else:
                    client.send_message(addr, float(val))
            report.committed = True
            report.dry_run = False

        return report
