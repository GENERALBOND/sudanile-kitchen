from django.shortcuts import render
from django.contrib.admin.views.decorators import staff_member_required
from django.contrib.auth.decorators import login_required

@login_required
@staff_member_required
def dashboard(request):
    from recipes.models import Recipe
    from users.models import User
    from submissions.models import RecipeSubmission
    from reviews.models import Review
    from favorites.models import Favorite
    
    context = {
        'total_recipes': Recipe.objects.count(),
        'total_users': User.objects.count(),
        'pending_submissions': RecipeSubmission.objects.filter(status='pending').count(),
        'total_reviews': Review.objects.count(),
        'total_favorites': Favorite.objects.count(),
        'user_email': request.user.email,
        'pending_submissions_list': RecipeSubmission.objects.filter(status='pending').order_by('-submitted_at')[:5],
        'recent_actions': [],
    }
    return render(request, 'admin/dashboard.html', context)


@login_required
@staff_member_required
def auth_index(request):
    from django.contrib.auth.models import Group
    from users.models import User

    context = {
        'user_email': request.user.email,
        'total_users': User.objects.count(),
        'total_groups': Group.objects.count(),
        'active_sessions': 0,
        'pending_password_resets': 0,
        'groups': Group.objects.all().order_by('name'),
    }
    return render(request, 'admin/authentication/index.html', context)
