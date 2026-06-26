# AgriPulse — Frontend (Flutter)

The mobile/web client. Talks ONLY to the core backend (`../backend`) over REST.

Each role logs into a **persistent, multi-page dashboard** — a responsive shell
with a left navigation rail (web/desktop/tablet) that collapses to a bottom
navigation bar on phones. There is no more "flash-card" home: the landing page
is a real overview with live KPIs and shortcuts, and every feature is a section
within the shell.

```
lib/
├── main.dart                      # app entry + role-based routing
├── config.dart                    # API base URL  ← EDIT THIS for your device
├── core/
│   └── shell/
│       └── role_shell.dart        # responsive NavigationRail ↔ NavigationBar shell
├── shared/
│   ├── models/                    # user.dart, post.dart, product.dart
│   ├── services/
│   │   ├── api_service.dart       # HTTP client: base URL, JWT header, JSON, errors
│   │   └── auth_service.dart      # register / login / logout / auto-login
│   └── widgets/common.dart        # shell widgets: PageBody, StatCard, QuickAction…
├── theme/app_theme.dart           # formal green & white theme
└── roles/
    ├── auth/                      # login + register
    ├── farmer/                    # dashboard shell + pages/overview + feature screens
    ├── seller/                    # dashboard shell + pages/ (overview, products, orders, weather&alerts)
    ├── analyst/                   # dashboard shell + pages/ (overview, analytics, broadcasts, monitoring, requests)
    └── community/community_screen.dart   # shared feed (all roles)
```

## Architecture: the dashboard shell

`RoleShell` ([core/shell/role_shell.dart](lib/core/shell/role_shell.dart)) takes a
list of `ShellDestination`s (label + icons + page) and renders one persistent
dashboard:

- **wide screens** → a `NavigationRail` that extends to a labelled sidebar;
- **narrow screens** → a bottom `NavigationBar`;
- pages are kept alive in an `IndexedStack` (scroll position / input preserved);
- a page can switch sections with `RoleShell.of(context)!.goTo(index)` — used by
  the overview "quick action" cards.

Each role's `*_dashboard.dart` just declares its destinations; the per-section UI
lives under that role's `pages/` folder (plus the shared farmer feature screens).

## Run it
1. Start the backend (and AI service) first — see [`../backend/README.md`](../backend/README.md).
2. Set the API URL in [lib/config.dart](lib/config.dart):
   - Android emulator → `http://10.0.2.2:8000`
   - iOS simulator / web / desktop → `http://localhost:8000`
   - Real phone → your computer's LAN IP, e.g. `http://192.168.0.10:8000`
3. ```bash
   cd frontend
   flutter pub get
   flutter run -d chrome      # or pick another device with: flutter run
   ```
4. Log in with a seeded account (password `Pass1234`), e.g. `farmer1@agripulse.com`.

## Android: allow HTTP in development
Android blocks cleartext HTTP by default. For local testing add to
`android/app/src/main/AndroidManifest.xml` inside `<application ...>`:
```xml
android:usesCleartextTraffic="true"
```
(Use HTTPS in production.)

> `android/`, `ios/`, `web/` platform folders aren't included. Generate them once with
> `flutter create .` from inside `frontend/` (it keeps existing `lib/` and `pubspec.yaml`).
