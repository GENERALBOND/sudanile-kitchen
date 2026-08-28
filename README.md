# 🍽️ Sudanile Kitchen

**Preserving South Sudanese Culinary Heritage**

Sudanile Kitchen is a digital platform for documenting, preserving, and promoting South Sudanese culinary heritage. A Flutter client (`mobile/`) serves authentic recipes, cultural food stories, community reviews and submissions to end users, backed by a Django REST API (`backend/`) and a custom Django admin panel.

---

## 📁 Repository Layout

```
backend/               Django REST API + admin panel
  config/              Project settings, URLs, custom admin views, tests
  users/               Custom user model, Firebase/JWT auth, profile
  recipes/             Recipes, categories, duplicate detection
  reviews/             Ratings & reviews
  favorites/           Saved recipes
  submissions/         Community recipe submissions (with image upload)
  notifications/       FCM push notifications, device tokens, community updates
  community/           Community feed (posts, likes, comments)
  templates/           Landing page + admin dashboard templates
  .env.example         Backend environment template
mobile/                Flutter app
  lib/                 App code (services, screens, models, providers)
  .env.example         Mobile environment template (Firebase, API URL)
database/              ERD diagram + PostgreSQL schema reference
docs/                  Project status report
documentation/         SRS, SDD and proposal documents
scripts/               Build & security helper scripts
security_test.py       API security test suite
```

---

## ✨ Features

### For Users
- **Browse recipes** — authentic South Sudanese recipes with cultural background
- **Search & filter** — by title, description, ingredients, category, difficulty, and sort order
- **Save favorites** — build a personal recipe collection
- **Rate & review** — 1–5 star ratings with comments (one review per recipe per user)
- **Submit recipes** — contribute family recipes for admin review, with optional image upload
- **Community feed** — share photos of dishes you've cooked, like and comment on others' posts, and tap a member to see all their posts
- **Guest mode** — browse without an account
- **Google sign-in** — plus email/password with email-verification gating
- **Push notifications** — opt-in alerts for new recipes, submission decisions, and community updates
- **Responsive design** — Android, iOS, and web

### For Admins
- **Content management** — create, edit, delete recipes and categories via a custom Django admin dashboard
- **Review submissions** — approve/reject community recipe submissions; decisions are emailed and pushed to the submitter
- **User management** — Django admin user, group and permission management
- **Analytics** — dashboard counts for recipes, users, submissions, reviews, and favorites

### Security
- **Firebase Auth** — ID tokens verified against Google's published signing certificates (no service account needed for verification)
- **JWT support** — SimpleJWT access/refresh tokens (1-day access, 7-day refresh) for the web login flow
- **Duplicate detection** — new recipes are checked against existing ones before creation
- **Image validation** — uploaded images are content-verified (JPEG/PNG/GIF only)
- **Django ORM** — SQL-injection safe queries; XSS protected by template auto-escaping
- **Production hardening** — HTTPS redirect, secure cookies, and Cloudinary media storage when `DEBUG=False`

> **Note:** there is **no API rate limiting** configured (see `REST_FRAMEWORK` in `backend/config/settings.py`).

---

## 🛠️ Technology Stack

### Backend (`backend/`)
| Layer | Technology |
|---|---|
| Framework | Django 4.2.16, Django REST Framework 3.15.2 |
| Auth | Firebase Authentication (Google ID-token verification) + djangorestframework-simplejwt |
| Database | SQLite locally; PostgreSQL in production (via `dj-database-url`) |
| Media | Local storage in dev; Cloudinary in production |
| Static | WhiteNoise |
| Push | Firebase Admin SDK / FCM |
| Config | python-decouple (`.env`) |
| Misc | django-cors-headers, django-filter, drf-yasg, gunicorn |

### Mobile (`mobile/`)
| Concern | Technology |
|---|---|
| Framework | Flutter (Dart SDK >= 3.0) |
| State management | `provider` |
| HTTP | `http` (hand-rolled `ApiService`, 5s timeout) |
| Auth | `firebase_auth`, `google_sign_in` |
| Push | `firebase_messaging` |
| Storage | `shared_preferences` |
| Pagination | `infinite_scroll_pagination` |
| Ratings UI | `flutter_rating_bar` |
| Image upload | `image_picker`, `http_parser` |
| Links | `url_launcher` |

---

## 🚀 Getting Started

### Prerequisites
- Python 3.12+
- Flutter 3.24+ (with Android/iOS/web toolchains as needed)
- Git
- A Firebase project (Auth + Cloud Messaging enabled)

### 1. Backend

```bash
cd backend

# Create and activate a virtual environment
python -m venv venv
source venv/Scripts/activate   # Windows
# source venv/bin/activate     # Linux/Mac

# Configure environment
cp .env.example .env           # then fill in real values

# Install dependencies
pip install -r requirements.txt

# Run migrations
python manage.py migrate

# Create a superuser (admin panel access)
python manage.py createsuperuser

# Start the server
python manage.py runserver
```

**Backend environment (`.env`):**
| Variable | Purpose |
|---|---|
| `SECRET_KEY` | Django secret key (required) |
| `DEBUG` | `True` for development |
| `ALLOWED_HOSTS` | Comma-separated hosts |
| `DATABASE_URL` | Blank → SQLite; set a `postgresql://…` URL in production |
| `FIREBASE_PROJECT_ID` | Firebase project ID used to verify ID tokens (required for auth) |
| `FIREBASE_SERVICE_ACCOUNT` / `FIREBASE_SERVICE_ACCOUNT_JSON` | FCM push credentials (optional; pushes are skipped without them) |
| `CLOUDINARY_CLOUD_NAME` / `CLOUDINARY_API_KEY` / `CLOUDINARY_API_SECRET` | Media storage in production (optional) |
| `BREVO_API_KEY` | Brevo transactional API key for sending submission-review notifications (required for email) |
| `DEFAULT_FROM_EMAIL` | Verified Brevo sender address used as the From on notifications |
| `DEMO_LOGIN_HINT` | Optional hint shown on the admin landing page |

### 2. Mobile

```bash
cd mobile

# Configure environment (Firebase keys + API URL are injected at build time)
cp .env.example .env           # then fill in real values

# Install dependencies
flutter pub get

# Run the app
flutter run --dart-define-from-file=.env        # e.g. -d chrome for web
flutter run --dart-define-from-file=.env -d android
```

**Mobile environment (`.env`):**
| Variable | Purpose |
|---|---|
| `API_BASE_URL` | Backend API root, e.g. `http://localhost:8000/api` |
| `FIREBASE_PROJECT_ID` | Firebase project id |
| `FIREBASE_*_API_KEY`, `FIREBASE_*_APP_ID`, … | Per-platform Firebase web/android/ios options |
| `GOOGLE_WEB_CLIENT_ID` | OAuth web client ID used as `serverClientId` for Google sign-in |

Nothing is hardcoded in source — all secrets are injected via `--dart-define-from-file=.env`. For **Android release** builds, signing keystore passwords must also be present in the environment (see `mobile/android/app/build.gradle.kts`):

```bash
export STORE_PASSWORD=...
export KEY_PASSWORD=...
```

A ready-made release build script is provided:

```bash
scripts/build_apk.sh     # builds with .env baked in, outputs mobile/dist/Sudanile-Kitchen-v<version>.apk
```

> The default `API_BASE_URL` (`http://localhost:8000/api`) only works for web/desktop/iOS-simulator. Use `http://10.0.2.2:8000/api` on the Android emulator and your LAN IP on a physical device.

### 3. Access the Application

| Service | URL |
|---|---|
| Admin landing / login | `http://localhost:8000/` |
| Admin panel | `http://localhost:8000/admin/` |
| Admin dashboard | `http://localhost:8000/admin/dashboard/` |
| Backend API | `http://localhost:8000/api/` |
| Flutter app | `flutter run` (web: `-d chrome`) |

---

## 🎭 App Rules (Roles & Permissions)

- **Roles** — users have a `role` of `user` or `admin` (`users/models.py`). New users are added to the *Regular User* group automatically.
- **Guest access** — browsing, searching, categories and recipe details are public (`AllowAny`).
- **Authenticated actions** — viewing your profile/favorites/submissions, favoriting, reviewing, submitting recipes, changing your password, and deleting your account all require a valid Firebase ID token (Bearer header).
- **Publishing** — recipes created through `POST /api/recipes/create/` are **published immediately only for admins**; submissions from regular users create a `RecipeSubmission` that requires admin approval.
- **Submission workflow** — a submission is `pending` → `approved`/`rejected`. On approval the recipe is added to the public collection; the submitter is notified by email and push.
- **Reviews** — a user may review a given recipe only once; ratings are averaged automatically into the recipe's `average_rating`.
- **Favorites** — one favorite per user per recipe.
- **Account deletion** — users delete their own account via the API; Django records (favorites, reviews, submissions, device tokens) cascade, and the matching Firebase Auth account is deleted best-effort. Staff/superuser accounts cannot be deleted via the API.
- **Push preferences** — notifications are opt-in per device with tags (`new_recipes`, `recipe_approval`, `community_updates`) chosen in the app's Notifications screen.

---

## 🔌 API Reference

All endpoints live under `/api/`. Authenticated endpoints accept a `Bearer` Firebase ID token (or SimpleJWT access token).

### Users — `/api/users/`
| Method | Endpoint | Auth | Description |
|---|---|---|---|
| POST | `/register/` | Public | Register (email/password), returns JWT pair |
| POST | `/login/` | Public | Login, returns JWT pair |
| GET/PUT | `/profile/` | Required | View / update your profile |
| POST | `/change-password/` | Required | Change your password |
| DELETE | `/delete-account/` | Required | Delete your account |

### Recipes — `/api/recipes/`
| Method | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/` | Public | List published recipes; filters: `search`, `category`, `difficulty`, `ordering` (`created_at`, `average_rating`, `view_count`); paginated (`PAGE_SIZE=100`) |
| GET | `/categories/` | Public | List categories |
| POST | `/create/` | Required | Create a recipe (admins publish immediately; duplicate detection) |
| GET | `/<id>/` | Public | Recipe detail (increments view count) |

### Reviews — `/api/reviews/`
| Method | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/recipe/<recipe_id>/` | Public | List a recipe's reviews |
| POST | `/recipe/<recipe_id>/create/` | Required | Submit a review (1–5 stars) |
| PUT/PATCH | `/<review_id>/update/` | Required | Update your own review |

### Favorites — `/api/favorites/`
| Method | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/` | Required | List your favorite recipes |
| POST | `/add/` | Required | Add a recipe to favorites (`{"recipe": <id>}`) |
| DELETE | `/remove/<recipe_id>/` | Required | Remove a recipe from favorites |

### Submissions — `/api/submissions/`
| Method | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/` | Required | List submissions (admins see all; users see their own) |
| POST | `/create/` | Required | Submit a recipe for review (multipart `image` upload allowed; JPEG/PNG/GIF) |

### Community — `/api/community/`
| Method | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/` | Public | List posts (`?user=<id>` filters one member; `?sort=popular` orders by likes) |
| POST | `/create/` | Required | Share a post (multipart `image` + optional `caption` / `recipe`; JPEG/PNG/GIF) |
| POST | `/<post_id>/like/` | Required | Like / unlike a post (toggles) |
| POST | `/<post_id>/report/` | Required | Report a post for admin review |
| DELETE | `/<post_id>/delete/` | Required | Delete a post (owner or admin) |
| GET | `/<post_id>/comments/` | Public | List a post's comments |
| POST | `/<post_id>/comments/create/` | Required | Add a comment to a post |
| DELETE | `/comments/<comment_id>/delete/` | Required | Delete a comment (owner or admin) |

### Notifications — `/api/notifications/`
| Method | Endpoint | Auth | Description |
|---|---|---|---|
| POST | `/register/` | Required | Register/update this device's FCM token + opted-in tags |
| POST | `/unregister/` | Public | Remove a device token (used during sign-out) |

---

## 🔔 Push Notifications (FCM)

- Devices register their FCM token with the backend (`notifications.DeviceToken`) together with the alert tags the user enabled.
- Backend signals push automatically:
  - a recipe **newly becomes published** → `new_recipes` subscribers;
  - a submission is **approved or rejected** → the submitter's `recipe_approval` devices.
- The mobile app shows foreground pushes as an in-app banner and routes taps to the relevant recipe or Home.
- Push is **optional**: without `FIREBASE_SERVICE_ACCOUNT*` credentials (or `GOOGLE_APPLICATION_CREDENTIALS`) sends are silently skipped and the rest of the app works normally.

---

## 📊 Database Schema

Reference: `database/ERD.png` and `database/schema.sql` (PostgreSQL port — Django migrations remain the source of truth).

| Table | Purpose |
|---|---|
| `users_user` | Custom user model (email login, role, email-verification fields) |
| `recipes_category` | Recipe categories |
| `recipes_recipe` | Recipes (ingredients/instructions as JSON, prep/cook time, difficulty, rating, view count, published/flagged flags) |
| `reviews_review` | 1–5 star reviews (unique per user+recipe) |
| `favorites_favorite` | Saved recipes (unique per user+recipe) |
| `submissions_recipesubmission` | Community recipe submissions (status, admin notes, image) |
| `notifications_devicetoken` | FCM push registrations (token, platform, tags) |
| `notifications_communityupdate` | Community news/updates for push |
| `community_post` | Community feed posts (photo, caption, optional linked recipe, flagged flag) |
| `community_postlike` | Likes on posts (unique per user+post) |
| `community_postcomment` | Comments on posts |

---

## 🧪 Testing

### Backend unit tests

```bash
cd backend
python manage.py test
```

Covers the admin landing page rendering and the staff-login redirect (`backend/config/tests.py`).

### API security test suite

`security_test.py` runs a 10-test suite (SQL injection, weak passwords, brute force, unauthorized access, RBAC, XSS, JWT, password reset, CORS, rate limiting) against a running server. Credentials are read from the environment — see `security_test.env.example`:

```bash
# From the repo root, with the backend running on :8000
export SECURITY_TEST_ADMIN_EMAIL=...
export SECURITY_TEST_ADMIN_PASSWORD=...
export SECURITY_TEST_REGULAR_EMAIL=...
export SECURITY_TEST_REGULAR_PASSWORD=...
python security_test.py
```

A report is written to `security_report.txt`.

### Mobile

```bash
cd mobile
flutter analyze
flutter test
```

---

## 🔒 Security Notes

- **Authentication** — Firebase ID tokens are verified against Google's signing certificates for the configured `FIREBASE_PROJECT_ID`; users are auto-created (as verified regular users) on first sign-in.
- **Deletion safety** — deleting your account requires re-authentication in the app and is refused for staff/superuser accounts.
- **Production** — with `DEBUG=False`: HTTPS redirect via `SECURE_PROXY_SSL_HEADER`, secure session/CSRF cookies, and Cloudinary-backed media storage.
- **Secrets** — never commit `.env` files. A pre-commit hook (`scripts/pre-commit-secrets.sh`) scans staged files for credentials; install it with:

```bash
cp scripts/pre-commit-secrets.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
```

---

## 🚢 Deployment

- **Heroku/Render-style** — `backend/Procfile` runs gunicorn (`config.wsgi:application`) and runs migrations on release; WhiteNoise serves static files.
- **Media** — set the Cloudinary variables in production to serve uploaded images from Cloudinary; leave blank to keep local storage.
- **Push/email** — configure FCM service-account credentials and a Brevo API key (`BREVO_API_KEY` + `DEFAULT_FROM_EMAIL`) for notifications to work in production. Email goes through Brevo's REST API because Render blocks outbound SMTP.
