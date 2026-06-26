from django.contrib import admin
from recipes.models import Recipe, Category
from users.models import User
from submissions.models import RecipeSubmission
from reviews.models import Review
from favorites.models import Favorite
from config.urls import admin_site

# Register models with custom admin site
admin_site.register(Recipe)
admin_site.register(Category)
admin_site.register(User)
admin_site.register(RecipeSubmission)
admin_site.register(Review)
admin_site.register(Favorite)
