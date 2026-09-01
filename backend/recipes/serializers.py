from rest_framework import serializers
from .models import Category, Recipe
from config.meal_types import clean_meal_types

class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = '__all__'

class RecipeSerializer(serializers.ModelSerializer):
    author_name = serializers.CharField(source='author.username', read_only=True)
    category_name = serializers.CharField(source='category.name', read_only=True)
    preparation_time = serializers.IntegerField(source='preparation_time_minutes', read_only=True)
    cooking_time = serializers.IntegerField(source='cooking_time_minutes', read_only=True)
    preparation_time_display = serializers.CharField(read_only=True)
    cooking_time_display = serializers.CharField(read_only=True)
    meal_types_display = serializers.CharField(read_only=True)

    class Meta:
        model = Recipe
        fields = ['id', 'title', 'description', 'ingredients', 'instructions', 'cultural_info',
                  'prep_hours', 'prep_minutes', 'prep_seconds', 
                  'cook_hours', 'cook_minutes', 'cook_seconds',
                  'preparation_time', 'cooking_time', 
                  'preparation_time_display', 'cooking_time_display',
                  'servings', 'difficulty', 'image_url',
                  'category', 'category_name', 'author', 'author_name', 
                  'average_rating', 'total_reviews', 'view_count',
                  'meal_types', 'meal_types_display',
                  'created_at', 'updated_at', 'is_published']
        read_only_fields = ('author', 'average_rating', 'total_reviews', 'view_count')

    def validate_meal_types(self, value):
        return clean_meal_types(value)

class RecipeCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Recipe
        fields = ['title', 'description', 'ingredients', 'instructions', 'cultural_info',
                  'prep_hours', 'prep_minutes', 'prep_seconds',
                  'cook_hours', 'cook_minutes', 'cook_seconds',
                  'servings', 'difficulty', 'image_url',
                  'category', 'meal_types']

    def validate_meal_types(self, value):
        return clean_meal_types(value)
