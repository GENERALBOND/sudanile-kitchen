from rest_framework import serializers
from django.contrib.auth.password_validation import validate_password
from .models import User

class UserSerializer(serializers.ModelSerializer):
    favorites_count = serializers.SerializerMethodField()
    reviews_count = serializers.SerializerMethodField()
    submissions_count = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ('id', 'username', 'email', 'role', 'is_staff',
                  'is_superuser', 'profile_picture', 'bio', 'created_at',
                  'favorites_count', 'reviews_count', 'submissions_count')
        read_only_fields = ('id', 'role', 'is_staff', 'is_superuser',
                            'created_at', 'email')
        extra_kwargs = {
            'username': {'required': False},
            'bio': {'required': False},
        }

    def get_favorites_count(self, obj):
        return obj.favorites.count()

    def get_reviews_count(self, obj):
        return obj.reviews.count()

    def get_submissions_count(self, obj):
        return obj.submissions.count()


class PublicProfileSerializer(UserSerializer):
    """Profile data safe to show to any viewer (used by the community feed).

    Excludes the private email address and adds the member's community stats.
    """

    post_count = serializers.SerializerMethodField()
    like_count = serializers.SerializerMethodField()
    comment_count = serializers.SerializerMethodField()

    class Meta(UserSerializer.Meta):
        fields = ('id', 'username', 'role', 'profile_picture', 'bio',
                  'created_at', 'favorites_count', 'reviews_count',
                  'submissions_count', 'post_count', 'like_count',
                  'comment_count')

    def get_post_count(self, obj):
        return obj.community_posts.count()

    def get_like_count(self, obj):
        return obj.community_likes.count()

    def get_comment_count(self, obj):
        return obj.community_comments.count()

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=True, validators=[validate_password])
    password2 = serializers.CharField(write_only=True, required=True)
    
    class Meta:
        model = User
        fields = ('username', 'email', 'password', 'password2')
    
    def validate_email(self, value):
        if not value.endswith('@gmail.com'):
            raise serializers.ValidationError('Only @gmail.com email addresses are allowed.')
        return value

    def validate(self, attrs):
        if attrs['password'] != attrs['password2']:
            raise serializers.ValidationError({"password": "Password fields didn't match."})
        return attrs
    
    def create(self, validated_data):
        validated_data.pop('password2')
        user = User.objects.create_user(**validated_data)
        return user

class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(required=True)
    new_password = serializers.CharField(required=True, validators=[validate_password])
