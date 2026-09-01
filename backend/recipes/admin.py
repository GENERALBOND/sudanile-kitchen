import re

from django.contrib import admin, messages
from django import forms
from django.db import models
from django.shortcuts import redirect, get_object_or_404
from django.urls import path
from .models import Category, Recipe
from .duplicate_check import find_duplicates
from config.meal_types import MEAL_TYPES, clean_meal_types


class RecipeAdminForm(forms.ModelForm):
    ingredients = forms.CharField(
        widget=forms.Textarea(attrs={'rows': 6, 'class': 'form-control'}),
        required=True,
        help_text="Enter each ingredient on a new line"
    )
    instructions = forms.CharField(
        widget=forms.Textarea(attrs={'rows': 8, 'class': 'form-control'}),
        required=True,
        help_text="Enter each instruction step on a new line"
    )
    prep_time = forms.CharField(
        widget=forms.TextInput(attrs={'class': 'form-control', 'placeholder': 'e.g., 30 mins'}),
        required=False,
    )
    cook_time = forms.CharField(
        widget=forms.TextInput(attrs={'class': 'form-control', 'placeholder': 'e.g., 45 mins'}),
        required=False,
    )
    status = forms.ChoiceField(
        choices=[('draft', 'Draft'), ('published', 'Published'), ('archived', 'Archived')],
        required=False,
        initial='published',
    )
    meal_types = forms.MultipleChoiceField(
        choices=MEAL_TYPES,
        widget=forms.CheckboxSelectMultiple,
        required=False,
        help_text='When is this recipe normally eaten? Select all that apply, or none for any time.',
    )

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        for field_name in ('prep_hours', 'prep_minutes', 'prep_seconds',
                           'cook_hours', 'cook_minutes', 'cook_seconds'):
            if field_name in self.fields:
                self.fields[field_name].required = False
        if self.instance.pk:
            if self.instance.ingredients:
                self.initial['ingredients'] = '\n'.join(
                    str(i) for i in self.instance.ingredients
                )
            if self.instance.instructions:
                self.initial['instructions'] = '\n'.join(
                    str(i) for i in self.instance.instructions
                )
            prep = []
            if self.instance.prep_hours:
                prep.append(f"{self.instance.prep_hours} hr{'s' if self.instance.prep_hours > 1 else ''}")
            if self.instance.prep_minutes:
                prep.append(f"{self.instance.prep_minutes} min{'s' if self.instance.prep_minutes > 1 else ''}")
            if self.instance.prep_seconds:
                prep.append(f"{self.instance.prep_seconds} sec{'s' if self.instance.prep_seconds > 1 else ''}")
            if prep:
                self.initial['prep_time'] = ' '.join(prep)
            cook = []
            if self.instance.cook_hours:
                cook.append(f"{self.instance.cook_hours} hr{'s' if self.instance.cook_hours > 1 else ''}")
            if self.instance.cook_minutes:
                cook.append(f"{self.instance.cook_minutes} min{'s' if self.instance.cook_minutes > 1 else ''}")
            if self.instance.cook_seconds:
                cook.append(f"{self.instance.cook_seconds} sec{'s' if self.instance.cook_seconds > 1 else ''}")
            if cook:
                self.initial['cook_time'] = ' '.join(cook)
            self.initial['status'] = 'published' if self.instance.is_published else 'draft'

    class Meta:
        model = Recipe
        fields = ('title', 'description', 'cultural_info', 'author', 'category',
                  'servings', 'difficulty', 'image_url',
                  'meal_types')

    def clean_ingredients(self):
        data = self.cleaned_data['ingredients']
        return [line.strip() for line in data.split('\n') if line.strip()]

    def clean_instructions(self):
        data = self.cleaned_data['instructions']
        return [line.strip() for line in data.split('\n') if line.strip()]

    def clean_meal_types(self):
        return clean_meal_types(self.cleaned_data.get('meal_types'))

    def save(self, commit=True):
        instance = super().save(commit=False)
        instance.ingredients = self.cleaned_data['ingredients']
        instance.instructions = self.cleaned_data['instructions']

        prep = self._parse_time(self.cleaned_data.get('prep_time', ''))
        instance.prep_hours, instance.prep_minutes, instance.prep_seconds = prep

        cook = self._parse_time(self.cleaned_data.get('cook_time', ''))
        instance.cook_hours, instance.cook_minutes, instance.cook_seconds = cook

        status = self.cleaned_data.get('status', 'published')
        wants_published = (status == 'published')

        if wants_published:
            duplicates = find_duplicates(
                instance.title,
                ingredients=instance.ingredients,
                category=instance.category,
                exclude_id=instance.pk,
            )
            if duplicates:
                instance.is_flagged = True
                instance.flagged_reason = duplicates[0]['reason']
                instance.is_published = False
            else:
                instance.is_flagged = False
                instance.flagged_reason = None
                instance.is_published = True
        else:
            instance.is_published = False

        if commit:
            instance.save()
            self.save_m2m()
        return instance

    @staticmethod
    def _parse_time(value):
        hours = minutes = seconds = 0
        if value:
            h = re.search(r'(\d+)\s*(?:hours?|hrs?|h)\b', value, re.IGNORECASE)
            m = re.search(r'(\d+)\s*(?:minutes?|mins?|min)\b', value, re.IGNORECASE)
            s = re.search(r'(\d+)\s*(?:seconds?|secs?|sec)\b', value, re.IGNORECASE)
            if h:
                hours = int(h.group(1))
            if m:
                minutes = int(m.group(1))
            if s:
                seconds = int(s.group(1))
        return hours, minutes, seconds


CATEGORY_ICON_CHOICES = [
    ('', 'No icon (auto)'),
    ('restaurant', 'Restaurant'),
    ('restaurant_menu', 'Restaurant menu'),
    ('lunch_dining', 'Main dish / lunch'),
    ('dinner_dining', 'Dinner'),
    ('bakery_dining', 'Bakery / bread'),
    ('breakfast_dining', 'Breakfast'),
    ('brunch_dining', 'Brunch'),
    ('ramen_dining', 'Ramen / noodles'),
    ('rice_bowl', 'Rice'),
    ('soup_kitchen', 'Stew / soup'),
    ('set_meal', 'Set meal'),
    ('tapas', 'Tapas'),
    ('flatware', 'Flatware'),
    ('local_pizza', 'Pizza'),
    ('kebab_dining', 'Kebab / grilled skewers'),
    ('icecream', 'Ice cream'),
    ('cake', 'Cake / dessert'),
    ('cookie', 'Cookie'),
    ('fastfood', 'Fast food / snack'),
    ('egg', 'Egg'),
    ('emoji_food_beverage', 'Hot drink'),
    ('local_cafe', 'Coffee / cafe'),
    ('coffee_maker', 'Kettle / coffee maker'),
    ('local_bar', 'Drinks / bar'),
    ('water_drop', 'Water'),
    ('eco', 'Fresh / green'),
    ('kitchen', 'Kitchen'),
    ('microwave', 'Microwave'),
    ('countertops', 'Countertop'),
    ('outdoor_grill', 'Outdoor grill'),
]


class CategoryAdminForm(forms.ModelForm):
    icon = forms.ChoiceField(
        required=False,
        choices=CATEGORY_ICON_CHOICES,
        widget=forms.Select(attrs={'class': 'form-control'}),
        help_text='Pick the Material icon shown for this category in the mobile app',
    )

    class Meta:
        model = Category
        fields = '__all__'

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Preserve legacy icon values (e.g. Tabler class names) so existing
        # categories can still be edited without a validation error.
        if self.instance and self.instance.pk and self.instance.icon:
            values = [value for value, _ in self.fields['icon'].choices]
            if self.instance.icon not in values:
                self.fields['icon'].choices = list(self.fields['icon'].choices) + [
                    (self.instance.icon, self.instance.icon)
                ]


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    form = CategoryAdminForm
    add_form_template = "admin/recipes/category/add_form.html"
    change_form_template = "admin/recipes/category/add_form.html"
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
    form = RecipeAdminForm
    add_form_template = "admin/recipes/recipe/add_form.html"
    change_form_template = "admin/recipes/recipe/add_form.html"
    change_list_template = "admin/recipes/recipe/change_list.html"
    list_display = ('id', 'title', 'author', 'category', 'average_rating', 'is_published', 'is_flagged', 'created_at')
    list_filter = ('category', 'difficulty', 'is_published', 'is_flagged')
    search_fields = ('title', 'description', 'cultural_info')
    readonly_fields = ('average_rating', 'total_reviews', 'view_count', 'created_at', 'updated_at', 'is_flagged', 'flagged_reason')
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
            'fields': ('servings', 'difficulty', 'image_url', 'is_published', 'meal_types')
        }),
    )

    actions = ['approve_flag', 'clear_flagged_flag']

    def get_changeform_initial_data(self, request):
        return {'author': request.user}

    def get_urls(self):
        urls = super().get_urls()
        custom_urls = [
            path('<path:object_id>/toggle-publish/',
                self.admin_site.admin_view(self.toggle_publish_view),
                name='recipes_recipe_toggle_publish'),
        ]
        return custom_urls + urls

    def toggle_publish_view(self, request, object_id):
        recipe = get_object_or_404(Recipe, pk=object_id)
        if not recipe.is_published and recipe.is_flagged:
            self.message_user(request, f'Cannot publish "{recipe.title}" - it is flagged.', messages.ERROR)
        else:
            recipe.is_published = not recipe.is_published
            recipe.save(update_fields=['is_published'])
            self.message_user(request, f'"{recipe.title}" is now {"published" if recipe.is_published else "unpublished"}.', messages.SUCCESS if recipe.is_published else messages.WARNING)
        return redirect(request.META.get('HTTP_REFERER', 'admin:recipes_recipe_changelist'))

    def save_model(self, request, obj, form, change):
        if not change and not obj.author_id:
            obj.author = request.user
        if obj.is_flagged and obj.is_published:
            obj.is_published = False
        super().save_model(request, obj, form, change)

    def approve_flag(self, request, queryset):
        updated = queryset.filter(is_flagged=True).update(
            is_flagged=False, flagged_reason=None, is_published=True
        )
        self.message_user(request, f'{updated} recipe(s) approved and published.', messages.SUCCESS)
    approve_flag.short_description = 'Approve flagged recipes (mark as not duplicate)'

    def clear_flagged_flag(self, request, queryset):
        updated = queryset.filter(is_flagged=True).update(
            is_flagged=False, flagged_reason=None
        )
        self.message_user(request, f'Cleared flag on {updated} recipe(s).', messages.WARNING)
    clear_flagged_flag.short_description = 'Clear flag (keep current publish state)'

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
