# django_backend/members/body_measurement_views.py

import json
from datetime import datetime, date
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from .models import Member, BodyMeasurement


def parse_date(date_str):
    """날짜 문자열을 date 객체로 변환"""
    try:
        return datetime.strptime(date_str, '%Y-%m-%d').date()
    except (ValueError, TypeError):
        return None


@csrf_exempt
@require_http_methods(["POST"])
def save_body_measurement(request):
    """
    POST /api/body-measurements/
    신체 변화 측정 기록 저장
    
    Body:
    {
        "member_id": "firebase_uid",
        "measurement_date": "2024-12-08",
        "weight_kg": 65.5,  # 선택
        "blood_sugar_fasting": 95,  # 선택
        "blood_sugar_postprandial": 140,  # 선택
        "memo": "아침 측정"  # 선택
    }
    """
    try:
        body = json.loads(request.body.decode('utf-8'))
        member_id = body.get('member_id')
        measurement_date_str = body.get('measurement_date')
        
        if not member_id or not measurement_date_str:
            return JsonResponse({'error': 'member_id와 measurement_date는 필수입니다.'}, status=400)
        
        measurement_date = parse_date(measurement_date_str)
        if not measurement_date:
            return JsonResponse({'error': '날짜 형식이 올바르지 않습니다. (YYYY-MM-DD)'}, status=400)
        
        try:
            member = Member.objects.get(firebase_uid=member_id)
        except Member.DoesNotExist:
            return JsonResponse({'error': 'Member not found'}, status=404)
        
        weight_kg = body.get('weight_kg')
        blood_sugar_fasting = body.get('blood_sugar_fasting')
        blood_sugar_postprandial = body.get('blood_sugar_postprandial')
        memo = body.get('memo', '')
        
        # 최소 하나의 측정값은 있어야 함
        if weight_kg is None and blood_sugar_fasting is None and blood_sugar_postprandial is None:
            return JsonResponse({'error': '최소 하나의 측정값(체중, 공복혈당, 식후혈당)을 입력해주세요.'}, status=400)
        
        # 같은 날짜에 여러 기록을 허용하므로 항상 새로 생성
        # (메모에 아침/점심/저녁을 구분하여 저장)
        measurement = BodyMeasurement.objects.create(
            member=member,
            measurement_date=measurement_date,
            weight_kg=weight_kg,
            blood_sugar_fasting=blood_sugar_fasting,
            blood_sugar_postprandial=blood_sugar_postprandial,
            memo=memo,
        )
        
        print(f'✅ [save_body_measurement] 신체 변화 기록 생성 완료: member_id={member_id}, date={measurement_date_str}, weight={weight_kg}, fasting={blood_sugar_fasting}, postprandial={blood_sugar_postprandial}, memo={memo}')
        
        return JsonResponse({
            'success': True,
            'measurement_id': measurement.id,
            'measurement_date': measurement_date_str,
            'weight_kg': float(weight_kg) if weight_kg else None,
            'blood_sugar_fasting': blood_sugar_fasting,
            'blood_sugar_postprandial': blood_sugar_postprandial,
            'memo': memo,
        }, status=201)
        
    except Exception as e:
        import traceback
        print(f'❌ [save_body_measurement] 오류: {e}')
        traceback.print_exc()
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
@require_http_methods(["GET"])
def get_body_measurements(request, member_id: str):
    """
    GET /api/body-measurements/<member_id>/?start_date=2024-12-01&end_date=2024-12-31
    신체 변화 측정 기록 조회 (기간별)
    
    Query Parameters:
    - start_date: 시작 날짜 (YYYY-MM-DD, 선택)
    - end_date: 종료 날짜 (YYYY-MM-DD, 선택)
    """
    try:
        try:
            member = Member.objects.get(firebase_uid=member_id)
        except Member.DoesNotExist:
            return JsonResponse({'error': 'Member not found'}, status=404)
        
        # Query parameters
        start_date_str = request.GET.get('start_date')
        end_date_str = request.GET.get('end_date')
        
        # 측정 기록 조회
        measurements = BodyMeasurement.objects.filter(member=member)
        
        if start_date_str:
            start_date = parse_date(start_date_str)
            if start_date:
                measurements = measurements.filter(measurement_date__gte=start_date)
        
        if end_date_str:
            end_date = parse_date(end_date_str)
            if end_date:
                measurements = measurements.filter(measurement_date__lte=end_date)
        
        measurements = measurements.order_by('-measurement_date', '-created_at')
        
        # 결과 변환
        results = []
        for m in measurements:
            results.append({
                'measurement_id': m.id,
                'measurement_date': m.measurement_date.strftime('%Y-%m-%d'),
                'weight_kg': float(m.weight_kg) if m.weight_kg else None,
                'blood_sugar_fasting': m.blood_sugar_fasting,
                'blood_sugar_postprandial': m.blood_sugar_postprandial,
                'memo': m.memo or '',
                'created_at': m.created_at.strftime('%Y-%m-%dT%H:%M:%S'),
            })
        
        print(f'✅ [get_body_measurements] 신체 변화 기록 조회 완료: member_id={member_id}, count={len(results)}')
        
        return JsonResponse({
            'success': True,
            'member_id': member_id,
            'count': len(results),
            'measurements': results,
        })
        
    except Exception as e:
        import traceback
        print(f'❌ [get_body_measurements] 오류: {e}')
        traceback.print_exc()
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
@require_http_methods(["GET"])
def get_body_measurement_by_date(request, member_id: str, date_str: str):
    """
    GET /api/body-measurements/<member_id>/<date_str>/
    특정 날짜의 신체 변화 측정 기록 조회
    
    date_str: YYYY-MM-DD
    """
    try:
        try:
            member = Member.objects.get(firebase_uid=member_id)
        except Member.DoesNotExist:
            return JsonResponse({'error': 'Member not found'}, status=404)
        
        target_date = parse_date(date_str)
        if not target_date:
            return JsonResponse({'error': '날짜 형식이 올바르지 않습니다. (YYYY-MM-DD)'}, status=400)
        
        # 해당 날짜의 측정 기록 조회 (여러 개일 수 있음)
        measurements = BodyMeasurement.objects.filter(
            member=member,
            measurement_date=target_date
        ).order_by('-created_at')
        
        results = []
        for m in measurements:
            results.append({
                'measurement_id': m.id,
                'measurement_date': m.measurement_date.strftime('%Y-%m-%d'),
                'weight_kg': float(m.weight_kg) if m.weight_kg else None,
                'blood_sugar_fasting': m.blood_sugar_fasting,
                'blood_sugar_postprandial': m.blood_sugar_postprandial,
                'memo': m.memo or '',
                'created_at': m.created_at.strftime('%Y-%m-%dT%H:%M:%S'),
            })
        
        print(f'✅ [get_body_measurement_by_date] 특정 날짜 신체 변화 기록 조회 완료: member_id={member_id}, date={date_str}, count={len(results)}')
        
        return JsonResponse({
            'success': True,
            'member_id': member_id,
            'date': date_str,
            'count': len(results),
            'measurements': results,
        })
        
    except Exception as e:
        import traceback
        print(f'❌ [get_body_measurement_by_date] 오류: {e}')
        traceback.print_exc()
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
@require_http_methods(["PUT", "DELETE"])
def update_or_delete_body_measurement(request, measurement_id: int):
    """
    PUT /api/body-measurements/<measurement_id>/ - 신체 변화 측정 기록 업데이트
    DELETE /api/body-measurements/<measurement_id>/ - 신체 변화 측정 기록 삭제
    
    PUT Body:
    {
        "weight_kg": 65.5,  # 선택
        "blood_sugar_fasting": 95,  # 선택
        "blood_sugar_postprandial": 140,  # 선택
        "memo": "아침 측정"  # 선택
    }
    """
    try:
        # DELETE 요청 처리
        if request.method == 'DELETE':
            try:
                measurement = BodyMeasurement.objects.get(id=measurement_id)
            except BodyMeasurement.DoesNotExist:
                return JsonResponse({'error': 'Measurement not found'}, status=404)
            
            measurement.delete()
            
            print(f'✅ [update_or_delete_body_measurement] 신체 변화 기록 삭제 완료: measurement_id={measurement_id}')
            
            return JsonResponse({
                'success': True,
                'message': '신체 변화 기록이 삭제되었습니다.',
            }, status=200)
        
        # PUT 요청 처리
        body = json.loads(request.body.decode('utf-8'))
        
        try:
            measurement = BodyMeasurement.objects.get(id=measurement_id)
        except BodyMeasurement.DoesNotExist:
            return JsonResponse({'error': 'Measurement not found'}, status=404)
        
        # 업데이트할 필드만 변경
        if 'weight_kg' in body:
            measurement.weight_kg = body.get('weight_kg')
        if 'blood_sugar_fasting' in body:
            measurement.blood_sugar_fasting = body.get('blood_sugar_fasting')
        if 'blood_sugar_postprandial' in body:
            measurement.blood_sugar_postprandial = body.get('blood_sugar_postprandial')
        if 'memo' in body:
            measurement.memo = body.get('memo', '')
        
        measurement.save()
        
        print(f'✅ [update_or_delete_body_measurement] 신체 변화 기록 업데이트 완료: measurement_id={measurement_id}')
        
        return JsonResponse({
            'success': True,
            'measurement_id': measurement.id,
            'measurement_date': measurement.measurement_date.strftime('%Y-%m-%d'),
            'weight_kg': float(measurement.weight_kg) if measurement.weight_kg else None,
            'blood_sugar_fasting': measurement.blood_sugar_fasting,
            'blood_sugar_postprandial': measurement.blood_sugar_postprandial,
            'memo': measurement.memo or '',
        }, status=200)
        
    except Exception as e:
        import traceback
        print(f'❌ [update_or_delete_body_measurement] 오류: {e}')
        traceback.print_exc()
        return JsonResponse({'error': str(e)}, status=500)

