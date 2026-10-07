# Community features

Accounts, profiles, reactions, comments, follows, polls, notifications,
submissions and moderation for the AllBioHub app. They are built on
Firebase (Authentication, Cloud Firestore, Cloud Functions, Cloud Storage).
WordPress stays the editorial CMS and is never written to.

Every feature ships **switched off** and is turned on remotely, one at a
time, without a new APK ([Feature switches](#feature-switches)). With
everything off the app behaves exactly like version 1: reading, search,
saving and the startup directory never need an account.

- [Setup checklist](#setup-checklist) (for the site owner, no code)
- [Architecture](#architecture)
- [Feature switches](#feature-switches)
- [Data model](#data-model)
- [Server API](#server-api)
- [Moderation and admin](#moderation-and-admin)
- [Anti-spam and safety](#anti-spam-and-safety)
- [Privacy and account deletion](#privacy-and-account-deletion)
- [Testing](#testing)
- [Migration and release](#migration-and-release)
- [Not built yet](#not-built-yet)

## Setup checklist

Everything here happens in the browser, in the
[Firebase console](https://console.firebase.google.com/project/allbiohub-d8015)
and in the GitHub repository's settings. Do the steps in order.

1. **Upgrade to the Blaze plan.** Firebase → ⚙️ → Usage and billing →
   Modify plan → Blaze. Server functions need it. Small apps stay inside
   the free monthly allowance; set a budget alert (for example $10) on the
   same page so you are emailed before anything is charged.
2. **Create the database.** Build → Firestore Database → Create database →
   *Production mode* → location **europe-west1 (Belgium)**.
3. **Turn on file storage.** Build → Storage → Get started → Production
   mode → same location.
4. **Turn on sign-in.** Build → Authentication → Get started → Sign-in
   method:
   - **Email/Password**: enable (leave "Email link" off).
   - **Google**: enable, choose a support email, save. Open Google again and
     copy the **Web client ID** (it ends in `.apps.googleusercontent.com`).
5. **Add the app's fingerprints** (needed for Google sign-in). GitHub →
   Actions → the latest **Release** run → summary → copy the two lines
   `SHA-1 digest` and `SHA-256 digest`. Firebase → ⚙️ Project settings →
   Your apps → the Android app → **Add fingerprint**, once for each.
6. **Add GitHub secrets.** GitHub → Settings → Secrets and variables →
   Actions → New repository secret:
   - `GOOGLE_WEB_CLIENT_ID`: the Web client ID from step 4.
   - `COMMUNITY_ADMIN_EMAILS`: your email address (several are separated by
     commas). These people can turn on editor access in the app.
   - `FIREBASE_SERVICE_ACCOUNT`: a key that lets GitHub publish the
     server code. Google Cloud console →
     [IAM → Service accounts](https://console.cloud.google.com/iam-admin/serviceaccounts?project=allbiohub-d8015)
     → Create service account (name it `github-deploy`) → give it the roles
     **Editor**, **Cloud Functions Admin**, **Cloud Run Admin** and
     **Service Account User** → Done → open it → Keys → Add key → JSON. Paste
     the whole downloaded file as the secret, then delete the file from
     your computer.
7. **Publish the server.** GitHub → Actions → **Deploy community backend**
   → Run workflow. The first run can fail with a message about Eventarc or
   permissions "propagating"; wait five minutes and run it again.
8. **Build the app.** GitHub → Actions → **Release** → Run workflow. Install
   the new APK.
9. **Become an editor.** In the new app, create an account with an email
   from step 6 and verify it. Then Profile → Account settings → **Editor
   access**.
10. **Switch features on.** Firebase → Firestore Database → Start collection
    `config` → document ID `app` → add a field `features` of type **map**,
    and inside it one **boolean** per feature set to `true`. Start with
    `accounts`, `communityProfiles`, `reactions` and `comments`; add the
    others when you are ready ([full list](#feature-switches)). The app
    picks up changes the next time it opens.

To turn a feature off again, set it to `false` (or delete it). Nothing is
lost: data stays and comes back when the feature is switched on.

## Architecture

```
 Flutter app ──reads──────────────▶ Cloud Firestore  (security rules: read-only,
     │                                    ▲            own data and public data)
     │                                    │ writes
     └──calls (signed in)──▶ Cloud Functions (validation, rate limits,
                                          │       counters, notifications)
                                          └─reads─▶ allbiohub.com (WordPress REST,
                                                    startup directory add-on)
```

- **The client is never trusted.** Firestore rules allow reads only (plus
  marking one's own notifications read). Every write is a callable Cloud
  Function that checks the signed-in user, their account status, input
  lengths, allowed values and rate limits before writing.
- **Counts are real.** Reaction, comment, reply, like, follower and vote
  counts are kept by the server in transactions and triggers. The app never
  invents or inflates numbers; zero counts are simply not shown.
- **Names come from the site.** Following a startup, founder or topic stores
  the name the server looked up on allbiohub.com, not what the app sent.
- **Region:** `europe-west1` for Firestore, Storage and Functions.
- **Code:** server in `firebase/functions/src`, rules in `firebase/*.rules`,
  app in `lib/core/community` (models, API, providers, switches) and
  `lib/features/community`, `lib/features/account` (screens).
- **Builds without Firebase** (no `FIREBASE_*` settings) use
  `UnavailableCommunityApi`: every feature is off and nothing pretends to
  work.

App settings (dart-define, see `.env.example`): `FIREBASE_*` as before, plus
`FIREBASE_STORAGE_BUCKET` (optional), `FIREBASE_FUNCTIONS_REGION`
(default `europe-west1`) and `GOOGLE_WEB_CLIENT_ID` (empty hides Google
sign-in). Server settings (written by the deploy workflow): `ADMIN_EMAILS`,
`WORDPRESS_BASE_URL`, `STARTUP_API_PATH`.

## Feature switches

`config/app` in Firestore, field `features` (map of booleans). Readable by
anyone, writable only from the console. The app caches the last value so it
opens with the same switches offline.

| Key | What it turns on | Needs `accounts` |
|---|---|---|
| `accounts` | Sign-in, Profile account section, account settings | — |
| `communityProfiles` | Public profile pages (`/u/…`) | yes |
| `reactions` | ❤️ 🔥 🤯 💡 under stories | yes |
| `comments` | Comments, replies, likes, reports | yes |
| `startupFollows` | Follow startups, watchlist, "Interested in this startup?" | yes |
| `founderFollows` | Founder pages, follow founders | yes |
| `topicFollows` | Follow topics (categories) | yes |
| `savedSync` | Saved stories, startups and founders sync to the account | yes |
| `polls` | Editorial polls | yes |
| `questionOfTheDay` | Question of the Day on Home | yes |
| `notificationCenter` | In-app notification center, account notification preferences | yes |
| `storySubmissions` | In-app "Submit a story" (otherwise the web form) | yes |
| `startupSubmissions` | In-app "Submit a startup" | yes |
| `startupClaims` | In-app startup claims (otherwise the web form) | yes |
| `forYou` | "For you" stories on Home from followed and chosen topics | no |
| `aiAssistant` | Reserved; nothing uses it yet | no |

A link to a page whose feature is off (for example from an old notification)
opens Home instead.

## Data model

| Path | Contents | Who can read |
|---|---|---|
| `config/app`, `config/moderation` | Switches; moderation settings | everyone |
| `profiles/{uid}` | username, displayName, bio, photoUrl, joinedAt, counts, visibility | public profiles: everyone; private: owner and editors |
| `users/{uid}` | status, suspendedUntil, notificationPrefs, usernameChangedAt | owner, editors |
| `users/{uid}/follows/{kind_id}` | kind, targetId, label, createdAt | owner, editors |
| `users/{uid}/saved/{kind_id}` | kind, id, title, image, url, data (JSON), savedAt | owner, editors |
| `users/{uid}/blocks/{uid}`, `mutes/{uid}` | blocked and muted people | owner, editors |
| `users/{uid}/notifications/{id}` | type, title, body, url, read, createdAt | owner (can mark read) |
| `users/{uid}/devices/{id}` | push token | nobody (server only) |
| `usernames/{name}` | uid (uniqueness index) | nobody |
| `articles/{postId}` | reactions map, reactionTotal, commentCount | everyone |
| `articles/{postId}/reactions/{uid}` | the person's reaction | that person |
| `comments/{id}` | articleId, parentId, rootId, depth (0–2), author snapshot, body, status, likeCount, replyCount, pinned, deleted | approved: everyone; otherwise author and editors |
| `comments/{id}/likes/{uid}` | like | that person |
| `followTargets/{kind_id}` | label, followerCount | everyone |
| `polls/{id}` | kind (`poll`/`qotd`), question, options [{id, label}], counts, totalVotes, status, allowChange, publishAt, expiresAt | active and closed: everyone |
| `polls/{id}/votes/{uid}` | optionId | that person |
| `storySubmissions`, `startupSubmissions`, `startupClaims` | the form, submitter, status, editorNote | submitter, editors |
| `reports/{id}` | reporter, target, reason, details, status | editors |
| `moderationLog/{id}` | every editor action | editors |
| `rateLimits`, `system` | server bookkeeping | nobody / editors |

Images: `avatars/{uid}/…` (public, owner writes, ≤ 5 MB JPEG/PNG/WebP) and
`submissions/{uid}/…` (submitter and editors).

## Server API

All callables run in `europe-west1` and require sign-in. "Verified" means a
verified email address; "profile" means a username has been chosen.

| Function | Who | Purpose |
|---|---|---|
| `checkUsername`, `createProfile` | signed in | Pick a unique username (3–20, `a-z 0-9 _`, starts with a letter; reserved and offensive names refused) |
| `updateProfile`, `changeUsername` | profile | Name, bio (≤ 160), privacy, photo; username change once per 30 days |
| `updateNotificationPrefs`, `registerDevice`, `unregisterDevice`, `markAllNotificationsRead` | signed in | Notifications |
| `setReaction` | signed in | One reaction per person per story, or none |
| `addComment`, `editComment`, `deleteComment`, `likeComment` | verified + profile | Comments (≤ 2000 chars, ≤ 2 links, replies up to depth 2) |
| `reportContent`, `blockUser`, `muteUser` | signed in | Safety |
| `setFollow`, `setSaved`, `importSaved` | signed in | Follows (≤ 500) and saved items |
| `votePoll` | signed in | One vote per poll (changeable only when the poll allows) |
| `submitStory`, `submitStartup`, `claimStartup` | verified | Submissions; answer "Your submission has been received and is awaiting editorial review." |
| `deleteAccount` | signed in, recent sign-in | Delete the account ([below](#privacy-and-account-deletion)) |
| `claimAdmin` | email in `ADMIN_EMAILS` | Grants editor access (custom claim `admin`) |
| `moderateComment`, `resolveReport`, `setUserStatus`, `savePoll`, `closePoll`, `reviewSubmission` | editors | Moderation |

Triggers and schedules: comment counters and reply notifications
(`onCommentWritten`), author name refresh (`onProfileUpdated`), submission
status notifications, `updatePollStatuses` (every 15 minutes),
`checkNewStories` (every 30 minutes: notifies followers of a topic, or of a
startup or founder named in a new story), `checkStartupChanges` (daily:
verified, featured and updated startups).

Errors carry a code the app turns into a plain message (signed out,
unverified email, rate limited, suspended, offline, and so on).

## Moderation and admin

There is deliberately **no web admin panel**: the Firebase console, which
already requires your Google sign-in and two-step verification, is the
admin tool. The server's triggers keep counts and notifications correct
when you edit documents there.

- **Comments:** Firestore → `comments` → filter `status == pending` →
  set `status` to `approved`, `rejected` or `removed`. Removed comments
  disappear from the app at once. To hold every new comment for review, set
  `premoderateComments: true` in `config/moderation`.
- **Held words:** `config/moderation.heldTerms` (array of strings) holds a
  comment containing any of them for review; `blockedUsernameTerms` refuses
  usernames; `newAccountHours` (default 24) holds links from new accounts.
- **Reports:** `reports` → filter `status == open`. Act on the content, then
  set `status` to `actioned` or `dismissed`. A report never removes
  anything by itself.
- **Suspending or banning:** `users/{uid}` → set `status` to `suspended`
  (with a `suspendedUntil` timestamp) or `banned`. For a ban also disable
  the person in Authentication → Users.
- **Submissions and claims:** open the document, set `status`
  (`under_review`, `accepted`, `rejected`, `published`; claims `approved` or
  `rejected`) and optionally `editorNote`. The sender is notified. Nothing
  is ever published automatically; write the story in WordPress as usual.
  An approved claim does **not** make a startup verified: verification
  stays in the WordPress directory.
- **Polls:** `polls` → Add document with `kind` (`poll` or `qotd`),
  `question`, `options` (array of maps `{id: "o1", label: "…"}`), `counts`
  (empty map), `totalVotes` 0, `status` `scheduled`, `publishAt` and
  optionally `expiresAt` (timestamps), `allowChange` (boolean). It goes
  live at `publishAt` and closes at `expiresAt`. Don't change options once
  people have voted.
- **Every editor action** through the callables is written to
  `moderationLog`.

Editor access is a token claim, never a field anyone can write. Only emails
listed in the `COMMUNITY_ADMIN_EMAILS` secret can claim it.

## Anti-spam and safety

- Rate limits per person: comments 4/minute, 30/hour, 100/day; submissions
  3/hour, 6/day; plus limits on every other action (reactions, likes,
  follows, votes, reports, blocks, profile changes, username checks).
- Comments with held words, or links from accounts younger than
  `newAccountHours`, wait for review. At most 2 links per comment.
- Commenting and submitting need a verified email.
- Block hides a person's comments and stops their replies notifying you;
  mute stops notifications only.
- Suspended and banned accounts can still read but can't post; a ban also
  signs them out everywhere.
- Notifications are deduplicated and follow each person's preferences
  (replies, likes, topic, startup and founder alerts, submission updates;
  marketing is off unless chosen).

## Privacy and account deletion

- Email addresses are never shown to other people or stored on profiles.
- Votes and reactions are private; only totals are public.
- Profiles can be private: the profile page is hidden from others.
- **Delete account** (Profile → Account settings) asks for the password (or
  Google) again, then: removes the profile, username, follows, saved items,
  notifications, devices and photos; takes back reactions, likes and votes
  so totals drop; empties the person's comments and shows them as
  "Deleted" (replies under them stay readable); removes contact details from their
  submissions; and finally deletes the sign-in account. The app says so
  plainly and only reports success when the server confirms it. Items
  saved on the phone itself stay until the app is uninstalled.

## Testing

```bash
flutter test                                  # app (fakes in test/helpers/fake_community.dart)
cd firebase/functions
npm ci && npm run lint && npm test            # server unit tests
npm run build && npm run test:emulator        # rules + functions on the emulators (needs Java 21, firebase-tools)
```

CI runs all three on every pull request.

## Migration and release

- **Safe to ship before setup.** With no `config/app` document every
  feature is off; the app is unchanged for readers.
- **No WordPress changes.** The server only reads the public REST API and
  the startup directory add-on.
- **Saved items** already on a phone are uploaded once when that person
  first signs in with `savedSync` on, and merged; nothing is deleted.
- **Rolling out:** switch on `accounts` + `communityProfiles` + `reactions`
  first, then `comments` (consider `premoderateComments: true` for the first
  weeks), then follows, polls, notifications and submissions.
- **Rolling back:** switch the feature off. Data is kept.
- **Deploying server changes:** Actions → Deploy community backend. Rules,
  indexes and functions are versioned in this repository.

## Not built yet

Kept out to avoid overbuilding; the data model leaves room for them:
badges and streaks, trending lists, startup comparison, the AI assistant,
an in-app moderation screen for editors, comment notifications by email,
and image uploads in comments.
