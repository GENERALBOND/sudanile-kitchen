from django.contrib import admin
from django.urls import path, include
from django.http import JsonResponse
from django.views.generic import RedirectView
from .admin_views import dashboard
from recipes.admin import CategoryAdmin
from recipes.models import Category

# Use the project's custom dashboard as the Django admin index
admin.site.index_template = 'admin/dashboard.html'
admin.site.site_header = 'Sudanile Kitchen Admin'
admin.site.site_title = 'Sudanile Admin'

category_admin = CategoryAdmin(Category, admin.site)

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
    # Direct category admin URL path
    path('admin/category/', category_admin.changelist_view, name='admin_category_changelist'),
    path('admin/category/add/', category_admin.add_view, name='admin_category_add'),
    path('admin/category/<int:object_id>/change/', category_admin.change_view, name='admin_category_change'),
    path('admin/category/<int:object_id>/delete/', category_admin.delete_view, name='admin_category_delete'),
    path('admin/category/<int:object_id>/history/', category_admin.history_view, name='admin_category_history'),
    # Direct submissions admin alias path
    path('admin/submissions/', RedirectView.as_view(pattern_name='admin:submissions_recipesubmission_changelist', query_string=True, permanent=False)),
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
