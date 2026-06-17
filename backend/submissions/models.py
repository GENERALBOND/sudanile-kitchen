from django.db import models
from users.models import User

class RecipeSubmission(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    ]
    
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='submissions')
    title = models.CharField(max_length=200)
    description = models.TextField()
    ingredients = models.JSONField()
    instructions = models.JSONField()
    cultural_info = models.TextField(blank=True)
    prep_hours = models.IntegerField(default=0, help_text="Preparation hours")
    prep_minutes = models.IntegerField(default=0, help_text="Preparation minutes")
    prep_seconds = models.IntegerField(default=0, help_text="Preparation seconds")
    cook_hours = models.IntegerField(default=0, help_text="Cooking hours")
    cook_minutes = models.IntegerField(default=0, help_text="Cooking minutes")
    cook_seconds = models.IntegerField(default=0, help_text="Cooking seconds")
    servings = models.IntegerField(default=4)
    difficulty = models.CharField(max_length=20, default='medium')
    image_url = models.URLField(blank=True, null=True)
    video_url = models.URLField(blank=True, null=True)
    category_name = models.CharField(max_length=100)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='pending')
    admin_notes = models.TextField(blank=True)
    submitted_at = models.DateTimeField(auto_now_add=True)
    reviewed_at = models.DateTimeField(null=True, blank=True)
    
    def __str__(self):
        return f"{self.title} - {self.user.email} - {self.status}"
    
    class Meta:
        ordering = ['-submitted_at']
