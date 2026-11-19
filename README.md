# Movie Tracker

Movie Tracker is a Flutter mobile app that lets users discover movies, keep a
watch journal with ratings and reviews, build watchlists and shared lists with
voting, follow actors, get recommendations and chat in a moderated forum.

Movie Tracker est une application mobile Flutter pour découvrir des films, tenir
un journal de visionnage, composer des listes (seul ou à plusieurs) et échanger
avec une communauté de cinéphiles.

## Features

| Module | Content |
|---|---|
| 1. Users | Sign up / sign in, editable database-backed profile and genre preferences, settings, live viewing dashboard with monthly activity, shareable recap calculated from the viewing journal |
| 2. Catalog | Home with featured movies, search with infinite scroll, filters, genres, movie details, where to watch, search history |
| 3. Journal | Log viewings with dates, ratings, notes and rewatch status; publish and read movie reviews |
| 4. Lists | To watch and favorites, custom lists, shared lists with invitation and votes, "What to watch tonight?" picker |
| 5. People | TMDB cast and actor profiles, persistent followed actors, filmographies, and personalized recommendations based on followed actors, favorites, ratings, and watch history |
| 6. Forum | Live-refreshing discussions, replies, likes, message reports, moderator review, content removal and reversible member restrictions |

## Design

Cinema theme inspired by Pathé: cinema red `#E30613` on near-black `#111114`.
All colors come from one palette file (`lib/core/theme/app_palette.dart`), with
a dark theme by default and an optional light theme. Fonts: Poppins (titles)
and Inter (text).

## Tech stack

- Flutter 3.x / Dart
- State management: flutter_riverpod
- Navigation: go_router (ShellRoute with a 5-tab bottom bar)
- Sharing: share_plus · Images: cached_network_image
- Tests: flutter_test, mocktail
- Data: TMDB provides movie data; the Node.js API with SQLite stores accounts,
  sessions, watchlists, favorites, custom lists, viewing entries, reviews, and
  review helpful votes, discussions, reports, and moderation restrictions.

## Architecture

Feature-based architecture. Modules communicate only through public interfaces
in `lib/shared/contracts`.

```
lib/
  core/               theme, router, shared widgets, utilities
  shared/contracts/   public interfaces of the 6 modules
  features/
    users/ catalog/ journal/ lists/ people/ forum/   (presentation, domain, data)
test/                 unit tests of the business logic
```

## Run the project

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

To run on Chrome: `flutter run -d chrome`.

Copy `assets/.env.example` to `assets/.env` and set your TMDB key and API URL:

```dotenv
TMDB_API_KEY=your_key
API_BASE_URL=http://localhost:3000/api
```

Run Flutter Web on any local port; the development CORS configuration accepts
`localhost` and `127.0.0.1` origins:

```bash
flutter run -d chrome --web-port=5000
```

For the Android emulator use `API_BASE_URL=http://10.0.2.2:3000/api`.
For a physical device, use your computer's LAN IP and configure that exact
origin in `backend/.env`. The wildcard localhost CORS entries are for
development only; production should use an explicit list of trusted origins.
The Android debug build permits local HTTP; production must use HTTPS.
`assets/.env` is ignored by Git. Without a TMDB key, movie data is not displayed.
The key is still bundled into the mobile app and can be extracted from its
binary. For production, proxy TMDB requests through a backend instead of
distributing a private key in the mobile app.

## Account API

The Node.js API uses SQLite and stores its database under `backend/data/` by
default. From the `backend/` directory:

```bash
npm install
```

Create `.env` from `.env.example`, then replace `JWT_SECRET` with a random
secret of at least 32 characters. In PowerShell, you can generate one locally
without sharing or committing it:

```powershell
Copy-Item .env.example .env
$secret = node -e "process.stdout.write(require('node:crypto').randomBytes(48).toString('base64url'))"
(Get-Content .env) -replace '^JWT_SECRET=.*$', "JWT_SECRET=$secret" |
  Set-Content .env
```

Then start the API:

```bash
npm start
```

The API is available at `http://localhost:3000/api`. Create an account in the
app to save a profile, watchlist, favorites, custom lists, journal entries,
reviews, and statistics per user. Journal and review routes are authenticated
and use the signed-in account; movie reviews can be read publicly.
Followed TMDB people and dismissed recommendations are also saved per account.
The recommendation feed ranks filmographies from followed actors and genres
derived from favorites, positive reviews, and highly rated journal entries,
then filters out watched, saved, and dismissed movies.

On the first API startup, the server creates the single moderator account
`admin@admin.com` with password `admin`. Sign in with those credentials in the
app to review reports, remove content, restrict members, and lift restrictions.
The server ignores moderator-role values from sign-up requests and ensures this
is the only moderator account.

The default password is intentionally convenient for local development and
must be changed before exposing the API to a network. Set `ADMIN_PASSWORD` in
`backend/.env` before the first startup to choose a different initial password.
The password is hashed in SQLite and is not reset when the API restarts.
Forum reports and moderation actions are stored in SQLite; the moderator can
review pending and historical reports.

Watchlists and favorites are private to each account. Custom lists can be
private or shared. To invite someone, enable sharing and enter the email
address of an existing account; access is added immediately (there is no
pending invitation or email delivery). The owner can invite or remove members,
and delete the list. Owners and invited members can add or remove movies;
members can leave a list at any time.

Run `npm test` from `backend/` to verify authentication, journal persistence,
review validation, forum moderation permissions, and account-data isolation.

This product uses the TMDB API but is not endorsed or certified by TMDB.
Streaming availability data is provided by JustWatch.

## Team

Project by a team of 6 students, one module per member.
