from unittest import mock

from django.test import TestCase, Client, override_settings
from django.contrib.auth import get_user_model
from submissions.models import RecipeSubmission
from recipes.models import Category, Recipe


@override_settings(
    EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend',
    FIREBASE_SERVICE_ACCOUNT='',
    FIREBASE_SERVICE_ACCOUNT_JSON='',
    FIREBASE_SERVICE_ACCOUNT_BASE64='',
)
class AdminApprovalTest(TestCase):
    def setUp(self):
        User = get_user_model()
        self.user = User.objects.create_user(
            username='tester', email='tester@test.com', password='pw')
        self.admin = User.objects.create_superuser(
            username='admin', email='admin@test.com', password='pw')
        self.category, _ = Category.objects.get_or_create(name='Test Cat')

    def _make_submission(self, title='Kisra Test', status='pending'):
        return RecipeSubmission.objects.create(
            user=self.user,
            title=title,
            description='A test dish',
            ingredients=['a', 'b', 'c'],
            instructions=['step one', 'step two'],
            category_name=self.category.name,
            status=status,
        )

    def test_approve_via_change_form(self):
        sub = self._make_submission()
        c = Client()
        self.assertTrue(c.login(username='admin@test.com', password='pw'))
        resp = c.post(f'/admin/submissions/recipesubmission/{sub.pk}/change/', {
            'title': sub.title,
            'description': sub.description,
            'user': self.user.pk,
            'category_name': self.category.name,
            'prep_hours': 0, 'prep_minutes': 0, 'prep_seconds': 0,
            'cook_hours': 0, 'cook_minutes': 0, 'cook_seconds': 0,
            'servings': 4, 'difficulty': 'medium',
            'ingredients': 'a\nb\nc',
            'instructions': 'step one\nstep two',
            'cultural_info': '',
            'image_url': '',
            'status': 'approved',
            'admin_notes': '',
            '_save': 'Save',
        }, follow=True)
        self.assertEqual(resp.status_code, 200)
        sub.refresh_from_db()
        self.assertEqual(sub.status, 'approved')

    def test_approve_via_bulk_action(self):
        sub = self._make_submission()
        c = Client()
        self.assertTrue(c.login(username='admin@test.com', password='pw'))
        resp = c.post('/admin/submissions/recipesubmission/', {
            'action': 'approve_submissions',
            '_selected_action': [str(sub.pk)],
            'index': '0',
        }, follow=True)
        self.assertEqual(resp.status_code, 200)
        sub.refresh_from_db()
        self.assertEqual(sub.status, 'approved')

    def test_approve_failure_rolls_back_and_shows_message(self):
        """A failure in the approval chain must not mark the submission
        approved, and must surface a friendly admin message (not a 500)."""
        sub = self._make_submission()
        c = Client()
        self.assertTrue(c.login(username='admin@test.com', password='pw'))

        with mock.patch(
            'recipes.models.Recipe.objects.create',
            side_effect=RuntimeError('boom: simulated recipe failure'),
        ):
            resp = c.post(f'/admin/submissions/recipesubmission/{sub.pk}/change/', {
                'title': sub.title,
                'description': sub.description,
                'user': self.user.pk,
                'category_name': self.category.name,
                'prep_hours': 0, 'prep_minutes': 0, 'prep_seconds': 0,
                'cook_hours': 0, 'cook_minutes': 0, 'cook_seconds': 0,
                'servings': 4, 'difficulty': 'medium',
                'ingredients': 'a\nb\nc',
                'instructions': 'step one\nstep two',
                'cultural_info': '',
                'image_url': '',
                'status': 'approved',
                'admin_notes': '',
                '_save': 'Save',
            }, follow=True)

        self.assertEqual(resp.status_code, 200)
        sub.refresh_from_db()
        self.assertEqual(sub.status, 'pending')
        self.assertFalse(Recipe.objects.exists())
        self.assertContains(resp, 'Approval failed and was rolled back: boom')

