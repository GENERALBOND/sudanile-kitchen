from django.contrib import admin
from .models import Post, PostLike, PostComment


class PostCommentInline(admin.TabularInline):
    model = PostComment
    extra = 0
    readonly_fields = ('user', 'comment', 'created_at')
    can_delete = False


@admin.register(Post)
class PostAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'caption_preview', 'recipe', 'is_flagged', 'created_at')
    list_filter = ('is_flagged', 'created_at')
    search_fields = ('user__email', 'user__username', 'caption')
    inlines = [PostCommentInline]
    readonly_fields = ('image_url', 'created_at')

    def caption_preview(self, obj):
        return obj.caption[:60] or '—'
    caption_preview.short_description = 'Caption'

    def changelist_view(self, request, extra_context=None):
        extra_context = extra_context or {}
        qs = self.get_queryset(request)
        extra_context.update({
            'user_email': getattr(request.user, 'email', ''),
            'total_posts': qs.count(),
            'flagged_count': qs.filter(is_flagged=True).count(),
            'like_count': PostLike.objects.count(),
            'comment_count': PostComment.objects.count(),
        })
        return super().changelist_view(request, extra_context=extra_context)

    actions = ['clear_flags']

    def clear_flags(self, request, queryset):
        updated = queryset.filter(is_flagged=True).update(is_flagged=False)
        self.message_user(request, f'Cleared flag on {updated} post(s).')
    clear_flags.short_description = 'Clear flags on selected posts'


@admin.register(PostLike)
class PostLikeAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'post', 'created_at')
    search_fields = ('user__email',)


@admin.register(PostComment)
class PostCommentAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'post', 'comment', 'created_at')
    search_fields = ('user__email', 'comment')
    list_filter = ('created_at',)
