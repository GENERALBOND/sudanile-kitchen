from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.shortcuts import get_object_or_404
from .models import Favorite
from .serializers import FavoriteSerializer
from recipes.models import Recipe
from recipes.serializers import RecipeSerializer

class FavoriteListView(generics.ListAPIView):
    serializer_class = FavoriteSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        return Favorite.objects.filter(user=self.request.user)

class FavoriteCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        recipe_id = request.data.get('recipe')
        if not recipe_id:
            return Response({'error': 'Recipe ID is required'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Check if recipe exists
        recipe = get_object_or_404(Recipe, id=recipe_id)
        
        # Check if already favorited
        favorite, created = Favorite.objects.get_or_create(
            user=request.user,
            recipe=recipe
        )
        
        if created:
            serializer = FavoriteSerializer(favorite)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        else:
            return Response({'message': 'Recipe already in favorites'}, status=status.HTTP_200_OK)

class FavoriteDeleteView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    
    def delete(self, request, recipe_id):
        favorite = Favorite.objects.filter(user=request.user, recipe_id=recipe_id).first()
        if favorite:
            favorite.delete()
            return Response({'message': 'Removed from favorites'}, status=status.HTTP_200_OK)
        return Response({'error': 'Favorite not found'}, status=status.HTTP_404_NOT_FOUND)
