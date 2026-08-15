from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from .serializers import DeviceTokenSerializer
from .models import DeviceToken


class PushStatusView(APIView):
    """Health check: whether FCM push credentials are configured and valid."""

    permission_classes = [permissions.AllowAny]

    def get(self, request):
        from . import push

        return Response({'fcm_configured': push.messaging_configured()})


class RegisterDeviceTokenView(APIView):
    """Upserts the caller's FCM token together with its alert tags."""

    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = DeviceTokenSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        token = serializer.validated_data['token'].strip()
        if not token:
            return Response(
                {'error': 'token is required.'}, status=status.HTTP_400_BAD_REQUEST
            )

        device, _ = DeviceToken.objects.update_or_create(
            token=token,
            defaults={
                'user': request.user,
                'platform': serializer.validated_data['platform'],
                'tags': serializer.validated_data.get('tags', []),
            },
        )
        return Response(DeviceTokenSerializer(device).data, status=status.HTTP_200_OK)


class UnregisterDeviceTokenView(APIView):
    """Removes a device token so the user stops receiving notifications.

    Deliberately unauthenticated: unregistration happens during sign-out, when
    the Firebase session is already gone and no Bearer token can be presented.
    The FCM token itself is the proof of ownership (a long, unguessable
    per-device secret), and deleting a token is harmless at worst — the device
    simply stops receiving pushes.
    """

    permission_classes = [permissions.AllowAny]

    def post(self, request):
        token = request.data.get('token', '').strip()
        if not token:
            return Response(
                {'error': 'token is required.'}, status=status.HTTP_400_BAD_REQUEST
            )
        DeviceToken.objects.filter(token=token).delete()
        return Response({'message': 'Token removed.'}, status=status.HTTP_200_OK)