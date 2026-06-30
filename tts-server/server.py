from __future__ import annotations

import shutil
import subprocess
import tempfile
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field


app = FastAPI(title="VirtualCharacterOS Mock TTS Server")


class TTSRequest(BaseModel):
    text: str = Field(min_length=1, max_length=4000)
    voice_id: str = Field(default="default", min_length=1, max_length=80)
    format: str = Field(default="mp3")
    speed: float = Field(default=1.0, ge=0.5, le=2.0)
    style: str = Field(default="natural")
    read_mode: str = Field(default="chat")


def macos_voice_for(voice_id: str) -> str:
    normalized = voice_id.strip().lower()
    mapping = {
        "default": "Tingting",
        "female": "Tingting",
        "male": "Sin-ji",
    }
    return mapping.get(normalized, "Tingting")


def speech_rate_for(speed: float) -> str:
    # macOS say uses words per minute. Keep the range conservative for chat.
    rate = round(175 * speed)
    return str(max(90, min(rate, 260)))


@app.get("/health")
def health() -> dict[str, str]:
    return {
        "status": "ok",
        "engine": "macos-say",
    }


@app.post("/v1/tts")
def tts(request: TTSRequest) -> FileResponse:
    if request.format.lower() != "mp3":
        raise HTTPException(status_code=400, detail="Only mp3 output is supported in the mock server.")

    if shutil.which("say") is None:
        raise HTTPException(status_code=500, detail="macOS say command is not available.")
    if shutil.which("ffmpeg") is None:
        raise HTTPException(status_code=500, detail="ffmpeg is not available on PATH.")

    text = request.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="Text is empty.")

    tmpdir = Path(tempfile.mkdtemp(prefix="vco-tts-"))
    aiff_path = tmpdir / "speech.aiff"
    mp3_path = tmpdir / "speech.mp3"

    try:
        subprocess.run(
            [
                "say",
                "-v",
                macos_voice_for(request.voice_id),
                "-r",
                speech_rate_for(request.speed),
                "-o",
                str(aiff_path),
                text,
            ],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
        )
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-loglevel",
                "error",
                "-i",
                str(aiff_path),
                "-codec:a",
                "libmp3lame",
                "-qscale:a",
                "4",
                str(mp3_path),
            ],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
        )
    except subprocess.CalledProcessError as exc:
        detail = exc.stderr.strip() or "TTS generation failed."
        raise HTTPException(status_code=500, detail=detail) from exc

    return FileResponse(
        path=mp3_path,
        media_type="audio/mpeg",
        filename="speech.mp3",
    )
