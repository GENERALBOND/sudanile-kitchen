from rest_framework import generics, permissions, filters, status
from rest_framework.response import Response
from django.db.models import Q
from .models import Category, Recipe
from .serializers import CategorySerializer, RecipeSerializer, RecipeCreateSerializer
from .duplicate_check import find_duplicates

class CategoryListView(generics.ListAPIView):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer
    permission_classes = [permissions.AllowAny]

class RecipeListView(generics.ListAPIView):
    serializer_class = RecipeSerializer
    permission_classes = [permissions.AllowAny]
    filter_backends = [filters.OrderingFilter]
    ordering_fields = ['created_at', 'average_rating', 'view_count']
    ordering = ['-created_at']
    
    def get_queryset(self):
        queryset = Recipe.objects.filter(is_published=True)
        
        search = self.request.query_params.get('search')
        if search:
            queryset = queryset.filter(
                Q(title__icontains=search) |
                Q(description__icontains=search) |
                Q(cultural_info__icontains=search) |
                Q(ingredients__icontains=search)
            )
        
        category = self.request.query_params.get('category')
        if category:
            queryset = queryset.filter(category__name__iexact=category)
        
        difficulty = self.request.query_params.get('difficulty')
        if difficulty:
            queryset = queryset.filter(difficulty__iexact=difficulty)
        
        meal_types = self.request.query_params.get('meal_types')
        if meal_types:
            # SQLite stores JSON as text, so a quoted-key substring match is
            # the portable way to filter array elements (JSON contains is not
            # supported on the SQLite backend).
            for meal_type in meal_types.split(','):
                if meal_type:
                    queryset = queryset.filter(meal_types__icontains=f'"{meal_type}"')
        
        return queryset

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
    
    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        duplicates = find_duplicates(
            serializer.validated_data.get('title', ''),
            ingredients=serializer.validated_data.get('ingredients'),
            category=serializer.validated_data.get('category'),
        )
        
        if duplicates:
            return Response({
                'error': 'Duplicate recipe detected.',
                'duplicate_with': {
                    'id': duplicates[0]['recipe'].id,
                    'title': duplicates[0]['recipe'].title,
                    'reason': duplicates[0]['reason'],
                }
            }, status=status.HTTP_409_CONFLICT)
        
        self.perform_create(serializer)
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    
    def perform_create(self, serializer):
        is_published = self.request.user.role == 'admin'
        serializer.save(author=self.request.user, is_published=is_published)
