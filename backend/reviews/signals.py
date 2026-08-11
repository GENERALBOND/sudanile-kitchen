from django.db.models.signals import pre_save, post_save
from django.dispatch import receiver

from config.renumber import lowest_free_id, sync_sequence
from .models import Review


@receiver(pre_save, sender=Review)
def use_next_available_id(sender, instance, **kwargs):
    if instance.pk is None:
        instance.pk = lowest_free_id(sender)


@receiver(post_save, sender=Review)
def keep_sequence_in_sync(sender, instance, **kwargs):
    sync_sequence(sender)