"""Command-line entry: mock demo pipeline."""

from __future__ import annotations

import argparse
import asyncio
import logging
import sys
from pathlib import Path

from auto_smaart.config import load_config
from auto_smaart.models import SolverResult
from auto_smaart.osc.writer import build_writer
from auto_smaart.smaart.client import SmaartClient
from auto_smaart.solver.engine import propose_corrections


def _setup_logging(verbose: bool) -> None:
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format="%(levelname)s %(name)s: %(message)s",
    )


def _print_proposals(result: SolverResult) -> None:
    print("\n=== Proposals (review before commit) ===")
    for eq in result.eq:
        print(f"  EQ [{eq.channel_id}]: {eq.rationale}")
        for b in eq.bands:
            print(f"    {b.frequency_hz:.1f} Hz  {b.gain_db:+.2f} dB  Q={b.q:.2f}")
    for d in result.delays:
        print(f"  Delay [{d.channel_id}]: {d.delay_ms:.2f} ms — {d.rationale}")
    print()


async def _run_demo(args: argparse.Namespace) -> int:
    config_path = Path(args.config) if args.config else None
    cfg = load_config(config_path)

    if args.mock:
        cfg.smaart.use_mock = True

    client = SmaartClient(cfg.smaart)
    writer = build_writer(cfg)

    channel_ids = [c.id for c in cfg.channels] or ["main"]

    async for frame in client.iter_spectrum(
        max_frames=args.frames,
        mock_on_failure=args.mock_fallback,
    ):
        print(f"Frame: {frame.label} ({len(frame.frequencies_hz)} bins)")
        result = propose_corrections(
            frame,
            solver=cfg.solver,
            safety=cfg.safety,
            channel_ids=channel_ids,
        )
        _print_proposals(result)

        commit = args.commit and not cfg.safety.dry_run
        if args.commit and cfg.safety.dry_run:
            print(
                "Note: --commit ignored while safety.dry_run is true "
                "(set safety.dry_run: false in config to allow OSC send).\n"
            )
        report = writer.apply_proposals(result, commit=args.commit)
        for line in report.messages:
            print(line)
        if report.committed:
            print("\nCommitted OSC messages to", f"{cfg.osc.host}:{cfg.osc.port}")
        elif args.commit:
            print("\nNo OSC sent (dry-run mode).")
        else:
            print("\nDry-run / suggest-only (pass --commit to attempt apply).")

    return 0


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(
        prog="auto-smaart",
        description="Smaart → solver → OSC (suggest-then-commit)",
    )
    parser.add_argument(
        "command",
        nargs="?",
        default="demo",
        choices=["demo"],
        help="demo: mock or live spectrum → proposals → OSC dry-run",
    )
    parser.add_argument(
        "-c",
        "--config",
        help="Path to config YAML (default: config.yaml or AUTO_SMAART_CONFIG)",
    )
    parser.add_argument(
        "--mock",
        action="store_true",
        help="Use fake Smaart spectrum (no WebSocket)",
    )
    parser.add_argument(
        "--mock-fallback",
        action="store_true",
        help="If live Smaart fails, fall back to mock stream",
    )
    parser.add_argument(
        "--frames",
        type=int,
        default=1,
        help="Number of spectrum frames to process",
    )
    parser.add_argument(
        "--commit",
        action="store_true",
        help="Attempt to apply proposals (still gated by safety.dry_run)",
    )
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args(argv)
    _setup_logging(args.verbose)

    if args.command == "demo":
        raise SystemExit(asyncio.run(_run_demo(args)))
    raise SystemExit(f"Unknown command: {args.command}")


if __name__ == "__main__":
    main()
