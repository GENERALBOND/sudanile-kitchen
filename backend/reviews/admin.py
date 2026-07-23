from django.contrib import admin
from django import forms
from .models import Review


class ReviewAdminForm(forms.ModelForm):
    class Meta:
        model = Review
        fields = ('user', 'recipe', 'rating', 'comment')
        widgets = {
            'comment': forms.Textarea(attrs={'rows': 4, 'class': 'form-control', 'placeholder': 'Write the user\'s review comment here...'}),
        }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields['user'].widget.attrs.update({'class': 'form-control', 'required': True})
        self.fields['recipe'].widget.attrs.update({'class': 'form-control', 'required': True})


@admin.register(Review)
class ReviewAdmin(admin.ModelAdmin):
    form = ReviewAdminForm
    add_form_template = "admin/reviews/review/add_form.html"
    change_form_template = "admin/reviews/review/add_form.html"
    list_display = ('id', 'user', 'recipe', 'rating', 'created_at')
    list_filter = ('rating', 'created_at')
    search_fields = ('user__email', 'recipe__title', 'comment')
    readonly_fields = ('created_at', 'updated_at')

    def get_changeform_initial_data(self, request):
        return {'user': request.user}

    def save_model(self, request, obj, form, change):
        if not change and not obj.user_id:
            obj.user = request.user
        super().save_model(request, obj, form, change)
