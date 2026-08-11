from rest_framework import serializers
from .models import RecipeSubmission

ALLOWED_IMAGE_CONTENT_TYPES = {'image/jpeg', 'image/png', 'image/gif'}
ALLOWED_IMAGE_FORMATS = {'JPEG', 'PNG', 'GIF'}


class RecipeSubmissionSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.username', read_only=True)
    image = serializers.ImageField(required=False, allow_null=True)

    class Meta:
        model = RecipeSubmission
        fields = [
            'id', 'title', 'description', 'ingredients', 'instructions',
            'cultural_info', 'prep_hours', 'prep_minutes', 'prep_seconds',
            'cook_hours', 'cook_minutes', 'cook_seconds', 'servings',
            'difficulty', 'image', 'image_url', 'video_url', 'category_name',
            'user', 'user_name', 'status', 'admin_notes', 'submitted_at', 'reviewed_at'
        ]
        read_only_fields = ('user', 'status', 'submitted_at', 'reviewed_at')

    def validate_image(self, image):
        if image is None:
            return image

        content_type = getattr(image, 'content_type', '')
        if content_type and content_type not in ALLOWED_IMAGE_CONTENT_TYPES:
            raise serializers.ValidationError(
                f'Unsupported image format "{content_type}". '
                'Only JPEG, PNG, and GIF images are allowed.'
            )

        # Verify the actual file contents decode as an image in the allowed formats.
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
        instance = super().create(validated_data)
        if instance.image:
            request = self.context.get('request')
            if request is not None:
                instance.image_url = request.build_absolute_uri(instance.image.url)
                instance.save(update_fields=['image_url'])
        return instance
