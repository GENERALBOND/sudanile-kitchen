from django.contrib import admin, messages
from django.utils import timezone

from .models import DeviceToken, CommunityUpdate
from . import push


@admin.register(DeviceToken)
class DeviceTokenAdmin(admin.ModelAdmin):
    list_display = ('user', 'platform', 'tags', 'updated_at')
    list_filter = ('platform',)
    search_fields = ('user__email', 'token')
    readonly_fields = ('created_at', 'updated_at')
    actions = ['send_test_notification']

    def send_test_notification(self, request, queryset):
        tokens = list(queryset.values_list('token', flat=True))
        push._send_to_tokens(
            tokens,
            'Test notification',
            'This is a test push from the Sudanile Kitchen admin.',
            data={'type': 'admin_test'},
        )
        self.message_user(
            request, f'Queued test push to {tokens.__len__()} device(s).',
            messages.SUCCESS,
        )

    send_test_notification.short_description = 'Send test push notification'


@admin.register(CommunityUpdate)
class CommunityUpdateAdmin(admin.ModelAdmin):
    list_display = ('title', 'published', 'notified_at', 'created_at')
    list_filter = ('published',)
    search_fields = ('title', 'body')
    readonly_fields = ('notified_at', 'created_at', 'updated_at')
    actions = ['publish_and_notify']

    def publish_and_notify(self, request, queryset):
        count = 0
        for update in queryset.filter(published=False):
            update.published = True
            update.notified_at = timezone.now()
            update.save()
            push.notify_tag(
                'community_updates',
                update.title,
                update.body,
                data={'type': 'community_update', 'community_update_id': update.pk},
                url=update.link or '/home',
            )
            count += 1
        self.message_user(
            request, f'Published and sent {count} community update(s).',
            messages.SUCCESS,
        )

    publish_and_notify.short_description = 'Publish & push to community'