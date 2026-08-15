"""Firebase Cloud Messaging (FCM) helpers.

Sending is driven by the mobile app's notification preferences: each installed
device is registered against the backend with a set of opt-in *tags*. Signals
(and the admin update flow) route messages to the tokens carrying the relevant
tag, so users only get the alerts they enabled in the app.

The Firebase Admin SDK is initialised lazily and every send is guarded, so the
rest of the app keeps working even when FCM credentials aren't configured yet.
"""

import base64
import json
import logging
import os

from django.conf import settings

logger = logging.getLogger(__name__)

# Every function in this module uses lazy imports so a missing `firebase_admin`
# installation (or missing credentials) never crashes an API request.
_app = None


def _credentials_options():
    """Build firebase_admin.initialize_app credentials options, or None."""
    # 1) A path to a service-account JSON file.
    credentials_path = getattr(settings, 'FIREBASE_SERVICE_ACCOUNT', None)
    # 2) An inline service-account JSON string.
    credentials_json = getattr(settings, 'FIREBASE_SERVICE_ACCOUNT_JSON', '')
    # 3) A base64-encoded inline service-account JSON string (single-line,
    #    so it pastes cleanly into single-line env vars on Render / Heroku).
    credentials_b64 = getattr(settings, 'FIREBASE_SERVICE_ACCOUNT_BASE64', '')
    # 4) Standard Google default credentials (GOOGLE_APPLICATION_CREDENTIALS).
    env_path = os.environ.get('GOOGLE_APPLICATION_CREDENTIALS')

    from firebase_admin import credentials
    from google.auth.exceptions import DefaultCredentialsError

    try:
        if credentials_path and os.path.isfile(credentials_path):
            return credentials.Certificate(credentials_path)
        if credentials_json:
            return credentials.Certificate(json.loads(credentials_json))
        if credentials_b64:
            decoded = base64.b64decode(credentials_b64).decode('utf-8')
            return credentials.Certificate(json.loads(decoded))
        if env_path and os.path.isfile(env_path):
            return credentials.Certificate(env_path)
    except Exception as exc:  # pragma: no cover - config validation path
        logger.error('Invalid FCM service-account credentials: %s', exc)
        return None

    # No explicit key file. Let the SDK try application-default credentials;
    # this is what most production hosts (Render, GCP, etc.) expose.
    try:
        return credentials.ApplicationDefault()
    except DefaultCredentialsError as exc:  # pragma: no cover - no creds
        logger.warning(
            'FCM not configured (no service account found): %s', exc
        )
        return None


def _messaging():
    """Return the FCM Messaging client, initialising the Admin SDK if needed."""
    global _app

    try:
        from firebase_admin import initialize_app
        import firebase_admin.messaging as messaging
    except ImportError:  # pragma: no cover - firebase-admin not installed
        logger.warning('firebase-admin is not installed; push disabled.')
        return None

    if _app is None:
        options = _credentials_options()
        if options is None:
            logger.warning('FCM not configured; push notifications disabled.')
            return None
        try:
            # Bound FCM's HTTP timeout so a slow/unreachable Google API never
            # hangs the request past gunicorn's worker timeout (30s default).
            _app = initialize_app(
                credential=options,
                options={'httpTimeout': 15},
            )
        except Exception as exc:  # pragma: no cover - invalid credentials
            logger.error('FCM initialisation failed: %s', exc)
            return None
    return messaging


def _build_message(title, body, data=None, url=None):
    try:
        from firebase_admin import messaging
    except ImportError:  # pragma: no cover
        return None
    # FCM requires every data value to be a string; ids arrive as ints, so
    # coerce everything up front (otherwise every push fails validation).
    payload = {str(k): str(v) for k, v in (data or {}).items()}
    if url:
        payload['url'] = url
    return messaging.Message(
        notification=messaging.Notification(title=title, body=body),
        data=payload,
    )


def _send_to_tokens(token_list, title, body, data=None, url=None):
    """Best-effort multicast push; malformed/unregistered tokens are pruned."""
    messaging = _messaging()
    tokens = [t for t in token_list if t]
    if messaging is None or not tokens:
        return

    try:
        from firebase_admin import messaging as m
        import firebase_admin.messaging
    except ImportError:  # pragma: no cover
        return

    message = _build_message(title, body, data, url)
    if message is None:
        return

    try:
        multicast = m.MulticastMessage(tokens=tokens, **{
            'notification': message.notification,
            'data': message.data,
        })
        response = messaging.send_each_for_multicast(multicast)
        if response.failure_count:
            _prune_failed_tokens(tokens, response)
        logger.info(
            'FCM: %d delivered, %d failed (tag dispatch)',
            response.success_count,
            response.failure_count,
        )
    except Exception as exc:  # pragma: no cover - network/API errors
        logger.error('FCM send failed: %s', exc)


def _prune_failed_tokens(tokens, batch_response):
    try:
        from firebase_admin import messaging

        removed = 0
        for result in batch_response.responses:
            if result.exception is not None and (
                isinstance(result.exception, messaging.UnregisteredError)
                or (
                    hasattr(result.exception, 'code')
                    and getattr(result.exception, 'code') == 404
                )
            ):
                idx = getattr(result, 'index', None)
                if idx is not None and idx < len(tokens):
                    from notifications.models import DeviceToken

                    deleted, _ = DeviceToken.objects.filter(token=tokens[idx]).delete()
                    removed += deleted
        if removed:
            logger.info('FCM: pruned %d unregistered token(s)', removed)
    except Exception as exc:  # pragma: no cover
        logger.warning('Could not prune invalid FCM tokens: %s', exc)


def _tokens_with_tag(tag):
    """Return FCM tokens of devices opted into the given tag."""
    from notifications.models import DeviceToken
    from django.db import connection

    queryset = DeviceToken.objects.all()
    # PostgreSQL supports a native JSON contains lookup; SQLite does not, so we
    # fall back to a portable in-Python check. Volumes here are small either way.
    if connection.vendor == 'postgresql':
        queryset = queryset.filter(tags__contains=[tag])
        return list(queryset.values_list('token', flat=True))
    return [t.token for t in queryset if tag in (t.tags or [])]


def notify_tag(tag, title, body, data=None, url=None):
    _send_to_tokens(_tokens_with_tag(tag), title, body, data, url)


def notify_user(user, tag, title, body, data=None, url=None):
    from notifications.models import DeviceToken

    tokens = [
        device.token
        for device in DeviceToken.objects.filter(user=user)
        if tag in (device.tags or [])
    ]
    _send_to_tokens(tokens, title, body, data, url)


def messaging_configured():
    """True when FCM credentials initialised successfully (for health checks)."""
    return _messaging() is not None