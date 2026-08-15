from django.db import models
from users.models import User
from recipes.models import Recipe


class Post(models.Model):
    """A photo of a cooked dish shared on the community feed.

    Posts are immediately visible to everyone. Optional link to the Recipe
    that was cooked so viewers can jump to the original dish.
    """

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='community_posts')
    image = models.ImageField(upload_to='community/', blank=True, null=True)
    image_url = models.URLField(blank=True, null=True)
    caption = models.TextField(blank=True, max_length=2000)
    recipe = models.ForeignKey(
        Recipe, on_delete=models.SET_NULL, null=True, blank=True, related_name='community_posts'
    )
    is_flagged = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.username} - {self.caption[:40] or 'photo'}"


class PostLike(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='community_likes')
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name='likes')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ['user', 'post']
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.username} liked post {self.post_id}"


class PostComment(models.Model):
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name='comments')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='community_comments')
    comment = models.TextField(max_length=1000)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['created_at']

    def __str__(self):
        return f"{self.user.username}: {self.comment[:40]}"
