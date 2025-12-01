from members.views import root, db_test, MemberCreateView, MemberPregnancyView

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', root),
    path('test-db/', db_test),
    path('members/', MemberCreateView.as_view()),
    path('pregnancy/', MemberPregnancyView.as_view()),   # 🔹 임신 상태 API
]
