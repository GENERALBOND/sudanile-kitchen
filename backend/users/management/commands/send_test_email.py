import socket
import traceback

from django.conf import settings
from django.core.mail import EmailMessage, get_connection
from django.core.management.base import BaseCommand, CommandError


class Command(BaseCommand):
    help = 'Send a test email through the configured SMTP backend to reveal the exact error.'

    def add_arguments(self, parser):
        parser.add_argument('recipient', nargs='?', default='')
        parser.add_argument(
            '--recipient',
            dest='recipient_opt',
            default='',
            help='Email address to send the test message to.',
        )

    def handle(self, *args, **options):
        recipient = options.get('recipient') or options.get('recipient_opt')
        if not recipient:
            raise CommandError('Pass a recipient address, e.g. manage.py send_test_email you@gmail.com')

        backend = settings.EMAIL_BACKEND
        host = settings.EMAIL_HOST
        port = settings.EMAIL_PORT
        tls = settings.EMAIL_USE_TLS
        ssl = settings.EMAIL_USE_SSL
        user = settings.EMAIL_HOST_USER
        password = settings.EMAIL_HOST_PASSWORD
        from_email = settings.DEFAULT_FROM_EMAIL

        self.stdout.write(f'Backend   : {backend}')
        self.stdout.write(f'Host      : {host}')
        self.stdout.write(f'Port      : {port}')
        self.stdout.write(f'TLS       : {tls}')
        self.stdout.write(f'SSL       : {ssl}')
        self.stdout.write(f'User      : {user or "(empty)"}')
        self.stdout.write(f'Password  : {"(set, " + str(len(password)) + " chars)" if password else "(empty)"}')
        self.stdout.write(f'From      : {from_email}')
        self.stdout.write(f'To        : {recipient}')

        if not user or not password:
            self.stderr.write(self.style.ERROR(
                'EMAIL_HOST_USER / EMAIL_HOST_PASSWORD are not set. '
                'Gmail requires an App Password (not your normal login).'
            ))

        self.stdout.write('\nResolving host...')
        try:
            for info in socket.getaddrinfo(host, port, proto=socket.IPPROTO_TCP):
                self.stdout.write(f'  -> {info[0].name} {info[4]}')
        except Exception as exc:
            self.stderr.write(self.style.ERROR(f'DNS lookup failed: {exc}'))

        self.stdout.write('\nConnecting & sending...')
        try:
            conn = get_connection(
                backend=backend,
                host=host,
                port=port,
                username=user,
                password=password,
                use_tls=tls,
                use_ssl=ssl,
                from_email=from_email,
                fail_silently=False,
                timeout=getattr(settings, 'EMAIL_TIMEOUT', 5),
            )
            conn.open()
            self.stdout.write(f'Connected to {host}:{port} OK')
            message = EmailMessage(
                subject='Sudanile Kitchen test email',
                body='This is a test email from the Sudanile Kitchen backend.',
                from_email=from_email,
                to=[recipient],
                connection=conn,
            )
            sent = message.send()
            self.stdout.write(self.style.SUCCESS(f'OK — {sent} message(s) sent.'))
        except Exception:
            self.stderr.write(self.style.ERROR('Send failed with the following error:'))
            traceback.print_exc()
            raise CommandError('Test email failed. See error above.')