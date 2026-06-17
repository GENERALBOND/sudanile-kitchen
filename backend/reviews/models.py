from django.db import models
from users.models import User
from recipes.models import Recipe

class Review(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='reviews')
    recipe = models.ForeignKey(Recipe, on_delete=models.CASCADE, related_name='reviews')
    rating = models.IntegerField(choices=[(i, i) for i in range(1, 6)])
    comment = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        unique_together = ['user', 'recipe']
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.user.email} - {self.recipe.title} - {self.rating}⭐"
    
    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)
        # Update recipe average rating
        from django.db.models import Avg
        avg = Review.objects.filter(recipe=self.recipe).aggregate(Avg('rating'))['rating__avg']
        self.recipe.average_rating = round(avg or 0, 1)
        self.recipe.total_reviews = Review.objects.filter(recipe=self.recipe).count()
        self.recipe.save()