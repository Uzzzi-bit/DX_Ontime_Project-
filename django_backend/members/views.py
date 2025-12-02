# django_backend/members/views.py
import json
import traceback

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.utils.dateparse import parse_datetime, parse_date

from .models import Member, MemberPregnancy


# ✅ 헬스 체크용 루트 뷰 (127.0.0.1:8000)
def root(request):
    return JsonResponse({"message": "DX Django backend is running 🚀"})


@csrf_exempt
def register_member(request):
    """
    POST /api/member/register/
    body: { "uid": "firebase-uid", "email": "user@example.com" }
    """
    if request.method != 'POST':
        return JsonResponse({'error': 'POST only'}, status=405)

    try:
        raw = request.body.decode('utf-8')
        print('>>> register_member raw body:', raw)
        body = json.loads(raw)
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON'}, status=400)

    uid = body.get('uid')
    email = body.get('email')  # 🔥 추가

    if not uid:
        return JsonResponse({'error': 'uid is required'}, status=400)

    try:
        print(f'>>> register_member uid = {uid}, email = {email}')

        # 1) 이미 firebase_uid 로 등록된 멤버가 있으면 그대로 사용
        try:
            member = Member.objects.get(firebase_uid=uid)
            created = False
            # 이메일이 비어 있거나, 바뀌었으면 업데이트
            if email and member.email != email:
                member.email = email
                member.save(update_fields=['email'])
        except Member.DoesNotExist:
            # 2) 새 멤버라면 email 이 필수
            if not email:
                return JsonResponse(
                    {'error': 'email is required for new member'},
                    status=400,
                )
            # email 은 UNIQUE 이므로 email 기준으로 get_or_create
            # nickname은 이메일의 @ 앞부분을 기본값으로 사용
            nickname = email.split('@')[0] if email else 'User'
            member, created = Member.objects.get_or_create(
                email=email,
                defaults={
                    'firebase_uid': uid,
                    'is_pregnant_mode': False,
                    'nickname': nickname,
                },
            )

        return JsonResponse({
            'ok': True,
            'created': created,
            'uid': member.firebase_uid,
            'email': member.email,
            'is_pregnant_mode': member.is_pregnant_mode,
        })
    except Exception as e:
        print('>>> register_member DB error:', e)
        traceback.print_exc()
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
      "memberId": "firebase-uid-123",   <- Firebase UID (문자열)
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

    # 클라이언트의 memberId = Firebase UID
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

    # datetime이면 date만 추출
    if hasattr(due_dt, 'date'):
        due_dt = due_dt.date()

    allergy_str = ','.join(allergies_list) if allergies_list else ''

    try:
        # ✅ firebase_uid로 Member 찾기
        member = Member.objects.get(firebase_uid=member_uid)

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
        traceback.print_exc()
        return JsonResponse(
            {'error': 'Server error in save_health_info', 'detail': str(e)},
            status=500,
        )


def get_health_info(request, uid):
    """
    건강 정보 조회
    GET /api/health/<uid>/

    여기서 uid = Firebase UID (문자열)
    """
    try:
        # ✅ firebase_uid 기준으로 조회
        member = Member.objects.get(firebase_uid=uid)
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
        'memberId': member.firebase_uid,
        'birthYear': preg.birth_year,
        'heightCm': preg.height_cm,
        'weightKg': preg.weight_kg,
        'dueDate': preg.due_date.isoformat(),
        'pregWeek': preg.preg_week,
        'hasGestationalDiabetes': preg.gestational_diabetes,
        'allergies': allergies_list,
    }

    return JsonResponse(data)


@csrf_exempt
def update_pregnant_mode(request):
    """
    임신 모드 업데이트
    POST /api/member/pregnant-mode/
    body: { "uid": "firebase-uid", "is_pregnant_mode": true }
    """
    if request.method != 'POST':
        return JsonResponse({'error': 'POST only'}, status=405)

    try:
        body = json.loads(request.body.decode('utf-8'))
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON'}, status=400)

    uid = body.get('uid')
    is_pregnant_mode = body.get('is_pregnant_mode')

    if not uid:
        return JsonResponse({'error': 'uid is required'}, status=400)

    if is_pregnant_mode is None:
        return JsonResponse({'error': 'is_pregnant_mode is required'}, status=400)

    try:
        member = Member.objects.get(firebase_uid=uid)
        member.is_pregnant_mode = bool(is_pregnant_mode)
        member.save(update_fields=['is_pregnant_mode'])
        
        return JsonResponse({
            'ok': True,
            'uid': member.firebase_uid,
            'is_pregnant_mode': member.is_pregnant_mode,
        })
    except Member.DoesNotExist:
        return JsonResponse({'error': 'member not found'}, status=404)
    except Exception as e:
        print('>>> update_pregnant_mode error:', e)
        traceback.print_exc()
        return JsonResponse(
            {'error': 'Server error in update_pregnant_mode', 'detail': str(e)},
            status=500,
        )