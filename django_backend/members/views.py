# django_backend/members/views.py
import json
import traceback

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.utils.dateparse import parse_datetime, parse_date

from .models import Member, MemberPregnancy, FamilyRelation, Image
from django.utils import timezone


# ✅ 헬스 체크용 루트 뷰 (127.0.0.1:8000)
def root(request):
    return JsonResponse({"message": "DX Django backend is running 🚀"})


@csrf_exempt
def register_member(request):
    """
    POST /api/member/register/
    body: { "uid": "firebase-uid", "email": "user@example.com", "nickname": "닉네임" }
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
    email = body.get('email')
    nickname = body.get('nickname')  # 사용자가 입력한 닉네임

    if not uid:
        return JsonResponse({'error': 'uid is required'}, status=400)

    try:
        print(f'>>> register_member uid = {uid}, email = {email}, nickname = {nickname}')

        # 1) 이미 firebase_uid 로 등록된 멤버가 있으면 그대로 사용
        try:
            member = Member.objects.get(firebase_uid=uid)
            created = False
            # 이메일이 비어 있거나, 바뀌었으면 업데이트
            if email and member.email != email:
                member.email = email
                member.save(update_fields=['email'])
            # 닉네임이 제공되었고, 기존 닉네임과 다르면 업데이트
            if nickname and member.nickname != nickname:
                member.nickname = nickname
                member.save(update_fields=['nickname'])
        except Member.DoesNotExist:
            # 2) 새 멤버라면 email 이 필수
            if not email:
                return JsonResponse(
                    {'error': 'email is required for new member'},
                    status=400,
                )
            # nickname이 제공되지 않으면 이메일의 @ 앞부분을 기본값으로 사용 (기존 로직 유지)
            final_nickname = nickname if nickname else (email.split('@')[0] if email else 'User')
            
            # email 은 UNIQUE 이므로 email 기준으로 get_or_create
            member, created = Member.objects.get_or_create(
                email=email,
                defaults={
                    'firebase_uid': uid,
                    'is_pregnant_mode': False,
                    'nickname': final_nickname,
                },
            )
            # get_or_create로 기존 멤버를 가져온 경우 nickname 업데이트
            if not created and nickname and member.nickname != nickname:
                member.nickname = nickname
                member.save(update_fields=['nickname'])

        return JsonResponse({
            'ok': True,
            'created': created,
            'uid': member.firebase_uid,
            'email': member.email,
            'nickname': member.nickname,
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
    
    역할 전환 로직:
    - is_pregnant_mode = False -> True: 보호자에서 임산부로 전환
      * 기존에 이 사용자가 guardian_member_id로 있던 관계들은 삭제
      * 이제 이 사용자는 member_id로 사용 가능
    - is_pregnant_mode = True -> False: 임산부에서 보호자로 전환
      * 기존에 이 사용자가 member_id로 있던 관계들은 삭제
      * 이제 이 사용자는 guardian_member_id로 사용 가능
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
        old_mode = member.is_pregnant_mode
        new_mode = bool(is_pregnant_mode)
        
        # 모드가 실제로 변경되는 경우에만 관계 데이터 정리
        if old_mode != new_mode:
            if new_mode:
                # 보호자 -> 임산부 전환
                # 이 사용자가 guardian_member_id로 있던 모든 관계 삭제
                deleted_as_guardian = FamilyRelation.objects.filter(
                    guardian_member_id=uid
                ).delete()[0]
                print(f'>>> {uid}: 보호자 -> 임산부 전환, {deleted_as_guardian}개 보호자 관계 삭제')
            else:
                # 임산부 -> 보호자 전환
                # 이 사용자가 member_id로 있던 모든 관계 삭제
                deleted_as_member = FamilyRelation.objects.filter(
                    member_id=uid
                ).delete()[0]
                print(f'>>> {uid}: 임산부 -> 보호자 전환, {deleted_as_member}개 임산부 관계 삭제')
        
        member.is_pregnant_mode = new_mode
        member.save(update_fields=['is_pregnant_mode'])
        
        return JsonResponse({
            'ok': True,
            'uid': member.firebase_uid,
            'is_pregnant_mode': member.is_pregnant_mode,
            'role': '임산부' if new_mode else '보호자',
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


@csrf_exempt
def update_family_members(request):
    """
    가족 구성원 업데이트 (전체 동기화)
    POST /api/family/update/

    body 예시:
    {
      "member_id": "firebase-uid-123",  // 임산부의 Firebase UID
      "relation_types": ["배우자", "부모님"]  // 선택된 relation_type 목록
    }
    
    동작:
    1. DB에서 해당 member_id의 모든 관계 조회
    2. 선택된 relation_type만 유지하고, 나머지는 삭제
    3. 선택된 relation_type 중 DB에 없는 것은 추가 (guardian_member_id는 임시로 relation_type 사용)
    """
    print(f'>>> update_family_members 호출됨: method={request.method}, path={request.path}')
    
    if request.method != 'POST':
        return JsonResponse({'error': 'POST only'}, status=405)

    try:
        body = json.loads(request.body.decode())
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON'}, status=400)

    member_id = body.get('member_id')  # 임산부의 Firebase UID
    relation_types = body.get('relation_types', [])  # 선택된 relation_type 목록

    if not member_id:
        return JsonResponse({'error': 'member_id is required'}, status=400)

    if not isinstance(relation_types, list):
        return JsonResponse({'error': 'relation_types must be a list'}, status=400)

    try:
        # 임산부가 Member에 등록되어 있는지 확인
        try:
            member = Member.objects.get(firebase_uid=member_id)
        except Member.DoesNotExist:
            return JsonResponse({'error': 'member not found'}, status=404)

        # 1. 기존 관계 조회
        existing_relations = FamilyRelation.objects.filter(member_id=member_id)
        existing_relation_types = set(existing_relations.values_list('relation_type', flat=True))
        selected_relation_types = set(relation_types)

        # 2. 삭제할 관계 (기존에 있지만 선택되지 않은 것)
        to_delete = existing_relation_types - selected_relation_types
        deleted_count = 0
        if to_delete:
            deleted_count = FamilyRelation.objects.filter(
                member_id=member_id,
                relation_type__in=to_delete
            ).delete()[0]

        # 3. 추가할 관계 (선택되었지만 기존에 없는 것)
        to_add = selected_relation_types - existing_relation_types
        created_count = 0
        for relation_type in to_add:
            # guardian_member_id는 임시로 relation_type을 사용
            # 실제로는 보호자의 Firebase UID를 받아야 하지만, 현재는 임시 처리
            FamilyRelation.objects.create(
                member_id=member_id,
                guardian_member_id=relation_type,  # 임시: 실제로는 보호자 UID
                relation_type=relation_type,
            )
            created_count += 1

        return JsonResponse({
            'ok': True,
            'created_count': created_count,
            'deleted_count': deleted_count,
            'total_selected': len(relation_types),
        })

    except Exception as e:
        traceback.print_exc()
        return JsonResponse(
            {'error': 'Server error in update_family_members', 'detail': str(e)},
            status=500,
        )


def get_family_members(request, member_id):
    """
    가족 구성원 조회
    GET /api/family/<member_id>/

    member_id: 임산부의 Firebase UID
    """
    try:
        relations = FamilyRelation.objects.filter(member_id=member_id).order_by('-created_at')
        
        guardians = []
        for relation in relations:
            guardians.append({
                'guardian_member_id': relation.guardian_member_id,
                'relation_type': relation.relation_type,
                'created_at': relation.created_at.isoformat(),
            })

        return JsonResponse({
            'ok': True,
            'member_id': member_id,
            'guardians': guardians,
            'count': len(guardians),
        })

    except Exception as e:
        traceback.print_exc()
        return JsonResponse(
            {'error': 'Server error in get_family_members', 'detail': str(e)},
            status=500,
        )