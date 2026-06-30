# Voice TTS Local Server v0

This spec defines the first voice path for VirtualCharacterOS.

## Decision

Use a local/private TTS server first, not on-device TTS and not cloud-only TTS.

Recommended v0 stack:

- Primary quality POC: F5-TTS local server.
- License-safer fallback: OpenVoice local server.
- iOS integration: `LocalServerVoiceProvider` over HTTPS.
- App playback: download/stream audio, cache by text + voice profile, play with `AVPlayer`.

Reason:

- The product goal is not basic text reading. It needs a recognizable virtual-character voice.
- Advanced voice cloning is too heavy for direct iPhone inference in v0.
- Keeping TTS behind a local/private server avoids shipping model weights inside the iOS app.
- A provider boundary lets the app later switch to ElevenLabs, Cartesia, Azure, Fish-Speech, or on-device TTS.

## Scope

This is a post-MVP0 feature spec. Current `MVP_SCOPE.md` says MVP0 does not implement voice, backend, or local model inference. Therefore this document is a design handoff, not an implementation of voice playback.

In scope for the future implementation:

- Add app-side voice provider protocol.
- Add local-server TTS provider.
- Add per-character voice profile configuration.
- Play assistant speech after text delivery.
- Cache generated audio locally.
- Support cloned voices through server-side `voiceId`.

Out of scope for v0:

- No direct iOS model inference.
- No microphone input.
- No realtime phone-call mode.
- No voice clone upload UI in the first app patch.
- No automatic cloning of public figures or unconsented real people.
- No storage of raw voice samples in the iOS app.
- No changes to ChatMessage schema in the first patch.

## Product Behavior

Default:

- Voice playback is off by default.
- User can enable voice in settings.
- Assistant text is displayed first; audio playback follows.
- If audio generation fails, the text message remains unaffected.

Narration handling:

- v0 default: read chat text only, do not read narration blocks.
- Setting option later: chat only / narration only / chat plus narration.
- Detailed narration mode may produce long narration, so narration audio must be explicitly enabled.

Character voice:

- Each character can have one active `VoiceProfile`.
- The voice profile points to a provider and a server-side `voiceId`.
- The app does not need to know how the voice was cloned.

## Architecture

```text
ChatViewModel
  -> assistant final text chunks
  -> VoicePlaybackCoordinator
      -> VoiceTextExtractor
      -> VoiceProvider
          -> LocalServerVoiceProvider
              -> POST /v1/tts
      -> AudioCache
      -> AVPlayer
```

Key rule:

- Voice must consume final visible assistant output.
- Voice must not call ContextBuilder.
- Voice must not call the LLM provider.
- Voice must not change message persistence.
- Voice failure must not block chat.

## iOS Types

Planned files:

- `Core/Voice/VoiceProfile.swift`
- `Core/Voice/VoiceProvider.swift`
- `Core/Voice/LocalServerVoiceProvider.swift`
- `Core/Voice/VoicePlaybackCoordinator.swift`
- `Core/Voice/VoiceTextExtractor.swift`
- `Core/Voice/AudioCache.swift`
- Settings UI additions in `ProviderSettingsView.swift`
- Settings state in `ProviderSettingsViewModel.swift`

Suggested model:

```swift
struct VoiceProfile: Codable, Equatable, Sendable {
    enum Provider: String, Codable, Sendable {
        case localServer
        case openVoice
        case f5TTS
        case cloud
    }

    var isEnabled: Bool
    var provider: Provider
    var serverBaseURL: URL?
    var voiceId: String
    var speed: Double
    var readsNarration: Bool
}
```

Storage:

- Use UserDefaults only for non-secret settings:
  - voice enabled
  - local server base URL
  - voiceId
  - speed
  - read narration toggle
- Do not store API keys for local server v0.
- If a remote/cloud TTS provider is added later, its API key must use Keychain.

## Local Server API

The iOS app should integrate with a stable local protocol, not a specific model API.

Endpoint:

```http
POST /v1/tts
Content-Type: application/json
Accept: audio/mpeg
```

Request:

```json
{
  "text": "还行，刚刚才慢下来一点",
  "voice_id": "linxiao_f5_v1",
  "format": "mp3",
  "speed": 1.0,
  "style": "natural",
  "read_mode": "chat"
}
```

Response:

- Preferred: raw audio bytes with `Content-Type: audio/mpeg`.
- Alternative: JSON with `audio_base64`, only if raw bytes are inconvenient.

Server responsibilities:

- Map `voice_id` to F5-TTS or OpenVoice assets.
- Own clone sample storage and consent records.
- Normalize audio loudness.
- Return stable errors without exposing model internals.

## Provider Choice

### F5-TTS first POC

Use when the goal is maximum naturalness and clone quality.

Pros:

- Strong zero-shot voice cloning quality.
- Good fit for expressive virtual-character voices.
- Useful for local/private server experiments.

Risks:

- Model licensing must be checked before commercial distribution.
- Server GPU/CPU requirements may be higher.
- More operational complexity than a hosted provider.

### OpenVoice fallback

Use when license simplicity and controllable deployment matter more.

Pros:

- More license-friendly for early product exploration.
- Voice cloning and style transfer are mature enough for a POC.
- Can run behind the same `/v1/tts` adapter.

Risks:

- Voice naturalness may be weaker than F5-TTS in some Chinese scenarios.
- Still needs careful evaluation with real character samples.

## Safety And Consent

Hard rules:

- Do not clone public figures, celebrities, streamers, teachers, classmates, or acquaintances without explicit permission.
- Do not present generated voice as the real person speaking.
- The app must keep the virtual-character boundary clear.
- Voice clone deletion must be supported on the server side.
- Do not use voice for identity verification.

Consent flow for future clone UI:

1. User confirms they own or are authorized to use the voice sample.
2. User records or uploads sample.
3. Server creates clone and returns `voiceId`.
4. App stores only `voiceId` and provider settings.
5. User can remove the voice profile.

## Caching

Cache key:

```text
provider + voiceId + speed + readMode + sha256(text)
```

Rules:

- Cache generated audio under app sandbox cache directory.
- Do not cache failed responses.
- Do not persist raw intermediate prompt or hidden system text.
- If text changes, regenerate audio.
- If voice profile changes, invalidate cache by key naturally.

## Implementation Plan

Task Voice 0.1: Scope update and spec acceptance

- Update `MVP_SCOPE.md` or create a new post-MVP task entry that allows voice work.
- Confirm local server route.
- Confirm F5-TTS first, OpenVoice fallback.

Task Voice 0.2: App-side voice interfaces

- Add `VoiceProfile`, `VoiceProvider`, `VoicePlaybackCoordinator`.
- No network call yet.
- Add no-op provider for build-safe integration.

Task Voice 0.3: Local server provider

- Implement HTTPS POST `/v1/tts`.
- Decode raw audio response.
- Add timeout and friendly failure handling.
- Do not print text or audio payloads.

Task Voice 0.4: Playback integration

- After assistant delivery completes, extract readable text.
- Generate/load audio.
- Play with `AVPlayer`.
- Add stop-on-new-message behavior.

Task Voice 0.5: Settings UI

- Add voice enabled toggle.
- Add local server URL.
- Add voiceId field.
- Add read narration toggle.

Task Voice 0.6: Local server POC

- Build a small external adapter for F5-TTS.
- Expose `/v1/tts`.
- Keep clone files and consent records outside the iOS app.

## Acceptance Criteria

For the first app implementation:

- Voice is off by default.
- Chat still works if the voice server is unavailable.
- No ChatMessage schema change.
- No MessageStore schema change.
- No LLM provider change.
- No API key stored in UserDefaults.
- No assistant text, prompt, or memory content printed to logs.
- Audio cache stays in sandbox cache directory.
- Voice playback can be stopped.
- New assistant reply stops previous playback.
- Narration is not read unless explicitly enabled.

## Open Questions

- Should voice playback start after the first assistant bubble or after all bubbles finish delivering?
- Should narration use the same voice, a separate narrator voice, or remain silent?
- Should detailed mode auto-enable narration audio, or should that always require a separate toggle?
- Should local server require a token even on LAN?
- What is the target hardware for F5-TTS: local Mac, cloud GPU, or user's own server?

