# django_backend/config/urls.py
from django.contrib import admin
from django.urls import path

from members.views import (
    root,
    register_member,
    save_health_info,
    get_health_info,
    update_pregnant_mode,
)

urlpatterns = [
    path('admin/', admin.site.urls),

    path('', root, name='root'),

    path('api/member/register/', register_member, name='member-register'),
    path('api/member/pregnant-mode/', update_pregnant_mode, name='member-pregnant-mode'),

    path('api/health/', save_health_info, name='health-save'),
    path('api/health/<str:uid>/', get_health_info, name='health-get'),
]
