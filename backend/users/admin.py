from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from django.contrib.auth.admin import GroupAdmin as BaseGroupAdmin
from django.contrib.auth.forms import UserCreationForm
from django.contrib.auth.models import Group, Permission
from django import forms
from .models import User

class CustomUserCreationForm(UserCreationForm):
    role = forms.ChoiceField(choices=User.ROLE_CHOICES, required=False)
    is_staff = forms.BooleanField(required=False)
    is_active = forms.BooleanField(required=False, initial=True)

    class Meta(UserCreationForm.Meta):
        model = User
        fields = ('username', 'email', 'role', 'is_staff', 'is_active')

@admin.register(User)
class CustomUserAdmin(UserAdmin):
    add_form = CustomUserCreationForm
    add_form_template = 'admin/users/user/add_form.html'

    list_display = ('email', 'username', 'role', 'is_staff', 'created_at')
    list_filter = ('role', 'is_staff', 'is_active')
    search_fields = ('email', 'username')
    ordering = ('email',)
    fieldsets = UserAdmin.fieldsets + (
        ('Additional Info', {'fields': ('role', 'profile_picture', 'bio')}),
    )
    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('username', 'email', 'password1', 'password2',
                       'role', 'is_staff', 'is_active'),
        }),
    )


class GroupAdminForm(forms.ModelForm):
    class Meta:
        model = Group
        fields = ('name', 'permissions')
        widgets = {
            'permissions': forms.SelectMultiple(attrs={'class': 'form-control', 'style': 'display:none'}),
        }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields['name'].widget.attrs.update({'class': 'form-control', 'placeholder': 'Enter group name (e.g., Editors, Moderators)'})
        self.fields['permissions'].queryset = Permission.objects.select_related('content_type').all()

    def get_chosen_perm_ids(self):
        if self.is_bound:
            return self.data.getlist('permissions')
        if self.instance.pk:
            return [str(pk) for pk in self.instance.permissions.values_list('pk', flat=True)]
        return []


class GroupAdmin(BaseGroupAdmin):
    form = GroupAdminForm
    add_form_template = 'admin/auth/group/add_form.html'
    change_form_template = 'admin/auth/group/add_form.html'

admin.site.unregister(Group)
admin.site.register(Group, GroupAdmin)
