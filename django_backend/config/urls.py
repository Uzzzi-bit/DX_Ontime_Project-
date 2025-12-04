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
from members.ai_chat_views import (
    create_session,
    get_session,
    list_sessions,
    end_session,
    reactivate_session,
    save_message,
    get_messages,
)
from members.meal_views import analyze_meal_image, save_meal, get_daily_nutrition, get_meals

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

    # AI 채팅 세션 및 메시지 API
    path('api/ai-chat/sessions/', create_session, name='ai-chat-create-session'),
    path('api/ai-chat/sessions/<int:session_id>/', get_session, name='ai-chat-get-session'),
    path('api/ai-chat/sessions/<str:member_id>/list/', list_sessions, name='ai-chat-list-sessions'),
    path('api/ai-chat/sessions/<int:session_id>/end/', end_session, name='ai-chat-end-session'),
    path('api/ai-chat/sessions/<int:session_id>/reactivate/', reactivate_session, name='ai-chat-reactivate-session'),
    path('api/ai-chat/messages/', save_message, name='ai-chat-save-message'),
    path('api/ai-chat/sessions/<int:session_id>/messages/', get_messages, name='ai-chat-get-messages'),
    
    # 식사 기록 API
    path('api/meals/analyze/', analyze_meal_image, name='meal-analyze'),
    path('api/meals/', save_meal, name='meal-save'),
    path('api/meals/<str:member_id>/<str:date_str>/', get_meals, name='meal-list'),
    path('api/meals/daily-nutrition/<str:member_id>/<str:date_str>/', get_daily_nutrition, name='meal-daily-nutrition'),
]
