from django.contrib import admin
from django.urls import path, include
from django.http import JsonResponse
from .admin_views import dashboard

# Use the project's custom dashboard as the Django admin index
admin.site.index_template = 'admin/dashboard.html'
admin.site.site_header = 'Sudanile Kitchen Admin'
admin.site.site_title = 'Sudanile Admin'

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
    # Mount the Django admin at /admin/ and render the custom dashboard template
    path('admin/', admin.site.urls),
    # Keep the dashboard view available at a dedicated path if needed
    path('admin/dashboard/', dashboard, name='admin_dashboard'),
    path('api/users/', include('users.urls')),
    path('api/recipes/', include('recipes.urls')),
    path('api/reviews/', include('reviews.urls')),
    path('api/favorites/', include('favorites.urls')),
    path('api/submissions/', include('submissions.urls')),
]
