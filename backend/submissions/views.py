from rest_framework import generics, permissions
from .models import RecipeSubmission
from .serializers import RecipeSubmissionSerializer

class SubmissionCreateView(generics.CreateAPIView):
    serializer_class = RecipeSubmissionSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

class SubmissionListView(generics.ListAPIView):
    serializer_class = RecipeSubmissionSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        if self.request.user.role == 'admin':
            return RecipeSubmission.objects.all()
        return RecipeSubmission.objects.filter(user=self.request.user)
