from auto_smaart.config import AppConfig, SafetyConfig, SolverConfig
from auto_smaart.models import SpectrumFrame
from auto_smaart.osc.writer import build_writer
from auto_smaart.solver.engine import propose_corrections


def test_propose_corrections_returns_bands():
    frame = SpectrumFrame(
        frequencies_hz=(100.0, 1000.0, 10000.0),
        magnitude_db=(6.0, 0.0, -6.0),
    )
    result = propose_corrections(
        frame,
        solver=SolverConfig(max_bands=2),
        safety=SafetyConfig(),
        channel_ids=["main_l"],
    )
    assert len(result.eq) == 1
    assert len(result.eq[0].bands) >= 1


def test_osc_dry_run_default():
    cfg = AppConfig()
    cfg.channels = []
    writer = build_writer(cfg)
    frame = SpectrumFrame(frequencies_hz=(1000.0,), magnitude_db=(3.0,))
    result = propose_corrections(
        frame,
        solver=cfg.solver,
        safety=cfg.safety,
        channel_ids=["main"],
    )
    report = writer.apply_proposals(result, commit=True)
    assert report.dry_run is True
    assert report.committed is False
    assert any("[dry-run]" in m for m in report.messages)
