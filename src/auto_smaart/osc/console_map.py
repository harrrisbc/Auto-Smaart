"""Abstract console mapping: logical channels → OSC address patterns."""

from __future__ import annotations

from abc import ABC, abstractmethod

from auto_smaart.config import ChannelMapEntry
from auto_smaart.models import ParametricBand


class ConsoleMap(ABC):
    @abstractmethod
    def eq_band_address(self, channel: ChannelMapEntry, band_index: int, param: str) -> str:
        """param: freq | gain | q"""

    @abstractmethod
    def delay_address(self, channel: ChannelMapEntry) -> str:
        ...


class GenericConsoleMap(ConsoleMap):
    """
    Generic paths for documentation / dry-run:
      {prefix}/eq/{band}/{freq|gain|q}
      {prefix}/delay
    """

    def eq_band_address(self, channel: ChannelMapEntry, band_index: int, param: str) -> str:
        prefix = channel.osc_path_prefix.rstrip("/")
        return f"{prefix}/eq/{band_index}/{param}"

    def delay_address(self, channel: ChannelMapEntry) -> str:
        prefix = channel.osc_path_prefix.rstrip("/")
        return f"{prefix}/delay"


class X32StubConsoleMap(ConsoleMap):
    """
    Example stub for Behringer/Midas X32-style OSC (verify on your firmware).

    TODO: Map to real addresses such as /ch/01/mix/fc, /ch/01/mix/gc, etc.
    This stub keeps readable generic paths but tags messages in dry-run output.
    """

    def eq_band_address(self, channel: ChannelMapEntry, band_index: int, param: str) -> str:
        # Placeholder — replace with documented X/M32 OSC paths per band
        ch = channel.id.replace("main_", "lr").replace("ch", "")
        return f"/stub/x32/{ch}/eq/{band_index}/{param}"

    def delay_address(self, channel: ChannelMapEntry) -> str:
        return f"/stub/x32/{channel.id}/delay"
