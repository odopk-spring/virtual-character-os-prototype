# Real Conversation Patterns v0

Source: `/Users/odopkk/Desktop/claude code/VirtualCharacterOS_Real_Conversation_Research_Report.md`

This document converts the research report into small, executable rules for VirtualCharacterOS. Each rule must be discussed and landed separately.

## Scope

This version only specifies Rule 1: Low-Signal Minimal Response v0.

Out of scope for this rule:

- No real no-reply / silence path.
- No proactive messaging.
- No Time Awareness implementation.
- No Memory recall redesign.
- No schema change.
- No model training or dataset import.
- No original dataset text in prompt, WorldBook, logs, or app data.

## Rule 1: Low-Signal Minimal Response v0

### Goal

When the user's latest message carries almost no new information, the character should answer like a real chat partner: briefly, naturally, and without trying to extend the conversation.

### Product Decision

Do not implement true silence in v0.

Reason: the current chat pipeline creates an assistant placeholder for each user send. True silence would require a separate UI/state/persistence path for "no assistant message", which is larger than this rule. V0 uses a very short response instead.

### Signal Categories

Add a new signal below `low`:

| Signal | Meaning | Typical user input | Desired behavior |
|---|---|---|---|
| `minimal` | Almost no information, mostly acknowledgement, filler, reaction, symbol, or closure | `嗯`, `哦`, `好`, `行`, `6`, `。`, `？`, `哈哈`, `没事`, `算了`, emoji-only | 1 short bubble, 1-5 Chinese chars, no question |
| `low` | Short but still has some stance or meaning | `好吧`, `还行`, `不是`, `可以吧`, `有点累` | 1 short bubble, roughly 5-15 Chinese chars, no analysis |
| `light` | Casual lightweight chat | short daily statement or mood cue | 1 short reply, usually 15-40 Chinese chars |
| `normal` | Default meaningful chat | normal question / statement | 1-2 short bubbles |
| `deep` | User explicitly asks for detailed help | design, code, analysis, plan, spec | More complete, still concise |

### Detection Rules

Classify as `minimal` when all are true:

1. The latest user message is not empty.
2. It does not contain an obvious detailed-help marker.
3. It is either:
   - in the exact minimal phrase list, or
   - <= 2 characters and not an actual content question, or
   - made only of punctuation, symbols, emoji-like characters, or repeated laughter.

Minimal exact phrase list:

`嗯`, `嗯嗯`, `哦`, `啊`, `呃`, `额`, `好`, `行`, `对`, `是`, `没`, `懂`, `6`, `。`, `？`, `?`, `...`, `……`, `哈哈`, `哈哈哈`, `hh`, `hhh`, `没事`, `算了`

Keep `low` for short inputs that are not pure filler, such as:

`好吧`, `可以`, `还行`, `不是`, `有点累`, `不知道`, `随便`

When uncertain, prefer `light` over `minimal`.

### Prompt Policy

For `minimal`, the system prompt must say:

- Give only a very short natural response.
- 1 short bubble.
- 1-5 Chinese chars when possible.
- Do not explain.
- Do not summarize.
- Do not ask a question.
- Do not reopen the topic.
- It is acceptable to let the exchange end naturally.

For `low`, keep the existing "short response" behavior, but make it less likely to ask a question or analyze.

### Engineering Behavior

In v0:

- `ReplySignalStrength` adds `minimal`.
- `ContextBuilder` maps `minimal` to the strict prompt policy above.
- `ChatViewModel.splitAssistantReply` should limit minimal replies to one bubble.
- Existing delivery delay remains mostly unchanged in this rule.
- No UserDefaults setting is added.
- No `messages.json`, `branches.json`, `hidden-messages.json`, Memory, or WorldBook schema is changed.

### Acceptance Criteria

Given the latest user message is `嗯`, `哦`, `好`, `哈哈`, `6`, or `。`:

- Context summary reports `signal=minimal`.
- Prompt contains a `minimal`-specific instruction.
- Assistant reply splitting returns at most 1 bubble for this response.
- The prompt does not ask the model to continue, summarize, explain, or ask a question.

Given the latest user message is `详细讲一下这个方案`:

- Signal remains `deep`.
- Deep response policy is unchanged.

Given the latest user message is `有点累`:

- Signal is not forced to `minimal`; it may be `low` or `light`.

### Risks

- A short but meaningful user message may be classified too low.
- The model may still ignore the prompt and answer too long.
- True no-reply remains deferred.

### Deferred Follow-ups

- Rule 2: Brevity bias.
- Rule 3: Multi-bubble segmentation calibration.
- Rule 4: Delivery timing matrix.
- Rule 5: Question suppression.
- Rule 6: No tutorial mode.
- Rule 7: Natural memory recall.
- Rule 8: Rule tier classification.
- Rule 9: Time gap response.
- Rule 10: Boundary honesty.
