import pytest

from auto_smaart.smaart.mock import mock_spectrum_stream


@pytest.mark.asyncio
async def test_mock_stream_yields_frames():
    frames = []
    async for f in mock_spectrum_stream(max_frames=2, interval_s=0):
        frames.append(f)
    assert len(frames) == 2
    assert len(frames[0].frequencies_hz) > 50
