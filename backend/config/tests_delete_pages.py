from django.contrib.auth import get_user_model
from django.contrib.auth.models import Group
from django.test import TestCase, override_settings

from favorites.models import Favorite
from recipes.models import Category, Recipe
from reviews.models import Review
from submissions.models import RecipeSubmission

User = get_user_model()


@override_settings(
    FIREBASE_SERVICE_ACCOUNT='',
    FIREBASE_SERVICE_ACCOUNT_JSON='',
    FIREBASE_SERVICE_ACCOUNT_BASE64='',
)
class DeletePageTests(TestCase):
    """The custom delete-confirmation pages must render with the admin shell
    and actually delete the object on confirm."""

    def setUp(self):
        self.admin = User.objects.create_superuser(
            email='admin@example.com', username='admin@example.com', password='pw'
        )
        self.author = User.objects.create_user(
            email='author@example.com', username='author@example.com', password='pw'
        )
        self.category = Category.objects.create(name='Test Category')
        self.recipe = Recipe.objects.create(
            title='Test Recipe', description='A recipe',
            ingredients=['a'], instructions=['b'],
            category=self.category, author=self.author,
        )
        self.favorite = Favorite.objects.create(user=self.author, recipe=self.recipe)
        self.review = Review.objects.create(
            user=self.author, recipe=self.recipe, rating=5, comment='Great'
        )
        self.submission = RecipeSubmission.objects.create(
            user=self.author, title='Test Submission', description='desc',
            ingredients=['a'], instructions=['b'], category_name='Test Category',
        )
        self.group = Group.objects.create(name='Editors')

    def login(self):
        self.assertTrue(self.client.login(email='admin@example.com', password='pw'))

    def _delete_urls(self):
        return [
            f'/admin/auth/group/{self.group.pk}/delete/',
            f'/admin/users/user/{self.author.pk}/delete/',
            f'/admin/category/{self.category.pk}/delete/',
            f'/admin/recipes/recipe/{self.recipe.pk}/delete/',
            f'/admin/submissions/recipesubmission/{self.submission.pk}/delete/',
            f'/admin/favorites/favorite/{self.favorite.pk}/delete/',
            f'/admin/reviews/review/{self.review.pk}/delete/',
        ]

    def test_all_delete_pages_render_with_custom_ui(self):
        self.login()
        for url in self._delete_urls():
            response = self.client.get(url)
            self.assertEqual(response.status_code, 200, f'{url} -> {response.status_code}')
            content = response.content.decode()
            self.assertIn('Sudanile Kitchen Admin', content)
            self.assertIn('Are you sure you want to delete', content)
            self.assertIn("Yes, I'm sure", content)
            self.assertIn('No, take me back', content)

    def test_delete_group(self):
        self.login()
        self.assertEqual(self.client.post(f'/admin/auth/group/{self.group.pk}/delete/', {'post': 'yes'}).status_code, 302)
        self.assertFalse(Group.objects.filter(pk=self.group.pk).exists())

    def test_delete_user(self):
        self.login()
        self.assertEqual(self.client.post(f'/admin/users/user/{self.author.pk}/delete/', {'post': 'yes'}).status_code, 302)
        self.assertFalse(User.objects.filter(pk=self.author.pk).exists())

    def test_delete_category(self):
        self.login()
        self.assertEqual(self.client.post(f'/admin/category/{self.category.pk}/delete/', {'post': 'yes'}).status_code, 302)
        self.assertFalse(Category.objects.filter(pk=self.category.pk).exists())

    def test_delete_recipe(self):
        self.login()
        self.assertEqual(self.client.post(f'/admin/recipes/recipe/{self.recipe.pk}/delete/', {'post': 'yes'}).status_code, 302)
        self.assertFalse(Recipe.objects.filter(pk=self.recipe.pk).exists())

    def test_delete_submission(self):
        self.login()
        self.assertEqual(self.client.post(f'/admin/submissions/recipesubmission/{self.submission.pk}/delete/', {'post': 'yes'}).status_code, 302)
        self.assertFalse(RecipeSubmission.objects.filter(pk=self.submission.pk).exists())

    def test_delete_favorite(self):
        self.login()
        self.assertEqual(self.client.post(f'/admin/favorites/favorite/{self.favorite.pk}/delete/', {'post': 'yes'}).status_code, 302)
        self.assertFalse(Favorite.objects.filter(pk=self.favorite.pk).exists())

    def test_delete_review(self):
        self.login()
        self.assertEqual(self.client.post(f'/admin/reviews/review/{self.review.pk}/delete/', {'post': 'yes'}).status_code, 302)
        self.assertFalse(Review.objects.filter(pk=self.review.pk).exists())

    def test_bulk_delete_recipe_confirmation_and_confirm(self):
        self.login()
        confirm = self.client.post('/admin/recipes/recipe/', {
            'action': 'delete_selected', '_selected_action': [str(self.recipe.pk)], 'index': '0',
        })
        self.assertEqual(confirm.status_code, 200)
        content = confirm.content.decode()
        self.assertIn('Sudanile Kitchen Admin', content)
        self.assertIn('Are you sure you want to delete the selected', content)
        self.assertIn("Yes, I'm sure", content)
        self.assertIn('No, take me back', content)
        done = self.client.post('/admin/recipes/recipe/', {
            'action': 'delete_selected', '_selected_action': [str(self.recipe.pk)],
            'index': '0', 'post': 'yes',
        })
        self.assertEqual(done.status_code, 302)
        self.assertFalse(Recipe.objects.filter(pk=self.recipe.pk).exists())

    def test_bulk_delete_category_confirmation_and_confirm(self):
        self.login()
        confirm = self.client.post('/admin/category/', {
            'action': 'delete_selected', '_selected_action': [str(self.category.pk)], 'index': '0',
        })
        self.assertEqual(confirm.status_code, 200)
        content = confirm.content.decode()
        self.assertIn('Sudanile Kitchen Admin', content)
        self.assertIn('Are you sure you want to delete the selected', content)
        self.assertIn("Yes, I'm sure", content)
        self.assertIn('No, take me back', content)
        done = self.client.post('/admin/category/', {
            'action': 'delete_selected', '_selected_action': [str(self.category.pk)],
            'index': '0', 'post': 'yes',
        })
        self.assertEqual(done.status_code, 302)
        self.assertFalse(Category.objects.filter(pk=self.category.pk).exists())