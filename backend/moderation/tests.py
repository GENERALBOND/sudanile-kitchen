from django.contrib.auth import get_user_model
from django.contrib.messages.storage.fallback import FallbackStorage
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import RequestFactory, TestCase, override_settings
from django.urls import reverse
from PIL import Image
from rest_framework.test import APIClient

from community.models import Post, PostComment
from moderation.models import ModerationEvent, Report

User = get_user_model()


def make_image(name='test.png'):
    from io import BytesIO
    buffer = BytesIO()
    Image.new('RGB', (20, 20), color='red').save(buffer, format='PNG')
    buffer.seek(0)
    return SimpleUploadedFile(name, buffer.read(), content_type='image/png')


def create_user(email='user@example.com', **kwargs):
    return User.objects.create_user(email=email, username=email, password='pw', **kwargs)


def admin_request(user):
    """Build a minimal request carrying a user and a message storage backend,
    enough for ModelAdmin actions."""
    request = RequestFactory().post('/')
    request.user = user
    setattr(request, 'session', 'session')
    setattr(request, '_messages', FallbackStorage(request))
    return request


class ReportApiTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.reporter = create_user()
        self.author = create_user(email='author@example.com')
        self.post = Post.objects.create(
            user=self.author,
            image=make_image(),
            caption='Offensive caption here',
        )
        self.comment = PostComment.objects.create(
            post=self.post, user=self.author, comment='Spammy comment text'
        )
        self.url = reverse('community-report')

    def test_requires_authentication(self):
        response = self.client.post(self.url, {'target_type': 'post', 'target_id': self.post.id})
        self.assertEqual(response.status_code, 401)

    def test_report_post_creates_report_with_snapshot(self):
        self.client.force_authenticate(self.reporter)
        response = self.client.post(
            self.url,
            {'target_type': 'post', 'target_id': self.post.id, 'reason': 'harassment'},
        )
        self.assertEqual(response.status_code, 201)
        report = Report.objects.get()
        self.assertEqual(report.reporter, self.reporter)
        self.assertEqual(report.target_type, 'post')
        self.assertEqual(report.status, 'pending')
        self.assertEqual(report.content_snapshot, 'Offensive caption here')

    def test_report_comment(self):
        self.client.force_authenticate(self.reporter)
        response = self.client.post(
            self.url,
            {'target_type': 'comment', 'target_id': self.comment.id, 'reason': 'spam',
             'details': 'Looks automated'},
        )
        self.assertEqual(response.status_code, 201)
        report = Report.objects.get()
        self.assertEqual(report.target_type, 'comment')
        self.assertEqual(report.comment_id, self.comment.id)
        self.assertEqual(report.details, 'Looks automated')

    def test_duplicate_report_is_rejected(self):
        self.client.force_authenticate(self.reporter)
        first = self.client.post(
            self.url,
            {'target_type': 'post', 'target_id': self.post.id, 'reason': 'spam'},
        )
        second = self.client.post(
            self.url,
            {'target_type': 'post', 'target_id': self.post.id, 'reason': 'other'},
        )
        self.assertEqual(first.status_code, 201)
        self.assertEqual(second.status_code, 200)
        self.assertEqual(Report.objects.count(), 1)

    def test_invalid_payloads(self):
        self.client.force_authenticate(self.reporter)
        response = self.client.post(
            self.url, {'target_type': 'bogus', 'target_id': 1, 'reason': 'spam'}
        )
        self.assertEqual(response.status_code, 400)
        response = self.client.post(
            self.url, {'target_type': 'post', 'target_id': 1, 'reason': 'not-a-reason'}
        )
        self.assertEqual(response.status_code, 400)
        response = self.client.post(
            self.url, {'target_type': 'post', 'target_id': 99999, 'reason': 'spam'}
        )
        self.assertEqual(response.status_code, 404)


class AutoHideTests(TestCase):
    def setUp(self):
        self.author = create_user()
        self.post = Post.objects.create(user=self.author, image=make_image(), caption='Target post')
        self.comment = PostComment.objects.create(post=self.post, user=self.author, comment='Target comment')
        self.post_url = reverse('community-post-list')
        self.comment_url = reverse('community-comment-list', args=[self.post.id])

    @override_settings(REPORT_AUTO_HIDE_THRESHOLD=3)
    def test_post_auto_hidden_after_threshold(self):
        for i in range(3):
            Report.objects.create(
                target_type='post', post=self.post,
                reporter=create_user(email=f'reporter{i}@example.com'),
                reason='spam',
            )
        self.post.refresh_from_db()
        self.assertTrue(self.post.is_flagged)
        self.assertEqual(Report.objects.filter(status='auto_hidden').count(), 3)
        response = self.client.get(self.post_url)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json().get('count'), 0)

    @override_settings(REPORT_AUTO_HIDE_THRESHOLD=3)
    def test_comment_auto_hidden_after_threshold(self):
        for i in range(3):
            Report.objects.create(
                target_type='comment', comment=self.comment,
                reporter=create_user(email=f'reporter{i}@example.com'),
                reason='spam',
            )
        self.comment.refresh_from_db()
        self.assertTrue(self.comment.is_flagged)
        response = self.client.get(self.comment_url)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.json()['results']), 0)

    @override_settings(REPORT_AUTO_HIDE_THRESHOLD=3)
    def test_below_threshold_not_hidden(self):
        Report.objects.create(
            target_type='post', post=self.post,
            reporter=create_user(email='r1@example.com'), reason='spam',
        )
        self.post.refresh_from_db()
        self.assertFalse(self.post.is_flagged)


class AdminActionTests(TestCase):
    def setUp(self):
        self.superuser = User.objects.create_superuser(
            email='admin@example.com', username='admin@example.com', password='pw'
        )
        self.author = create_user(email='author2@example.com')
        self.reporter = create_user(email='reporter2@example.com')
        self.post = Post.objects.create(user=self.author, image=make_image(), caption='Flag me')
        self.comment = PostComment.objects.create(post=self.post, user=self.author, comment='Bad comment')
        self.report = Report.objects.create(
            target_type='post', post=self.post,
            reporter=self.reporter, reason='inappropriate',
        )

    def test_dismiss_restores_content(self):
        self.post.is_flagged = True
        self.post.save(update_fields=['is_flagged'])
        Report.objects.filter(pk=self.report.pk).update(status='auto_hidden')
        self.report.refresh_from_db()

        from moderation.admin import ReportAdmin
        admin_obj = ReportAdmin(Report, None)
        admin_obj.dismiss_reports(admin_request(self.superuser), Report.objects.filter(pk=self.report.pk))

        self.report.refresh_from_db()
        self.post.refresh_from_db()
        self.assertEqual(self.report.status, 'dismissed')
        self.assertFalse(self.post.is_flagged)

    def test_hide_flags_content_and_records_event(self):
        from moderation.admin import ReportAdmin
        admin_obj = ReportAdmin(Report, None)
        admin_obj.hide_content(admin_request(self.superuser), Report.objects.filter(pk=self.report.pk))

        self.report.refresh_from_db()
        self.post.refresh_from_db()
        self.assertEqual(self.report.status, 'resolved')
        self.assertEqual(self.report.action_taken, 'hidden')
        self.assertTrue(self.post.is_flagged)
        self.assertTrue(ModerationEvent.objects.filter(user=self.author, event_type='hidden').exists())

    def test_delete_removes_content_but_keeps_report(self):
        from moderation.admin import ReportAdmin
        admin_obj = ReportAdmin(Report, None)
        admin_obj.delete_content(admin_request(self.superuser), Report.objects.filter(pk=self.report.pk))

        self.report.refresh_from_db()
        self.assertFalse(Post.objects.filter(pk=self.post.pk).exists())
        self.assertEqual(self.report.post_id, None)
        self.assertEqual(self.report.status, 'resolved')
        self.assertEqual(self.report.action_taken, 'deleted')
        self.assertTrue(ModerationEvent.objects.filter(user=self.author, event_type='deleted').exists())

    def test_warn_author_records_event(self):
        from moderation.admin import ReportAdmin
        admin_obj = ReportAdmin(Report, None)
        admin_obj.warn_author(admin_request(self.superuser), Report.objects.filter(pk=self.report.pk))

        self.report.refresh_from_db()
        self.assertEqual(self.report.action_taken, 'warned')
        self.assertTrue(ModerationEvent.objects.filter(user=self.author, event_type='warned').exists())

    def test_ban_disables_account(self):
        from moderation.admin import ReportAdmin
        admin_obj = ReportAdmin(Report, None)
        admin_obj.ban_user(admin_request(self.superuser), Report.objects.filter(pk=self.report.pk))

        self.report.refresh_from_db()
        self.assertEqual(self.report.action_taken, 'banned')
        self.author.refresh_from_db()
        self.assertFalse(self.author.is_active)