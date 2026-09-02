from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView, TokenVerifyView
from .views import (
    RegisterView, LoginView, ProfileView, PublicProfileView, ChangePasswordView,
    DeleteAccountView, ProfilePictureUploadView,
)

urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', LoginView.as_view(), name='login'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token-refresh'),
    path('token/verify/', TokenVerifyView.as_view(), name='token-verify'),
    path('profile/', ProfileView.as_view(), name='profile'),
    path('profile/<int:user_id>/', PublicProfileView.as_view(), name='public-profile'),
    path('change-password/', ChangePasswordView.as_view(), name='change-password'),
    path('delete-account/', DeleteAccountView.as_view(), name='delete-account'),
    path('upload-profile-picture/', ProfilePictureUploadView.as_view(),
         name='upload-profile-picture'),
]
