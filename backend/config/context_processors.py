from recipes.models import Recipe
from users.models import User
from submissions.models import RecipeSubmission
from reviews.models import Review
from favorites.models import Favorite
from django.utils import timezone

def admin_stats(request):
    if request.path.startswith('/admin/'):
        return {
            'total_recipes': Recipe.objects.count(),
            'total_users': User.objects.count(),
            'pending_submissions': RecipeSubmission.objects.filter(status='pending').count(),
            'total_reviews': Review.objects.count(),
            'total_favorites': Favorite.objects.count(),
            'user_email': request.user.email if request.user.is_authenticated else 'Guest',
            'pending_submissions_list': RecipeSubmission.objects.filter(status='pending').order_by('-submitted_at')[:5],
            'recent_actions': [],  # You can add custom logic here
        }
    return {}
