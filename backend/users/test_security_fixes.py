import json

from rest_framework import status
from django.test import TestCase

from .models import User


class SecurityFixesTests(TestCase):
    def test_inactive_user_cannot_login_via_password(self):
        """A disabled (is_active=False) account must not get JWTs on login."""
        User.objects.create_user(
            username='inact1', email='inact1@test.com', password='Str0ng!Passw0rd'
        )
        u = User.objects.get(email='inact1@test.com')
        u.is_active = False
        u.save()
        resp = self.client.post(
            '/api/users/login/',
            data=json.dumps({
                'email': 'inact1@test.com', 'password': 'Str0ng!Passw0rd',
            }),
            content_type='application/json',
        )
        self.assertEqual(resp.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_active_user_can_login(self):
        User.objects.create_user(
            username='act1', email='act1@test.com', password='Str0ng!Passw0rd'
        )
        resp = self.client.post(
            '/api/users/login/',
            data=json.dumps({'email': 'act1@test.com', 'password': 'Str0ng!Passw0rd'}),
            content_type='application/json',
        )
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertIn('access', resp.json())

    def test_protected_endpoint_requires_auth(self):
        resp = self.client.get('/api/users/profile/')
        self.assertEqual(resp.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_public_recipes_readable_without_auth(self):
        resp = self.client.get('/api/recipes/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)

    def test_change_password_enforces_validators(self):
        User.objects.create_user(
            username='cp1', email='cp1@test.com', password='Str0ng!Passw0rd'
        )
        login = self.client.post(
            '/api/users/login/',
            data=json.dumps({'email': 'cp1@test.com', 'password': 'Str0ng!Passw0rd'}),
            content_type='application/json',
        )
        access = login.json()['access']
        resp = self.client.post(
            '/api/users/change-password/',
            data=json.dumps({
                'old_password': 'Str0ng!Passw0rd', 'new_password': 'short',
            }),
            content_type='application/json',
            HTTP_AUTHORIZATION=f'Bearer {access}',
        )
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)
