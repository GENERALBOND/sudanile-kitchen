from django.db.models import Count
from django.shortcuts import get_object_or_404
from rest_framework import generics, permissions, status
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Post, PostComment, PostLike
from moderation.models import Report
from .serializers import (
    PostSerializer,
    PostCreateSerializer,
    PostCommentSerializer,
    PostCommentCreateSerializer,
)


class CommunityFeedPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = 'page_size'


class PostListView(generics.ListAPIView):
    """Public feed. Supports ?user=<id> to show one user's posts and
    ?sort=popular to order by like count."""

    serializer_class = PostSerializer
    permission_classes = [permissions.AllowAny]
    pagination_class = CommunityFeedPagination

    def get_queryset(self):
        queryset = Post.objects.filter(is_flagged=False).select_related('user', 'recipe')
        user_id = self.request.query_params.get('user')
        if user_id:
            queryset = queryset.filter(user_id=user_id)
        if self.request.query_params.get('sort') == 'popular':
            queryset = queryset.annotate(like_total=Count('likes')).order_by('-like_total', '-created_at')
        return queryset

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context


class PostCreateView(generics.CreateAPIView):
    serializer_class = PostCreateSerializer
    permission_classes = [permissions.IsAuthenticated]

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class PostDetailView(generics.RetrieveAPIView):
    """A single post — used by the mobile app to open a post from a
    notification tap."""

    serializer_class = PostSerializer
    permission_classes = [permissions.AllowAny]

    def get_object(self):
        return get_object_or_404(
            Post.objects.select_related('user', 'recipe'),
            id=self.kwargs.get('post_id'),
        )

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context


class PostDeleteView(APIView):
    """Owners (and admins) may delete a post."""

    permission_classes = [permissions.IsAuthenticated]

    def delete(self, request, post_id):
        post = get_object_or_404(Post, id=post_id)
        if post.user != request.user and request.user.role != 'admin':
            return Response({'error': 'You can only delete your own posts.'},
                            status=status.HTTP_403_FORBIDDEN)
        post.delete()
        return Response({'message': 'Post deleted.'}, status=status.HTTP_200_OK)


class PostLikeToggleView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, post_id):
        post = get_object_or_404(Post, id=post_id)
        like, created = PostLike.objects.get_or_create(user=request.user, post=post)
        if created:
            return Response({'liked': True, 'like_count': post.likes.count()},
                            status=status.HTTP_201_CREATED)
        like.delete()
        return Response({'liked': False, 'like_count': post.likes.count()},
                        status=status.HTTP_200_OK)


class PostReportView(APIView):
    """Legacy report endpoint kept for older app builds: flags a post so
    admins can review it. New clients should use CommunityReportView."""

    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, post_id):
        post = get_object_or_404(Post, id=post_id)
        post.is_flagged = True
        post.save(update_fields=['is_flagged'])
        return Response({'message': 'Post reported.'}, status=status.HTTP_200_OK)


class CommunityReportView(APIView):
    """Create a report against a community post or comment.

    One report per user per target. Once a target reaches the auto-hide
    threshold it is hidden from the feed until a moderator reviews it.
    """

    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        target_type = request.data.get('target_type')
        target_id = request.data.get('target_id')
        reason = request.data.get('reason')
        details = (request.data.get('details') or '').strip()

        if target_type not in ('post', 'comment'):
            return Response(
                {'error': 'target_type must be "post" or "comment".'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not target_id:
            return Response(
                {'error': 'target_id is required.'}, status=status.HTTP_400_BAD_REQUEST
            )
        valid_reasons = {r[0] for r in Report.REASON_CHOICES}
        if reason not in valid_reasons:
            return Response(
                {'error': f'reason must be one of: {", ".join(sorted(valid_reasons))}.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if target_type == 'post':
            post = get_object_or_404(Post, id=target_id)
            comment = None
        else:
            comment = get_object_or_404(PostComment, id=target_id)
            post = None

        if Report.objects.filter(
            reporter=request.user,
            **({'post_id': target_id} if target_type == 'post' else {'comment_id': target_id}),
        ).exists():
            return Response(
                {'message': 'Thanks — we already received your report.'},
                status=status.HTTP_200_OK,
            )

        Report.objects.create(
            target_type=target_type,
            post=post,
            comment=comment,
            reporter=request.user,
            reason=reason,
            details=details,
        )
        return Response(
            {'message': "Thanks — we'll review this."}, status=status.HTTP_201_CREATED
        )


class PostCommentListView(generics.ListAPIView):
    serializer_class = PostCommentSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        post_id = self.kwargs.get('post_id')
        return PostComment.objects.filter(post_id=post_id, is_flagged=False).select_related('user')


class PostCommentCreateView(generics.CreateAPIView):
    serializer_class = PostCommentCreateSerializer
    permission_classes = [permissions.IsAuthenticated]

    def perform_create(self, serializer):
        post = get_object_or_404(Post, id=self.kwargs.get('post_id'))
        serializer.save(user=self.request.user, post=post)


class PostCommentDeleteView(APIView):
    """Owners (and admins) may delete a comment."""

    permission_classes = [permissions.IsAuthenticated]

    def delete(self, request, comment_id):
        comment = get_object_or_404(PostComment, id=comment_id)
        if comment.user != request.user and request.user.role != 'admin':
            return Response({'error': 'You can only delete your own comments.'},
                            status=status.HTTP_403_FORBIDDEN)
        comment.delete()
        return Response({'message': 'Comment deleted.'}, status=status.HTTP_200_OK)
