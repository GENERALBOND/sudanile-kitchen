from django.urls import path
from .views import (
    PushStatusView,
    RegisterDeviceTokenView,
    UnregisterDeviceTokenView,
)

urlpatterns = [
    path('status/', PushStatusView.as_view(), name='push-status'),
    path('register/', RegisterDeviceTokenView.as_view(), name='register-device-token'),
    path('unregister/', UnregisterDeviceTokenView.as_view(), name='unregister-device-token'),
]