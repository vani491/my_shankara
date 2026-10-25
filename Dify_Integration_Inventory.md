# Dify Integration Inventory — MyShankara Flutter App

Purpose: complete inventory of everything the app sends to / reads from the self-hosted
Dify Service API, as preparation for moving all Dify calls behind an own proxy server.

Scope note: all Dify traffic in this app lives in exactly **one file**:
`lib/screens/aa_guru_chatbot.dart`. No other Dart file, service, or platform config
touches Dify. Derived from reading the code only — the app was not run.

Date: 2026-10-11 · Branch: main

---

## 1. Dify endpoints in use

| Feature | Dify endpoint | File / function | Fields used |
|---|---|---|---|
| Send chat turn | `POST /v1/chat-messages` (`response_mode: "blocking"`, **not** streaming) | `aa_guru_chatbot.dart:1560` `_callDify(userText, conversationId)`; call site `:571` in `_handleSend` | **REQ:** `inputs{}`, `query`, `response_mode`, `conversation_id`, `user`, `files[]`<br>**RESP read:** `answer` (fallback `data`, `message`), `conversation_id`, `message_id`<br>**RESP ignored:** `task_id`, `created_at`, `metadata`, `usage`, `retriever_resources`, `mode`, `event` |
| Delete a chat | `DELETE /v1/conversations/{conversation_id}` | `aa_guru_chatbot.dart:1594` `_deleteDifyConversation()`; call site `:481` in `_deleteChatEverywhere` | **REQ body:** `{ user }`<br>**RESP:** status code only; `404` treated as success |
| Thumbs up/down + dislike reason | `POST /v1/messages/{message_id}/feedbacks` | `aa_guru_chatbot.dart:1616` `_sendDifyFeedback()`; call site `:1349` in `_FeedbackBar._submitFeedback` | **REQ:** `rating` (`"like"` / `"dislike"` / `null` to clear), `user`, `content` (only when non-empty; from dislike dialog)<br>**RESP:** status code only |

Transport: `package:http` (`http.post` / `http.delete`). No Dio, no streaming client,
no explicit timeouts, no retry, no cert pinning.

---

## 2. `/chat-messages` request body — field by field

| Field | Value | Source |
|---|---|---|
| `query` | user's typed text, trimmed | `_controller.text` → `_handleSend` → `_callDify(userText)` |
| `inputs` | `{}` | hardcoded empty literal — **no start-node variables sent at all** |
| `response_mode` | `"blocking"` | hardcoded string in client |
| `conversation_id` | `_difyConversationId` (String, `""` on first turn) | Firestore `users/{uid}/chats/{chatId}.difyConversationId`, loaded at `:314` and `:372`; overwritten from the response at `:582`; persisted by `_saveDifyConversationId()` (`:175`); reset to `""` by `_startNewChat()` (`:397`) |
| `user` | `_difyEndUserId()` (`:35`) = `FirebaseAuth.instance.currentUser?.uid ?? 'guest'` | Firebase Auth uid. Guests are real Firebase **anonymous** users, so this is their anon uid; the literal `'guest'` is only the no-session fallback |
| `files` | `[]` | hardcoded empty literal |
| `auto_generate_name` | not sent | not used |

No conversation history is sent — only the latest `query`; Dify holds history
server-side keyed by `conversation_id`.

**Response parsing** (`:1578-1587`):

```dart
answer         = data['answer'] ?? data['data'] ?? data['message'] ?? resp.body  // loose fallback chain
conversationId = data['conversation_id'] ?? ''   // only assigned if non-empty
messageId      = data['message_id'] ?? ''        // null-ed if empty; gates feedback UI via _canRate
```

Post-processing: `answer.trim()` with `RegExp(r'\n{3,}')` collapsed to `'\n\n'` (`:572`).

---

## 3. SSE events parsed

**None — not used.**

The app only ever uses `response_mode: "blocking"` and parses a single JSON object.
There is no `text/event-stream` handling, no `data: ` line parsing, no `LineSplitter`,
no `http.Client().send()` / `StreamedResponse` anywhere in the repo.

Specifically **not** handled: `message`, `message_end`, `message_replace`,
`agent_message`, `agent_thought`, `message_file`, `tts_message`, `tts_message_end`,
`workflow_started`, `node_started`, `node_finished`, `workflow_finished`,
`iteration_*`, `parallel_branch_*`, `error`, `ping`.

`task_id` is never captured, so streaming cannot be stopped.

---

## 4. Base URL / key / headers

```
Base URL : const String _difyBaseUrl = 'https://dify.myshankara.ai/v1'   (aa_guru_chatbot.dart:27)
API key  : const String _difyApiKey  = '[REDACTED]'                      (aa_guru_chatbot.dart:28)
```

The key is a hardcoded Dart `const`, compiled into the shipped client binary.
No `.env` file, no `--dart-define`, no platform/native config, no remote config.
It appears in exactly one place (`:28`) and nowhere else in the repo.

Headers sent on **all three** calls (identical `const` maps):

```
Authorization: Bearer [REDACTED]
Content-Type: application/json
```

No other headers (no User-Agent override, no `Accept`, no request id, no idempotency key).

---

## 5. Files / voice / start-node inputs

| Capability | Status |
|---|---|
| File or image upload to Dify | **not used** (`POST /files/upload` never called; `files: []` always empty) |
| Vision / image in chat | **not used** |
| Speech-to-text (`audio-to-text`) | **not used** |
| Text-to-speech (`text-to-audio`) | **not used** |
| Chatflow start-node input variables | **not used** (`inputs` is a hardcoded `{}`) |
| Conversation variables | **not used** |

Note: the app *does* depend on `image_picker` (profile avatar only,
`edit_profile_screen.dart:36`) and `just_audio` (sloka/darshan audio from
`dashboard.myshankara.ai`, `ab_home_screen.dart` / `ac_darshan_screen.dart`).
Neither is wired to Dify.

---

## 6. Dify features the app does NOT use

- `POST /chat-messages` with `response_mode: "streaming"` — not used
- `POST /chat-messages/{task_id}/stop` — not used (`task_id` never read)
- `GET /conversations` (list) — not used (history comes from Firestore instead)
- `POST /conversations/{id}/name` (rename / auto-name) — not used (titles derived locally from first user msg)
- `GET /conversations/{id}/variables` — not used
- `GET /messages` (message history for a conversation) — not used (messages stored in Firestore instead)
- `GET /messages/{id}/suggested` (suggested questions) — not used
- `GET /parameters` — not used
- `GET /meta` — not used
- `GET /site` (app / WebApp settings) — not used
- `POST /files/upload` — not used
- `POST /audio-to-text` — not used
- `POST /text-to-audio` — not used
- `GET /app/feedbacks` (feedback list) — not used
- Annotation / annotation-reply APIs — not used
- Workflow APIs (`/workflows/run`, `/workflows/tasks/...`) — not used
- Any `/apps` or console/admin APIs — not used
- Pagination, `first_id` / `limit` params anywhere — not used

---

## 7. Risks / oddities — what the proxy should take over

1. **API key in the client.** The Dify Service API key is a hardcoded `const` (`:28`)
   shipped in the APK/IPA. Anyone can extract it and use the app's Dify quota directly.
   This is the #1 reason for the proxy; the key must move server-side and the app must
   send a Firebase ID token instead.

2. **Client owns `user`.** `_difyEndUserId()` (`:35`) is read from the device's own
   Firebase session and sent as a plain string. With the key extracted, a caller can
   impersonate **any** uid — read/pollute another user's Dify conversation, or vote
   feedback as them. The proxy should derive `user` from a verified Firebase ID token
   and ignore anything the client sends.

3. **Client owns `conversation_id`.** Sent as an opaque string with no server-side check
   that this conversation belongs to this uid. Dify itself scopes by user, but the proxy
   should still verify ownership (e.g. against `users/{uid}/chats`) before forwarding —
   otherwise a guessed/leaked conversation id plus the extracted key is a cross-tenant read.

4. **Client owns `response_mode`, `inputs`, `files`.** All hardcoded today, so the server
   can simply pin them: force `response_mode`, inject `inputs` from trusted server state,
   and reject/validate `files`. Do not pass these through.

5. **Quota and paywall are client-side only.** The guest daily limit
   (`_kGuestDailyLimit = 5`, `:22`) and `AccessService.hasAccess()` trial/subscription
   check (`:542-549`) both run in the app before `_callDify`. Bypassing the UI (or using
   the extracted key) bypasses both entirely. Rate limiting and entitlement must be
   enforced in the proxy.

6. **Loose answer parsing.** `answer = data['answer'] ?? data['data'] ?? data['message'] ?? resp.body`
   (`:1579`). On an unexpected 2xx shape the raw HTTP body — potentially including server
   error detail — is rendered to the user as the assistant's reply. The proxy should return
   one normalized shape so the client can stop guessing.

7. **No timeout, no retry, no cancel.** `http.post` has no `.timeout()`; blocking mode means
   the UI waits for the full generation with no way to abort (`task_id` is never captured,
   `/stop` is never called). Worth fixing while introducing the proxy.

8. **DELETE with a body.** `_deleteDifyConversation` sends a JSON body on an HTTP `DELETE`
   (`:1596-1603`). Dify accepts it, but some proxies, CDNs and WAFs strip or reject DELETE
   bodies. If the proxy forwards verbatim, this call can silently fail.

9. **Feedback depends on uid stability.** Both the delete and feedback calls must send the
   **same** `user` as the original `chat-messages` request or Dify 404s (noted in the code
   comments at `:30-34` and `:1613-1615`). An anonymous guest who later links/upgrades to a
   real account gets a different uid, orphaning their earlier conversations and message
   feedback. The proxy's identity mapping should account for anon → permanent account linking.

10. **Best-effort server cleanup.** `_deleteChat` (`:467`) removes the chat from the local
    list immediately and fires the Firestore + Dify deletes in the background via
    `unawaited(...)`; on failure it only shows a snackbar and never reverts or retries, so
    Dify conversations can be orphaned server-side. A proxy-side delete queue would make
    this reliable.

11. **Account deletion does not delete Dify data.** No account-deletion path calls
    `_deleteDifyConversation`; conversations survive in Dify after the user deletes their
    account. Relevant for data-deletion / GDPR claims — the proxy is the natural place to
    fan out a full-user purge.

12. **Likely bug: `_loadChat` (`:448`)** sets `_currentChatId` and the message list but never
    sets `_difyConversationId`. Opening an older chat from the history drawer therefore keeps
    whatever conversation id was last in memory, so the next turn is appended to the **wrong**
    Dify conversation (and then written over the reopened chat's `difyConversationId` at
    `:592`). Read from code only — not reproduced at runtime.
