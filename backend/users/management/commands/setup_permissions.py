from django.core.management.base import BaseCommand
from django.contrib.auth.models import Group, Permission
from django.contrib.contenttypes.models import ContentType
from users.models import User
from recipes.models import Recipe, Category
from reviews.models import Review
from favorites.models import Favorite
from submissions.models import RecipeSubmission

class Command(BaseCommand):
    help = 'Setup default permissions for regular users'

    def handle(self, *args, **options):
        # Create Regular User Group
        regular_group, created = Group.objects.get_or_create(name='Regular User')
        
        if created:
            self.stdout.write(self.style.SUCCESS('Created Regular User group'))
        else:
            self.stdout.write(self.style.WARNING('Regular User group already exists'))
        
        # Get all permissions for regular users
        permissions = []
        
        # Recipe permissions (view only for regular users)
        recipe_ct = ContentType.objects.get_for_model(Recipe)
        permissions.extend([
            Permission.objects.get(codename='view_recipe', content_type=recipe_ct),
        ])
        
        # Category permissions (view only)
        category_ct = ContentType.objects.get_for_model(Category)
        permissions.extend([
            Permission.objects.get(codename='view_category', content_type=category_ct),
        ])
        
        # Review permissions (add, change, delete own reviews)
        review_ct = ContentType.objects.get_for_model(Review)
        permissions.extend([
            Permission.objects.get(codename='add_review', content_type=review_ct),
            Permission.objects.get(codename='change_review', content_type=review_ct),
            Permission.objects.get(codename='delete_review', content_type=review_ct),
            Permission.objects.get(codename='view_review', content_type=review_ct),
        ])
        
        # Favorite permissions (add, delete own favorites)
        favorite_ct = ContentType.objects.get_for_model(Favorite)
        permissions.extend([
            Permission.objects.get(codename='add_favorite', content_type=favorite_ct),
            Permission.objects.get(codename='delete_favorite', content_type=favorite_ct),
            Permission.objects.get(codename='view_favorite', content_type=favorite_ct),
        ])
        
        # Recipe Submission permissions (add, view own submissions)
        submission_ct = ContentType.objects.get_for_model(RecipeSubmission)
        permissions.extend([
            Permission.objects.get(codename='add_recipesubmission', content_type=submission_ct),
            Permission.objects.get(codename='view_recipesubmission', content_type=submission_ct),
            Permission.objects.get(codename='change_recipesubmission', content_type=submission_ct),
            Permission.objects.get(codename='delete_recipesubmission', content_type=submission_ct),
        ])
        
        # Assign permissions to group
        regular_group.permissions.set(permissions)
        
        self.stdout.write(self.style.SUCCESS(f'Assigned {len(permissions)} permissions to Regular User group'))
        
        # List all permissions
        self.stdout.write(self.style.SUCCESS('\nPermissions assigned:'))
        for perm in regular_group.permissions.all():
            self.stdout.write(f'  - {perm.content_type.app_label}.{perm.codename}')
        
        # Update all existing regular users to be in this group
        regular_users = User.objects.filter(role='user')
        for user in regular_users:
            user.groups.add(regular_group)
            user.is_staff = False
            user.is_superuser = False
            user.save()
        
        self.stdout.write(self.style.SUCCESS(f'\nUpdated {regular_users.count()} existing regular users'))
