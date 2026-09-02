import logging
import os
import socket
from pathlib import Path
from decouple import config
from datetime import timedelta
import dj_database_url

# Render instances have no IPv6 route, so outbound connects fail with
# "Network is unreachable" (Errno 101) when DNS returns an IPv6 address first.
# Force IPv4 for all outbound connections (email API, Firebase, etc.).
_getaddrinfo = socket.getaddrinfo
def _ipv4_first(*args, **kwargs):
    return [r for r in _getaddrinfo(*args, **kwargs) if r[0] == socket.AF_INET]
socket.getaddrinfo = _ipv4_first

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = config('SECRET_KEY')
DEBUG = config('DEBUG', default=True, cast=bool)
# Explicit host allowlist. The `*` wildcard is only safe while DEBUG is on and
# Django restricts `*` to localhost anyway; production must set ALLOWED_HOSTS
# to the real domain(s) so Host-header injection / DNS-rebinding is blocked.
_ALLOWED_HOSTS = config(
    'ALLOWED_HOSTS',
    default='*,localhost,127.0.0.1' if DEBUG else '',
).split(',')
ALLOWED_HOSTS = [h.strip() for h in _ALLOWED_HOSTS if h.strip()]
if DEBUG:
    # In development, `*` resolves to localhost; keep 127.0.0.1 available too,
    # plus `testserver` which Django's test client uses.
    ALLOWED_HOSTS = ['localhost', '127.0.0.1', '0.0.0.0', '[::1]', 'testserver']

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'corsheaders',
    'rest_framework_simplejwt',
    'rest_framework_simplejwt.token_blacklist',
    'users',
    'recipes.apps.RecipesConfig',
    'reviews.apps.ReviewsConfig',
    'favorites',
    'submissions.apps.SubmissionsConfig',
    'notifications.apps.NotificationsConfig',
    'community.apps.CommunityConfig',
    'moderation.apps.ModerationConfig',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'config.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.template.context_processors.csrf',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
                'config.context_processors.admin_stats',
            ],
        },
    },
]

WSGI_APPLICATION = 'config.wsgi.application'

DATABASES = {
    'default': dj_database_url.config(
        default=f'sqlite:///{BASE_DIR / "db.sqlite3"}',
        conn_max_age=600,
        conn_health_checks=True,
    )
}

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
MEDIA_URL = 'media/'
MEDIA_ROOT = BASE_DIR / 'media'

# Production security (enabled automatically when DEBUG is off)
if not DEBUG:
    SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
    SECURE_SSL_REDIRECT = config('SECURE_SSL_REDIRECT', default=True, cast=bool)
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True

# Cloudinary media storage (used in production; leave blank to store locally).
# cloudinary_storage must come AFTER django.contrib.staticfiles so Django's own
# collectstatic command is used (the cloudinary one depends on legacy settings
# removed in Django 4.2).
CLOUDINARY_CLOUD_NAME = config('CLOUDINARY_CLOUD_NAME', default='')
CLOUDINARY_API_KEY = config('CLOUDINARY_API_KEY', default='')
CLOUDINARY_API_SECRET = config('CLOUDINARY_API_SECRET', default='')
if CLOUDINARY_CLOUD_NAME:
    INSTALLED_APPS.append('cloudinary_storage')
    INSTALLED_APPS.append('cloudinary')
    DEFAULT_FILE_STORAGE = 'cloudinary_storage.storage.MediaCloudinaryStorage'
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

AUTH_USER_MODEL = 'users.User'

# CORS Configuration.
# Only the app's own origins are allowed to make credentialed requests. Wildcard
# CORS with credentials is a security hole: any origin could attach the user's
# cookies/session to its requests. Allowed origins come from ALLOWED_ORIGINS
# (comma-separated in the environment), falling back to a safe explicit list.
CORS_ALLOW_ALL_ORIGINS = False
CORS_ALLOW_CREDENTIALS = True
_CORS_ALLOWED_ORIGINS = config(
    'ALLOWED_ORIGINS',
    default='https://sudanile-5b766.web.app,http://localhost:3000,http://localhost:8080',
).split(',')
CORS_ALLOWED_ORIGINS = [o.strip() for o in _CORS_ALLOWED_ORIGINS if o.strip()]
# No cookies/session are required by the JSON API (auth is Bearer-based), so we
# still restrict methods to what the app uses. CSRF remains enforced for the
# session-based Django admin.
CORS_ALLOW_METHODS = [
    'DELETE',
    'GET',
    'OPTIONS',
    'PATCH',
    'POST',
    'PUT',
]

# REST Framework settings.
# The default permission is IsAuthenticatedOrReadOnly so every endpoint is
# locked down unless a view explicitly opts into anonymous access (register,
# login, public profiles, push-status). Individual public views set AllowAny.
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'users.authentication.FirebaseAuthentication',
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticatedOrReadOnly',
    ],
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 100,
    'DEFAULT_RENDERER_CLASSES': [
        'rest_framework.renderers.JSONRenderer',
    ],
    # Rate limiting: anonymous clients are throttled globally, and the auth
    # endpoints (login/registration) get a tighter burst limit to blunt
    # brute-force and credential-stuffing. Logged-in users are less restricted.
    'DEFAULT_THROTTLE_CLASSES': [
        'rest_framework.throttling.AnonRateThrottle',
        'rest_framework.throttling.UserRateThrottle',
        'rest_framework.throttling.ScopedRateThrottle',
    ],
    'DEFAULT_THROTTLE_RATES': {
        'anon': '100/hour',
        'user': '1000/hour',
        'auth': '30/hour',
        'device_unregister': '50/hour',
    },
}

SIMPLE_JWT = {
    # Short access tokens limit the blast radius of a leaked token. Refresh
    # tokens can be revoked server-side (token_blacklist) to invalidate a whole
    # session on sign-out / password change.
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=30),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=14),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
    # Bind each token to a unique jti so blacklisting individual tokens works.
    'UPDATE_LAST_LOGIN': True,
}

# Firebase project whose ID tokens the API accepts (see users.authentication).
FIREBASE_PROJECT_ID = config('FIREBASE_PROJECT_ID')

# Email Configuration (submission review + moderation notifications).
# Sent through Brevo's transactional REST API (HTTPS) — Render instances
# cannot open outbound SMTP connections, but HTTPS egress works.
EMAIL_BACKEND = 'config.brevo_backend.BrevoEmailBackend'
# Brevo -> SMTP & API -> API keys (a transactional API key, not an SMTP key).
BREVO_API_KEY = config('BREVO_API_KEY')
# Must be a verified sender in Brevo (Settings -> Senders & IPs).
DEFAULT_FROM_EMAIL = config('DEFAULT_FROM_EMAIL')
# Display name used on the From line; Brevo requires a non-empty sender name.
BREVO_SENDER_NAME = config('BREVO_SENDER_NAME', default='Sudanile Kitchen Team')
# Bound API calls so a slow Brevo response can't hang the request past
# gunicorn's worker timeout (30s default) and take the whole site down.
BREVO_TIMEOUT = config('BREVO_TIMEOUT', default=10, cast=int)

# Templates Configuration
TEMPLATES[0]['DIRS'] = [os.path.join(BASE_DIR, 'templates')]

# Firebase Cloud Messaging (push notifications).
# Set FIREBASE_SERVICE_ACCOUNT to the path of the downloaded service-account
# JSON, FIREBASE_SERVICE_ACCOUNT_JSON to its inline JSON, or
# FIREBASE_SERVICE_ACCOUNT_BASE64 to its base64-encoded form (recommended for
# single-line env vars on Render). Leave all blank to use
# GOOGLE_APPLICATION_CREDENTIALS. When no credentials are available, pushes
# are silently skipped (the app still works).
FIREBASE_SERVICE_ACCOUNT = config('FIREBASE_SERVICE_ACCOUNT', default='')
FIREBASE_SERVICE_ACCOUNT_JSON = config('FIREBASE_SERVICE_ACCOUNT_JSON', default='')
FIREBASE_SERVICE_ACCOUNT_BASE64 = config('FIREBASE_SERVICE_ACCOUNT_BASE64', default='')

# Moderation: number of pending reports on one post/comment before it is
# automatically hidden from the feed until a moderator reviews it.
REPORT_AUTO_HIDE_THRESHOLD = config('REPORT_AUTO_HIDE_THRESHOLD', default=3, cast=int)

# Logging: write WARNING+ (and all app-logger errors) to stdout so SMTP/email
# failures are visible in Render's logs instead of being silently swallowed.
# The submission/moderation code logs failed sends with logger.error().
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'simple': {
            'format': '[{asctime}] {levelname} {name}: {message}',
            'style': '{',
        },
    },
    'handlers': {
        'console': {
            'level': 'DEBUG',
            'class': 'logging.StreamHandler',
            'formatter': 'simple',
        },
    },
    'loggers': {
        'submissions': {'handlers': ['console'], 'level': 'INFO', 'propagate': False},
        'moderation': {'handlers': ['console'], 'level': 'INFO', 'propagate': False},
        'notifications': {'handlers': ['console'], 'level': 'INFO', 'propagate': False},
    },
    'root': {
        'level': 'WARNING',
        'handlers': ['console'],
    },
}
