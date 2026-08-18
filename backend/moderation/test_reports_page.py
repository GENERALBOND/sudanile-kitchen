from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from django.urls import reverse

from community.models import Post, PostComment
from moderation.models import ModerationEvent, Report

from .tests import create_user, make_image

User = get_user_model()


@override_settings(
    FIREBASE_SERVICE_ACCOUNT='',
    FIREBASE_SERVICE_ACCOUNT_JSON='',
    FIREBASE_SERVICE_ACCOUNT_BASE64='',
)
class ReportsPageTests(TestCase):
    def setUp(self):
        self.admin = User.objects.create_superuser(
            email='admin@example.com', username='admin@example.com', password='pw'
        )
        self.author = create_user(email='author@example.com')
        self.reporter = create_user(email='reporter@example.com')
        self.post = Post.objects.create(user=self.author, image=make_image(), caption='Flag me')
        self.comment = PostComment.objects.create(post=self.post, user=self.author, comment='Bad comment')
        self.report = Report.objects.create(
            target_type='post', post=self.post,
            reporter=self.reporter, reason='harassment',
        )
        self.url = reverse('admin_reports')

    def login(self):
        self.assertTrue(self.client.login(email='admin@example.com', password='pw'))

    # ---- Access control ------------------------------------------------

    def test_anonymous_redirected(self):
        response = self.client.get(self.url)
        self.assertIn(response.status_code, (302, 403))

    def test_non_staff_redirected_to_admin_login(self):
        user = create_user(email='staff_no@example.com')
        self.client.force_login(user)
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, 302)
        self.assertIn('/admin/login/', response.get('Location', ''))

    def test_staff_can_view(self):
        self.login()
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, 200)
        content = response.content.decode()
        for probe in ('Moderation Reports', 'Bulk action', 'Flag me', 'reporter@example.com'):
            self.assertIn(probe, content)

    # ---- Filters & search ----------------------------------------------

    def test_status_filters_render(self):
        self.login()
        for status in ('active', 'pending', 'auto_hidden', 'resolved', 'dismissed', 'all'):
            response = self.client.get(self.url, {'status': status})
            self.assertEqual(response.status_code, 200, f'status={status}')

    def test_search_filters_by_snapshot(self):
        self.login()
        response = self.client.get(self.url, {'q': 'Flag me'})
        self.assertEqual(response.status_code, 200)
        self.assertIn('Flag me', response.content.decode())
        response = self.client.get(self.url, {'q': 'zzz-no-match-zzz'})
        self.assertIn('No reports found', response.content.decode())

    def test_invalid_status_falls_back_to_active(self):
        self.login()
        response = self.client.get(self.url, {'status': 'bogus'})
        self.assertEqual(response.status_code, 200)

    # ---- Bulk actions ---------------------------------------------------

    def test_dismiss_restores_content(self):
        self.post.is_flagged = True
        self.post.save(update_fields=['is_flagged'])
        Report.objects.filter(pk=self.report.pk).update(status='auto_hidden')
        self.login()
        response = self.client.post(self.url, {
            'action': 'dismiss_reports', 'report_ids': [str(self.report.pk)],
        })
        self.assertEqual(response.status_code, 302)
        self.report.refresh_from_db()
        self.post.refresh_from_db()
        self.assertEqual(self.report.status, 'dismissed')
        self.assertFalse(self.post.is_flagged)

    def test_hide_content_flags_and_records_event(self):
        self.login()
        self.client.post(self.url, {
            'action': 'hide_content', 'report_ids': [str(self.report.pk)],
        })
        self.report.refresh_from_db()
        self.post.refresh_from_db()
        self.assertEqual(self.report.status, 'resolved')
        self.assertEqual(self.report.action_taken, 'hidden')
        self.assertTrue(self.post.is_flagged)
        self.assertTrue(ModerationEvent.objects.filter(user=self.author, event_type='hidden').exists())

    def test_delete_content_removes_post(self):
        self.login()
        self.client.post(self.url, {
            'action': 'delete_content', 'report_ids': [str(self.report.pk)],
        })
        self.report.refresh_from_db()
        self.assertFalse(Post.objects.filter(pk=self.post.pk).exists())
        self.assertEqual(self.report.status, 'resolved')
        self.assertEqual(self.report.action_taken, 'deleted')

    def test_warn_author_records_event(self):
        self.login()
        self.client.post(self.url, {
            'action': 'warn_author', 'report_ids': [str(self.report.pk)],
        })
        self.report.refresh_from_db()
        self.assertEqual(self.report.action_taken, 'warned')
        self.assertTrue(ModerationEvent.objects.filter(user=self.author, event_type='warned').exists())

    def test_ban_user_disables_account(self):
        self.login()
        self.client.post(self.url, {
            'action': 'ban_user', 'report_ids': [str(self.report.pk)],
        })
        self.report.refresh_from_db()
        self.assertEqual(self.report.action_taken, 'banned')
        self.author.refresh_from_db()
        self.assertFalse(self.author.is_active)

    def test_no_action_selected_shows_warning(self):
        self.login()
        response = self.client.post(self.url, {'report_ids': [str(self.report.pk)]})
        self.assertEqual(response.status_code, 302)
        self.report.refresh_from_db()
        self.assertEqual(self.report.status, 'pending')

    def test_unknown_action_shows_error(self):
        self.login()
        response = self.client.post(self.url, {
            'action': 'delete_everything', 'report_ids': [str(self.report.pk)],
        })
        self.assertEqual(response.status_code, 302)
        self.report.refresh_from_db()
        self.assertEqual(self.report.status, 'pending')

    def test_no_ids_noop(self):
        self.login()
        response = self.client.post(self.url, {'action': 'dismiss_reports'})
        self.assertEqual(response.status_code, 302)

    def test_comment_report_listed_and_actionable(self):
        self.login()
        comment_report = Report.objects.create(
            target_type='comment', comment=self.comment,
            reporter=self.reporter, reason='spam',
        )
        response = self.client.get(self.url)
        self.assertIn('Bad comment', response.content.decode())
        self.client.post(self.url, {
            'action': 'hide_content', 'report_ids': [str(comment_report.pk)],
        })
        comment_report.refresh_from_db()
        self.comment.refresh_from_db()
        self.assertEqual(comment_report.status, 'resolved')
        self.assertTrue(self.comment.is_flagged)


class ReportDetailPageTests(TestCase):
    def setUp(self):
        self.admin = User.objects.create_superuser(
            email='admin@example.com', username='admin@example.com', password='pw'
        )
        self.author = create_user(email='author@example.com')
        self.reporter = create_user(email='reporter@example.com')
        self.post = Post.objects.create(user=self.author, image=make_image(), caption='Flag me')
        self.report = Report.objects.create(
            target_type='post', post=self.post,
            reporter=self.reporter, reason='harassment',
        )

    def login(self):
        self.assertTrue(self.client.login(email='admin@example.com', password='pw'))

    def detail_url(self, report):
        return reverse('admin_report_detail', args=[report.pk])

    def test_anonymous_redirected(self):
        response = self.client.get(self.detail_url(self.report))
        self.assertIn(response.status_code, (302, 403))

    def test_staff_can_view_report(self):
        self.login()
        response = self.client.get(self.detail_url(self.report))
        self.assertEqual(response.status_code, 200)
        content = response.content.decode()
        for probe in ('Report #', 'Flag me', 'reporter@example.com', 'author@example.com',
                      'Harassment or bullying', 'Moderation actions'):
            self.assertIn(probe, content)

    def test_missing_report_is_404(self):
        self.login()
        response = self.client.get(reverse('admin_report_detail', args=[99999]))
        self.assertEqual(response.status_code, 404)

    def test_deleted_target_still_renders(self):
        self.login()
        self.post.delete()
        self.report.refresh_from_db()
        response = self.client.get(self.detail_url(self.report))
        self.assertEqual(response.status_code, 200)
        self.assertIn('Flag me', response.content.decode())

    def test_dismiss_from_detail_page(self):
        self.post.is_flagged = True
        self.post.save(update_fields=['is_flagged'])
        Report.objects.filter(pk=self.report.pk).update(status='auto_hidden')
        self.login()
        response = self.client.post(self.detail_url(self.report), {'action': 'dismiss_reports'})
        self.assertEqual(response.status_code, 302)
        self.report.refresh_from_db()
        self.post.refresh_from_db()
        self.assertEqual(self.report.status, 'dismissed')
        self.assertFalse(self.post.is_flagged)

    def test_hide_content_from_detail_page(self):
        self.login()
        response = self.client.post(self.detail_url(self.report), {'action': 'hide_content'})
        self.assertEqual(response.status_code, 302)
        self.report.refresh_from_db()
        self.post.refresh_from_db()
        self.assertEqual(self.report.action_taken, 'hidden')
        self.assertTrue(self.post.is_flagged)

    def test_delete_content_from_detail_page(self):
        self.login()
        response = self.client.post(self.detail_url(self.report), {'action': 'delete_content'})
        self.assertEqual(response.status_code, 302)
        self.report.refresh_from_db()
        self.assertFalse(Post.objects.filter(pk=self.post.pk).exists())
        self.assertEqual(self.report.action_taken, 'deleted')
        response = self.client.get(self.detail_url(self.report))
        self.assertEqual(response.status_code, 200)

    def test_save_admin_note(self):
        self.login()
        response = self.client.post(self.detail_url(self.report), {
            'action': 'save_note', 'admin_note': 'Reviewed; keep an eye on this author.',
        })
        self.assertEqual(response.status_code, 302)
        self.report.refresh_from_db()
        self.assertEqual(self.report.admin_note, 'Reviewed; keep an eye on this author.')

    def test_unknown_action_redirects_without_changes(self):
        self.login()
        response = self.client.post(self.detail_url(self.report), {'action': 'delete_everything'})
        self.assertEqual(response.status_code, 302)
        self.report.refresh_from_db()
        self.assertEqual(self.report.status, 'pending')
