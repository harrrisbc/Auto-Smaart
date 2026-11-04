"""Configuration loading: YAML file + AUTO_SMAART_* environment overrides."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Literal

import yaml
from pydantic import BaseModel, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class SmaartConfig(BaseModel):
    host: str = "127.0.0.1"
    port: int = 26000
    use_mock: bool = False


class OscConfig(BaseModel):
    host: str = "127.0.0.1"
    port: int = 10023
    console: Literal["generic", "x32_stub"] = "generic"


class SafetyConfig(BaseModel):
    dry_run: bool = True
    max_eq_boost_db: float = Field(default=6.0, ge=0)
    max_eq_cut_db: float = Field(default=12.0, ge=0)
    max_delay_ms: float = Field(default=500.0, ge=0)


class SolverConfig(BaseModel):
    target_curve: Literal["flat"] = "flat"
    max_bands: int = Field(default=4, ge=1, le=16)
    band_q_default: float = Field(default=2.0, gt=0)


class ChannelMapEntry(BaseModel):
    id: str
    osc_path_prefix: str = "/ch/01/mix"
    eq_band_indices: list[int] = Field(default_factory=lambda: [1, 2, 3, 4])


class AppConfig(BaseModel):
    smaart: SmaartConfig = Field(default_factory=SmaartConfig)
    osc: OscConfig = Field(default_factory=OscConfig)
    safety: SafetyConfig = Field(default_factory=SafetyConfig)
    solver: SolverConfig = Field(default_factory=SolverConfig)
    channels: list[ChannelMapEntry] = Field(default_factory=list)


class EnvOverrides(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="AUTO_SMAART_", env_nested_delimiter="__")

    smaart__host: str | None = None
    smaart__port: int | None = None
    osc__host: str | None = None
    osc__port: int | None = None
    safety__dry_run: bool | None = None


def _deep_merge_dict(base: dict, override: dict) -> dict:
    out = dict(base)
    for key, val in override.items():
        if key in out and isinstance(out[key], dict) and isinstance(val, dict):
            out[key] = _deep_merge_dict(out[key], val)
        elif val is not None:
            out[key] = val
    return out


def load_config(path: Path | None = None) -> AppConfig:
    """Load config from YAML (default config.yaml) and apply env overrides."""
    cfg_path = path or Path(os.environ.get("AUTO_SMAART_CONFIG", "config.yaml"))
    data: dict = {}
    if cfg_path.is_file():
        with cfg_path.open() as f:
            loaded = yaml.safe_load(f) or {}
            if not isinstance(loaded, dict):
                raise ValueError(f"Config root must be a mapping: {cfg_path}")
            data = loaded

    env = EnvOverrides()
    env_dict: dict = {}
    if env.smaart__host is not None:
        env_dict.setdefault("smaart", {})["host"] = env.smaart__host
    if env.smaart__port is not None:
        env_dict.setdefault("smaart", {})["port"] = env.smaart__port
    if env.osc__host is not None:
        env_dict.setdefault("osc", {})["host"] = env.osc__host
    if env.osc__port is not None:
        env_dict.setdefault("osc", {})["port"] = env.osc__port
    if env.safety__dry_run is not None:
        env_dict.setdefault("safety", {})["dry_run"] = env.safety__dry_run

    merged = _deep_merge_dict(data, env_dict)
    return AppConfig.model_validate(merged)
