from rest_framework import serializers
from recipes.models import Recipe
from .models import Post, PostComment

ALLOWED_IMAGE_CONTENT_TYPES = {'image/jpeg', 'image/png', 'image/gif'}
ALLOWED_IMAGE_FORMATS = {'JPEG', 'PNG', 'GIF'}


class PostCommentSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.username', read_only=True)
    user_profile_picture = serializers.CharField(source='user.profile_picture', read_only=True)

    class Meta:
        model = PostComment
        fields = ('id', 'post', 'user', 'user_name', 'user_profile_picture',
                  'comment', 'created_at')
        read_only_fields = ('post', 'user', 'created_at')


class PostCommentCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = PostComment
        fields = ('comment',)


class PostSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.username', read_only=True)
    user_profile_picture = serializers.CharField(source='user.profile_picture', read_only=True)
    like_count = serializers.SerializerMethodField()
    comment_count = serializers.SerializerMethodField()
    is_liked_by_me = serializers.SerializerMethodField()
    recipe_title = serializers.CharField(source='recipe.title', read_only=True, default=None)
    recipe_image_url = serializers.CharField(source='recipe.image_url', read_only=True, default=None)

    class Meta:
        model = Post
        fields = ('id', 'user', 'user_name', 'user_profile_picture', 'caption',
                  'image_url', 'recipe', 'recipe_title', 'recipe_image_url',
                  'like_count', 'comment_count', 'is_liked_by_me', 'created_at')
        read_only_fields = ('user', 'image_url', 'created_at')

    def get_like_count(self, obj):
        return obj.likes.count()

    def get_comment_count(self, obj):
        return obj.comments.count()

    def get_is_liked_by_me(self, obj):
        request = self.context.get('request')
        if request is None or not request.user.is_authenticated:
            return False
        return obj.likes.filter(user=request.user).exists()


class PostCreateSerializer(serializers.ModelSerializer):
    image = serializers.ImageField(required=True)
    caption = serializers.CharField(required=False, allow_blank=True, max_length=2000)
    recipe = serializers.PrimaryKeyRelatedField(
        queryset=Recipe.objects.all(),
        required=False,
        allow_null=True,
    )

    class Meta:
        model = Post
        fields = ('image', 'caption', 'recipe')

    def validate_image(self, image):
        content_type = getattr(image, 'content_type', '')
        if content_type and content_type not in ALLOWED_IMAGE_CONTENT_TYPES:
            raise serializers.ValidationError(
                f'Unsupported image format "{content_type}". '
                'Only JPEG, PNG, and GIF images are allowed.'
            )

        from PIL import Image
        from django.core.files.uploadedfile import UploadedFile
        try:
            fmt = None
            if isinstance(image, UploadedFile):
                image.seek(0)
                with Image.open(image) as img:
                    fmt = img.format
                image.seek(0)
            if fmt and fmt not in ALLOWED_IMAGE_FORMATS:
                raise serializers.ValidationError(
                    f'Unsupported image format "{fmt}". '
                    'Only JPEG, PNG, and GIF images are allowed.'
                )
        except serializers.ValidationError:
            raise
        except Exception:
            raise serializers.ValidationError(
                'The uploaded file is not a valid image. '
                'Only JPEG, PNG, and GIF images are allowed.'
            )

        return image

    def create(self, validated_data):
        request = self.context.get('request')
        validated_data['user'] = request.user
        instance = Post.objects.create(**validated_data)
        if instance.image:
            instance.image_url = request.build_absolute_uri(instance.image.url)
            instance.save(update_fields=['image_url'])
        return instance

    def to_representation(self, instance):
        # Return the full post payload (id, author, counts, is_liked_by_me...)
        # so the client can prepend it to the feed without a follow-up fetch.
        return PostSerializer(instance, context=self.context).data
