from django.urls import path
from .views import ReviewListView, ReviewCreateView, ReviewUpdateView

urlpatterns = [
    path('recipe/<int:recipe_id>/', ReviewListView.as_view(), name='review-list'),
    path('recipe/<int:recipe_id>/create/', ReviewCreateView.as_view(), name='review-create'),
    path('<int:review_id>/update/', ReviewUpdateView.as_view(), name='review-update'),
]