from rest_framework import generics, permissions, status
from rest_framework.response import Response
from .models import Review
from .serializers import ReviewSerializer, ReviewCreateSerializer
from recipes.models import Recipe

class ReviewListView(generics.ListAPIView):
    serializer_class = ReviewSerializer
    permission_classes = [permissions.AllowAny]
    
    def get_queryset(self):
        recipe_id = self.kwargs.get('recipe_id')
        return Review.objects.filter(recipe_id=recipe_id)

class ReviewCreateView(generics.CreateAPIView):
    serializer_class = ReviewCreateSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def perform_create(self, serializer):
        recipe_id = self.kwargs.get('recipe_id')
        recipe = Recipe.objects.get(id=recipe_id)
        serializer.save(user=self.request.user, recipe=recipe)

class ReviewUpdateView(generics.UpdateAPIView):
    queryset = Review.objects.all()
    serializer_class = ReviewCreateSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_object(self):
        return Review.objects.get(id=self.kwargs.get('review_id'), user=self.request.user)