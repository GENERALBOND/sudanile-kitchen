from django.contrib import admin
from django import forms
from django.db.models import Count
from recipes.models import Recipe
from .models import Favorite


class FavoriteAdminForm(forms.ModelForm):
    class Meta:
        model = Favorite
        fields = ('user', 'recipe')

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields['user'].widget.attrs.update({'class': 'form-control', 'required': True})
        self.fields['recipe'].widget.attrs.update({'class': 'form-control', 'required': True})


@admin.register(Favorite)
class FavoriteAdmin(admin.ModelAdmin):
    form = FavoriteAdminForm
    add_form_template = "admin/favorites/favorite/add_form.html"
    change_form_template = "admin/favorites/favorite/add_form.html"
    change_list_template = 'admin/favorites/favorite/change_list.html'
    list_display = ('id', 'user', 'recipe', 'created_at')
    list_filter = ('created_at',)
    search_fields = ('user__email', 'recipe__title')

    def get_changeform_initial_data(self, request):
        return {'user': request.user}

    def save_model(self, request, obj, form, change):
        if not change and not obj.user_id:
            obj.user = request.user
        super().save_model(request, obj, form, change)

    def changelist_view(self, request, extra_context=None):
        extra_context = extra_context or {}
        top_saved = list(
            Favorite.objects.values('recipe')
            .annotate(save_count=Count('id'))
            .order_by('-save_count')[:4]
        )
        recipe_ids = [entry['recipe'] for entry in top_saved]
        recipes = {
            recipe.pk: recipe
            for recipe in Recipe.objects.filter(pk__in=recipe_ids)
        }
        top_saved_recipes = [
            {'recipe': recipes[entry['recipe']], 'save_count': entry['save_count']}
            for entry in top_saved
            if entry['recipe'] in recipes
        ]
        extra_context.update({
            'user_email': getattr(request.user, 'email', ''),
            'top_saved_recipes': top_saved_recipes,
        })
        return super().changelist_view(request, extra_context=extra_context)
