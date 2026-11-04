"""Shared data models for spectra, proposals, and apply results."""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum


class ProposalKind(str, Enum):
    EQ = "eq"
    DELAY = "delay"


@dataclass(frozen=True)
class SpectrumFrame:
    """One live spectrum or transfer-function magnitude slice."""

    frequencies_hz: tuple[float, ...]
    magnitude_db: tuple[float, ...]
    label: str = "live"


@dataclass(frozen=True)
class ParametricBand:
    frequency_hz: float
    gain_db: float
    q: float


@dataclass(frozen=True)
class EqProposal:
    channel_id: str
    bands: tuple[ParametricBand, ...]
    rationale: str = ""


@dataclass(frozen=True)
class DelayProposal:
    channel_id: str
    delay_ms: float
    rationale: str = ""


@dataclass
class SolverResult:
    eq: list[EqProposal] = field(default_factory=list)
    delays: list[DelayProposal] = field(default_factory=list)


@dataclass
class ApplyReport:
    dry_run: bool
    messages: list[str] = field(default_factory=list)
    committed: bool = False
