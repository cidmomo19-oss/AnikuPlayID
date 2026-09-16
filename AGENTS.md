# AGENTS.md — AnikuPlay

Single source of truth for this repository. Every task/session must follow
it exactly. If a task's instructions ever conflict with this file, this
file wins.

## 1. What this is

AnikuPlay is a full anime streaming client: a Flutter mobile app backed by
a Cloudflare Workers API and Cloudflare D1 database. It has account-based
personalization, a YouTube-style watch page with likes/dislikes/comments,
offline downloads, and a lightweight gamification layer (achievements,
streaks, profile stats). Build it to the standard of a real commercial
product — consistent design, real tests, real error handling, no
placeholder/lorem-ipsum content anywhere in the shipped app.

## 2. Monorepo layout

```
/app      → Flutter client (Dart), package name com.anikuplay.app
/server   → Cloudflare Worker API (TypeScript, Hono, Drizzle ORM, D1)
/docs     → architecture notes, diagrams
```

## 3. Tech stack

| Layer | Choice |
|---|---|
| Mobile framework | Flutter (stable channel), null-safety |
| State management | Riverpod (`flutter_riverpod` + `riverpod_generator`) |
| Routing | `go_router` |
| Networking | `dio` (auth token attached via interceptor) |
| Secure storage | `flutter_secure_storage` (JWT) |
| Local DB | `drift` (offline cache + guest-mode bookmarks/history) |
| Models | `freezed` + `json_serializable` |
| Images | `cached_network_image` |
| Video | `video_player` (fully custom controls) |
| Icons | `lucide_icons` (consistent modern line-icon set, not default Material icons) |
| Sharing | `share_plus` |
| Notifications | `flutter_local_notifications` (download progress + local "new episode" alerts) |
| App icon | `flutter_launcher_icons` |
| Backend framework | `hono` on Cloudflare Workers |
| Auth | Stateless JWT via `jose`; passwords hashed with Web Crypto PBKDF2 (no native bcrypt on Workers — this is the correct edge-compatible approach) |
| ORM | `drizzle-orm` (D1/SQLite dialect) + `drizzle-kit` |
| Database | Cloudflare D1, binding name `DB` |
| Deploy | `wrangler` |
| CI | GitHub Actions |

## 4. Conventions

- UI-facing text is in Bahasa Indonesia, written in the professional tone
  from §12. Code, comments, commit messages, and PR descriptions are in
  English.
- Dart: Effective Dart style, `flutter analyze` must report zero issues.
  One feature per folder under `lib/features/<feature>/` with `view/`,
  `provider/`, `widgets/`. No hardcoded colors/sizes/radii outside
  `lib/core/theme/`.
- TypeScript: strict mode, no `any` without a comment justifying it. Route
  handlers stay thin; logic lives in `server/src/services/`.
- Add sensible indexes (Drizzle `index()`) on columns used in WHERE/JOIN
  frequently (e.g. `episode_reactions.episode_id`, `comments.episode_id`,
  `anime.status`).
- Every new provider/model/service/route gets at least one test.
- Never commit secrets. Anything sensitive is a Worker secret
  (`wrangler secret put`) or a Jules repo environment variable.

## 5. Commands

> **Cloudflare credentials are already available in this environment** as
> the environment variables `CLOUDFLARE_API_TOKEN` and
> `CLOUDFLARE_ACCOUNT_ID`. `wrangler` automatically authenticates using
> `CLOUDFLARE_API_TOKEN` when it is set — never run `wrangler login`, never
> ask the human for an API token or account ID, and never stop a task
> because Cloudflare auth "isn't set up." If a `wrangler` command fails
> with an auth error, first check the env vars are actually present
> (`echo $CLOUDFLARE_API_TOKEN | cut -c1-4`) before assuming they're
> missing — do not fall back to asking the human unless they are truly
> absent.

**/app**
```
flutter pub get
flutter analyze
flutter test
dart run flutter_launcher_icons   # only after assets/icon/icon.png exists
flutter build apk --release
```

**/server**
```
npm install
npm run typecheck
npm test
npx drizzle-kit generate
npx wrangler d1 migrations apply anikuplay-db --remote
npx wrangler deploy
```

A phase is not done until the relevant commands above pass cleanly.

## 6. Data model (Drizzle schema, D1/SQLite dialect)

```ts
// server/src/db/schema.ts
import { sqliteTable, integer, text, real, primaryKey, index } from 'drizzle-orm/sqlite-core';
import { sql } from 'drizzle-orm';

export const usersTable = sqliteTable('users', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  username: text('username').notNull().unique(),
  email: text('email').notNull().unique(),
  passwordHash: text('password_hash').notNull(), // format: "<saltHex>:<hashHex>"
  createdAt: text('created_at').default(sql`CURRENT_TIMESTAMP`),
});

export const animeTable = sqliteTable('anime', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  title: text('title').notNull(),
  alternativeTitle: text('alternative_title').default(''),
  posterUrl: text('poster_url').default(''),
  bannerUrl: text('banner_url').default(''),
  synopsis: text('synopsis').default(''),
  studio: text('studio').default(''),
  year: integer('year').default(0),
  season: text('season').default(''),
  type: text('type').default('TV'),
  status: text('status').default('Ongoing'), // 'Ongoing' | 'Completed'
  rating: real('rating').default(0), // editorial rating, set by admin
  viewCount: integer('view_count').default(0),
  createdAt: text('created_at').default(sql`CURRENT_TIMESTAMP`),
  updatedAt: text('updated_at').default(sql`CURRENT_TIMESTAMP`),
}, (t) => ({ statusIdx: index('anime_status_idx').on(t.status) }));

export const genresTable = sqliteTable('genres', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  name: text('name').notNull().unique(),
});

export const animeGenresTable = sqliteTable('anime_genres', {
  animeId: integer('anime_id').notNull().references(() => animeTable.id, { onDelete: 'cascade' }),
  genreId: integer('genre_id').notNull().references(() => genresTable.id, { onDelete: 'cascade' }),
}, (t) => ({ pk: primaryKey({ columns: [t.animeId, t.genreId] }) }));

export const episodesTable = sqliteTable('episodes', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  animeId: integer('anime_id').notNull().references(() => animeTable.id, { onDelete: 'cascade' }),
  episodeNumber: integer('episode_number').notNull(),
  title: text('title').default(''),
});

export const episodeSourcesTable = sqliteTable('episode_sources', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  episodeId: integer('episode_id').notNull().references(() => episodesTable.id, { onDelete: 'cascade' }),
  quality: text('quality').notNull(), // '480p' | '720p' | '1080p'
  url: text('url').notNull(),
});

export const episodeReactionsTable = sqliteTable('episode_reactions', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  episodeId: integer('episode_id').notNull().references(() => episodesTable.id, { onDelete: 'cascade' }),
  userId: integer('user_id').notNull().references(() => usersTable.id, { onDelete: 'cascade' }),
  type: text('type').notNull(), // 'like' | 'dislike'
  createdAt: text('created_at').default(sql`CURRENT_TIMESTAMP`),
}, (t) => ({
  uniq: primaryKey({ columns: [t.episodeId, t.userId] }),
  epIdx: index('reactions_episode_idx').on(t.episodeId),
}));

export const commentsTable = sqliteTable('comments', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  episodeId: integer('episode_id').notNull().references(() => episodesTable.id, { onDelete: 'cascade' }),
  userId: integer('user_id').notNull().references(() => usersTable.id, { onDelete: 'cascade' }),
  body: text('body').notNull(),
  createdAt: text('created_at').default(sql`CURRENT_TIMESTAMP`),
}, (t) => ({ epIdx: index('comments_episode_idx').on(t.episodeId) }));

export const userBookmarksTable = sqliteTable('user_bookmarks', {
  userId: integer('user_id').notNull().references(() => usersTable.id, { onDelete: 'cascade' }),
  animeId: integer('anime_id').notNull().references(() => animeTable.id, { onDelete: 'cascade' }),
  createdAt: text('created_at').default(sql`CURRENT_TIMESTAMP`),
}, (t) => ({ pk: primaryKey({ columns: [t.userId, t.animeId] }) }));

export const userWatchProgressTable = sqliteTable('user_watch_progress', {
  userId: integer('user_id').notNull().references(() => usersTable.id, { onDelete: 'cascade' }),
  animeId: integer('anime_id').notNull().references(() => animeTable.id, { onDelete: 'cascade' }),
  episodeNumber: integer('episode_number').notNull(),
  positionSeconds: integer('position_seconds').default(0),
  durationSeconds: integer('duration_seconds').default(0),
  updatedAt: text('updated_at').default(sql`CURRENT_TIMESTAMP`),
}, (t) => ({ pk: primaryKey({ columns: [t.userId, t.animeId] }) }));

export const viewEventsTable = sqliteTable('view_events', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  animeId: integer('anime_id').notNull(),
  episodeId: integer('episode_id'),
  createdAt: text('created_at').default(sql`CURRENT_TIMESTAMP`),
});

export const achievementsTable = sqliteTable('achievements', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  code: text('code').notNull().unique(),
  title: text('title').notNull(),
  description: text('description').notNull(),
  icon: text('icon').notNull(), // lucide icon name, e.g. 'trophy'
});

export const userAchievementsTable = sqliteTable('user_achievements', {
  userId: integer('user_id').notNull().references(() => usersTable.id, { onDelete: 'cascade' }),
  achievementId: integer('achievement_id').notNull().references(() => achievementsTable.id, { onDelete: 'cascade' }),
  unlockedAt: text('unlocked_at').default(sql`CURRENT_TIMESTAMP`),
}, (t) => ({ pk: primaryKey({ columns: [t.userId, t.achievementId] }) }));
```

## 7. API contract

Envelope: lists → `{ "data": [...], "meta": {...} }`, single items →
`{ "data": {...} }`, errors → `{ "error": { "message": "..." } }` with the
matching HTTP status.

**Public**
| Method | Path | Notes |
|---|---|---|
| GET | `/api/health` | `{status:"ok"}` |
| GET | `/api/anime` | `q, genre, status, sort(latest\|rating\|trending), page, limit` |
| GET | `/api/anime/:id` | full detail incl. episodes, each with reaction counts + comment count |
| GET | `/api/genres` | |
| POST | `/api/anime/:id/view` | increments `view_count`, logs a `view_events` row |
| GET | `/api/episodes/:id/comments` | `page, limit`, newest first |

**Auth-required** (`Authorization: Bearer <JWT>`)
| Method | Path | Notes |
|---|---|---|
| POST | `/api/auth/register` | `{username, email, password}` → `{token, user}` |
| POST | `/api/auth/login` | `{email, password}` → `{token, user}` |
| GET | `/api/me` | profile + computed stats (see §13) |
| GET | `/api/me/bookmarks` | |
| PUT | `/api/me/bookmarks/:animeId` | add |
| DELETE | `/api/me/bookmarks/:animeId` | remove |
| PUT | `/api/me/history/:animeId` | upsert `{episodeNumber, positionSeconds, durationSeconds}` |
| DELETE | `/api/me/history/:animeId` | |
| POST | `/api/episodes/:id/comments` | `{body}` |
| DELETE | `/api/comments/:id` | only own comment (or admin) |
| PUT | `/api/episodes/:id/reaction` | `{type: 'like'\|'dislike'\|null}` (null removes it) |

**Admin** (`Authorization: Bearer <ADMIN_TOKEN>`)
| Method | Path | Notes |
|---|---|---|
| POST/PUT/DELETE | `/api/admin/anime[/:id]` | as before |
| POST | `/api/admin/anime/:id/episodes` | |
| GET | `/api/admin/analytics` | views/day for last 14 days + top 5 anime, powers the dashboard chart |
| GET | `/admin` | HTML dashboard: CRUD tables + a Chart.js (CDN `<script>`, no bundler) bar chart from `/api/admin/analytics` |

## 8. Auth implementation notes

- Password hashing: generate a random 16-byte salt, derive with
  `crypto.subtle.deriveBits` using PBKDF2-SHA256, 100,000 iterations, store
  as `"<saltHex>:<hashHex>"` in `passwordHash`. Do not use `bcrypt`
  (native bindings don't run on Workers) — pure Web Crypto only.
- JWT: sign with `jose`'s `SignJWT`, HS256, secret from Worker secret
  `JWT_SECRET` (generate a random 32+ char value and `wrangler secret put`
  it, same pattern as `ADMIN_TOKEN`). Payload: `{sub: userId}`, 30-day
  expiry. A Hono middleware verifies it and attaches the user to context
  for every auth-required route.
- Browsing and watching anime never requires login. Login is required only
  for: bookmarking, history sync, reactions, comments, and the profile
  screen. Guests still get local-only bookmarks/history via `drift`; on
  login, merge local data into the server and switch to server as source
  of truth.

## 9. Design system

**Themes**: support both dark (default) and light, toggle in Settings.
```dart
// dark
violet=0xFF7C5CFC magenta=0xFFFF4FA0 cyan=0xFF22E5C8 gold=0xFFFFC94D
bgBase=0xFF0A0A10 surface1=0xFF17171F textPrimary=0xFFF5F5FA textSecondary=0xFFACACC2
// light
bgBase=0xFFF7F6FA surface1=0xFFFFFFFF textPrimary=0xFF14141C textSecondary=0xFF5A5A6E
// violet/magenta/cyan/gold accents stay identical in both themes
```
Spacing scale: 4/8/12/16/24/32. Corner radii: 10/14/18/24/32 (xs→xl).
Icons: `lucide_icons` package everywhere (no default Material icon set) for
a consistent, premium line-icon look.

**Elevation**: use soft shadows (`BoxShadow` blur 16-24, opacity ≤0.25,
violet-tinted on dark theme) instead of Material's default elevation tint.

**Every screen defines three states explicitly**: loading (shimmer, never
a bare spinner for list content), empty (icon + one-line copy from §12),
error (icon + retry button). No screen may silently show a blank page.

**App icon**: the user will upload a 1024×1024 PNG to `app/assets/icon/icon.png`
directly in the repo. If that file exists, configure and run
`flutter_launcher_icons` against it. If it does not exist yet when a task
runs, skip icon generation, keep Flutter's default icon, and say clearly in
the PR description that icon generation is pending that upload.

## 10. Player screen layout (this is the most detail-sensitive screen — follow it exactly)

Portrait by default. Structure, top to bottom:

1. **Video area** (fixed at top, 16:9): custom `video_player` controls —
   play/pause, seek bar, ±10s skip, speed cycle, quality switcher, and a
   **fullscreen button** that manually rotates to landscape fullscreen
   (orientation is never changed automatically — only via this button).
   In fullscreen, everything below is hidden; a collapse button returns to
   portrait.
2. **Header row**: small rounded poster thumbnail (56×56) + anime title +
   "Episode N" subtitle, below the video.
3. **Action row**: Like button with count, Dislike button with count (both
   highlight the user's current choice; tapping while logged out opens a
   login prompt sheet instead of failing silently), Download button
   (same download flow as the Detail screen), Episode picker button (opens
   a bottom sheet listing all episodes; tapping one switches playback
   in place, no navigation).
4. **Comments section**: header with live count, a comment input (disabled
   with a "Masuk untuk berkomentar" prompt if logged out), then the
   paginated comment list (avatar placeholder, username, timestamp, body),
   "muat lebih banyak" at the bottom.

Everything from step 2 downward lives in one scrollable column below the
fixed video area.

## 11. Gamification

**Achievements** (seed these into the `achievements` table):
| code | title | condition |
|---|---|---|
| first_watch | Penonton Pertama | completed 1 episode |
| binge_starter | Maraton Dimulai | 5+ episodes watched in one calendar day |
| night_owl | Night Owl | watched an episode between 00:00–04:00 |
| genre_explorer | Penjelajah Genre | watched anime from 3+ distinct genres |
| collector | Kolektor | 10+ bookmarks |
| critic | Kritikus | posted 5+ comments |

Compute achievement unlocks server-side in `GET /api/me` (check conditions
against `user_watch_progress`/`user_bookmarks`/`comments`, insert into
`user_achievements` if newly met, return the full unlocked list). Show a
toast (copy in §12) client-side when a new one appears compared to the
last fetch.

**Streak**: consecutive days with at least one `user_watch_progress` update,
computed server-side, returned in `GET /api/me` as `streakDays`.

**Profile screen** shows: avatar placeholder, username, streak, total
episodes watched, total hours watched, bookmark count, and an achievement
grid (locked ones shown greyed out with their condition as a hint).

## 12. Voice & copy

Tone: confident, warm, concise — like a real product, never robotic
placeholder text. Use these (or close variants) directly:

- Onboarding tagline: "Nonton anime favoritmu, kapan saja, di mana saja."
- Empty bookmarks: "Belum ada koleksi tersimpan. Yuk, mulai jelajahi dan simpan anime favoritmu di sini."
- Empty history: "Riwayat tontonanmu akan muncul di sini setelah kamu mulai menonton."
- Empty comments: "Jadilah yang pertama berkomentar di episode ini."
- Login prompt (comment/reaction): "Masuk untuk bergabung dalam diskusi."
- Achievement unlock toast: "🏆 Lencana baru terbuka: {judul lencana}!"
- Offline/error state: "Koneksi terputus. Menampilkan data tersimpan terakhir."
- About screen: "AnikuPlay dibangun dengan Flutter dan Cloudflare Workers, dirancang untuk pengalaman menonton anime yang cepat, mulus, dan modern."

## 13. `/api/me` response shape

```ts
type MeResponse = {
  id: number; username: string; email: string;
  streakDays: number; episodesWatched: number; hoursWatched: number; bookmarkCount: number;
  achievements: { code: string; title: string; description: string; icon: string; unlockedAt: string | null }[];
};
```

## 14. Navigation map

```
/                          Home
/search                    Search
/genres, /genres/:genre    Genre browsing
/detail/:id                Anime detail
/player/:animeId/:ep       Watch page (see §10)
/history  /bookmarks  /downloads
/login  /register
/profile  /settings
/onboarding                first-launch only
```

## 15. Seed data

Use these 4 fictional titles (never substitute real/copyrighted anime),
with Google's public sample videos and picsum.photos placeholder posters
(both guaranteed to resolve):

```ts
export const seedAnime = [
  { title: "Shadow Ronin: Ashes of Kaen", alternativeTitle: "Kage no Ronin",
    posterUrl: "https://picsum.photos/seed/anikuplay1/400/600",
    synopsis: "A nameless ronin rises from the ruins of a fallen empire to confront his own past while protecting the last standing village from a shadow that hunts every night.",
    genres: ["Action", "Fantasy", "Drama"], studio: "Studio Nightfall",
    year: 2024, season: "Fall", type: "TV", status: "Ongoing", rating: 8.4,
    episodes: [
      { episodeNumber: 1, sources: [
        { quality: "480p", url: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4" },
        { quality: "720p", url: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4" }] },
      { episodeNumber: 2, sources: [
        { quality: "480p", url: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4" },
        { quality: "720p", url: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4" }] } ] },
  { title: "Starlight Academy", alternativeTitle: "Hoshikage Gakuen",
    posterUrl: "https://picsum.photos/seed/anikuplay2/400/600",
    synopsis: "Five members of an astronomy club build a homemade telescope while surviving exams, crushes, and a school festival gone sideways.",
    genres: ["Slice of Life", "Romance", "Comedy"], studio: "Wonder Frame",
    year: 2023, season: "Spring", type: "TV", status: "Completed", rating: 7.9,
    episodes: [
      { episodeNumber: 1, sources: [
        { quality: "480p", url: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4" },
        { quality: "720p", url: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4" }] } ] },
  { title: "Ashen Skies Chronicle", alternativeTitle: "Haikai no Sora",
    posterUrl: "https://picsum.photos/seed/anikuplay3/400/600",
    synopsis: "A world torn apart by giant-mecha war; a young pilot finds a prototype unit hiding the truth of who started it all.",
    genres: ["Sci-Fi", "Mecha", "Action"], studio: "Ironclad Motion",
    year: 2025, season: "Winter", type: "TV", status: "Ongoing", rating: 8.8,
    episodes: [
      { episodeNumber: 1, sources: [
        { quality: "480p", url: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4" },
        { quality: "720p", url: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4" }] } ] },
  { title: "Whispering Pines High", alternativeTitle: "Sasayaku Matsu Gakuen",
    posterUrl: "https://picsum.photos/seed/anikuplay4/400/600",
    synopsis: "Four transfer students find their new school's urban legend is real — and every student who ignores it disappears.",
    genres: ["Mystery", "Supernatural", "Drama"], studio: "Pale Moon Works",
    year: 2022, season: "Summer", type: "TV", status: "Completed", rating: 7.5,
    episodes: [
      { episodeNumber: 1, sources: [
        { quality: "480p", url: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4" },
        { quality: "720p", url: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4" }] } ] },
];
```

## 16. Font

Manrope, bundled as a build-time asset — never fetched at runtime (this has
caused a real crash before, do not repeat it):
1. Download `https://github.com/google/fonts/raw/main/ofl/manrope/Manrope%5Bwght%5D.ttf`.
2. Verify the first bytes are `00 01 00 00`, `true`, or `OTTO` — abort if not.
3. Commit as `app/assets/fonts/Manrope.ttf`.
4. Register once per weight (400/500/600/700/800) in `pubspec.yaml`, all
   pointing at the same file (standard Flutter variable-font pattern).

## 17. Definition of done (every phase)

- [ ] All relevant commands in §5 pass cleanly.
- [ ] No hardcoded design values outside `lib/core/theme/`.
- [ ] Every screen has explicit loading/empty/error states (§9).
- [ ] No `TODO`/`FIXME` without a follow-up note in the PR description.
- [ ] No secrets committed; PR description lists any manual step needed
      (new secret to set, asset to upload, etc.).
- [ ] New backend routes have tests; new Flutter providers/models have tests.
