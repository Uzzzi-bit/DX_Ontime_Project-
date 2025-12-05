# django_backend/members/views.py
import json
import traceback

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.utils.dateparse import parse_datetime, parse_date

from .models import Member, MemberPregnancy, FamilyRelation, MemberNutritionTarget
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
    nickname = body.get('nickname')

    if not uid:
        return JsonResponse({'error': 'uid is required'}, status=400)

    try:
        print(f'>>> register_member uid = {uid}, email = {email}, nickname = {nickname}')

        # 1) 이미 firebase_uid 로 등록된 멤버가 있으면 그대로 사용
        try:
            member = Member.objects.get(firebase_uid=uid)
            created = False
            if email and member.email != email:
                member.email = email
                member.save(update_fields=['email'])
            if nickname and member.nickname != nickname:
                member.nickname = nickname
                member.save(update_fields=['nickname'])
        except Member.DoesNotExist:
            if not email:
                return JsonResponse(
                    {'error': 'email is required for new member'},
                    status=400,
                )
            final_nickname = nickname if nickname else (email.split('@')[0] if email else 'User')
            
            member, created = Member.objects.get_or_create(
                email=email,
                defaults={
                    'firebase_uid': uid,
                    'is_pregnant_mode': False,
                    'nickname': final_nickname,
                },
            )
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
    건강정보가 없어도 회원가입 시 닉네임은 반환
    """
    try:
        member = Member.objects.get(firebase_uid=uid)
    except Member.DoesNotExist:
        return JsonResponse({'error': 'member not found'}, status=404)

    # 기본 데이터 (회원가입 시 닉네임은 항상 있음)
    data = {
        'memberId': member.firebase_uid,
        'nickname': member.nickname,  # 회원가입 시 닉네임은 항상 반환
    }

    # 건강정보가 있으면 추가 정보 반환
    try:
        preg = member.pregnancy
        
        allergies_list = []
        if preg.allergies:
            allergies_list = [s.strip() for s in preg.allergies.split(',') if s.strip()]

        # DecimalField를 float로 변환 (JSON 직렬화 문제 해결)
        height_cm_float = float(preg.height_cm) if preg.height_cm is not None else None
        weight_kg_float = float(preg.weight_kg) if preg.weight_kg is not None else None
        
        # 건강정보 추가
        data.update({
            'birthYear': preg.birth_year,
            'heightCm': height_cm_float,
            'weightKg': weight_kg_float,
            'dueDate': preg.due_date.isoformat(),
            'pregWeek': preg.preg_week,
            'pregnancy_week': preg.preg_week,  # 호환성을 위해 둘 다 포함
            'hasGestationalDiabetes': preg.gestational_diabetes,
            'allergies': allergies_list,
            'conditions': '없음',  # TODO: 나중에 conditions 필드 추가 시 수정
        })
    except MemberPregnancy.DoesNotExist:
        # 건강정보가 없어도 닉네임은 반환 (회원가입은 했으므로)
        pass

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
        old_mode = member.is_pregnant_mode
        new_mode = bool(is_pregnant_mode)
        
        if old_mode != new_mode:
            if new_mode:
                deleted_as_guardian = FamilyRelation.objects.filter(
                    guardian_member_id=uid
                ).delete()[0]
                print(f'>>> {uid}: 보호자 -> 임산부 전환, {deleted_as_guardian}개 보호자 관계 삭제')
            else:
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
    """
    print(f'>>> update_family_members 호출됨: method={request.method}, path={request.path}')
    
    if request.method != 'POST':
        return JsonResponse({'error': 'POST only'}, status=405)

    try:
        body = json.loads(request.body.decode())
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON'}, status=400)

    member_id = body.get('member_id')
    relation_types = body.get('relation_types', [])

    if not member_id:
        return JsonResponse({'error': 'member_id is required'}, status=400)

    if not isinstance(relation_types, list):
        return JsonResponse({'error': 'relation_types must be a list'}, status=400)

    try:
        try:
            member = Member.objects.get(firebase_uid=member_id)
        except Member.DoesNotExist:
            return JsonResponse({'error': 'member not found'}, status=404)

        existing_relations = FamilyRelation.objects.filter(member_id=member_id)
        existing_relation_types = set(existing_relations.values_list('relation_type', flat=True))
        selected_relation_types = set(relation_types)

        to_delete = existing_relation_types - selected_relation_types
        deleted_count = 0
        if to_delete:
            deleted_count = FamilyRelation.objects.filter(
                member_id=member_id,
                relation_type__in=to_delete
            ).delete()[0]

        to_add = selected_relation_types - existing_relation_types
        created_count = 0
        for relation_type in to_add:
            FamilyRelation.objects.create(
                member_id=member_id,
                guardian_member_id=relation_type,
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


def get_nutrition_target(request, trimester):
    """
    임신 분기별 영양소 권장량 조회
    GET /api/nutrition-target/<trimester>/
    
    trimester: 1, 2, 3 (1분기, 2분기, 3분기)
    
    Response:
    {
        "trimester": 1,
        "calories": 2200,
        "carb": 260.0,
        "protein": 70.0,
        "fat": 70.0,
        "sodium": 2000.0,
        "iron": 27.0,
        "folate": 600.0,
        "calcium": 1000.0,
        "vitamin_d": 15.0,
        "omega3": 300.0,
        "sugar": 50.0,
        "magnesium": 350.0,
        "vitamin_a": 770.0,
        "vitamin_b12": 2.6,
        "vitamin_c": 85.0,
        "dietary_fiber": 28.0,
        "potassium": 2900.0
    }
    """
    try:
        trimester_int = int(trimester)
        if trimester_int not in [1, 2, 3]:
            return JsonResponse({'error': 'trimester must be 1, 2, or 3'}, status=400)
        
        # 디버그: 모델의 테이블 이름 확인
        print(f'>>> [get_nutrition_targets] 테이블 이름: {MemberNutritionTarget._meta.db_table}')
        print(f'>>> [get_nutrition_targets] trimester: {trimester_int}')
        
        target = MemberNutritionTarget.objects.get(trimester=trimester_int)
        print(f'>>> [get_nutrition_targets] 데이터 조회 성공: {target}')
        
        result = {
            'trimester': target.trimester,
            'calories': target.calories,
            'carb': float(target.carb),  # 모델 필드명은 carb, DB 컬럼명은 carbs
            'protein': float(target.protein),
            'fat': float(target.fat),
            'sodium': float(target.sodium),
            'iron': float(target.iron),
            'folate': float(target.folate),
            'calcium': float(target.calcium),
            'vitamin_d': float(target.vitamin_d),
            'omega3': float(target.omega3),
        }
        
        # 추가 영양소 필드 (null일 수 있음)
        if target.sugar is not None:
            result['sugar'] = float(target.sugar)
        if target.magnesium is not None:
            result['magnesium'] = float(target.magnesium)
        if target.vitamin_a is not None:
            result['vitamin_a'] = float(target.vitamin_a)
        if target.vitamin_b12 is not None:
            result['vitamin_b12'] = float(target.vitamin_b12)
        if target.vitamin_c is not None:
            result['vitamin_c'] = float(target.vitamin_c)
        if target.dietary_fiber is not None:
            result['dietary_fiber'] = float(target.dietary_fiber)
        if target.potassium is not None:
            result['potassium'] = float(target.potassium)
        
        return JsonResponse(result)
    except MemberNutritionTarget.DoesNotExist:
        return JsonResponse({'error': 'nutrition target not found for trimester'}, status=404)
    except ValueError:
        return JsonResponse({'error': 'invalid trimester format'}, status=400)
    except Exception as e:
        traceback.print_exc()
        return JsonResponse(
            {'error': 'Server error in get_nutrition_target', 'detail': str(e)},
            status=500,
        )

