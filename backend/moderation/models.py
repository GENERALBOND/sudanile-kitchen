from django.conf import settings
from django.db import models
from django.db.models import Q

from community.models import Post, PostComment


class Report(models.Model):
    """A user report against a community post or comment.

    Every report is one row; repeated reports on the same target by the
    same user are prevented by the unique constraints below. When the
    number of *pending* reports on a target reaches the auto-hide
    threshold the target is flagged and hidden from the feed until an
    admin reviews it.
    """

    TARGET_POST = 'post'
    TARGET_COMMENT = 'comment'
    TARGET_CHOICES = [
        (TARGET_POST, 'Post'),
        (TARGET_COMMENT, 'Comment'),
    ]

    REASON_CHOICES = [
        ('spam', 'Spam or scam'),
        ('harassment', 'Harassment or bullying'),
        ('misinformation', 'Misinformation'),
        ('inappropriate', 'Inappropriate content'),
        ('other', 'Other'),
    ]

    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('auto_hidden', 'Auto-hidden'),
        ('resolved', 'Resolved'),
        ('dismissed', 'Dismissed'),
    ]

    ACTION_CHOICES = [
        ('', 'None'),
        ('hidden', 'Content hidden'),
        ('deleted', 'Content deleted'),
        ('warned', 'Author warned'),
        ('banned', 'Author banned'),
    ]

    target_type = models.CharField(max_length=10, choices=TARGET_CHOICES)
    post = models.ForeignKey(
        Post,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='reports',
        help_text='Null after the post is deleted; the original text is kept in the snapshot.',
    )
    comment = models.ForeignKey(
        PostComment,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='reports',
        help_text='Null after the comment is deleted; the original text is kept in the snapshot.',
    )
    content_snapshot = models.TextField(
        blank=True, help_text='Snapshot of the reported content so the audit trail survives deletion.'
    )
    reporter = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='reports_made'
    )
    reason = models.CharField(max_length=30, choices=REASON_CHOICES)
    details = models.TextField(blank=True)
    status = models.CharField(max_length=12, choices=STATUS_CHOICES, default='pending')
    action_taken = models.CharField(max_length=12, choices=ACTION_CHOICES, default='', blank=True)
    admin_note = models.TextField(
        blank=True, help_text='Private note for the moderator reviewing this report.'
    )
    resolved_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='reports_resolved',
    )
    resolved_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        constraints = [
            models.UniqueConstraint(
                fields=['reporter', 'post'],
                condition=Q(post__isnull=False),
                name='unique_report_post_per_user',
            ),
            models.UniqueConstraint(
                fields=['reporter', 'comment'],
                condition=Q(comment__isnull=False),
                name='unique_report_comment_per_user',
            ),
        ]

    def __str__(self):
        return f'{self.target_type} report #{self.id} ({self.status})'

    @property
    def target(self):
        return self.post if self.target_type == self.TARGET_POST else self.comment

    @property
    def target_author(self):
        if self.target_type == self.TARGET_POST:
            return self.post.user if self.post else None
        return self.comment.user if self.comment else None

    @property
    def target_summary(self):
        if self.target_type == self.TARGET_POST:
            return self.content_snapshot or self.post.caption[:80] if self.post else '(deleted)'
        return self.content_snapshot or self.comment.comment[:80] if self.comment else '(deleted)'

    def save(self, *args, **kwargs):
        if not self.content_snapshot:
            if self.target_type == self.TARGET_POST and self.post_id:
                self.content_snapshot = self.post.caption
            elif self.target_type == self.TARGET_COMMENT and self.comment_id:
                self.content_snapshot = self.comment.comment
        super().save(*args, **kwargs)

    def report_count(self):
        """Number of active (pending/auto-hidden) reports on the target."""
        queryset = Report.objects.filter(status__in=['pending', 'auto_hidden'])
        if self.target_type == self.TARGET_POST:
            return queryset.filter(post_id=self.post_id).count()
        return queryset.filter(comment_id=self.comment_id).count()

    report_count.short_description = 'Active reports'


class ModerationEvent(models.Model):
    """Audit trail of actions taken against a user (warnings, hidden
    content, deletions, bans). Powers the moderator's history card."""

    EVENT_CHOICES = [
        ('warned', 'Warned'),
        ('hidden', 'Content hidden'),
        ('deleted', 'Content deleted'),
        ('banned', 'User banned'),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='moderation_events'
    )
    event_type = models.CharField(max_length=12, choices=EVENT_CHOICES)
    note = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.user.username} - {self.get_event_type_display()}'