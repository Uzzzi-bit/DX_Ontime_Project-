# django_backend/config/urls.py
from django.contrib import admin
from django.urls import path

from members.views import (
    root,
    register_member,
    save_health_info,
    get_health_info,
    update_pregnant_mode,
    update_family_members,
    get_family_members,
    get_nutrition_target,
)
from members.image_views import save_image, update_image, get_images

urlpatterns = [
    path('admin/', admin.site.urls),

    path('', root, name='root'),

    path('api/member/register/', register_member, name='member-register'),
    path('api/member/pregnant-mode/', update_pregnant_mode, name='member-pregnant-mode'),

    path('api/health/', save_health_info, name='health-save'),
    path('api/health/<str:uid>/', get_health_info, name='health-get'),

    path('api/family/update/', update_family_members, name='family-update'),
    path('api/family/<str:member_id>/', get_family_members, name='family-get'),

    # 이미지 API: POST는 저장, GET은 조회 (같은 경로에서 메서드로 구분)
    path('api/images/', save_image, name='image-save-list'),  # POST: 저장, GET: 조회
    path('api/images/<int:image_id>/', update_image, name='image-update'),

    # 영양소 권장량 API
    path('api/nutrition-target/<int:trimester>/', get_nutrition_target, name='nutrition-target'),
]
