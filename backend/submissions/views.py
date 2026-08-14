from rest_framework import generics, permissions, status
from rest_framework.response import Response
from .models import RecipeSubmission
from .serializers import RecipeSubmissionSerializer

class SubmissionCreateView(generics.CreateAPIView):
    serializer_class = RecipeSubmissionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def create(self, request, *args, **kwargs):
        title = (request.data.get('title') or '').strip()
        if title:
            existing = RecipeSubmission.objects.filter(
                user=request.user,
                title__iexact=title,
                status__in=['pending', 'approved'],
            ).exists()
            if existing:
                return Response(
                    {'detail': 'You have already submitted a recipe with this title. '
                               'It is currently under review.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
        return super().create(request, *args, **kwargs)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

class SubmissionListView(generics.ListAPIView):
    serializer_class = RecipeSubmissionSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        if self.request.user.role == 'admin':
            return RecipeSubmission.objects.all()
        return RecipeSubmission.objects.filter(user=self.request.user)
