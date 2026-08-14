"""Signal handlers that dispatch push notifications via FCM.

Kept in the `notifications` app so all push delivery lives in one place; they
listen on Recipe / RecipeSubmission lifecycle events:

  * a recipe is (newly) published   -> "new_recipes"  subscribers
  * a submission is approved        -> the submitting user's devices,
                                       tagged "recipe_approval"
"""

import logging

from django.db.models.signals import post_save, pre_save
from django.dispatch import receiver

from recipes.models import Recipe
from submissions.models import RecipeSubmission
from . import push

logger = logging.getLogger(__name__)


@receiver(pre_save, sender=Recipe)
def _cache_previous_publication_state(sender, instance, **kwargs):
    """Snapshot is_published before the row changes, for the post_save diff."""
    if instance.pk:
        try:
            previous = sender.objects.get(pk=instance.pk).is_published
        except sender.DoesNotExist:
            previous = None
        instance._previous_is_published = previous
    else:
        instance._previous_is_published = None


@receiver(post_save, sender=Recipe)
def notify_new_recipe(sender, instance, **kwargs):
    """Push an alert when a recipe newly becomes published."""
    if not getattr(instance, 'is_published', False):
        return
    if getattr(instance, '_previous_is_published', None):
        # Already published before this save — don't spam on every edit.
        return

    try:
        push.notify_tag(
            'new_recipes',
            'New recipe on Sudanile Kitchen',
            f'{instance.title} is now live — check it out!',
            data={'type': 'new_recipe', 'recipe_id': instance.id},
            url=f'/recipes/{instance.id}',
        )
    except Exception as exc:
        logger.error('Failed to push new-recipe update: %s', exc)


@receiver(pre_save, sender=RecipeSubmission)
def notify_submission_review_push(sender, instance, **kwargs):
    """Push the approval/rejection outcome to the submitting user's devices."""
    if not instance.pk:
        return
    try:
        old_instance = sender.objects.get(pk=instance.pk)
    except sender.DoesNotExist:
        return

    if old_instance.status == instance.status:
        return

    try:
        if instance.status == 'approved':
            push.notify_user(
                instance.user,
                'recipe_approval',
                'Your recipe was approved!',
                f'"{instance.title}" is now part of the Sudanile Kitchen '
                f'collection. Thank you for sharing your culinary heritage.',
                data={'type': 'recipe_approval', 'submission_id': instance.pk},
                url='/submissions',
            )
        elif instance.status == 'rejected':
            push.notify_user(
                instance.user,
                'recipe_approval',
                'Recipe submission update',
                f'Unfortunately, "{instance.title}" was not approved. '
                f'You can review the feedback and submit it again.',
                data={'type': 'recipe_approval', 'submission_id': instance.pk},
                url='/submissions',
            )
    except Exception as exc:
        logger.error('Failed to push approval update: %s', exc)