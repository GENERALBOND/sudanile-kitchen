import traceback

from django.conf import settings
from django.core.mail import EmailMessage, get_connection
from django.core.management.base import BaseCommand, CommandError


class Command(BaseCommand):
    help = 'Send a test email through the Brevo backend to reveal the exact error.'

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

        api_key = getattr(settings, 'BREVO_API_KEY', '')
        sender = getattr(settings, 'DEFAULT_FROM_EMAIL', '')

        self.stdout.write(f'Backend : {settings.EMAIL_BACKEND}')
        self.stdout.write(f'API key : {"(set, " + str(len(api_key)) + " chars)" if api_key else "(empty)"}')
        self.stdout.write(f'Sender  : {sender or "(empty)"}')
        self.stdout.write(f'To      : {recipient}')

        if not api_key:
            self.stderr.write(self.style.ERROR(
                'BREVO_API_KEY is not set. Create one under Brevo -> SMTP & API -> API keys.'
            ))
        if not sender:
            self.stderr.write(self.style.ERROR(
                'DEFAULT_FROM_EMAIL is not set (and it must be a verified Brevo sender).'
            ))

        self.stdout.write('\nSending...')
        try:
            conn = get_connection(fail_silently=False)
            message = EmailMessage(
                subject='Sudanile Kitchen test email',
                body='This is a test email from the Sudanile Kitchen backend.',
                from_email=sender,
                to=[recipient],
                connection=conn,
            )
            sent = message.send()
            self.stdout.write(self.style.SUCCESS(f'OK — {sent} message(s) sent.'))
        except Exception:
            self.stderr.write(self.style.ERROR('Send failed with the following error:'))
            traceback.print_exc()
            raise CommandError('Test email failed. See error above.')
