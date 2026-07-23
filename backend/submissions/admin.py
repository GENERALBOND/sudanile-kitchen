from django.contrib import admin
from django.contrib import messages
from django import forms
from django.utils import timezone
from .models import RecipeSubmission
from recipes.models import Recipe, Category


class SubmissionAdminForm(forms.ModelForm):
    ingredients = forms.CharField(
        widget=forms.Textarea(attrs={'rows': 6, 'class': 'form-control'}),
        required=True,
    )
    instructions = forms.CharField(
        widget=forms.Textarea(attrs={'rows': 8, 'class': 'form-control'}),
        required=True,
    )
    category_name = forms.ChoiceField(
        required=True,
        widget=forms.Select(attrs={'class': 'form-control'}),
    )

    class Meta:
        model = RecipeSubmission
        fields = '__all__'

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        cats = list(Category.objects.values_list('name', flat=True).order_by('name'))
        self.fields['category_name'].choices = [(c, c) for c in cats]
        if self.instance.pk and self.instance.category_name:
            current = self.instance.category_name
            if current not in cats:
                self.fields['category_name'].choices.append((current, current))
        if self.instance.pk:
            if self.instance.ingredients:
                self.initial['ingredients'] = '\n'.join(
                    str(i) for i in self.instance.ingredients
                )
            if self.instance.instructions:
                self.initial['instructions'] = '\n'.join(
                    str(i) for i in self.instance.instructions
                )

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
        if commit:
            instance.save()
            self.save_m2m()
        return instance


@admin.register(RecipeSubmission)
class RecipeSubmissionAdmin(admin.ModelAdmin):
    form = SubmissionAdminForm
    change_form_template = "admin/submissions/recipesubmission/change_form.html"
    change_list_template = "admin/submissions/recipesubmission/change_list.html"
    list_display = ('id', 'title', 'user', 'status', 'submitted_at')
    list_filter = ('status', 'submitted_at')
    search_fields = ('title', 'user__email', 'category_name')
    readonly_fields = ('submitted_at', 'reviewed_at')
    
    actions = ['approve_submissions', 'reject_submissions']

    def get_changeform_initial_data(self, request):
        return {'user': request.user}
    
    def changelist_view(self, request, extra_context=None):
        extra_context = extra_context or {}
        qs = self.get_queryset(request)
        extra_context.update({
            'user_email': getattr(request.user, 'email', ''),
            'total_submissions': qs.count(),
            'pending_count': qs.filter(status='pending').count(),
            'approved_count': qs.filter(status='approved').count(),
            'rejected_count': qs.filter(status='rejected').count(),
        })
        return super().changelist_view(request, extra_context=extra_context)

    def approve_submissions(self, request, queryset):
        approved_count = 0
        error_count = 0
        
        for submission in queryset.filter(status='pending'):
            try:
                # Get or create category
                category, _ = Category.objects.get_or_create(name=submission.category_name)
                
                # Check if recipe already exists (to avoid duplicates)
                existing_recipe = Recipe.objects.filter(title=submission.title).first()
                if existing_recipe:
                    self.message_user(
                        request, 
                        f'⚠️ Recipe "{submission.title}" already exists!', 
                        messages.WARNING
                    )
                    submission.status = 'approved'
                    submission.reviewed_at = timezone.now()
                    submission.save()
                    continue
                
                # Create recipe from submission
                recipe = Recipe.objects.create(
                    title=submission.title,
                    description=submission.description,
                    ingredients=submission.ingredients,
                    instructions=submission.instructions,
                    cultural_info=submission.cultural_info or "",
                    prep_hours=submission.prep_hours,
                    prep_minutes=submission.prep_minutes,
                    prep_seconds=submission.prep_seconds,
                    cook_hours=submission.cook_hours,
                    cook_minutes=submission.cook_minutes,
                    cook_seconds=submission.cook_seconds,
                    servings=submission.servings,
                    difficulty=submission.difficulty,
                    image_url=submission.image_url,
                    video_url=submission.video_url,
                    category=category,
                    author=submission.user,
                    is_published=True
                )
                
                # Update submission status
                submission.status = 'approved'
                submission.reviewed_at = timezone.now()
                submission.save()
                
                approved_count += 1
                self.message_user(
                    request, 
                    f'✅ Approved "{submission.title}" - Recipe ID: {recipe.id}', 
                    messages.SUCCESS
                )
                
            except Exception as e:
                error_count += 1
                self.message_user(
                    request, 
                    f'❌ Error approving "{submission.title}": {str(e)}', 
                    messages.ERROR
                )
        
        if approved_count > 0:
            self.message_user(
                request, 
                f'Successfully approved {approved_count} submission(s)', 
                messages.SUCCESS
            )
    
    approve_submissions.short_description = "Approve selected submissions"
    
    def reject_submissions(self, request, queryset):
        count = queryset.filter(status='pending').update(
            status='rejected',
            reviewed_at=timezone.now()
        )
        self.message_user(request, f'Rejected {count} submission(s)', messages.WARNING)
    
    reject_submissions.short_description = "Reject selected submissions"
    
    fieldsets = (
        ('Recipe Information', {
            'fields': ('title', 'description', 'category_name', 'user')
        }),
        ('Preparation Time', {
            'fields': (('prep_hours', 'prep_minutes', 'prep_seconds'),)
        }),
        ('Cooking Time', {
            'fields': (('cook_hours', 'cook_minutes', 'cook_seconds'),)
        }),
        ('Content', {
            'fields': ('ingredients', 'instructions', 'cultural_info')
        }),
        ('Media', {
            'fields': ('image_url', 'video_url')
        }),
        ('Status', {
            'fields': ('status', 'admin_notes', 'submitted_at', 'reviewed_at')
        }),
    )
