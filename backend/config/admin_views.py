from django.contrib import admin, messages
from django.contrib.admin.views.decorators import staff_member_required
from django.contrib.auth.decorators import login_required
from django.core.paginator import Paginator
from django.db.models import Q
from django.shortcuts import redirect, render

@login_required
@staff_member_required
def dashboard(request):
    from recipes.models import Recipe
    from users.models import User
    from submissions.models import RecipeSubmission
    from reviews.models import Review
    from favorites.models import Favorite
    from moderation.models import Report
    
    context = {
        'total_recipes': Recipe.objects.count(),
        'total_users': User.objects.count(),
        'pending_submissions': RecipeSubmission.objects.filter(status='pending').count(),
        'total_reviews': Review.objects.count(),
        'total_favorites': Favorite.objects.count(),
        'pending_reports': Report.objects.filter(status__in=['pending', 'auto_hidden']).count(),
        'user_email': request.user.email,
        'pending_submissions_list': RecipeSubmission.objects.filter(status='pending').order_by('-submitted_at')[:5],
        'recent_actions': [],
    }
    return render(request, 'admin/dashboard.html', context)


@login_required
@staff_member_required
def auth_index(request):
    from django.contrib.auth.models import Group
    from users.models import User

    context = {
        'user_email': request.user.email,
        'total_users': User.objects.count(),
        'total_groups': Group.objects.count(),
        'active_sessions': 0,
        'pending_password_resets': 0,
        'groups': Group.objects.all().order_by('name'),
    }
    return render(request, 'admin/authentication/index.html', context)


REPORT_STATUS_FILTERS = {
    'active': ['pending', 'auto_hidden'],
    'pending': ['pending'],
    'auto_hidden': ['auto_hidden'],
    'resolved': ['resolved'],
    'dismissed': ['dismissed'],
    'all': None,
}

MODERATION_ACTIONS = ('dismiss_reports', 'hide_content', 'delete_content', 'warn_author', 'ban_user')


@login_required
@staff_member_required
def reports_index(request):
    from moderation.models import Report
    from moderation.admin import ReportAdmin

    counts = {
        'pending': Report.objects.filter(status='pending').count(),
        'auto_hidden': Report.objects.filter(status='auto_hidden').count(),
        'resolved': Report.objects.filter(status='resolved').count(),
        'dismissed': Report.objects.filter(status='dismissed').count(),
        'active': Report.objects.filter(status__in=['pending', 'auto_hidden']).count(),
        'total': Report.objects.count(),
    }

    if request.method == 'POST':
        action = request.POST.get('action', '')
        ids = request.POST.getlist('report_ids')
        if action in MODERATION_ACTIONS and ids:
            report_admin = ReportAdmin(Report, admin.site)
            getattr(report_admin, action)(request, Report.objects.filter(pk__in=ids))
        elif not action:
            messages.warning(request, 'Choose a moderation action from the dropdown.')
        else:
            messages.error(request, f'Unknown moderation action: {action}')
        return redirect('admin_reports')

    status = request.GET.get('status', 'active')
    if status not in REPORT_STATUS_FILTERS:
        status = 'active'
    q = request.GET.get('q', '').strip()

    queryset = Report.objects.select_related('reporter', 'post', 'comment', 'post__user', 'comment__user')
    filter_values = REPORT_STATUS_FILTERS[status]
    if filter_values is not None:
        queryset = queryset.filter(status__in=filter_values)
    if q:
        queryset = queryset.filter(
            Q(content_snapshot__icontains=q)
            | Q(reporter__email__icontains=q)
            | Q(reporter__username__icontains=q)
        )
    queryset = queryset.order_by('-created_at')

    paginator = Paginator(queryset, 20)
    page_obj = paginator.get_page(request.GET.get('page'))

    context = {
        'user_email': request.user.email,
        'counts': counts,
        'status': status,
        'q': q,
        'page_obj': page_obj,
        'reports': page_obj.object_list,
    }
    return render(request, 'admin/moderation/reports.html', context)
