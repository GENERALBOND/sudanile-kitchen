from django.contrib import admin
from .models import Favorite

@admin.register(Favorite)
class FavoriteAdmin(admin.ModelAdmin):
    change_list_template = 'admin/favorites/favorite/change_list.html'
    list_display = ('id', 'user', 'recipe', 'created_at')
    list_filter = ('created_at',)
    search_fields = ('user__email', 'recipe__title')
