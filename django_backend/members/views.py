# django_backend/members/views.py
import json
from datetime import date

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.utils.dateparse import parse_datetime, parse_date

from .models import Member, MemberPregnancy


# ✅ 헬스 체크용 루트 뷰 (127.0.0.1:8000 에서 보이던 그거)
def root(request):
    return JsonResponse({"message": "DX Django backend is running 🚀"})


@csrf_exempt
def register_member(request):
    """
    회원 기본 정보 저장 (회원가입 첫 단계)
    POST /api/member/register/

    body 예시 :
    {
      "uid": "firebase-uid-123",
      "email": "test@example.com",
      "nickname": "테스트맘",
      "phone": "010-0000-0000",
      "address": "서울시 어딘가",
      "is_pregnant_mode": true
    }
    """
    if request.method != 'POST':
        return JsonResponse({'error': 'POST only'}, status=405)

    try:
        body = json.loads(request.body.decode())
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON'}, status=400)

    uid = body.get('uid')
    email = body.get('email')
    nickname = body.get('nickname') or ''
    phone = body.get('phone') or ''
    address = body.get('address') or ''
    is_pregnant_mode = body.get('is_pregnant_mode', False)

    if not uid:
        return JsonResponse({'error': 'uid is required'}, status=400)

    try:
        # ✅ PK = uid 기준으로 upsert
        member, created = Member.objects.update_or_create(
            uid=uid,
            defaults={
                'email': email,
                'nickname': nickname,
                'phone': phone,
                'address': address,
                'is_pregnant_mode': bool(is_pregnant_mode),
            },
        )

        return JsonResponse(
            {
                'ok': True,
                'created': created,
                'uid': member.uid,
                'email': member.email,
                'nickname': member.nickname,
            }
        )

    except Exception as e:
        return JsonResponse(
            {'error': 'Server error in register_member', 'detail': str(e)},
            status=500,
        )


@csrf_exempt
def save_health_info(request):
    """
    건강 정보 저장
    POST /api/health/

    body 예시 :
    {
      "memberId": "firebase-uid-123",
      "birthYear": 1993,
      "heightCm": 162,
      "weightKg": 60,
      "dueDate": "2025-10-01",
      "pregWeek": 20,
      "hasGestationalDiabetes": true,
      "allergies": ["우유", "땅콩"]
    }
    """
    if request.method != 'POST':
        return JsonResponse({'error': 'POST only'}, status=405)

    try:
        body = json.loads(request.body.decode())
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON'}, status=400)

    member_uid = body.get('memberId')
    birth_year = body.get('birthYear')
    height_cm = body.get('heightCm')
    weight_kg = body.get('weightKg')
    due_date_str = body.get('dueDate')
    preg_week = body.get('pregWeek')
    has_gdm = body.get('hasGestationalDiabetes', False)
    allergies_list = body.get('allergies', [])

    if not (member_uid and birth_year and height_cm and weight_kg and due_date_str and preg_week):
        return JsonResponse({'error': '필수 필드 누락'}, status=400)

    due_dt = parse_datetime(due_date_str) or parse_date(due_date_str)
    if due_dt is None:
        return JsonResponse({'error': 'dueDate 형식 오류'}, status=400)

    if hasattr(due_dt, 'date'):
        due_dt = due_dt.date()

    allergy_str = ','.join(allergies_list) if allergies_list else ''

    try:
        member = Member.objects.get(uid=member_uid)

        preg, created = MemberPregnancy.objects.update_or_create(
            member=member,
            defaults={
                'birth_year': int(birth_year),
                'height_cm': float(height_cm),
                'weight_kg': float(weight_kg),
                'due_date': due_dt,
                'preg_week': int(preg_week),
                'gestational_diabetes': bool(has_gdm),
                'allergies': allergy_str,
            },
        )

        return JsonResponse({'ok': True, 'created': created})

    except Member.DoesNotExist:
        return JsonResponse({'error': 'member not found'}, status=404)
    except Exception as e:
        return JsonResponse(
            {'error': 'Server error in save_health_info', 'detail': str(e)},
            status=500,
        )


def get_health_info(request, uid):
    """
    건강 정보 조회
    GET /api/health/<uid>/
    """
    try:
        member = Member.objects.get(uid=uid)
    except Member.DoesNotExist:
        return JsonResponse({'error': 'member not found'}, status=404)

    try:
        preg = member.pregnancy
    except MemberPregnancy.DoesNotExist:
        return JsonResponse({'error': 'pregnancy not found'}, status=404)

    allergies_list = []
    if preg.allergies:
        allergies_list = [s.strip() for s in preg.allergies.split(',') if s.strip()]

    data = {
        'memberId': member.uid,
        'birthYear': preg.birth_year,
        'heightCm': preg.height_cm,
        'weightKg': preg.weight_kg,
        'dueDate': preg.due_date.isoformat(),
        'pregWeek': preg.preg_week,
        'hasGestationalDiabetes': preg.gestational_diabetes,
        'allergies': allergies_list,
    }

    return JsonResponse(data)
