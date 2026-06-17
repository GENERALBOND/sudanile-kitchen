from rest_framework import generics, permissions
from .models import Category, Recipe
from .serializers import CategorySerializer, RecipeSerializer, RecipeCreateSerializer

class CategoryListView(generics.ListAPIView):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer
    permission_classes = [permissions.AllowAny]

class RecipeListView(generics.ListAPIView):
    serializer_class = RecipeSerializer
    permission_classes = [permissions.AllowAny]
    
    def get_queryset(self):
        return Recipe.objects.filter(is_published=True).order_by('-created_at')

class RecipeDetailView(generics.RetrieveAPIView):
    queryset = Recipe.objects.all()
    serializer_class = RecipeSerializer
    permission_classes = [permissions.AllowAny]
    lookup_field = 'id'
    
    def retrieve(self, request, *args, **kwargs):
        instance = self.get_object()
        instance.view_count += 1
        instance.save()
        return super().retrieve(request, *args, **kwargs)

class RecipeCreateView(generics.CreateAPIView):
    serializer_class = RecipeCreateSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def perform_create(self, serializer):
        is_published = self.request.user.role == 'admin'
        serializer.save(author=self.request.user, is_published=is_published)
