from django.db import models
from users.models import User


class DeviceToken(models.Model):
    """A push-notification registration endpoint (FCM token) for a device."""

    PLATFORM_CHOICES = [
        ('android', 'Android'),
        ('ios', 'iOS'),
        ('web', 'Web'),
    ]

    # Tags the user has opted into (mirrors the mobile Notifications settings):
    #   "new_recipes"       — new published recipes
    #   "recipe_approval"   — the user's own submission was approved/rejected
    #   "community_updates" — news and updates from the community
    user = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name='device_tokens'
    )
    token = models.CharField(max_length=512, unique=True)
    platform = models.CharField(max_length=10, choices=PLATFORM_CHOICES, default='android')
    tags = models.JSONField(default=list, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.user.email} {self.platform} token"


class CommunityUpdate(models.Model):
    """A news/community update that can be pushed to opted-in users."""

    title = models.CharField(max_length=200)
    body = models.TextField()
    link = models.URLField(blank=True, null=True)
    published = models.BooleanField(default=False)
    notified_at = models.DateTimeField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.title

    class Meta:
        ordering = ['-created_at']