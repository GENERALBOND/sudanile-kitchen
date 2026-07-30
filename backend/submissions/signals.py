from django.db.models.signals import pre_save
from django.dispatch import receiver
from django.utils import timezone
from .models import RecipeSubmission
from recipes.models import Recipe, Category
from recipes.duplicate_check import find_duplicates


@receiver(pre_save, sender=RecipeSubmission)
def create_recipe_on_approval(sender, instance, **kwargs):
    if instance.pk:
        try:
            old_instance = sender.objects.get(pk=instance.pk)
            if old_instance.status == 'pending' and instance.status == 'approved':
                existing_recipe = Recipe.objects.filter(title=instance.title).first()
                if not existing_recipe:
                    category, _ = Category.objects.get_or_create(name=instance.category_name)

                    duplicates = find_duplicates(
                        instance.title,
                        ingredients=instance.ingredients,
                        category=category,
                    )

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
                        is_published=not bool(duplicates),
                        is_flagged=bool(duplicates),
                        flagged_reason=duplicates[0]['reason'] if duplicates else None,
                    )

                    if not instance.reviewed_at:
                        instance.reviewed_at = timezone.now()

                    if duplicates:
                        print(f"FLAGGED as duplicate: {recipe.title} (ID: {recipe.id}) - {duplicates[0]['reason']}")
                    else:
                        print(f"Auto-created recipe from submission: {recipe.title} (ID: {recipe.id})")
        except sender.DoesNotExist:
            pass
