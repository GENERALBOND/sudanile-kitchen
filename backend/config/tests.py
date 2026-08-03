import os
import secrets
import string

from django.test import TestCase
from django.urls import reverse
from users.models import User

# Test-only password, overridable via env so no real credential is committed.
TEST_ADMIN_PASSWORD = os.environ.get(
    'TEST_ADMIN_PASSWORD',
    ''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range(24)),
)


class LandingPageTests(TestCase):
    def test_home_page_renders_landing_page(self):
        response = self.client.get(reverse('home'))

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, 'Sudanile Kitchen · Login')
        self.assertContains(response, 'Access dashboard')

    def test_admin_login_redirects_to_admin_dashboard(self):
        User.objects.create_superuser(email='admin@sudanile.kitchen', username='admin', password=TEST_ADMIN_PASSWORD)

        response = self.client.post(
            reverse('home'),
            {'email': 'admin@sudanile.kitchen', 'password': TEST_ADMIN_PASSWORD},
            follow=False,
        )

        self.assertEqual(response.status_code, 302)
        self.assertEqual(response.url, '/admin/')

    def test_authenticated_staff_still_sees_landing_page_on_get(self):
        user = User.objects.create_superuser(email='staff@sudanile.kitchen', username='staff', password=TEST_ADMIN_PASSWORD)
        self.client.force_login(user)

        response = self.client.get(reverse('home'))

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, 'Sudanile Kitchen · Login')
