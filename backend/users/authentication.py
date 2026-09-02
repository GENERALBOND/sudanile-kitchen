import logging
import re

from django.conf import settings
from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed

import cachecontrol
import requests
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token

from .models import User

logger = logging.getLogger(__name__)

# Google's published signing certificates for the project's Firebase Auth
# instance. Verifying against these means no service account or Firebase Admin
# SDK credential is required server-side.
FIREBASE_CERT_URL = (
    'https://www.googleapis.com/robot/v1/metadata/x509/'
    'securetoken@system.gserviceaccount.com'
)

# Certificate fetches are cached HTTP-wise (honouring Cache-Control from
# Google's endpoint) so token verification doesn't hit the network on every
# API request.
_CACHED_SESSION = cachecontrol.CacheControl(requests.Session())


def _unique_username(base, exclude=None):
    candidate = base
    i = 1
    while User.objects.filter(username=candidate).exclude(pk=exclude).exists():
        suffix = str(i)
        candidate = f'{base[:140 - len(suffix)]}{suffix}'
        i += 1
    return candidate


def _google_request():
    return google_requests.Request(_CACHED_SESSION)


def firebase_uid_from_token(token):
    """Return the Firebase Auth uid (the token's `sub` claim), or None."""
    if not token:
        return None
    try:
        claims = google_id_token.verify_token(
            token,
            request=_google_request(),
            audience=getattr(settings, 'FIREBASE_PROJECT_ID', None),
            certs_url=FIREBASE_CERT_URL,
        )
        return claims.get('sub')
    except Exception as exc:
        logger.debug('Could not resolve Firebase uid from token: %s', exc)
        return None


def delete_firebase_user(uid):
    """Best-effort deletion of the Firebase Auth account via the Admin SDK.

    Uses the same (lazily resolved, fully guarded) credentials as the
    notifications push client, so this never crashes the API request when the
    Admin SDK or its credentials aren't configured — the Django record is the
    authoritative deletion and is handled by the caller.
    """
    if not uid:
        return
    try:
        from notifications.push import _credentials_options

        import firebase_admin
        from firebase_admin import auth

        try:
            app = firebase_admin.get_app()
        except ValueError:
            options = _credentials_options()
            if options is None:
                logger.warning(
                    'FCM not configured; skipped deleting Firebase account %s', uid
                )
                return
            app = firebase_admin.initialize_app(credential=options)

        auth.delete_user(uid, app=app)
        logger.info('Deleted Firebase Auth account %s', uid)
    except Exception as exc:
        logger.warning('Could not delete Firebase account %s: %s', uid, exc)


class FirebaseAuthentication(BaseAuthentication):
    """Validates a Firebase ID token sent as a `Bearer` credential.

    The token is checked against Google's signing certificates for the
    project's Firebase Auth instance, so it must have been issued to this exact
    project. Users are resolved by the verified token's email address, and are
    created (as verified, regular users) on their first sign-in so the rest of
    the API (profile, favorites, reviews, submissions) works unchanged.
    """

    keyword = 'Bearer'

    def authenticate(self, request):
        auth_header = request.META.get('HTTP_AUTHORIZATION', '')
        if not auth_header:
            return None

        parts = auth_header.split()
        if len(parts) != 2 or parts[0].lower() != self.keyword.lower():
            return None

        token = parts[1]
        try:
            claims = google_id_token.verify_token(
                token,
                request=_google_request(),
                audience=getattr(settings, 'FIREBASE_PROJECT_ID', None),
                certs_url=FIREBASE_CERT_URL,
            )
        except Exception as exc:
            # Not a Firebase token (or expired/invalid). Fall through so the
            # next authenticator in the chain (e.g. SimpleJWT, used by the
            # web login flow) gets a chance to validate it.
            logger.debug('Firebase token verification failed: %s', exc)
            return None

        email = claims.get('email')
        if not email:
            raise AuthenticationFailed('Token does not contain an email.')

        is_verified = bool(claims.get('email_verified', False))
        # Firebase's `name` claim carries the display name the user chose at
        # registration (the client sets it via `updateDisplayName`).
        display_name = claims.get('name') or ''

        user, created = User.objects.get_or_create(
            email=email,
            defaults={
                'username': self._generate_username(email, display_name),
                'is_email_verified': is_verified,
            },
        )

        if not created and display_name:
            # The Django user may have been created in an earlier session with
            # an auto-generated username derived from the email, before the
            # chosen display name was available. Promote it to the chosen name,
            # but only while it still looks auto-generated so usernames the
            # user later edited in Account Settings are left untouched.
            auto_username = self._generate_username(email)
            if user.username == auto_username and user.username != display_name:
                user.username = _unique_username(display_name, exclude=user.pk)
                user.save(update_fields=['username'])

        if user.is_email_verified != is_verified:
            user.is_email_verified = is_verified
            user.save(update_fields=['is_email_verified'])

        # A disabled account (moderation ban via is_active=False) must not be
        # able to authenticate, even with a valid Firebase ID token. Django's
        # ModelBackend already refuses inactive users for the password login,
        # so enforce the same rule here.
        if not user.is_active:
            raise AuthenticationFailed('This account has been disabled.')

        return (user, token)

    def authenticate_header(self, request):
        return self.keyword

    @staticmethod
    def _generate_username(email, display_name=None):
        # Keep only characters the Django username validator allows, and
        # guarantee a non-empty fallback (emails like "@gmail.com"). Prefer the
        # user-chosen display name when one is present.
        raw = display_name or email.split('@')[0]
        base = re.sub(r'[^a-zA-Z0-9.@_+-]', '', raw)[:140]
        if not base:
            base = 'user'
        return _unique_username(base)
