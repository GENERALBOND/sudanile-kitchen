from django.contrib import admin
from django.db import models
from .models import Category, Recipe

@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    change_list_template = "admin/recipes/category/change_list.html"
    list_display = ('id', 'name', 'description')
    search_fields = ('name',)

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        return qs.annotate(recipe_count=models.Count('recipes'))

    def changelist_view(self, request, extra_context=None):
        extra_context = extra_context or {}
        qs = self.get_queryset(request)
        duplicate_example = None
        duplicate_names = (
            super().get_queryset(request)
                .values('name')
                .annotate(name_count=models.Count('id'))
                .filter(name_count__gt=1)
                .order_by('name')
        )
        if duplicate_names:
            duplicate_example = super().get_queryset(request).filter(name=duplicate_names[0]['name']).first()

        total_categories = qs.count()
        missing_desc_count = qs.filter(description__exact='').count()
        extra_context.update({
            'user_email': getattr(request.user, 'email', ''),
            'total_categories': total_categories,
            'duplicate_count': duplicate_names.count(),
            'duplicate_example': duplicate_example,
            'missing_description_count': missing_desc_count,
        })
        return super().changelist_view(request, extra_context=extra_context)

@admin.register(Recipe)
class RecipeAdmin(admin.ModelAdmin):
    change_list_template = "admin/recipes/recipe/change_list.html"
    list_display = ('id', 'title', 'author', 'category', 'average_rating', 'is_published', 'created_at')
    list_filter = ('category', 'difficulty', 'is_published')
    search_fields = ('title', 'description', 'cultural_info')
    readonly_fields = ('average_rating', 'total_reviews', 'view_count', 'created_at', 'updated_at')
    fieldsets = (
        ('Basic Information', {
            'fields': ('title', 'description', 'cultural_info', 'author', 'category')
        }),
        ('Preparation Time', {
            'fields': (('prep_hours', 'prep_minutes', 'prep_seconds'),),
            'description': 'Enter preparation time in hours, minutes, and seconds'
        }),
        ('Cooking Time', {
            'fields': (('cook_hours', 'cook_minutes', 'cook_seconds'),),
            'description': 'Enter cooking time in hours, minutes, and seconds'
        }),
        ('Recipe Content', {
            'fields': ('ingredients', 'instructions')
        }),
        ('Media & Additional', {
            'fields': ('servings', 'difficulty', 'image_url', 'video_url', 'is_published')
        }),
    )

    def changelist_view(self, request, extra_context=None):
        """Inject a few counts and the current user's email into the changelist template."""
        extra_context = extra_context or {}
        qs = self.get_queryset(request)
        extra_context.update({
            'user_email': getattr(request.user, 'email', ''),
            'total_recipes': qs.count(),
            'flagged_count': qs.filter(is_flagged=True).count() if hasattr(qs.model, 'is_flagged') else 0,
            'published_count': qs.filter(is_published=True).count() if hasattr(qs.model, 'is_published') else qs.count(),
            'unpublished_count': qs.filter(is_published=False).count() if hasattr(qs.model, 'is_published') else 0,
        })
        return super().changelist_view(request, extra_context=extra_context)
