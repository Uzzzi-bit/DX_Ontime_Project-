# django_backend/members/recommendation_views.py
"""
레시피 추천 API
"""
import json
from datetime import datetime, date
from typing import Dict, List, Optional

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.utils.dateparse import parse_date
from django.utils import timezone

from .models import Member, Recommendation


@csrf_exempt
def save_recommendations(request):
    """
    POST /api/recommendations/
    AI 추천 레시피 저장
    
    body: {
        "member_id": "firebase_uid",
        "recommendation_date": "2024-12-04",
        "banner_message": "추천 배너 메시지",
        "recipes": [
            {
                "title": "레시피 제목",
                "fullTitle": "전체 제목",
                "imagePath": "이미지 경로",
                "ingredients": ["재료1", "재료2"],
                "cookingSteps": ["조리법1", "조리법2"],
                "tip": "팁",
                "isOvenAvailable": true,
                "ovenMode": "오븐",
                "ovenTimeMinutes": 20,
                "calories": 350,
                "tags": ["단백질", "비타민"]
            },
            ...
        ]
    }
    """
    if request.method != 'POST':
        return JsonResponse({'error': 'POST only'}, status=405)
    
    try:
        body = json.loads(request.body.decode('utf-8'))
        member_id = body.get('member_id')
        recommendation_date_str = body.get('recommendation_date')
        banner_message = body.get('banner_message', '')
        recipes = body.get('recipes', [])
        
        if not member_id or not recommendation_date_str:
            return JsonResponse({
                'error': 'member_id and recommendation_date are required'
            }, status=400)
        
        # 날짜 파싱
        recommendation_date = parse_date(recommendation_date_str)
        if not recommendation_date:
            return JsonResponse({'error': 'Invalid date format (YYYY-MM-DD)'}, status=400)
        
        # Member 확인
        try:
            member = Member.objects.get(firebase_uid=member_id)
        except Member.DoesNotExist:
            return JsonResponse({'error': 'Member not found'}, status=404)
        
        # 레시피 전체 데이터를 JSON으로 저장
        recipes_json = recipes if recipes else []
        
        # 첫 번째 레시피의 제목을 recommended_food로 사용
        recommended_food = recipes[0].get('title', '추천 메뉴') if recipes else '추천 메뉴'
        
        # Recommendation 생성 (기존 것을 삭제하지 않고 항상 새로 저장)
        # 조회 시에는 created_at 기준으로 가장 최신 것을 가져옴
        recommendation = Recommendation.objects.create(
            member=member,
            recommendation_date=recommendation_date,
            banner_message=banner_message,
            recipes_data=recipes_json,
            recommended_food=recommended_food,
            reason=f'AI 추천 레시피 {len(recipes)}개',
        )
        
        # 해당 날짜의 총 추천 횟수 확인
        total_count = Recommendation.objects.filter(
            member=member,
            recommendation_date=recommendation_date
        ).count()
        
        print(f'✅ [save_recommendations] 레시피 저장 완료: member_id={member_id}, date={recommendation_date_str}, 레시피 {len(recipes)}개 (총 {total_count}번째 추천)')
        
        return JsonResponse({
            'success': True,
            'rec_id': recommendation.rec_id,
            'recommendation_date': recommendation_date_str,
            'recipes_count': len(recipes),
        }, status=201)
    
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON'}, status=400)
    except Exception as e:
        import traceback
        traceback.print_exc()
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
def get_recommendations(request, member_id: str, date_str: str):
    """
    GET /api/recommendations/<member_id>/<date>/
    특정 날짜의 AI 추천 레시피 조회
    
    date format: YYYY-MM-DD
    """
    if request.method != 'GET':
        return JsonResponse({'error': 'GET only'}, status=405)
    
    try:
        # 날짜 파싱
        target_date = parse_date(date_str)
        if not target_date:
            return JsonResponse({'error': 'Invalid date format (YYYY-MM-DD)'}, status=400)
        
        # Member 확인
        try:
            member = Member.objects.get(firebase_uid=member_id)
        except Member.DoesNotExist:
            return JsonResponse({'error': 'Member not found'}, status=404)
        
        # 해당 날짜의 가장 최신 추천 레시피 조회 (created_at 기준 최신순)
        # 여러 번 추천하면 여러 개가 저장되지만, 항상 가장 마지막(최신) 것을 표시
        recommendation = Recommendation.objects.filter(
            member=member,
            recommendation_date=target_date
        ).order_by('-created_at').first()
        
        # 디버그: 해당 날짜의 총 추천 횟수 출력
        total_count = Recommendation.objects.filter(
            member=member,
            recommendation_date=target_date
        ).count()
        if total_count > 0:
            print(f'📊 [get_recommendations] 해당 날짜 추천 횟수: {total_count}개 (최신 것만 반환)')
        
        if not recommendation:
            return JsonResponse({
                'success': False,
                'date': date_str,
                'banner_message': None,
                'recipes': [],
                'message': '해당 날짜에 추천 레시피가 없습니다.'
            })
        
        recipes_data = recommendation.recipes_data or []
        
        print(f'✅ [get_recommendations] 레시피 조회 완료: member_id={member_id}, date={date_str}, 레시피 {len(recipes_data)}개')
        
        return JsonResponse({
            'success': True,
            'date': date_str,
            'banner_message': recommendation.banner_message,
            'recipes': recipes_data,
            'recipes_count': len(recipes_data),
            'created_at': recommendation.created_at.isoformat() if recommendation.created_at else None,
        })
    
    except Exception as e:
        import traceback
        traceback.print_exc()
        return JsonResponse({'error': str(e)}, status=500)

