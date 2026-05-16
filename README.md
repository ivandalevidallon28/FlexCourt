# FlexCourt

Court reservations from both sides of the desk: players book slots with day/night pricing and clear states (pending → approved, rejected, or cancelled). Admins approve the queue, wrangle schedules, courts, categories, users, and ball rental stock.

Flutter on the front, Supabase for auth and data — plus Firebase Messaging if you’re using push.

---

### For players

Sign in or register, see your reservations and drill into one, browse courts, read in-app notifications, and use the ball rental list when equipment is part of your venue.

### For admins

Everything above, plus `/admin/*` routes. Access is enforced in `go_router`: only profiles with `role` set to `admin` stick around on admin URLs; everyone else gets bounced to home. Easiest sanity check after “why won’t Admin open?” is `lib/core/router/app_router.dart`.

---

### What’s in the box

Riverpod drives state; `go_router` handles URLs and redirects. Models use Freezed + `json_serializable` (so you’ll run `build_runner` when structs change). Theming supports light/dark; push uses `firebase_messaging` plus `flutter_local_notifications` for local surfaces.

Backend contract is plain Supabase (`supabase_flutter` initialization in `main.dart`).

---

### Before you run

Install Flutter and run `flutter doctor` until whatever platform you’re targeting looks happy. Dart is pinned via `pubspec.yaml` (`>=3.4.0`).

You’ll need a Supabase project URL and anon key for real data.

---

### Run locally

```bash
cd FlexCourt
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Values are read from `String.fromEnvironment` in `lib/core/constants/env.dart`. Use your own defines for staging/production; treat keys like passwords.

Push notifications need Firebase wired per platform (Android `google-services`, iOS/macOS plist and capabilities, etc.) — standard FlutterFire path.

---

### Codegen

Touching Freezed / JSON models:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Active refactors:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

---

### Where things live

`lib/core/` holds theme, env, routing, shared widgets. Each area under `lib/features/` (auth, courts, reservations, pricing, categories, ball rental, reservation change requests, notifications, admin) tends to mirror data/services/presentation splits as the app grew.

Deeper behaviour — overlap rules, rate bands, notification expectations — is spelled out under `lib/features/specs/` (start with `court_reservation_system.md` if you’re changing booking logic).

---

### CI you can run in five seconds

```bash
flutter analyze
flutter test
```

---

### Targets

Classic Flutter tree: `android/`, `ios/`, `macos/`, `web/`. Only wire the platforms you ship; messaging and backgrounds behave differently on each.

There’s no `LICENSE` in the root yet — add one if this goes public.
