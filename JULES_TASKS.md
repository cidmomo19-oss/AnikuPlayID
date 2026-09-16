# Jules task queue — AnikuPlay

Run **one phase at a time**. Wait for the PR, review it, merge to `main`
before starting the next phase — later phases assume earlier code already
exists on `main`. Every phase already tells Jules to read `AGENTS.md`
first; that file has the full spec (schema, API contract, design system,
player layout, gamification, copy). Don't skip ahead even if a phase looks
done faster than expected.

Before Phase 1: if you have the app icon ready, upload it now to
`app/assets/icon/icon.png` (1024×1024 PNG) directly in the repo — it'll get
picked up automatically once `/app` exists. If not ready yet, upload it any
time before Phase 5.

---

### Phase 1 — Backend: schema, auth, API, admin dashboard, deploy

Read AGENTS.md first (§2–§8, §11, §13, §15).

In `/server`, build the entire backend in one pass:
- Scaffold with Hono + TypeScript (`npm create cloudflare@latest`), add
  `drizzle-orm`, `drizzle-kit`, `jose`, `vitest`, `@cloudflare/vitest-pool-workers`.
- Implement the full Drizzle schema from AGENTS.md §6 (all tables,
  including users, reactions, comments, bookmarks, watch progress, view
  events, achievements). Generate and apply the migration. Create the D1
  database `anikuplay-db` if it doesn't already exist (check with
  `wrangler d1 list` first) and wire the binding `DB` in `wrangler.toml`.
- Implement every endpoint in AGENTS.md §7 (public, auth-required, admin),
  following the auth implementation notes in §8 exactly (PBKDF2 via Web
  Crypto, JWT via `jose`, `JWT_SECRET` and `ADMIN_TOKEN` as Worker secrets
  — generate random values for both and print them in the PR description).
  Implement the `/api/me` stats + achievement-unlock computation logic
  described in §11/§13.
- Build `server/scripts/seed.ts`: inserts the 4 anime from §15 (idempotent,
  check by title) and the 6 achievements from §11 (idempotent, check by
  code). Add an npm `seed` script and run it against the remote database.
- Build the `/admin` HTML dashboard: token-gated (prompt once, store in
  localStorage), CRUD tables for anime/episodes, and a bar chart (Chart.js
  via CDN `<script>` tag, no bundler) rendering `/api/admin/analytics`.
- Write Vitest tests for every route (happy path + at least one error case
  each) against local Miniflare D1.
- Deploy with `wrangler deploy` and confirm `/api/health` returns 200.

Acceptance: `npm run typecheck && npm test` pass; `npm run seed` is
idempotent (running twice doesn't duplicate rows); deployed `/api/health`
returns `{"status":"ok"}`; PR description includes the generated
`ADMIN_TOKEN` and confirms `JWT_SECRET` was set.

---

### Phase 2 — Flutter foundation + core browsing

Read AGENTS.md first (§3, §6–§7, §9, §12, §14, §16).

In `/app`:
- `flutter create` with package `com.anikuplay.app`, app display name
  "AnikuPlay". Add every dependency listed in AGENTS.md §3.
- Theme (`lib/core/theme/`): dark + light palettes, spacing/radius scale,
  elevation style, all exactly per §9. Bundle the Manrope font per §16
  (download → verify → commit → register, never fetch at runtime).
- App icon: if `assets/icon/icon.png` exists, configure and run
  `flutter_launcher_icons`; if not, skip and note it's pending in the PR.
- Models matching AGENTS.md §7/§13 (`Anime`, `AnimeSummary`, `Episode`,
  `EpisodeSource`, `Genre`, `User`, `Comment`, `MeStats`, `Achievement`) as
  `freezed`/`json_serializable` classes.
- `lib/data/api/`: `dio` client with a method per endpoint in §7, plus an
  interceptor that attaches `Authorization: Bearer <token>` from
  `flutter_secure_storage` when a token is present.
- `lib/data/local/`: `drift` database — `CachedAnimeEntry`,
  `WatchHistoryEntry`, `BookmarkEntry`, `DownloadEntry` (guest-mode local
  storage; becomes a cache/fallback once auth lands in Phase 3).
- `go_router` registering every route in AGENTS.md §14. Fully implement
  Home, Search, Genres, and Detail (with bookmark toggle against local
  drift for now). All other routes (`/login`, `/register`, `/player/...`,
  `/history`, `/bookmarks`, `/downloads`, `/profile`, `/settings`) get a
  simple placeholder screen so navigation never crashes — they're built in
  later phases.
- A 3-slide onboarding flow (`/onboarding`) shown once on first launch
  (persist a flag locally), using the taglines from §12, skippable.
- Every implemented screen has explicit loading (shimmer)/empty/error
  states per §9. Widget tests for Home, Search, Detail covering those
  states.

Acceptance: `flutter analyze` reports zero issues; `flutter test` passes;
the app launches to onboarding then Home, and every route in the nav map
opens something (even if a placeholder) without crashing.

---

### Phase 3 — Auth, YouTube-style player, reactions, comments, downloads

Read AGENTS.md first (§8, §10, §12) very carefully — §10 (player layout) is
exact, follow it precisely.

In `/app`:
- **Auth**: Login/Register screens with validation and API-error display,
  an `authProvider` (Riverpod) storing the JWT via `flutter_secure_storage`.
  On successful login, merge any local guest bookmarks/history into the
  server (call the sync endpoints), then switch bookmark/history providers
  to be server-backed (falling back to local drift when offline).
- **Player screen** (`/player/:animeId/:ep`), replacing the Phase 2
  placeholder — build exactly the layout in AGENTS.md §10: fixed video area
  on top with custom controls including a manual fullscreen toggle button
  (never auto-rotate), then a scrollable column below with the header row,
  action row (like/dislike with counts and highlighted state — logged-out
  taps open a login-prompt sheet, copy from §12), episode-picker bottom
  sheet, and the comments section (gated input, paginated list, "muat
  lebih banyak"). Resume playback from saved position (server if logged
  in, else drift), save position every 8s and on dispose, and call the
  view-increment endpoint once per playback session.
- **Downloads**: a download button per episode/resolution — add it to both
  the Detail screen's episode list (built in Phase 2) and the player's
  action row, sharing one underlying provider. Stream to local storage via
  `dio` with a progress notification (`flutter_local_notifications`),
  record it in the `DownloadEntry` drift table, and build the real
  **Downloads** screen (`/downloads`) listing offline episodes playable
  with no network. Handle Android storage/notification permissions for
  API 24+.
- Replace the History and Bookmarks placeholders with real screens reading
  from the now-synced providers.

Acceptance: `flutter analyze` and `flutter test` pass; a fresh account can
register, watch an episode, like it, post a comment, download an episode,
and see it play in airplane mode.

---

### Phase 4 — Gamification, profile, settings

Read AGENTS.md first (§11, §12).

In `/app`:
- **Profile** (`/profile`): stats and achievement grid from `/api/me`
  (locked achievements shown greyed out with their condition as a hint),
  streak display. Show the unlock toast from §12 when the achievement list
  gains an entry compared to the last fetch (cache the previous list
  locally to diff against).
- **Settings** (`/settings`): theme toggle (light/dark), logout, "clear
  local cache" action, About section using the copy from §12, app version.
- Apply the light theme across every existing screen and verify contrast.
- Share button on Detail (via `share_plus`) sharing the anime title + a
  plain descriptive link/text.
- A lightweight "new episode" local notification: on app foreground, if a
  bookmarked anime's episode count increased since the last time it was
  fetched (compare against the cached count in drift), fire a local
  notification. No push/server infrastructure needed.

Acceptance: `flutter analyze` and `flutter test` pass; manually watching
one episode on a fresh account unlocks "Penonton Pertama" and shows the
toast; light theme has no unreadable text/contrast issues.

---

### Phase 5 — Motion & visual polish

Read AGENTS.md first (§9, §10) — implement the motion feel exactly, don't
improvise something looser or bouncier.

Across `/app`:
- Implement a custom `ScrollPhysics` with non-linear rubber-band
  resistance (grows as you pull further, max stretch ≈56 logical px,
  spring-back ~300ms, subtle not cartoonish) and apply it to every
  scrollable list/grid.
- Consistent fade+slide page transitions across all `go_router` routes.
- A shared "press-scale" wrapper (scale to ~0.94 grid / ~0.97 rows on
  tap-down, spring back on release) applied to every tappable card.
- If `assets/icon/icon.png` wasn't available in Phase 2, check again now
  and run `flutter_launcher_icons` if it exists.
- Full QA pass: hunt down any remaining hardcoded colors/spacing outside
  the theme tokens, and any screen missing a loading/empty/error state,
  and fix them.

Acceptance: `flutter analyze` and `flutter test` pass; no visual
regressions in existing widget tests; overscroll feels smooth, not
exaggerated, on a manual scroll test.

---

### Phase 6 — CI/CD, release, and docs

In the repo root:
- `.github/workflows/ci.yml`: keep the lint/test jobs for both packages,
  add a release job that builds `flutter build apk --release` on `v*` tag
  pushes and attaches it to a GitHub Release, and a `/server` deploy job
  (`wrangler deploy`) on merge to `main` using the `CLOUDFLARE_API_TOKEN`
  already available in this repo's environment.
- Rewrite the root `README.md` as a proper project showcase: short pitch,
  full feature list, tech stack table, a mermaid diagram of app ↔ Worker ↔
  D1, setup instructions for a new contributor, and a placeholder section
  for screenshots.

Acceptance: pushing a `v0.1.0` tag produces a downloadable APK on GitHub
Releases; merging to `main` redeploys the Worker automatically; README
reads like a real product page.

---

## Later ideas (not scheduled — only if you want to keep going after Phase 6)

- Push notifications via Firebase Cloud Messaging (the local-notification
  version in Phase 4 is a no-infrastructure approximation of this).
- "Similar anime" recommendations on Detail based on shared genres.
- Admin moderation tools for comments (hide/delete from the dashboard).
