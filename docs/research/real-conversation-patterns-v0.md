# Real Conversation Patterns v0

Source: `/Users/odopkk/Desktop/claude code/VirtualCharacterOS_Real_Conversation_Research_Report.md`

This document converts the research report into small, executable rules for VirtualCharacterOS. Each rule must be discussed and landed separately.

## Scope

This version specifies Rules 1-4: Low-Signal Minimal Response, Brevity Bias, Question Suppression, and No Tutorial Mode.

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

- Future: Multi-bubble segmentation calibration.
- Future: Delivery timing matrix.
- Future: Multi-bubble no-tutorial calibration.
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

## Rule 3: Question Suppression v0

### Problem

LLM assistants often end casual replies with a question to keep the conversation alive. In real chat, most turns do not need a question. Mechanical follow-up questions make the character feel like an interviewer, therapist, or customer service agent.

### Evidence

- Real conversation includes many statements, acknowledgments, laughs, evaluations, light self-disclosures, and natural closures.
- LLMs tend to over-engage and over-ask in casual small talk.
- For VCO, letting a turn end naturally is often more realistic than forcing another question.

These are rule-extraction references only. Do not import dataset text, examples, or private conversation content into code, prompt, WorldBook, logs, or tests.

### Question Policy by Signal

| Signal | Question policy |
|---|---|
| `minimal` | Never ask. Do not reopen the topic. Let the reply end naturally. |
| `low` | Default no question. Do not use pending questions to pull the user back. V0 does not allow even short confirmation questions here. |
| `light` | Usually no question. One short, specific question is allowed only when the user clearly opens a topic but leaves key context missing. |
| `normal` | Questions are allowed, but not as the default ending. Prefer a statement, small reaction, evaluation, or light self-disclosure. If asking, ask one specific question. |
| `deep` | Clarifying questions are allowed when requirements, constraints, or goals are missing. If enough context exists, answer directly rather than asking a chain of questions. |
| boundary / safety | Questions are allowed when needed for safety, identity boundaries, or accuracy. This rule must not suppress required clarification. |

### Mechanical Generic Questions

These patterns are not absolutely forbidden, but should not appear mechanically as default endings:

- `你呢？`
- `你觉得呢？`
- `你想聊聊吗？`
- `要不要继续说说？`
- `可以跟我说说吗？`
- `你还有什么想聊的吗？`
- `那你现在感觉怎么样？`
- `你平时也会这样吗？`
- `你是怎么做到的？`
- `需要我帮你分析一下吗？`

### Reasonable Follow-up Conditions

Ask at most one question when:

1. The user explicitly asks for help but omits a necessary constraint.
2. The user opens a topic and clearly leaves a key context gap.
3. The current task is `deep` and a precise clarification would improve the answer.
4. Boundary, safety, identity, or accuracy requires clarification.

### Policy

1. Do not end every reply with a question.
2. Prefer statements, small reactions, evaluations, light self-disclosure, or natural closure.
3. Ask at most one question when needed.
4. Avoid generic continuation questions.
5. Avoid therapist or customer-service probing.
6. If the previous assistant reply already asked a question, avoid asking another one unless the user directly requested it.
7. For `minimal` and `low`, never reopen the conversation with a new question.
8. For `deep`, clarification questions must be precise.

### Engineering Behavior

In v0:

- Add a short question-suppression hint in `ContextBuilder` near the reply policy.
- Keep `minimal` and `low` pending question hints suppressed.
- Keep `light` pending question hint weak and explicitly optional.
- Keep `normal` and `deep` pending question hints, but phrase them as optional, short callbacks.
- Add a conservative tail-question suppression helper:
  - Only for `minimal`, `low`, and `light`.
  - Only when the final independent bubble is an obvious generic question.
  - Only when dropping it leaves at least one bubble.
  - Do not process `normal` or `deep`.
  - Do not delete specific, information-bearing questions.

### Non-goals

- Do not remove all questions.
- Do not delete pending question tracking.
- Do not implement true silence / no-reply.
- Do not implement Time Awareness.
- Do not redesign Memory recall.
- Do not modify WorldBook seed or schema.
- Do not modify Memory, Branch, Hidden, History, Provider, Keychain, or LLM code.

### Acceptance Criteria

Given `minimal` input:

- No pending question hint is injected.
- The reply remains at most 1 bubble.
- The prompt tells the model not to ask.

Given `low` input:

- No pending question hint is injected.
- The reply remains at most 1 bubble.
- The prompt tells the model to avoid questions by default.

Given `light` input:

- Pending question hint, if present, is weak and optional.
- Obvious generic trailing questions may be dropped only if they are a separate final bubble.

Given `normal` input:

- The prompt discourages question-as-default endings but does not forbid questions.

Given `deep` input:

- Specific clarification questions remain allowed.

### Risks

- Prompt-only suppression cannot guarantee the model will avoid questions.
- Over-suppression may make the character feel cold.
- Deep requests and safety/boundary situations still need reasonable clarification questions.
- The conservative tail helper may miss some generic questions by design.

## Rule 4: No Tutorial Mode v0

### Problem

LLM assistants often explain, summarize, advise, or structure casual replies like a tutor, therapist, customer service agent, or productivity coach. In ordinary chat, that makes the character feel like a service interface instead of a person in a messaging app.

### Evidence

- LLMs tend to over-explain and over-empathize in casual small talk.
- Real chat often uses reactions, small evaluations, incomplete thoughts, brief opinions, and casual self-disclosure.
- Tutorial-style replies break character realism because they turn light conversation into teaching, consulting, or support scripts.

These are rule-extraction references only. Do not import dataset text, examples, or private conversation content into code, prompt, WorldBook, logs, or tests.

### Tutorial Mode Policy by Signal

| Signal | Explanation policy | Summary policy | Advice policy |
|---|---|---|---|
| `minimal` | Never explain. | Never summarize. | Never advise. |
| `low` | No explanation. One light acknowledgement is enough. | Do not make an emotional summary. | No advice. |
| `light` | Usually no explanation. Do not analyze why the user feels or thinks something. | Avoid summarizing the user. | Usually no advice; prefer a small reaction, attitude, or light empathy. |
| `normal` | One brief conversational point is allowed. Do not default to analysis or steps. | Do not summarize unless it prevents misunderstanding. | Do not default to plans or solutions unless the user asks for help. |
| `deep` | Structured explanation is allowed when the user explicitly requests detail, analysis, plan, code, prompt, implementation, or complete design. | Summaries are allowed when useful for the task. | Advice, steps, task lists, code blocks, and structured answers are allowed when requested. |
| boundary / safety | Careful explanation and clarification are allowed when needed for safety, identity boundaries, medical, legal, financial, or accuracy reasons. | Use only what is necessary. | Safety and boundary guidance must not be suppressed by this rule. |

### Template Phrases to Suppress in Casual Chat

These patterns are not absolutely forbidden. Some may be reasonable in `deep` tasks. The goal is to suppress them as default casual-chat tone:

- `首先 / 其次 / 最后`
- `总结一下`
- `本质上来说`
- `这说明`
- `从几个方面来看`
- `我建议你可以`
- `你可以尝试`
- `我们可以一步一步`
- `我理解你的感受`
- `听起来你现在`
- `这可能是因为`
- `如果你愿意，我可以`
- `希望对你有帮助`
- `没问题，我来帮你分析`

### Conditions for Structured Answers

Structured or tutorial-like answers are allowed when:

1. The user explicitly asks for detail, analysis, explanation, plan, code, prompt, implementation, audit, or complete design.
2. The user asks for practical help and the answer would be worse without steps or structure.
3. The topic involves boundary, safety, identity, medical, legal, financial, or accuracy constraints.
4. The current signal is `deep`, and structure improves clarity without adding corporate or customer-service filler.

### Rules

1. Do not explain unless asked.
2. Do not summarize the user unless it prevents misunderstanding.
3. Do not give advice unless the user asks for advice or help.
4. Do not use `首先/其次/最后` in casual chat.
5. Do not sound like a therapist, teacher, customer service agent, or productivity coach.
6. Prefer small reactions, opinions, casual self-disclosure, or brief agreement.
7. It is acceptable to leave a reply slightly incomplete.
8. Deep requests may be structured, but still avoid corporate, template, or support-script tone.

### Engineering Behavior

In v0:

- Add a short No Tutorial Mode hint in `ContextBuilder` near the reply policy.
- Keep `minimal`, `low`, `light`, `normal`, and `deep` length and question policies from Rules 1-3.
- Make `minimal` and `low` explicitly reject explanation, summary, and advice.
- Make `light` and `normal` avoid default analysis, advice, and step-by-step structure.
- Keep `deep` capable of structured answers for plans, code, prompts, design, and detailed analysis.
- Add a conservative tutorial-tail suppression helper:
  - Only for `minimal`, `low`, and `light`.
  - Only when the final independent bubble is an obvious generic advice or support-script tail.
  - Only when dropping it leaves at least one bubble.
  - Do not process `normal` or `deep`.
  - Do not delete specific, information-bearing advice.

### Non-goals

- Do not remove deep-answer ability.
- Do not block code, plan, prompt, or implementation tasks.
- Do not forbid all explanations.
- Do not forbid all advice.
- Do not forbid all summaries.
- Do not implement Time Awareness.
- Do not redesign Memory recall.
- Do not modify WorldBook seed or schema.
- Do not modify Memory, Branch, Hidden, History, Provider, Keychain, or LLM code.
- Do not import datasets or train models.
- Do not change UI, delivery pace, or true silence behavior.

### Acceptance Criteria

Given `minimal` input:

- The prompt forbids explanation, summary, advice, and tutorial mode.
- The reply remains at most 1 bubble.

Given `low` input:

- The prompt forbids explanation and advice.
- The reply remains at most 1 bubble.

Given `light` input:

- The prompt defaults to reaction, attitude, or light empathy.
- The reply does not enter therapist, teacher, or customer-service mode by default.
- Obvious generic tutorial tails may be dropped only if they are separate final bubbles.

Given `normal` input:

- The prompt allows one brief point, but discourages default steps, plans, and user summaries.

Given `deep` input:

- Detailed plans, code, prompts, structured analysis, and implementation guidance remain allowed.

### Risks

- Prompt-only suppression cannot guarantee the model will avoid tutorial tone.
- Over-suppression may make the character seem cold or unhelpful.
- Deep tasks must not be misclassified or reduced to a one-line casual reply.
- Boundary and safety contexts still require careful explanation.
- The conservative tail helper may miss many tutorial phrases by design.
