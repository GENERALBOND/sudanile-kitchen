import logging

from django.conf import settings
from django.core.mail import send_mail
from django.db.models.signals import pre_save, post_save
from django.dispatch import receiver
from django.utils import timezone
from config.renumber import lowest_free_id, sync_sequence
from .models import RecipeSubmission
from recipes.models import Recipe, Category
from recipes.duplicate_check import find_duplicates

logger = logging.getLogger(__name__)


def send_submission_review_email(submission):
    """Notifies the submitting user whether their recipe was accepted/rejected."""
    if submission.status not in ('approved', 'rejected'):
        return

    user = submission.user
    if not user.email:
        return

    if submission.status == 'approved':
        subject = 'Your recipe was approved - Sudanile Kitchen'
        message = (
            f"Hi {user.username},\n\n"
            f"Good news! Your recipe \"{submission.title}\" has been approved "
            f"and is now part of the Sudanile Kitchen collection. Thank you "
            f"for sharing your culinary heritage with the community.\n\n"
            f"Sudanile Kitchen"
        )
    else:
        subject = 'Your recipe submission was not approved - Sudanile Kitchen'
        message = (
            f"Hi {user.username},\n\n"
            f"Unfortunately, your recipe submission \"{submission.title}\" was "
            f"not approved."
        )
        if submission.admin_notes:
            message += f"\n\nReason: {submission.admin_notes}"
        message += (
            f"\n\nYou're welcome to review the feedback and submit the recipe "
            f"again at any time.\n\n"
            f"Sudanile Kitchen"
        )

    try:
        send_mail(
            subject=subject,
            message=message,
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[user.email],
            fail_silently=False,
        )
        logger.info(
            f"Sent {submission.status} notification to {user.email} "
            f"for \"{submission.title}\""
        )
    except Exception as e:
        logger.error(
            f"Failed to send submission notification to {user.email}: {e}"
        )


@receiver(pre_save, sender=RecipeSubmission)
def notify_submission_review(sender, instance, **kwargs):
    if not instance.pk:
        return
    try:
        old_instance = sender.objects.get(pk=instance.pk)
    except sender.DoesNotExist:
        return
    if (
        old_instance.status != instance.status
        and instance.status in ('approved', 'rejected')
    ):
        send_submission_review_email(instance)


@receiver(pre_save, sender=RecipeSubmission)
def use_next_available_id(sender, instance, **kwargs):
    if instance.pk is None:
        instance.pk = lowest_free_id(sender)


@receiver(post_save, sender=RecipeSubmission)
def keep_sequence_in_sync(sender, instance, **kwargs):
    sync_sequence(sender)


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
