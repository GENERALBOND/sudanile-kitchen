from rest_framework import serializers
from .models import DeviceToken, CommunityUpdate


VALID_TAGS = ('new_recipes', 'recipe_approval', 'community_updates')


class DeviceTokenSerializer(serializers.ModelSerializer):
    tags = serializers.ListField(
        child=serializers.CharField(),
        allow_empty=True,
        default=list,
    )

    class Meta:
        model = DeviceToken
        fields = ['token', 'platform', 'tags']
        read_only_fields = ['id']

    def validate_platform(self, value):
        choices = dict(DeviceToken.PLATFORM_CHOICES)
        if value not in choices:
            raise serializers.ValidationError(
                f"platform must be one of {', '.join(choices)}."
            )
        return value

    def validate_tags(self, value):
        unknown = set(value) - set(VALID_TAGS)
        if unknown:
            raise serializers.ValidationError(
                f"Unknown tag(s): {', '.join(sorted(unknown))}. "
                f"Valid tags: {', '.join(VALID_TAGS)}."
            )
        return list(dict.fromkeys(value))


class CommunityUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = CommunityUpdate
        fields = ['id', 'title', 'body', 'link', 'published', 'created_at']