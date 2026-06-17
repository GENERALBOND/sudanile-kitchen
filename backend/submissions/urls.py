from django.urls import path
from .views import SubmissionCreateView, SubmissionListView

urlpatterns = [
    path('', SubmissionListView.as_view(), name='submission-list'),
    path('create/', SubmissionCreateView.as_view(), name='submission-create'),
]
