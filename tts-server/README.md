# VirtualCharacterOS Mock TTS Server

This is a local development TTS server for testing the iOS voice-message UI before integrating F5-TTS or OpenVoice.

It uses macOS `say` to synthesize speech and `ffmpeg` to convert the result to mp3.

## Install

```bash
cd tts-server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

`say` is included with macOS. `ffmpeg` must be available on `PATH`.

## Run

```bash
cd tts-server
source .venv/bin/activate
uvicorn server:app --host 127.0.0.1 --port 8000
```

Then configure the iOS app:

- Enable `语音消息`
- `TTS Server URL`: `http://127.0.0.1:8000`
- `Voice ID`: `default`

The app automatically calls:

```text
POST http://127.0.0.1:8000/v1/tts
```

## Test

```bash
curl -X POST http://127.0.0.1:8000/v1/tts \
  -H 'Content-Type: application/json' \
  -o sample.mp3 \
  -d '{"text":"你好，这是本地语音测试。","voice_id":"default","format":"mp3","speed":1.0,"style":"natural","read_mode":"chat"}'
```

## Voice IDs

Current mock voice IDs:

- `default`
- `female`
- `male`

They map to installed macOS voices when available, with safe fallbacks.

## Limits

This is not voice cloning. It only verifies the app playback loop:

- voice-message UI
- local TTS request protocol
- mp3 response playback
- transcript display
- audio cache behavior

F5-TTS or OpenVoice should replace this server behind the same `/v1/tts` API later.
