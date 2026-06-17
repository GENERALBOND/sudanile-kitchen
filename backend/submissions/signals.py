from django.db.models.signals import pre_save
from django.dispatch import receiver
from django.utils import timezone
from .models import RecipeSubmission
from recipes.models import Recipe, Category

@receiver(pre_save, sender=RecipeSubmission)
def create_recipe_on_approval(sender, instance, **kwargs):
    """
    Automatically create a Recipe when a submission is approved
    """
    # Check if this is an existing submission
    if instance.pk:
        try:
            old_instance = sender.objects.get(pk=instance.pk)
            # If status changed from pending to approved
            if old_instance.status == 'pending' and instance.status == 'approved':
                # Check if recipe already exists
                existing_recipe = Recipe.objects.filter(title=instance.title).first()
                if not existing_recipe:
                    # Get or create category
                    category, _ = Category.objects.get_or_create(name=instance.category_name)
                    
                    # Create the recipe
                    recipe = Recipe.objects.create(
                        title=instance.title,
                        description=instance.description,
                        ingredients=instance.ingredients,
                        instructions=instance.instructions,
                        cultural_info=instance.cultural_info or "",
                        prep_hours=instance.prep_hours,
                        prep_minutes=instance.prep_minutes,
                        prep_seconds=instance.prep_seconds,
                        cook_hours=instance.cook_hours,
                        cook_minutes=instance.cook_minutes,
                        cook_seconds=instance.cook_seconds,
                        servings=instance.servings,
                        difficulty=instance.difficulty,
                        image_url=instance.image_url,
                        video_url=instance.video_url,
                        category=category,
                        author=instance.user,
                        is_published=True
                    )
                    
                    # Set reviewed_at if not already set
                    if not instance.reviewed_at:
                        instance.reviewed_at = timezone.now()
                        
                    print(f"✅ Auto-created recipe from submission: {recipe.title} (ID: {recipe.id})")
        except sender.DoesNotExist:
            # New instance, nothing to check
            pass
