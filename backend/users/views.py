import logging
import uuid
from rest_framework import status, generics, permissions
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import authenticate
from django.core.files.storage import default_storage
from PIL import Image
from .models import User
from .serializers import UserSerializer, RegisterSerializer, ChangePasswordSerializer, PublicProfileSerializer
from .authentication import firebase_uid_from_token, delete_firebase_user

logger = logging.getLogger(__name__)

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()

        refresh = RefreshToken.for_user(user)
        return Response({
            'user': UserSerializer(user).data,
            'refresh': str(refresh),
            'access': str(refresh.access_token),
        }, status=status.HTTP_201_CREATED)

class LoginView(APIView):
    permission_classes = [permissions.AllowAny]
    
    def post(self, request):
        email = request.data.get('email')
        password = request.data.get('password')
        user = authenticate(request, username=email, password=password)
        
        if user is not None:
            refresh = RefreshToken.for_user(user)
            return Response({
                'user': UserSerializer(user).data,
                'refresh': str(refresh),
                'access': str(refresh.access_token),
            })
        return Response({'error': 'Invalid credentials'}, status=status.HTTP_401_UNAUTHORIZED)

class ProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_object(self):
        return self.request.user

class PublicProfileView(generics.RetrieveAPIView):
    """A member's public profile, for the community feed.

    Exposes community stats and no private email address, so any user (or
    guest) can view another member's profile page.
    """

    queryset = User.objects.all()
    serializer_class = PublicProfileSerializer
    permission_classes = [permissions.AllowAny]
    lookup_url_kwarg = 'user_id'

class DeleteAccountView(APIView):
    """Deletes the caller's account.

    Removes the Django user (favorites, reviews, submissions and push-device
    tokens follow via CASCADE) and, when the request carried a Firebase ID
    token, best-effort deletes the matching Firebase Auth account so the user
    can't simply sign back in and get a freshly auto-created profile.
    """

    permission_classes = [permissions.IsAuthenticated]

    def delete(self, request):
        user = request.user
        if user.is_staff or user.is_superuser:
            return Response(
                {'error': 'Staff accounts cannot be deleted via the API.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # request.auth is the raw Bearer token for Firebase-authenticated
        # requests (the web/JWT path uses non-string tokens, in which case
        # there is no Firebase account to clean up).
        token = request.auth if isinstance(request.auth, str) else None
        uid = firebase_uid_from_token(token) if token else None
        delete_firebase_user(uid)

        email = user.email
        user.delete()
        logger.info('Deleted account for %s', email)
        return Response(status=status.HTTP_204_NO_CONTENT)


class ProfilePictureUploadView(APIView):
    """Uploads (or removes) the caller's profile picture.

    POST with a multipart ``image`` field (JPEG/PNG/GIF only) stores the file in
    media storage and points the user's ``profile_picture`` at the resulting
    absolute URL. DELETE clears the picture. Both return the updated profile.
    """

    permission_classes = [permissions.IsAuthenticated]

    ALLOWED_CONTENT_TYPES = {'image/jpeg', 'image/png', 'image/gif'}
    ALLOWED_FORMATS = {'JPEG', 'PNG', 'GIF'}

    def _validate_image(self, image):
        content_type = getattr(image, 'content_type', '')
        if content_type and content_type not in self.ALLOWED_CONTENT_TYPES:
            return (
                f'Unsupported image format "{content_type}". '
                'Only JPEG, PNG, and GIF images are allowed.'
            ), None
        try:
            image.seek(0)
            with Image.open(image) as img:
                fmt = img.format
            image.seek(0)
        except Exception:
            return (
                'The uploaded file is not a valid image. '
                'Only JPEG, PNG, and GIF images are allowed.'
            ), None
        if fmt not in self.ALLOWED_FORMATS:
            return (
                f'Unsupported image format "{fmt}". '
                'Only JPEG, PNG, and GIF images are allowed.'
            ), None
        return None, fmt

    def post(self, request):
        user = request.user
        image = request.FILES.get('image')
        if image is None:
            return Response(
                {'error': 'No image provided.'}, status=status.HTTP_400_BAD_REQUEST
            )

        error, fmt = self._validate_image(image)
        if error:
            return Response({'error': error}, status=status.HTTP_400_BAD_REQUEST)

        ext = {'JPEG': 'jpg', 'PNG': 'png', 'GIF': 'gif'}.get(fmt, 'jpg')
        filename = f'profile_pictures/{uuid.uuid4().hex}.{ext}'
        try:
            saved_name = default_storage.save(filename, image)
            url = default_storage.url(saved_name)
            absolute_url = (
                url if url.startswith('http') else request.build_absolute_uri(url)
            )
        except Exception as exc:
            logger.error('Profile picture upload failed: %s', exc)
            return Response(
                {'error': 'Could not save the image. Please try again.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        user.profile_picture = absolute_url
        user.save(update_fields=['profile_picture', 'updated_at'])
        return Response(UserSerializer(user).data, status=status.HTTP_200_OK)

    def delete(self, request):
        user = request.user
        user.profile_picture = None
        user.save(update_fields=['profile_picture', 'updated_at'])
        return Response(UserSerializer(user).data, status=status.HTTP_200_OK)


class ChangePasswordView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        user = request.user
        old_password = request.data.get('old_password')
        new_password = request.data.get('new_password')
        
        if not user.check_password(old_password):
            return Response({'error': 'Current password is incorrect'}, status=status.HTTP_400_BAD_REQUEST)
        
        if len(new_password) < 6:
            return Response({'error': 'Password must be at least 6 characters'}, status=status.HTTP_400_BAD_REQUEST)
        
        user.set_password(new_password)
        user.save()
        
        refresh = RefreshToken.for_user(user)
        return Response({
            'message': 'Password changed successfully',
            'refresh': str(refresh),
            'access': str(refresh.access_token),
        })
