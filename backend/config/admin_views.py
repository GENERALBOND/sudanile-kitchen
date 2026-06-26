from django.shortcuts import render, redirect
from django.contrib.admin.views.decorators import staff_member_required
from django.contrib.auth.decorators import login_required
from django.urls import reverse
from django.http import HttpResponseRedirect

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
