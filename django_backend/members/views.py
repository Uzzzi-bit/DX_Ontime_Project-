# members/views.py

from django.http import JsonResponse
from django.db import connection
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_exempt

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

from .models import Member, MemberPregnancy
from .serializers import MemberSerializer, MemberPregnancySerializer


# --------------------------------------------------
# 0. 기본 루트 (/)
# --------------------------------------------------
def root(request):
    """
    서버 살아있는지 확인용 기본 엔드포인트
    GET /  ->  {"message": "DX Django backend is running 🚀"}
    """
    return JsonResponse(
        {"message": "DX Django backend is running 🚀"},
        json_dumps_params={"ensure_ascii": False},
    )


# --------------------------------------------------
# 1. DB 테스트 (/test-db/)
# --------------------------------------------------
def db_test(request):
    """
    오라클 연결 테스트용
    GET /test-db/  ->  {"ok": true, "result": 1}
    """
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1 AS num FROM dual")
            row = cursor.fetchone()
        return JsonResponse({"ok": True, "result": row[0]})
    except Exception as e:
        return JsonResponse(
            {"ok": False, "error": str(e)},
            status=500,
            json_dumps_params={"ensure_ascii": False},
        )


# --------------------------------------------------
# 2. 회원가입 API (/members/)
# --------------------------------------------------
@method_decorator(csrf_exempt, name="dispatch")
class MemberCreateView(APIView):
    """
    POST /members/

    요청 JSON 예시:
    {
      "member_id": "user01",
      "password": "1234",
      "nickname": "지은맘",
      "birth_date": "19980101",
      "phone": "01012345678",
      "address": "서울시 강남구 ...",
      "is_pregnant_mode": "Y"
    }
    """

    def post(self, request):
        data = request.data

        member_id = data.get("member_id")
        if not member_id:
            return Response(
                {"ok": False, "message": "member_id는 필수입니다."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # 1) 중복 체크
        if Member.objects.filter(member_id=member_id).exists():
            return Response(
                {"ok": False, "message": "이미 존재하는 member_id 입니다."},
                status=status.HTTP_409_CONFLICT,
            )

        serializer = MemberSerializer(data=data)
        if serializer.is_valid():
            member = serializer.save()
            return Response(
                {"ok": True, "member_id": member.member_id},
                status=status.HTTP_201_CREATED,
            )

        # 유효성 검사 실패
        return Response(
            {"ok": False, "errors": serializer.errors},
            status=status.HTTP_400_BAD_REQUEST,
        )


# --------------------------------------------------
# 3. 임산부 현재 상태 API (/pregnancy/)
#    - MEMBER_PREGNANCY 테이블용
#    - 한 회원당 1행 (OneToOne)
# --------------------------------------------------
@method_decorator(csrf_exempt, name="dispatch")
class MemberPregnancyView(APIView):
    """
    POST /pregnancy/

    요청 JSON 예시:
    {
      "member_id": "user01",
      "pregnancy_week": 12,
      "due_date": "2025-07-01",
      "weight": 60.5,
      "height": 165.0,
      "age": 32,
      "gestational_diabetes": "N",
      "allergy": "우유, 계란",
      "allergy_custom": "특이사항 없음"
    }

    - 이미 MEMBER_PREGNANCY 행이 있으면 UPDATE
    - 없으면 새로 INSERT
    """

    def post(self, request):
        data = request.data
        member_id = data.get("member_id")

        if not member_id:
            return Response(
                {"ok": False, "message": "member_id는 필수입니다."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # 1) 회원 존재 여부 확인
        try:
            member = Member.objects.get(member_id=member_id)
        except Member.DoesNotExist:
            return Response(
                {"ok": False, "message": "해당 member_id 회원이 없습니다."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # 2) 기존 임신 상태 레코드가 있는지 확인 (1:1 관계)
        try:
            pregnancy = MemberPregnancy.objects.get(member=member)
            # UPDATE 모드
            serializer = MemberPregnancySerializer(
                pregnancy, data=data, partial=True
            )
            mode = "update"
        except MemberPregnancy.DoesNotExist:
            # CREATE 모드 - member 필드는 강제로 세팅
            payload = data.copy()
            payload["member"] = member.member_id  # OneToOneField(pk=member_id)
            serializer = MemberPregnancySerializer(data=payload)
            mode = "create"

        if serializer.is_valid():
            obj = serializer.save()
            return Response(
                {
                    "ok": True,
                    "mode": mode,  # "create" or "update"
                    "member_id": obj.member.member_id,
                },
                status=status.HTTP_201_CREATED,
            )

        return Response(
            {"ok": False, "errors": serializer.errors},
            status=status.HTTP_400_BAD_REQUEST,
        )
