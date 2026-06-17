from django.contrib import admin
from django.contrib import messages
from django.utils import timezone
from .models import RecipeSubmission
from recipes.models import Recipe, Category

@admin.register(RecipeSubmission)
class RecipeSubmissionAdmin(admin.ModelAdmin):
    list_display = ('id', 'title', 'user', 'status', 'submitted_at')
    list_filter = ('status', 'submitted_at')
    search_fields = ('title', 'user__email', 'category_name')
    readonly_fields = ('submitted_at',)
    
    actions = ['approve_submissions', 'reject_submissions']
    
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
