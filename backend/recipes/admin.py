import re

from django.contrib import admin
from django import forms
from django.db import models
from .models import Category, Recipe


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

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
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
                  'servings', 'difficulty', 'image_url', 'video_url')

    def clean_ingredients(self):
        data = self.cleaned_data['ingredients']
        return [line.strip() for line in data.split('\n') if line.strip()]

    def clean_instructions(self):
        data = self.cleaned_data['instructions']
        return [line.strip() for line in data.split('\n') if line.strip()]

    def save(self, commit=True):
        instance = super().save(commit=False)
        instance.ingredients = self.cleaned_data['ingredients']
        instance.instructions = self.cleaned_data['instructions']

        prep = self._parse_time(self.cleaned_data.get('prep_time', ''))
        instance.prep_hours, instance.prep_minutes, instance.prep_seconds = prep

        cook = self._parse_time(self.cleaned_data.get('cook_time', ''))
        instance.cook_hours, instance.cook_minutes, instance.cook_seconds = cook

        status = self.cleaned_data.get('status', 'published')
        instance.is_published = (status == 'published')

        if commit:
            instance.save()
            self.save_m2m()
        return instance

    @staticmethod
    def _parse_time(value):
        hours = minutes = seconds = 0
        if value:
            h = re.search(r'(\d+)\s*(?:hour|hr|h)(?![a-z])', value, re.IGNORECASE)
            m = re.search(r'(\d+)\s*(?:min|minute)(?![a-z])', value, re.IGNORECASE)
            s = re.search(r'(\d+)\s*(?:sec|second)(?![a-z])', value, re.IGNORECASE)
            if h:
                hours = int(h.group(1))
            if m:
                minutes = int(m.group(1))
            if s:
                seconds = int(s.group(1))
        return hours, minutes, seconds


class CategoryAdminForm(forms.ModelForm):
    icon = forms.CharField(
        required=False,
        widget=forms.TextInput(attrs={'class': 'form-control', 'placeholder': 'e.g., ti-tag'}),
    )

    class Meta:
        model = Category
        fields = '__all__'


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

    def get_changeform_initial_data(self, request):
        return {'author': request.user}

    def save_model(self, request, obj, form, change):
        if not change and not obj.author_id:
            obj.author = request.user
        super().save_model(request, obj, form, change)

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
