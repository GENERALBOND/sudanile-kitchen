from django.conf import settings
from django.db.models.signals import post_save
from django.dispatch import receiver

from .models import Report


def auto_hide_threshold():
    return getattr(settings, 'REPORT_AUTO_HIDE_THRESHOLD', 3)


@receiver(post_save, sender=Report)
def maybe_auto_hide_target(sender, instance, **kwargs):
    """When a target accumulates enough pending reports, flag it so it is
    hidden from the feed until a moderator reviews it."""
    if instance.status != 'pending':
        return

    threshold = auto_hide_threshold()
    if instance.target_type == Report.TARGET_POST:
        pending = Report.objects.filter(post_id=instance.post_id, status='pending').count()
        target, field = instance.post, 'post_id'
    else:
        pending = Report.objects.filter(comment_id=instance.comment_id, status='pending').count()
        target, field = instance.comment, 'comment_id'

    if pending < threshold or target is None or target.is_flagged:
        return

    target.is_flagged = True
    target.save(update_fields=['is_flagged'])

    filters = {field: target.id, 'status': 'pending'}
    Report.objects.filter(**filters).update(status='auto_hidden')