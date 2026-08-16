from django.urls import path
from .views import (
    PostListView,
    PostCreateView,
    PostDetailView,
    PostDeleteView,
    PostLikeToggleView,
    PostReportView,
    CommunityReportView,
    PostCommentListView,
    PostCommentCreateView,
    PostCommentDeleteView,
)

urlpatterns = [
    path('', PostListView.as_view(), name='community-post-list'),
    path('create/', PostCreateView.as_view(), name='community-post-create'),
    path('<int:post_id>/', PostDetailView.as_view(), name='community-post-detail'),
    path('<int:post_id>/delete/', PostDeleteView.as_view(), name='community-post-delete'),
    path('<int:post_id>/like/', PostLikeToggleView.as_view(), name='community-post-like'),
    path('<int:post_id>/report/', PostReportView.as_view(), name='community-post-report'),
    path('report/', CommunityReportView.as_view(), name='community-report'),
    path('<int:post_id>/comments/', PostCommentListView.as_view(), name='community-comment-list'),
    path('<int:post_id>/comments/create/', PostCommentCreateView.as_view(), name='community-comment-create'),
    path('comments/<int:comment_id>/delete/', PostCommentDeleteView.as_view(), name='community-comment-delete'),
]
