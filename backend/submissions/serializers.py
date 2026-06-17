from rest_framework import serializers
from .models import RecipeSubmission

class RecipeSubmissionSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.username', read_only=True)
    
    class Meta:
        model = RecipeSubmission
        fields = [
            'id', 'title', 'description', 'ingredients', 'instructions',
            'cultural_info', 'prep_hours', 'prep_minutes', 'prep_seconds',
            'cook_hours', 'cook_minutes', 'cook_seconds', 'servings',
            'difficulty', 'image_url', 'video_url', 'category_name',
            'user', 'user_name', 'status', 'admin_notes', 'submitted_at', 'reviewed_at'
        ]
        read_only_fields = ('user', 'status', 'submitted_at', 'reviewed_at')
