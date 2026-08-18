import logging
import time

from django.conf import settings
from django.contrib import admin, messages
from django.core.mail import send_mail
from django.utils import timezone as dj_timezone
from django.utils.html import format_html

from notifications import push

from .models import ModerationEvent, Report

logger = logging.getLogger(__name__)

REPORTER_ACTIONED = "Thanks — your report was reviewed and acted on."
REPORTER_DISMISSED = "We reviewed your report and it doesn't break our rules."


def _notify_reporter(report, title, body):
    push.notify_user(report.reporter, 'community_updates', title, body)


def _notify_author(author, title, body):
    if author is not None:
        push.notify_user(author, 'community_updates', title, body)


MODERATION_EMAILS = {
    'hidden': {
        'subject': 'Your content was hidden - Sudanile Kitchen',
        'action_line': 'Your content was hidden from the community feed because it goes '
                       'against our community guidelines.',
    },
    'deleted': {
        'subject': 'Your content was deleted - Sudanile Kitchen',
        'action_line': 'Your content was deleted from the community feed because it goes '
                       'against our community guidelines.',
    },
    'warned': {
        'subject': 'Community warning - Sudanile Kitchen',
        'action_line': 'You have received a warning because your content goes against our '
                       'community guidelines.',
    },
    'banned': {
        'subject': 'Your account has been disabled - Sudanile Kitchen',
        'action_line': 'Your account has been disabled because of repeated violations of '
                       'our community guidelines.',
    },
}


def _notify_author_email(action_value, report):
    """Sends a plain-text email to the content author explaining what happened.

    Best-effort: a missing author/email or a failed SMTP send never breaks the
    moderation action. Includes the report reason, any admin note and a snippet
    of the reported content so the author knows exactly why.
    """
    author = report.target_author
    if author is None or not author.email:
        return
    template = MODERATION_EMAILS.get(action_value)
    if template is None:
        return

    snapshot = report.content_snapshot or ''
    if len(snapshot) > 300:
        snapshot = snapshot[:300] + '…'

    lines = [
        f'Hi {author.username or author.email},',
        '',
        template['action_line'],
    ]
    if report.reason:
        lines += ['', f'Reason: {report.get_reason_display()}']
    if report.admin_note:
        lines += ['', f'Moderator note: {report.admin_note}']
    if snapshot:
        lines += ['', f'Content: "{snapshot}"']
    if action_value == 'banned':
        lines += ['', 'Your account will remain disabled until an admin re-enables it.']
    lines += [
        '',
        'If you believe this was a mistake, reply to this email and our team will review it.',
        '',
        'Sudanile Kitchen',
    ]

    # Transient SMTP errors often clear on retry; each attempt is bounded by
    # EMAIL_TIMEOUT so the total stays under gunicorn's worker timeout.
    for attempt in (1, 2):
        try:
            send_mail(
                subject=template['subject'],
                message='\n'.join(lines),
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[author.email],
                fail_silently=False,
            )
            logger.info(
                'Sent moderation email to %s (action=%s, report=%s)',
                author.email, action_value, report.pk,
            )
            return
        except Exception as exc:
            logger.error(
                'Failed to send moderation email to %s (attempt %s): %s',
                author.email, attempt, exc,
            )
            if attempt == 1:
                time.sleep(1)


def _record_event(author, event_type, note):
    if author is not None:
        ModerationEvent.objects.create(user=author, event_type=event_type, note=note)


def _resolve_batch(queryset, admin_user, status_value, action_value):
    """Shared resolution logic for bulk actions: mark every active report on
    each selected target as resolved/dismissed."""
    now = dj_timezone.now()
    updated = []
    for report in queryset:
        if report.status not in ('pending', 'auto_hidden'):
            continue
        Report.objects.filter(
            status__in=['pending', 'auto_hidden'],
            **({'post_id': report.post_id} if report.target_type == Report.TARGET_POST
               else {'comment_id': report.comment_id}),
        ).update(
            status=status_value, action_taken=action_value,
            resolved_by=admin_user, resolved_at=now,
        )
        updated.append(report)
    return updated


@admin.register(Report)
class ReportAdmin(admin.ModelAdmin):
    list_display = (
        'id', 'target_type', 'target_summary', 'reporter', 'reason',
        'status_badge', 'active_report_count', 'created_at',
    )
    list_filter = ('status', 'reason', 'target_type')
    search_fields = (
        'content_snapshot', 'post__caption', 'comment__comment',
        'reporter__email', 'reporter__username',
    )
    ordering = ('-created_at',)
    list_select_related = ('reporter', 'post', 'comment')
    actions = ('dismiss_reports', 'hide_content', 'delete_content', 'warn_author', 'ban_user')

    fieldsets = (
        (None, {
            'fields': ('target_type', 'target_summary_readonly', 'content_snapshot',
                       'reporter', 'reason', 'details'),
        }),
        ('Moderation', {
            'description': 'Decide how to handle this report. Dismissing restores the '
                           'content; hiding hides it; deleting removes it permanently.',
            'fields': ('status', 'action_taken', 'admin_note', 'author_history',
                       'resolved_by', 'resolved_at'),
        }),
    )
    readonly_fields = (
        'target_type', 'content_snapshot', 'reporter', 'reason', 'details',
        'target_summary_readonly', 'author_history', 'resolved_by', 'resolved_at',
        'status', 'action_taken',
    )

    def has_add_permission(self, request):
        # Reports are created through the mobile API, never manually.
        return False

    @admin.display(description='Target')
    def target_summary_readonly(self, obj):
        if obj.target_type == Report.TARGET_POST and obj.post_id:
            caption = obj.content_snapshot or obj.post.caption
            return format_html(
                '<strong>Post #{}</strong> by {}<br/><span style="color:var(--body-quiet-color)">{}</span>',
                obj.post_id, obj.post.user.email, caption,
            )
        if obj.target_type == Report.TARGET_COMMENT and obj.comment_id:
            text = obj.content_snapshot or obj.comment.comment
            return format_html(
                '<strong>Comment #{}</strong> on post #{} by {}<br/>'
                '<span style="color:var(--body-quiet-color)">{}</span>',
                obj.comment_id, obj.comment.post_id, obj.comment.user.email, text,
            )
        return '<em>Content deleted — see snapshot below.</em>'

    @admin.display(description='Status')
    def status_badge(self, obj):
        colors = {
            'pending': '#f0c060', 'auto_hidden': '#f08080',
            'resolved': '#6fcf89', 'dismissed': '#8a8880',
        }
        color = colors.get(obj.status, '#8a8880')
        return format_html(
            '<span style="display:inline-block;padding:2px 8px;border-radius:10px;'
            'font-size:11px;color:#1a1a18;background:{}">{}</span>',
            color, obj.get_status_display(),
        )

    @admin.display(description='Active reports')
    def active_report_count(self, obj):
        count = obj.report_count()
        if count > 1:
            return format_html('<strong>{}</strong>', count)
        return count

    @admin.display(description='Author moderation history')
    def author_history(self, obj):
        author = obj.target_author
        if author is None:
            return '—'
        events = ModerationEvent.objects.filter(user=author).order_by('-created_at')
        parts = [
            f'{author.email} · account created {author.date_joined:%b %d, %Y} · '
            f'{author.community_posts.count()} posts'
        ]
        if not events.exists():
            parts.append('No prior moderation events.')
        for event in events:
            parts.append(f'{event.created_at:%b %d, %Y} — {event.get_event_type_display()}: {event.note or "—"}')
        return '\n'.join(parts)

    # ---- Bulk actions ----------------------------------------------------

    def dismiss_reports(self, request, queryset):
        resolved = _resolve_batch(queryset, request.user, 'dismissed', '')
        for report in resolved:
            target = report.target
            if target is not None and target.is_flagged:
                target.is_flagged = False
                target.save(update_fields=['is_flagged'])
            _notify_reporter(report, 'Report reviewed', REPORTER_DISMISSED)
        self.message_user(
            request,
            f'{len(resolved)} report(s) dismissed and content restored where needed.',
            messages.SUCCESS,
        )

    dismiss_reports.short_description = 'Dismiss — content is fine (restores it)'

    def hide_content(self, request, queryset):
        resolved = _resolve_batch(queryset, request.user, 'resolved', 'hidden')
        for report in resolved:
            target = report.target
            if target is not None and not target.is_flagged:
                target.is_flagged = True
                target.save(update_fields=['is_flagged'])
            _record_event(report.target_author, 'hidden', f'Post/comment hidden after report #{report.pk}.')
            _notify_author_email('hidden', report)
            _notify_reporter(report, 'Report reviewed', REPORTER_ACTIONED)
        self.message_user(
            request, f'{len(resolved)} report(s) resolved; content hidden from the feed.', messages.SUCCESS,
        )

    hide_content.short_description = 'Hide content from the feed'

    def delete_content(self, request, queryset):
        resolved = _resolve_batch(queryset, request.user, 'resolved', 'deleted')
        for report in resolved:
            author = report.target_author
            # Email the author before deleting, since the FK becomes null afterwards.
            _notify_author_email('deleted', report)
            target = report.target
            if target is not None:
                _record_event(
                    author, 'deleted',
                    f'Content deleted after report #{report.pk}.',
                )
                target.delete()
            _notify_reporter(report, 'Report reviewed', REPORTER_ACTIONED)
        self.message_user(
            request, f'{len(resolved)} report(s) resolved; content deleted.', messages.SUCCESS,
        )

    delete_content.short_description = 'Delete content permanently'

    def warn_author(self, request, queryset):
        resolved = _resolve_batch(queryset, request.user, 'resolved', 'warned')
        for report in resolved:
            author = report.target_author
            _record_event(
                author, 'warned',
                f'Warned for report #{report.pk} ({report.get_reason_display()}).',
            )
            _notify_author_email('warned', report)
            _notify_author(author, 'Community warning', 'Please keep posts and comments respectful.')
            _notify_reporter(report, 'Report reviewed', REPORTER_ACTIONED)
        self.message_user(
            request, f'{len(resolved)} report(s) resolved; author(s) warned.', messages.SUCCESS,
        )

    warn_author.short_description = 'Warn the author (no content change)'

    def ban_user(self, request, queryset):
        resolved = _resolve_batch(queryset, request.user, 'resolved', 'banned')
        for report in resolved:
            author = report.target_author
            if author is not None:
                _record_event(
                    author, 'banned',
                    f'Account disabled after report #{report.pk} ({report.get_reason_display()}).',
                )
                author.is_active = False
                author.save(update_fields=['is_active'])
            _notify_author_email('banned', report)
            _notify_reporter(report, 'Report reviewed', REPORTER_ACTIONED)
        self.message_user(
            request, f'{len(resolved)} report(s) resolved; author account(s) disabled.', messages.SUCCESS,
        )

    ban_user.short_description = 'Disable the author\'s account'


@admin.register(ModerationEvent)
class ModerationEventAdmin(admin.ModelAdmin):
    list_display = ('user', 'event_type', 'note', 'created_at')
    list_filter = ('event_type',)
    search_fields = ('user__email', 'user__username', 'note')
    ordering = ('-created_at',)
    readonly_fields = ('user', 'event_type', 'note', 'created_at')

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False