import logging
import os
import socket
from pathlib import Path
from decouple import config
from datetime import timedelta
import dj_database_url

# Render instances have no IPv6 route, and smtp.gmail.com resolves to an IPv6
# address first, so SMTP connects fail with "Network is unreachable" (Errno 101).
# Force IPv4 for outbound connections so email actually sends.
_getaddrinfo = socket.getaddrinfo
def _ipv4_first(*args, **kwargs):
    return [r for r in _getaddrinfo(*args, **kwargs) if r[0] == socket.AF_INET]
socket.getaddrinfo = _ipv4_first

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = config('SECRET_KEY')
DEBUG = config('DEBUG', default=True, cast=bool)
ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='*,localhost,127.0.0.1').split(',')

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

# CORS Configuration
CORS_ALLOW_ALL_ORIGINS = True
CORS_ALLOW_CREDENTIALS = True

# REST Framework settings - NO RATE LIMITING
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'users.authentication.FirebaseAuthentication',
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.AllowAny',
    ],
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 100,
    'DEFAULT_RENDERER_CLASSES': [
        'rest_framework.renderers.JSONRenderer',
    ],
}

SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(days=1),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
}

# Firebase project whose ID tokens the API accepts (see users.authentication).
FIREBASE_PROJECT_ID = config('FIREBASE_PROJECT_ID')

# Email Configuration (used for submission review notifications)
EMAIL_BACKEND = config('EMAIL_BACKEND', default='django.core.mail.backends.smtp.EmailBackend')
EMAIL_HOST = config('EMAIL_HOST', default='smtp.gmail.com')
EMAIL_PORT = config('EMAIL_PORT', default=587, cast=int)
EMAIL_USE_TLS = config('EMAIL_USE_TLS', default=True, cast=bool)
# Use SSL (port 465) instead of STARTTLS (587) if the host blocks 587.
EMAIL_USE_SSL = config('EMAIL_USE_SSL', default=False, cast=bool)
EMAIL_HOST_USER = config('EMAIL_HOST_USER', default='')
EMAIL_HOST_PASSWORD = config('EMAIL_HOST_PASSWORD', default='')
DEFAULT_FROM_EMAIL = config('DEFAULT_FROM_EMAIL', default='noreply@sudanile.com')
# Bound SMTP connects so a slow/unreachable mail server can't hang the request
# past gunicorn's worker timeout (30s default) and take the whole site down.
EMAIL_TIMEOUT = config('EMAIL_TIMEOUT', default=5, cast=int)

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
