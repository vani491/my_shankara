# MyShankara Code Findings

Read-only review. No code was changed. Paths are relative to the repo root. Line numbers are from the working tree at `main` (6a7044a).

## 1. Authentication (Q1)

1. **Provider/SDK:** Firebase Auth (`pubspec.yaml`)
   - `firebase_auth: ^6.1.1`
   - `firebase_core: ^4.2.0`
   - `google_sign_in: ^7.2.0`
   - `cloud_firestore: ^6.1.0`
   - The resolved versions are in `pubspec.lock`. I did not read them.
2. **Sign-in methods in the code:**
   - Email/password sign-up: `createUserWithEmailAndPassword`, then `sendEmailVerification` (`lib/onboarding_flow/ba_create_account.dart:255-263`).
   - Email/password login and password reset (`lib/screens/existing_user_login.dart:202, 645`; `lib/services/auth_service.dart:20-28`).
   - Google: `AuthService.signInWithGoogle()` (`lib/services/auth_service.dart:35-53`). It is called from `ba_create_account.dart:235` and `existing_user_login.dart:175`.
   - Anonymous/guest: `signInAnonymously()` (`lib/onboarding_flow/ca_onboarding_as_guest.dart:165`; `lib/services/auth_service.dart:31`).
   - Apple: button only, not implemented. `_onAppleSignUp() {}` is empty (`ba_create_account.dart:247`), the `onPressed` is commented out, and the visible handler only prints (`ba_create_account.dart:344-346`).
   - Phone OTP: not implemented. `edit_profile_screen.dart` has a fake `_verifyPhone` with a dialog and no Firebase call. That file is not referenced by any route or import.
3. **Guest mode:** Yes.
   - Guests are real Firebase anonymous users. The anonymous UID is held by Firebase Auth on the device and used as the Dify `user` id (`aa_guru_chatbot.dart:35`).
   - Guest state is detected with `currentUser.isAnonymous` (`app_drawer.dart:23`, `aa_guru_chatbot.dart:57`, `ac_darshan_screen.dart:47`).
   - The app writes no Firestore profile or chat data for guests.
   - Local guest data: the SharedPreferences keys `guest_msg_date` and `guest_msg_count` (`aa_guru_chatbot.dart:60-84`). The daily limit is `_kGuestDailyLimit`.
   - Sign-out removes `isOnboarded` and signs out of Firebase (`main.dart:369-373`). It does not delete the anonymous account.
4. **Methods enabled in the Firebase console:** Not visible from the repo.
   - There is no `firebase.json` auth config. It only lists the project and app IDs, and the project id is `first-firebase-project-c0d4a`.
   - `android/app/google-services.json` has `oauth_client` entries of type 1 (Android) and type 3 (web). This suggests Google sign-in is configured. It does not prove which providers are enabled.
   - The repo has no Firestore security rules file and no Cloud Functions directory.

## 2. Profile data (Q2, Q3, Q4)

1. **Writes to the user profile.** Everything goes to the Firestore doc `users/{uid}`.
   - **Initial profile** (`lib/screens/profile_basics.dart:682-697`, `set(..., merge: true)`), written when the first-time form is saved:
     - `fullName`, `preferredName`
     - `gender` (enum name: `male`, `female` or `other`; null if unselected)
     - `yearOfBirth` (int)
     - `age` (int, computed as current year minus year of birth)
     - `createdAt` (server timestamp)
     - `totalDiyasLit` (0)
     - `lastLitDate` (empty string)
     - `trialStartDate` (server timestamp)
   - **Edit mode** (`profile_basics.dart:639-642`): only `preferredName` is written. The Save button in edit mode calls `_savePreferredName` (`:289`).
   - **Diya** (`lib/services/diya_service.dart:26-29`): `totalDiyasLit` (increment) and `lastLitDate`.
   - **Diya log** at `users/{uid}/diyaLogs/{yyyy-MM-dd}` (`diya_service.dart:22-25`): `lit` and `timestamp`.
   - **Chats** are covered in sections 3 and 4.
   - **Email** is not written to Firestore. It stays in Firebase Auth only.
   - **`subscription_status`** is read (`access_service.dart:20`, `guru_dakshina.dart:69`) but never written by the app. It must be set elsewhere.
   - **Notification settings** are not in Firestore. They are SharedPreferences keys: `notifications_enabled`, `notif_hour`, `notif_minute` (`settings_notifications.dart`, `notification_service.dart:247-249`, `main.dart:205-208`). `notif_first_prompt_done` is also stored (`ab_home_screen.dart:68-69`).
   - **Other local flags:** `isOnboarded` (`main.dart:136-142`) and `_hintSeenPrefKey` (`ac_darshan_screen.dart:112`).
2. **Year of birth:**
   - It is stored, as a year only (int `yearOfBirth`). A full date of birth is never collected. The derived `age` is also stored (`profile_basics.dart:680-687`).
   - The 18+ check is client-side only:
     - The form validator rejects age under 18 (`profile_basics.dart:439-450`).
     - The year picker shows a blocking popup (`:543`, `:555-585`).
   - Server-side enforcement: none found. The repo has no security rules and no functions.
   - The `age` value is computed as the current year minus the year of birth.
3. **Gender** is collected in the UI and stored. Every usage, with file and line:
   - `lib/screens/profile_basics.dart:21`: `enum Gender { male, female, other }`.
   - `:51`: `_selectedGender` state.
   - `:88-92`: read from Firestore into the form in edit mode.
   - `:253`: displayed read-only in edit mode. "other" is shown as "Prefer not to say" (`:153-164`).
   - `:403-413`: radio buttons in the creation form. `_genderRadio` is at `:587-623`.
   - `:685`: written to Firestore as `gender`.
   - `lib/screens/edit_profile_screen.dart:31, 380-391`: a separate gender dropdown that is local state only. The screen is dead code (no route or import) and writes nothing.
   - No usage in the Guru Chat request, analytics, personalization or backend. The app has no analytics SDK and no functions directory.
4. **Profile fields sent anywhere other than Firestore:**
   - **Dify:** no profile field. Only the Firebase UID is sent as `user` (see section 3).
   - **Support form** (`lib/screens/support.dart:34-37, 72-86`):
     - It sends an email over SMTP using Gmail with credentials hardcoded in the app source (line 72).
     - The email contains the name and email typed into the form, plus the message. Name and email are pre-filled from `FirebaseAuth.currentUser` `displayName` and `email` and are editable.
   - Preferred name is cached in memory only (`lib/services/user_name_cache.dart`).

## 3. Guru Chat / Dify request (Q7)

1. **Payload** for `POST https://dify.myshankara.ai/v1/chat-messages` (`lib/screens/aa_guru_chatbot.dart:1560-1577`):
   - `inputs`: `{}` (empty, no keys)
   - `query`: the user's message text
   - `response_mode`: `"blocking"`
   - `conversation_id`: the stored Dify conversation id, or `""` for a new chat
   - `user`: `FirebaseAuth.currentUser?.uid ?? 'guest'` (`:35`). This is the Firebase UID for signed-in users and also for anonymous guests. It is not an email or a random ID.
   - `files`: `[]`
   - Other Dify calls use the same `user` value:
     - Delete conversation: `DELETE /conversations/{id}` (`:1594-1611`)
     - Feedback: `POST /messages/{id}/feedbacks` (`:1616-1638`)
2. **Profile data in the request:** None. No name, preferred name, gender, year of birth or email is sent. The only personal identifier is the UID.
3. **Conversation history:** The app sends no history. Dify keeps it server-side keyed by `conversation_id`, and only the latest `query` is sent.
4. **Memory/summary of past conversations:**
   - The app sends no memory or summary, and `inputs` is empty.
   - Dify-side conversation variables or memory cannot be seen from this repo.
   - The app stores `lastMessage` (the latest message text, written per chat doc at `:210-212`). This is not a summary and is not sent anywhere.
5. **Direct vs proxy:** Called **directly from the app** with `http.post` to `https://dify.myshankara.ai/v1`.
   - The Dify API key is hardcoded in the Dart source: `_difyApiKey` (`:28`). It ships in the client binary.
   - There is no backend, proxy or Cloud Function.
6. **Logging of Dify requests:** None found.
   - No Crashlytics, analytics or Sentry in `pubspec.yaml`.
   - Failures are shown as a generic UI message (`:595-602`).
   - Chat messages are saved to Firestore (section 4), which is not a request log.
   - Dify-side logs cannot be seen from this repo.

## 4. Guru Chat storage in the app (Q8)

1. **Messages saved:**
   - **Firestore, signed-in non-guest users only.**
     - Chat doc `users/{uid}/chats/{chatId}`:
       - `createdAt` (server timestamp)
       - `lastMessage` (the text of the latest message)
       - `difyConversationId`
     - Message doc `users/{uid}/chats/{chatId}/messages/{auto-id}`:
       - `role` (user or bot)
       - `text`
       - `timestamp` (server timestamp)
       - `messageId` (Dify message id, when present)
       - `feedback` (thumbs state)
     - Written at `aa_guru_chatbot.dart:175-215, 403-418`, and updated for feedback at `:219-239`.
   - **Guests:** nothing is saved. Their chat is in memory only (`:258-260, 565`).
   - **Not used:** `lib/services/chat_service.dart` is dead code. It has no callers. If it were used it would write `title`, `updatedAt`, `sender`, `text`, `timestamp`.
   - **No local persistence** of chat content (no SQLite/Hive; SharedPreferences holds only the guest counter).
2. **Account linkage and sync:**
   - Linked to the UID by the path. It is synced to the backend and not on-device only.
   - There is no offline cache logic apart from the default Firestore SDK cache.
   - The whole history is reloaded from Firestore (`:347-390`).
3. **Retention/TTL:** None found.
   - No TTL or auto-delete logic in the code.
   - There are no rules or functions in the repo, so this cannot be checked in the repo.
4. **Account deletion:**
   - **No** full account deletion feature found.
   - The only `currentUser.delete()` calls remove an unverified email account, with a dialog:
     - `profile_basics.dart:134`
     - `bb_verify_email_screen.dart:141`
   - Neither deletes the Firestore `users/{uid}` doc, chats, or Dify conversations.
   - Per-chat deletion exists (`aa_guru_chatbot.dart:467-504`):
     - `_deleteChat`, then `_deleteChatEverywhere`
     - `_deleteChatFromFirestore` batch-deletes the messages and the chat doc.
     - `_deleteDifyConversation` calls the Dify delete API (`:1594`).
     - Errors only show a snackbar, so a failed delete can leave data behind.
   - Sign-out (`main.dart:369-373`) deletes nothing server-side.
5. **conversation_id persisted:** Yes.
   - Saved as `difyConversationId` on the chat doc (`aa_guru_chatbot.dart:175-185`).
   - Restored when a chat is opened (`:314`) and sent on each later request, so a conversation can be resumed.
   - The in-memory copy is cleared on a new chat (`:397`).
   - Guests do not persist it. It is lost when the screen is closed.
   - One caveat: `_loadChat` (`:448-459`, used from the chat history list) sets `_currentChatId` and the messages but does not set `_difyConversationId`. Opening an older chat from the history list may therefore continue with the previous conversation id. I read the code but did not run the app, so this is unconfirmed.
