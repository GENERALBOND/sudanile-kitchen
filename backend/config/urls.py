from django.contrib import admin
from django.urls import path, include
from django.http import JsonResponse
from .admin_views import dashboard

def home(request):
    return JsonResponse({
        'message': 'Welcome to Sudanile Kitchen API',
        'version': '1.0.0',
        'documentation': '/admin/',
        'endpoints': {
            'users': '/api/users/',
            'recipes': '/api/recipes/',
            'categories': '/api/recipes/categories/',
            'favorites': '/api/favorites/',
            'reviews': '/api/reviews/',
            'submissions': '/api/submissions/',
            'admin': '/admin/',
        }
    })

urlpatterns = [
    path('', home, name='home'),
    path('admin/', dashboard, name='admin_dashboard'),  # Custom dashboard
    path('admin/django/', admin.site.urls),  # Django admin - use different path
    path('api/users/', include('users.urls')),
    path('api/recipes/', include('recipes.urls')),
    path('api/reviews/', include('reviews.urls')),
    path('api/favorites/', include('favorites.urls')),
    path('api/submissions/', include('submissions.urls')),
]
