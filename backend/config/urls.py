from django.contrib import admin
from django.contrib.auth import authenticate, login
from django.shortcuts import redirect, render
from django.urls import path, include
from django.views.generic import RedirectView
from .admin_views import dashboard
from recipes.admin import CategoryAdmin
from recipes.models import Category
from users.models import User

# Use the project's custom dashboard as the Django admin index
admin.site.index_template = 'admin/dashboard.html'
admin.site.site_header = 'Sudanile Kitchen Admin'
admin.site.site_title = 'Sudanile Admin'

category_admin = CategoryAdmin(Category, admin.site)

def home(request):
    if request.method == 'POST':
        identifier = request.POST.get('email', '').strip()
        password = request.POST.get('password', '')

        if not identifier or not password:
            return render(request, 'landing.html', {'error': 'Please enter both email/username and password.'})

        user = None
        if '@' in identifier:
            user = authenticate(request, email=identifier, password=password)
        else:
            user = authenticate(request, username=identifier, password=password)

        if user is not None and user.is_staff:
            login(request, user)
            return redirect('admin:index')

        return render(request, 'landing.html', {'error': 'Invalid admin credentials.', 'email': identifier})

    return render(request, 'landing.html')

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
