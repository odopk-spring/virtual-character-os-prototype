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

- Rule 3: Multi-bubble segmentation calibration.
- Rule 4: Delivery timing matrix.
- Rule 5: Question suppression.
- Rule 6: No tutorial mode.
- Rule 7: Natural memory recall.
- Rule 8: Rule tier classification.
- Rule 9: Time gap response.
- Rule 10: Boundary honesty.

## Rule 2: Brevity Bias v0

### Problem

LLM casual replies are systematically longer, more explanatory, and more complete than ordinary human chat replies. This makes a virtual character feel like an assistant, teacher, or customer service script instead of a person in a messaging app.

VCO already handles `minimal` inputs. The remaining issue is that `low`, `light`, and `normal` inputs can still produce long explanations, emotional summaries, advice, or question-heavy endings.

### Evidence

- Real messaging corpora generally show short message lengths, with a typical personal-chat message closer to a short phrase than a full paragraph.
- Personal chat timing and length studies suggest that everyday turns often carry one small idea, not a full analysis.
- Chinese public and topic-driven dialogue datasets provide only rough quantity references; they are not private long-term 1v1 chat data and must not be used as training material.
- LLM small-talk research indicates that model replies tend to be much more verbose than human casual replies.

These are rule-extraction references only. Do not import dataset text, examples, or private conversation content into code, prompt, WorldBook, logs, or tests.

### Length Targets

| Signal | Target length | Bubble target | Notes |
|---|---:|---:|---|
| `minimal` | 1-5 Chinese chars | 1 bubble | Unchanged from Rule 1. No question, no explanation, no topic reopening. |
| `low` | 5-15 Chinese chars | 1 bubble | Acknowledge lightly. Default no question. No analysis. |
| `light` | 10-35 Chinese chars | usually 1 bubble, max 2 | Short natural reply with a little attitude or mood. Avoid advice mode. |
| `normal` | 20-70 Chinese chars | 1-2 bubbles | One core idea is enough. Do not write a complete mini-essay. |
| `deep` | 80-220 Chinese chars per full reply | max 3 bubbles | Only for explicit requests for detail, analysis, plan, code, prompt, or complete explanation. Still conversational. |

### Policy

1. Default to short.
2. One natural sentence is often enough.
3. Do not explain unless the user asks for explanation.
4. Do not summarize the user's message unless clarification is truly needed.
5. Do not add advice unless asked or the context clearly calls for one small suggestion.
6. Do not end every reply with a question.
7. It is acceptable for a reply to feel slightly incomplete, as long as it sounds like natural chat.
8. Deep requests may be fuller, but should still avoid essay, customer-service, or tutorial structure.

### Engineering Behavior

In v0:

- Keep `minimal` behavior unchanged.
- Add an always-on brevity hint inside the reply length policy.
- Calibrate `low`, `light`, `normal`, and `deep` prompt wording with the length targets above.
- Suppress pending question hints for `low`.
- Soften pending question hints for `light`.
- Keep pending question behavior for `normal` and `deep`, but phrase it as a short optional callback.
- Limit assistant bubble count by signal:
  - `minimal`: max 1
  - `low`: max 1
  - `light`: max 2
  - `normal`: max 2
  - `deep`: max 3
- Do not rewrite the segmentation algorithm.
- Do not change delivery delay logic.

### Non-goals

- No true silence / no-reply.
- No model training.
- No dataset import.
- No Time Awareness.
- No Memory recall redesign.
- No WorldBook seed or schema change.
- No UI change.

### Acceptance Criteria

Given the latest user message is `还行吧`, `不知道`, `可以`, or `不是`:

- Signal is not `minimal`.
- Reply policy targets a short `low` response.
- Pending question hint is not injected.
- Assistant reply is limited to 1 bubble.

Given the latest user message is `今天有点累` or `刚刚吃完饭`:

- Reply policy targets a short `light` response.
- Pending question hint, if present, is softened.
- Assistant reply is limited to at most 2 bubbles.

Given the latest user message is `我今天想改一个小功能，但是不知道怎么拆任务`:

- Reply policy targets a concise `normal` response.
- Assistant reply is limited to at most 2 bubbles.

Given the latest user message explicitly asks for detail, analysis, code, prompt, or a complete plan:

- Signal remains `deep`.
- The answer may be fuller, but remains conversational and is limited to at most 3 bubbles.

### Risks

- Prompt-only brevity does not guarantee a short model answer.
- Over-compression may make some characters feel cold or uninterested.
- Deep replies may become too short if the prompt is tuned too aggressively.
- This rule does not fully solve excessive questioning; that remains a future dedicated rule.
- This rule does not fully solve tutorial-like style; that remains a future dedicated rule.
