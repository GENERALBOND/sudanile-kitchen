from django.test import TestCase, Client
from django.urls import reverse

from users.models import User
from recipes.models import Category, Recipe
from submissions.models import RecipeSubmission
from config.meal_types import clean_meal_types, meal_types_display
from django.core.exceptions import ValidationError


class MealTypeHelpersTests(TestCase):
    def test_clean_accepts_valid_list(self):
        self.assertEqual(clean_meal_types(['breakfast', 'lunch']), ['breakfast', 'lunch'])

    def test_clean_accepts_none_and_empty(self):
        self.assertEqual(clean_meal_types(None), [])
        self.assertEqual(clean_meal_types([]), [])

    def test_clean_deduplicates(self):
        self.assertEqual(clean_meal_types(['breakfast', 'breakfast']), ['breakfast'])

    def test_clean_rejects_unknown_key(self):
        with self.assertRaises(ValidationError):
            clean_meal_types(['brunch'])

    def test_clean_rejects_any_combined(self):
        with self.assertRaises(ValidationError):
            clean_meal_types(['any', 'lunch'])

    def test_display_empty_is_any_time(self):
        self.assertEqual(meal_types_display([]), 'Any time')
        self.assertEqual(meal_types_display(['any']), 'Any time')

    def test_display_joins_labels(self):
        self.assertEqual(meal_types_display(['breakfast', 'lunch']), 'Breakfast, Lunch')
        self.assertEqual(meal_types_display(['dinner']), 'Dinner / Supper')


class MealTypeModelTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email='chef@test.com', username='chef', password='pw'
        )
        self.category = Category.objects.create(name='Stews')

    def test_recipe_default_is_empty_list(self):
        recipe = Recipe.objects.create(
            title='Kisra', description='d', ingredients=['a'],
            instructions=['b'], author=self.user, category=self.category,
        )
        self.assertEqual(recipe.meal_types, [])
        self.assertEqual(recipe.meal_types_display, 'Any time')

    def test_recipe_stores_multiple_meals(self):
        recipe = Recipe.objects.create(
            title='Mullah', description='d', ingredients=['a'],
            instructions=['b'], author=self.user, category=self.category,
            meal_types=['lunch', 'dinner'],
        )
        self.assertEqual(recipe.meal_types, ['lunch', 'dinner'])
        self.assertEqual(recipe.meal_types_display, 'Lunch, Dinner / Supper')


class MealTypeApiTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email='chef@test.com', username='chef', password='pw'
        )
        self.category = Category.objects.create(name='Stews')
        self.breakfast = Recipe.objects.create(
            title='Breakfast Porridge', description='d', ingredients=['a'],
            instructions=['b'], author=self.user, category=self.category,
            meal_types=['breakfast'], is_published=True,
        )
        self.dinner = Recipe.objects.create(
            title='Dinner Stew', description='d', ingredients=['a'],
            instructions=['b'], author=self.user, category=self.category,
            meal_types=['dinner'], is_published=True,
        )
        self.anytime = Recipe.objects.create(
            title='Any Snack', description='d', ingredients=['a'],
            instructions=['b'], author=self.user, category=self.category,
            is_published=True,
        )
        self.hidden = Recipe.objects.create(
            title='Hidden', description='d', ingredients=['a'],
            instructions=['b'], author=self.user, category=self.category,
            meal_types=['lunch'], is_published=False,
        )

    def test_serializer_exposes_meal_types(self):
        resp = self.client.get('/api/recipes/')
        self.assertEqual(resp.status_code, 200)
        data = {r['title']: r for r in resp.json()['results']}
        self.assertEqual(data['Dinner Stew']['meal_types'], ['dinner'])
        self.assertEqual(data['Dinner Stew']['meal_types_display'], 'Dinner / Supper')
        self.assertEqual(data['Any Snack']['meal_types_display'], 'Any time')

    def test_filter_by_single_meal(self):
        resp = self.client.get('/api/recipes/?meal_types=breakfast')
        self.assertEqual(resp.status_code, 200)
        titles = [r['title'] for r in resp.json()['results']]
        self.assertEqual(titles, ['Breakfast Porridge'])

    def test_filter_by_multiple_meals(self):
        resp = self.client.get('/api/recipes/?meal_types=dinner')
        self.assertEqual(resp.status_code, 200)
        titles = [r['title'] for r in resp.json()['results']]
        self.assertIn('Dinner Stew', titles)

    def test_filter_respects_published_only(self):
        resp = self.client.get('/api/recipes/?meal_types=lunch')
        titles = [r['title'] for r in resp.json()['results']]
        self.assertNotIn('Hidden', titles)

    def _auth_headers(self):
        from rest_framework_simplejwt.tokens import RefreshToken
        refresh = RefreshToken.for_user(self.user)
        return {'HTTP_AUTHORIZATION': f'Bearer {refresh.access_token}'}

    def test_submission_serializer_accepts_meal_types(self):
        resp = self.client.post(
            '/api/submissions/create/',
            {
                'title': 'New Dish', 'description': 'd',
                'ingredients': ['a'], 'instructions': ['b'],
                'category_name': 'Stews',
                'meal_types': ['breakfast', 'lunch'],
            },
            content_type='application/json',
            **self._auth_headers(),
        )
        self.assertEqual(resp.status_code, 201, resp.content)
        submission = RecipeSubmission.objects.get(title='New Dish')
        self.assertEqual(submission.meal_types, ['breakfast', 'lunch'])

    def test_submission_serializer_rejects_unknown_meal(self):
        resp = self.client.post(
            '/api/submissions/create/',
            {
                'title': 'Bad Meal', 'description': 'd',
                'ingredients': ['a'], 'instructions': ['b'],
                'category_name': 'Stews',
                'meal_types': ['supper'],
            },
            content_type='application/json',
            **self._auth_headers(),
        )
        self.assertEqual(resp.status_code, 400)


class MealTypeApprovalTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email='chef@test.com', username='chef', password='pw'
        )
        self.submission = RecipeSubmission.objects.create(
            title='Approved Dish', description='d', ingredients=['a'],
            instructions=['b'], category_name='Grains', user=self.user,
            meal_types=['lunch', 'dinner'],
        )

    def test_approval_copies_meal_types_to_recipe(self):
        self.submission.status = 'approved'
        self.submission.save()
        recipe = Recipe.objects.get(title='Approved Dish')
        self.assertEqual(recipe.meal_types, ['lunch', 'dinner'])


class MealTypeAdminTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_superuser(
            email='admin@test.com', username='admin', password='pw'
        )
        self.chef = User.objects.create_user(
            email='chef@test.com', username='chef', password='pw'
        )
        self.category = Category.objects.create(name='Stews')
        self.client = Client()
        self.client.force_login(self.user)

    def test_recipe_change_form_renders_meal_chips(self):
        recipe = Recipe.objects.create(
            title='Kisra', description='d', ingredients=['a'],
            instructions=['b'], author=self.chef, category=self.category,
            meal_types=['breakfast', 'lunch'],
        )
        resp = self.client.get(
            reverse('admin:recipes_recipe_change', args=[recipe.pk])
        )
        self.assertEqual(resp.status_code, 200)
        content = resp.content.decode()
        self.assertIn('name="meal_types"', content)
        self.assertIn('Dinner / Supper', content)
        self.assertIn('value="breakfast" checked', content)

    def test_recipe_admin_save_persists_meal_types(self):
        recipe = Recipe.objects.create(
            title='Kisra', description='d', ingredients=['a'],
            instructions=['b'], author=self.chef, category=self.category,
            meal_types=['breakfast', 'lunch'],
        )
        resp = self.client.post(
            reverse('admin:recipes_recipe_change', args=[recipe.pk]),
            {
                'title': recipe.title, 'description': 'd',
                'author': self.chef.pk, 'category': self.category.pk,
                'servings': '4', 'difficulty': 'medium',
                'ingredients': 'a', 'instructions': 'b',
                'meal_types': ['breakfast'],
                '_save': 'Save',
            },
        )
        self.assertEqual(resp.status_code, 302)
        recipe.refresh_from_db()
        self.assertEqual(recipe.meal_types, ['breakfast'])
