from django.urls import path
from .views import RegisterDeviceTokenView, UnregisterDeviceTokenView

urlpatterns = [
    path('register/', RegisterDeviceTokenView.as_view(), name='register-device-token'),
    path('unregister/', UnregisterDeviceTokenView.as_view(), name='unregister-device-token'),
]