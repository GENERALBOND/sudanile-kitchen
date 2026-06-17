from rest_framework import status, generics, permissions
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import authenticate
from django.core.mail import send_mail
from django.conf import settings
from django.contrib.auth.tokens import default_token_generator
from django.utils.http import urlsafe_base64_encode, urlsafe_base64_decode
from django.utils.encoding import force_bytes, force_str
from django.utils import timezone
from django.template.loader import render_to_string
from django.utils.html import strip_tags
import secrets
from .models import User
from .serializers import UserSerializer, RegisterSerializer, ChangePasswordSerializer

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]
    
    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        
        # Generate email verification token
        token = default_token_generator.make_token(user)
        uid = urlsafe_base64_encode(force_bytes(user.pk))
        user.email_verification_token = token
        user.email_verification_sent_at = timezone.now()
        user.save()
        
        # Send verification email
        verification_link = f"http://localhost:8000/api/users/verify-email/{uid}/{token}/"
        
        html_message = f'''
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
                .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
                .header {{ background-color: #FF9800; color: white; padding: 20px; text-align: center; }}
                .content {{ padding: 20px; background-color: #f9f9f9; }}
                .button {{ display: inline-block; padding: 12px 24px; background-color: #FF9800; color: white; text-decoration: none; border-radius: 5px; margin: 20px 0; }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🍽️ Sudanile Kitchen</h1>
                </div>
                <div class="content">
                    <h2>Welcome {user.username}!</h2>
                    <p>Thank you for registering with Sudanile Kitchen. Please verify your email address to start exploring South Sudanese cuisine.</p>
                    <p>Click the button below to verify your email:</p>
                    <div style="text-align: center;">
                        <a href="{verification_link}" class="button">Verify Email</a>
                    </div>
                    <p>Or copy this link into your browser:</p>
                    <p style="word-break: break-all;"><small>{verification_link}</small></p>
                    <p>This link will expire in 24 hours.</p>
                    <p>If you didn't create this account, please ignore this email.</p>
                </div>
            </div>
        </body>
        </html>
        '''
        
        plain_message = strip_tags(html_message)
        
        try:
            send_mail(
                subject='Verify Your Email - Sudanile Kitchen',
                message=plain_message,
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[user.email],
                html_message=html_message,
                fail_silently=False,
            )
        except Exception as e:
            print(f"Email send error: {e}")
        
        refresh = RefreshToken.for_user(user)
        return Response({
            'user': UserSerializer(user).data,
            'refresh': str(refresh),
            'access': str(refresh.access_token),
            'message': 'Please check your email to verify your account.'
        }, status=status.HTTP_201_CREATED)

class VerifyEmailView(APIView):
    permission_classes = [permissions.AllowAny]
    
    def get(self, request, uidb64, token):
        try:
            uid = force_str(urlsafe_base64_decode(uidb64))
            user = User.objects.get(pk=uid)
            
            if user.is_email_verified:
                return Response({
                    'message': 'Email already verified.'
                }, status=status.HTTP_200_OK)
            
            if default_token_generator.check_token(user, token):
                user.is_email_verified = True
                user.email_verification_token = None
                user.save()
                
                return Response({
                    'message': 'Email verified successfully! You can now login.'
                }, status=status.HTTP_200_OK)
            else:
                return Response({
                    'error': 'Invalid or expired verification token.'
                }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            return Response({
                'error': 'Invalid verification link.'
            }, status=status.HTTP_400_BAD_REQUEST)

class ResendVerificationEmailView(APIView):
    permission_classes = [permissions.AllowAny]
    
    def post(self, request):
        email = request.data.get('email')
        
        try:
            user = User.objects.get(email=email)
            
            if user.is_email_verified:
                return Response({
                    'message': 'Email already verified.'
                }, status=status.HTTP_200_OK)
            
            # Check if last email was sent within 5 minutes
            if user.email_verification_sent_at:
                elapsed = timezone.now() - user.email_verification_sent_at
                if elapsed.total_seconds() < 300:  # 5 minutes
                    return Response({
                        'error': 'Please wait 5 minutes before requesting another verification email.'
                    }, status=status.HTTP_429_TOO_MANY_REQUESTS)
            
            # Generate new token
            token = default_token_generator.make_token(user)
            uid = urlsafe_base64_encode(force_bytes(user.pk))
            user.email_verification_token = token
            user.email_verification_sent_at = timezone.now()
            user.save()
            
            # Send verification email
            verification_link = f"http://localhost:8000/api/users/verify-email/{uid}/{token}/"
            
            html_message = f'''
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <style>
                    body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
                    .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
                    .header {{ background-color: #FF9800; color: white; padding: 20px; text-align: center; }}
                    .content {{ padding: 20px; background-color: #f9f9f9; }}
                    .button {{ display: inline-block; padding: 12px 24px; background-color: #FF9800; color: white; text-decoration: none; border-radius: 5px; margin: 20px 0; }}
                </style>
            </head>
            <body>
                <div class="container">
                    <div class="header">
                        <h1>🍽️ Sudanile Kitchen</h1>
                    </div>
                    <div class="content">
                        <h2>Verify Your Email</h2>
                        <p>Click the button below to verify your email address:</p>
                        <div style="text-align: center;">
                            <a href="{verification_link}" class="button">Verify Email</a>
                        </div>
                        <p>This link will expire in 24 hours.</p>
                    </div>
                </div>
            </body>
            </html>
            '''
            
            plain_message = strip_tags(html_message)
            
            send_mail(
                subject='Verify Your Email - Sudanile Kitchen',
                message=plain_message,
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[email],
                html_message=html_message,
                fail_silently=False,
            )
            
            return Response({
                'message': 'Verification email sent. Please check your inbox.'
            }, status=status.HTTP_200_OK)
            
        except User.DoesNotExist:
            return Response({
                'error': 'User with this email does not exist.'
            }, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return Response({
                'error': 'Failed to send verification email. Please try again.'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class LoginView(APIView):
    permission_classes = [permissions.AllowAny]
    
    def post(self, request):
        email = request.data.get('email')
        password = request.data.get('password')
        user = authenticate(request, username=email, password=password)
        
        if user is not None:
            # Check if email is verified
            if not user.is_email_verified:
                return Response({
                    'error': 'Please verify your email before logging in.',
                    'email_not_verified': True
                }, status=status.HTTP_401_UNAUTHORIZED)
            
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
