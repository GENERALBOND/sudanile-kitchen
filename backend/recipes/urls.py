from django.urls import path
from .views import CategoryListView, RecipeListView, RecipeDetailView, RecipeCreateView

urlpatterns = [
    path('', RecipeListView.as_view(), name='recipe-list'),
    path('categories/', CategoryListView.as_view(), name='category-list'),
    path('create/', RecipeCreateView.as_view(), name='recipe-create'),
    path('<int:id>/', RecipeDetailView.as_view(), name='recipe-detail'),
]
