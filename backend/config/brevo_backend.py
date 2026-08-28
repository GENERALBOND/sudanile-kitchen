import logging

import requests
from django.conf import settings
from django.core.mail.backends.base import BaseEmailBackend
from django.core.mail.message import sanitize_address

logger = logging.getLogger(__name__)

# Brevo (ex-Sendinblue) transactional email REST API.
# Docs: https://developers.brevo.com/docs/sending-emails
SEND_URL = 'https://api.brevo.com/v3/smtp/email'


def _addr_spec(address, encoding):
    """Extract the bare 'x@y' from sanitize_address across Django versions.

    Django <=5 returns an Address(display_name, addr_spec) namedtuple; Django 6
    returns a formatted string like 'Name <x@y>' (or just 'x@y').
    """
    sanitized = sanitize_address(address, encoding)
    if isinstance(sanitized, str):
        return sanitized[sanitized.rfind('<') + 1:sanitized.find('>')] if '>' in sanitized else sanitized
    return sanitized[1]


def _display_name(address, encoding):
    """Extract the display name ('Name' from 'Name <x@y>') across Django versions."""
    sanitized = sanitize_address(address, encoding)
    if isinstance(sanitized, str):
        if '>' in sanitized and '<' in sanitized:
            return sanitized[:sanitized.rfind('<')].strip().strip('"')
        return ''
    return sanitized[0]


class BrevoEmailBackend(BaseEmailBackend):
    """Sends email through Brevo's transactional REST API over plain HTTPS.

    Replaces the SMTP backend: Render instances cannot open outbound SMTP
    connections (Gmail and Brevo SMTP both time out / ENETUNREACH), while
    HTTPS egress works fine. Call sites keep using django.core.mail as usual.
    """

    def __init__(self, fail_silently=False, **kwargs):
        super().__init__(fail_silently=fail_silently)
        self.api_key = getattr(settings, 'BREVO_API_KEY', '')
        self.timeout = getattr(settings, 'BREVO_TIMEOUT', 10)
        default_from = getattr(settings, 'DEFAULT_FROM_EMAIL', '')
        self.sender = _addr_spec(default_from, settings.DEFAULT_CHARSET)
        self.sender_name = getattr(settings, 'BREVO_SENDER_NAME', '')

    def send_messages(self, email_messages):
        messages = list(email_messages)
        if not messages:
            return 0
        if not self.api_key:
            self._fail('BREVO_API_KEY is not set (Brevo -> SMTP & API -> API keys).')
            return 0

        sent = 0
        for message in messages:
            recipients = [_addr_spec(addr, message.encoding) for addr in message.to]
            if not recipients:
                self._fail(f'No recipients for message from {message.from_email}')
                continue

            body = message.body
            if isinstance(body, bytes):
                body = body.decode(message.encoding or 'utf-8')
            html = None
            for alternative in getattr(message, 'alternatives', []) or []:
                content, mimetype = (
                    (alternative.content, alternative.mimetype)
                    if hasattr(alternative, 'content') else alternative
                )
                if mimetype == 'text/html':
                    html = content
                    break

            sender_email = _addr_spec(message.from_email, message.encoding) or self.sender
            if not sender_email:
                self._fail('DEFAULT_FROM_EMAIL is not set, and the message has no from_email.')
                continue
            sender_name = _display_name(message.from_email, message.encoding) or self.sender_name

            payload = {
                'sender': {'name': sender_name, 'email': sender_email},
                'to': [{'email': addr} for addr in recipients],
                'subject': message.subject,
                'textContent': body,
            }
            if html:
                payload['htmlContent'] = html
            if message.reply_to:
                payload['replyTo'] = {'email': _addr_spec(message.reply_to[0], message.encoding)}

            try:
                response = requests.post(
                    SEND_URL,
                    json=payload,
                    headers={'api-key': self.api_key, 'Content-Type': 'application/json'},
                    timeout=self.timeout,
                )
            except requests.RequestException as exc:
                self._fail(f'Brevo API request failed: {exc}')
                continue

            if response.status_code not in (200, 201, 202):
                self._fail(f'Brevo API returned HTTP {response.status_code}: {response.text[:500]}')
                continue

            sent += 1
            logger.info('Sent "%s" to %s via Brevo', message.subject, ', '.join(recipients))
        return sent

    def _fail(self, error):
        if self.fail_silently:
            logger.error('Brevo email send suppressed: %s', error)
            return
        raise RuntimeError(error)
