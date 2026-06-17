from django.contrib import admin
from .models import Category, Recipe

@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ('id', 'name', 'description')
    search_fields = ('name',)

@admin.register(Recipe)
class RecipeAdmin(admin.ModelAdmin):
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
