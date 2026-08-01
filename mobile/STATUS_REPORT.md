# Sudanile Kitchen — Mobile App Status Report

**Scope:** `mobile/` (Flutter client)
**Reviewed:** 2026-07-26
**Method:** Full read of `lib/`, `test/`, `pubspec.yaml`; cross-checked API calls against `backend/*/urls.py`; ran `flutter analyze` and `flutter test` live.

---

## 1. What this app is

Sudanile Kitchen is a Flutter client for a South Sudanese recipe platform. It talks to a Django REST backend (`../backend`) over plain `http` (package `http`, not `dio`), holds session state with `provider`, and persists the JWT access token with `shared_preferences`. There is no `android/`, `ios/`, `web/`, `macos/`, `windows/`, or `linux/` folder in the repo — they're intentionally git-ignored (see `.gitignore`) and haven't been generated locally, so `flutter run` won't work out of the box (see §4.1).

### Tech stack
| Concern | Package | Notes |
|---|---|---|
| State management | `provider` ^6.1.2 | Two providers: `AuthService`, `FavoritesProvider` |
| HTTP | `http` ^1.3.0 | Hand-rolled `ApiService` wrapper, 5s timeout |
| Local storage | `shared_preferences` ^2.5.3 | Only stores the JWT access token + local-only notification/privacy toggles |
| Pagination | `infinite_scroll_pagination` ^4.0.0 | Used in `SearchScreen` |
| Ratings UI | `flutter_rating_bar` ^4.0.1 | |
| Links | `url_launcher` ^6.3.1 | About screen socials/email |
| Dates | `intl` ^0.20.2 | Declared but not actually used anywhere in `lib/` |
| Images/video | `cached_network_image` ^3.3.0, `video_player` ^2.8.0 | **Declared in pubspec but never imported or used anywhere in `lib/`** — dead weight |

### Directory layout
```
lib/
  main.dart                    — app entrypoint, MultiProvider + MaterialApp
  models/                      — Recipe, Category, Review, User (plain fromJson/toJson, no code-gen)
  providers/favorites_provider.dart
  services/                    — api_service.dart, auth_service.dart, recipe_service.dart
  screens/                     — 16 screens (see §2)
  widgets/                     — RecipeCard, CategoryCard, LoadingIndicator, CustomSearchBar
  utils/responsive.dart        — breakpoint helpers, imported nowhere
```

---

## 2. Feature inventory (what's implemented)

| Area | Screen(s) | State |
|---|---|---|
| Splash / auto-login | `splash_screen.dart` | Preloads categories/recipes/favorites in parallel if a token exists, then routes to Home or Login |
| Auth | `login_screen.dart`, `register_screen.dart`, `forgot_password_screen.dart` | Login, register w/ email verification gate, resend-verification. **Forgot-password is UI-only (§4.2)** |
| Home | `home_screen.dart` | Bottom-nav shell (Home/Search/Favorites/Profile) + FAB to submit a recipe; guest mode supported with soft paywall dialogs |
| Browse | `all_categories_screen.dart`, `all_recipes_screen.dart` | Grid views; `all_recipes_screen` does its own client-side search/filter over an already-fetched full list (not paginated) |
| Search | `search_screen.dart` | Server-side paginated list (`infinite_scroll_pagination`) + client-side autocomplete suggestions typed against a locally cached recipe list; category/difficulty/sort filters |
| Recipe detail | `recipe_detail_screen.dart` | Hero image, chips, ingredients/instructions, reviews list, submit-review dialog, favorite toggle |
| Favorites | `favorites_screen.dart` + `favorites_provider.dart` | List, swipe-to-remove, pull-to-refresh |
| Submit recipe | `submit_recipe_screen.dart` | Full form → `POST /submissions/create/` |
| Profile | `profile_screen.dart` | Guest / signed-out / signed-in variants; stats row is **hardcoded to `0`** (§4.3); admin dashboard entry is a stub snackbar |
| Account settings | `account_settings_screen.dart` | Edit username/bio, change password, delete account. Photo upload is a stub. **Delete account calls a non-existent backend endpoint (§4.2)** |
| Notifications / Privacy | `notifications_screen.dart`, `privacy_security_screen.dart` | Toggle UIs that **only write to `SharedPreferences`** — nothing is sent to the backend, so these settings have no real effect (no push notifications, no 2FA, no biometric login actually wired up) |
| About | `about_screen.dart` | Static content + social links via `url_launcher` |

Guest mode, email-verification gating, and the favorites/auth provider wiring are all genuinely implemented and functional, not stubs — this is a real app with a working core loop (browse → detail → favorite/review/submit), not a prototype.

---

## 3. Current health snapshot

| Check | Result |
|---|---|
| `flutter analyze` | ✅ **0 issues** (the committed `analyze_full.txt` is stale — it lists ~40 `avoid_print`/`use_build_context_synchronously` warnings that no longer exist in the current code; delete or regenerate it) |
| `flutter test` | ❌ **1/1 failing** — `test/widget_test.dart` is still the default Flutter counter-app template; it has nothing to do with this app (§4.1) |
| Platform folders | ❌ Missing (`android/`, `ios/`, `web/`, …) — gitignored, never generated in this checkout |
| Backend contract check | ⚠️ Two client-called endpoints don't exist server-side (§4.2) |

---

## 4. Gaps and how to close them

Ordered by impact. Each item names the exact file(s) to touch.

### 4.1 Critical — project won't build or test as-is

**a) No platform projects exist yet.**
`flutter run` will fail immediately because there's no `android/` or `ios/` folder.
```bash
cd mobile
flutter create . --project-name sudanile_kitchen --platforms=android,ios
flutter pub get
```
Do this once per developer machine (they're gitignored on purpose, so this isn't a repo bug — just an undocumented setup step). **Fix:** add this command to the root `README.md` setup instructions, right before "flutter run".

**b) The only test file is the unmodified Flutter template and fails.**
`test/widget_test.dart` builds `SudanileKitchenApp()` and looks for a counter (`find.text('0')`), which doesn't exist in this app — it hard-fails every run of `flutter test` / CI.
**Fix:** either delete it and write a real smoke test (e.g. pump `SudanileKitchenApp` and assert the splash screen renders `'Sudanile Kitchen'`), or replace its body with a minimal non-failing widget test. There is currently **zero test coverage** on models, services, or providers — `Recipe.fromJson`, `AuthService`, and `FavoritesProvider` are all easy, high-value unit test targets since they contain the actual business logic.

### 4.2 High — client/server contract mismatches (silent failures at runtime)

Cross-checking every `_apiService.get/post/put/delete(...)` call in `lib/services/` against `backend/*/urls.py`:

| Mobile call | File | Backend route exists? |
|---|---|---|
| `POST /users/forgot-password/` | `forgot_password_screen.dart:29` | **No** — `users/urls.py` has no such path. The code even has a comment: *"This endpoint needs to be created in the backend"*, and the screen swallows the resulting error and shows a fake success message regardless. Users who request a reset will always see "Check Your Email" and never receive one. |
| `DELETE /users/delete-account/` with body | `account_settings_screen.dart:158` | **No** — not in `users/urls.py`. Account deletion is completely non-functional; it will always hit the `catch` block and show "Failed to delete account". |
| Everything else (`register`, `login`, `profile`, `change-password`, `resend-verification`, `recipes/*`, `reviews/*`, `favorites/*`, `submissions/create`) | | ✅ Matches backend routes 1:1 |

**Fix — pick one:**
1. Implement `ForgotPasswordView`/password-reset-confirm and `DeleteAccountView` in `backend/users/` (root `README.md` already documents `POST /api/users/forgot-password/` and `POST /api/users/reset-password/` as intended endpoints, so this was planned, just never built), and wire the Django email backend for the reset link, or
2. If these are out of scope for now, hide the "Forgot Password" link and the "Delete Account" action in the mobile UI so users don't hit a dead end, and remove the misleading "success" messaging in `forgot_password_screen.dart` (lines 33–41 currently show `_emailSent = true` even in the `catch` block).

### 4.3 Medium — features that render but don't do anything real

- **`RecipeCard` widget never shows the recipe image.** `lib/widgets/recipe_card.dart` (used by `SearchScreen` and `FavoritesScreen`) always renders a static orange `Icon(Icons.restaurant)` container instead of `Image.network(recipe.imageUrl)` — even though `Recipe.imageUrl` exists and *is* used correctly in `home_screen.dart` and `all_recipes_screen.dart`. This is an inconsistency, not a missing feature: **fix by copying the `Image.network(...).errorBuilder` pattern from `home_screen.dart:_buildRecipeCard` into `recipe_card.dart`.**
- **Profile stats are hardcoded.** `profile_screen.dart:149-151` always shows `0` for "Recipes Saved / Reviews Written / Recipes Submitted" regardless of the signed-in user. `favorites.length` is already available via `FavoritesProvider`; reviews-written and submissions-count would need small backend additions (a `/users/stats/` endpoint, or count fields on the profile serializer).
- **Notifications & Privacy screens are local-only.** All toggles in `notifications_screen.dart` and `privacy_security_screen.dart` persist to `SharedPreferences` and show a "saved!" snackbar, but nothing is sent to the backend and nothing changes app behavior (no push notification registration, no biometric/2FA implementation, "Download My Data" / "Clear Search History" / "Login History" / "Active Sessions" are all snackbar stubs). This is fine as a placeholder, but the UI currently implies these are live security features — worth a "Coming soon" label if not being built out now.
- **Admin dashboard entry is a stub.** `profile_screen.dart:187-191` shows a snackbar ("Admin dashboard coming soon!") instead of linking anywhere — the backend already has a working Django admin dashboard (`backend/config/admin_views.py`, `templates/admin/dashboard.html`); the mobile app doesn't need to reimplement it, just `url_launcher` out to `{baseUrl}/admin/` for admin users if that's the intended flow, or hide the tile until an in-app admin view is built.
- **Profile photo upload is a stub.** `account_settings_screen.dart:246-251` — snackbar only, no image picker wired up.

### 4.4 Low — cleanup / config hygiene

- **Hardcoded API base URL.** `lib/services/api_service.dart:8` — `static const String baseUrl = 'http://localhost:8000/api';`. This only works for web/desktop or an iOS simulator; it will fail on a physical device and needs `10.0.2.2` for the Android emulator. Recommend a build-time flag: `String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000/api')` and document the `--dart-define=API_BASE_URL=...` invocation per platform.
- **Unused dependencies.** `cached_network_image` and `video_player` are in `pubspec.yaml` (with literal `# Add this` comments) but never imported anywhere in `lib/`. Either wire them in (they'd be a genuine improvement — `CachedNetworkImage` instead of raw `Image.network` everywhere, and `video_player` for the "Video Tutorials" feature the About screen already advertises) or remove them to shrink the app.
- **`intl` and `utils/responsive.dart` are unused.** No file imports either. Remove if not planned for near-term use, since `Responsive` looks like it was scaffolded for tablet/desktop layouts that were never applied to any screen.
- **`RecipeDetailScreen.recipe` is typed `dynamic`** (`recipe_detail_screen.dart:11`) instead of `Recipe`. Harmless today since it's always constructed with a `Recipe`, but it defeats static type-checking for no reason — change to `final Recipe recipe`.
- **Stale `analyze_full.txt` committed to the repo.** It no longer reflects current lint state (see §3) and will mislead anyone reading it before running `flutter analyze` themselves. Either regenerate it as part of CI or delete it and rely on live `flutter analyze`.
- **Empty `README.md` in `mobile/`.** All setup instructions currently live only in the repo root `README.md`. Consider at least a pointer from `mobile/README.md` to the root doc, since anyone opening the Flutter project directly in an IDE won't see it.

---

## 5. Suggested fix order

1. **Unblock local dev** — run `flutter create .` for the platforms you need, fix/replace `test/widget_test.dart` (§4.1). Both are quick and immediately make `flutter run`/`flutter test` usable.
2. **Decide the fate of forgot-password and delete-account** (§4.2) — either build the two backend endpoints or hide the entry points. Leaving them as-is means real users can hit a "your account was deleted" success message that didn't actually delete anything.
3. **Fix `RecipeCard` images** (§4.3, first bullet) — smallest diff, most visible user-facing improvement (search & favorites currently look broken/placeholder-only).
4. **Parameterize the API base URL** (§4.4) so the app is testable on a real device/emulator, not just simulator/web.
5. Everything else in §4.3/§4.4 is polish — tackle opportunistically or when the corresponding backend support lands.

---

## 6. Not a gap, just worth knowing

- Guest mode, email-verification-gated login, JWT persistence + auto-login on splash, and the favorites provider are all real, working, and reasonably well structured — this app has a solid functional core, the issues above are edges, not the foundation.
- The backend (`backend/`) has a Django admin dashboard, JWT auth, rate limiting, and CORS already in place per the root README — the mobile gaps above are specifically about the *client* not fully using or matching what's there (or, in the two §4.2 cases, calling things that were planned but never built).
