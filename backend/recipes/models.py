from django.db import models
from users.models import User

class Category(models.Model):
    name = models.CharField(max_length=100, unique=True)
    description = models.TextField(blank=True)
    icon = models.URLField(blank=True, null=True)
    
    def __str__(self):
        return self.name

class Recipe(models.Model):
    DIFFICULTY_CHOICES = [
        ('easy', 'Easy'),
        ('medium', 'Medium'),
        ('hard', 'Hard'),
    ]
    
    title = models.CharField(max_length=200)
    description = models.TextField()
    ingredients = models.JSONField()
    instructions = models.JSONField()
    cultural_info = models.TextField(blank=True)
    
    # Preparation time with hours, minutes, seconds
    prep_hours = models.IntegerField(default=0, help_text="Preparation hours")
    prep_minutes = models.IntegerField(default=0, help_text="Preparation minutes")
    prep_seconds = models.IntegerField(default=0, help_text="Preparation seconds")
    
    # Cooking time with hours, minutes, seconds
    cook_hours = models.IntegerField(default=0, help_text="Cooking hours")
    cook_minutes = models.IntegerField(default=0, help_text="Cooking minutes")
    cook_seconds = models.IntegerField(default=0, help_text="Cooking seconds")
    
    servings = models.IntegerField(default=4)
    difficulty = models.CharField(max_length=20, choices=DIFFICULTY_CHOICES, default='medium')
    image_url = models.URLField(blank=True, null=True)
    video_url = models.URLField(blank=True, null=True)
    category = models.ForeignKey(Category, on_delete=models.SET_NULL, null=True, related_name='recipes')
    author = models.ForeignKey(User, on_delete=models.CASCADE, related_name='recipes')
    average_rating = models.FloatField(default=0)
    total_reviews = models.IntegerField(default=0)
    view_count = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_published = models.BooleanField(default=True)
    
    @property
    def preparation_time_seconds(self):
        return (self.prep_hours * 3600) + (self.prep_minutes * 60) + self.prep_seconds
    
    @property
    def cooking_time_seconds(self):
        return (self.cook_hours * 3600) + (self.cook_minutes * 60) + self.cook_seconds
    
    @property
    def total_time_seconds(self):
        return self.preparation_time_seconds + self.cooking_time_seconds
    
    @property
    def preparation_time_display(self):
        parts = []
        if self.prep_hours > 0:
            parts.append(f"{self.prep_hours} hr{'s' if self.prep_hours > 1 else ''}")
        if self.prep_minutes > 0:
            parts.append(f"{self.prep_minutes} min{'s' if self.prep_minutes > 1 else ''}")
        if self.prep_seconds > 0:
            parts.append(f"{self.prep_seconds} sec{'s' if self.prep_seconds > 1 else ''}")
        return " ".join(parts) if parts else "0 mins"
    
    @property
    def cooking_time_display(self):
        parts = []
        if self.cook_hours > 0:
            parts.append(f"{self.cook_hours} hr{'s' if self.cook_hours > 1 else ''}")
        if self.cook_minutes > 0:
            parts.append(f"{self.cook_minutes} min{'s' if self.cook_minutes > 1 else ''}")
        if self.cook_seconds > 0:
            parts.append(f"{self.cook_seconds} sec{'s' if self.cook_seconds > 1 else ''}")
        return " ".join(parts) if parts else "0 mins"
    
    @property
    def preparation_time_minutes(self):
        return self.preparation_time_seconds // 60
    
    @property
    def cooking_time_minutes(self):
        return self.cooking_time_seconds // 60
    
    def __str__(self):
        return self.title
    
    class Meta:
        ordering = ['-created_at']
