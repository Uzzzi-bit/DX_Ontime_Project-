# django_backend/members/meal_views.py
"""
식사 기록 및 영양소 분석 API
"""
import json
import base64
import os
import requests
from datetime import datetime, date
from typing import Dict, List, Optional

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.utils.dateparse import parse_date
from django.utils import timezone

from .models import Member, Image, Meal, NutritionAnalysis
from .yolo_service import analyze_image_with_yolo
from .food_nutrition_service import get_food_nutrition  # 폴백용

# AI 백엔드 URL (환경 변수로 설정 가능)
AI_BACKEND_URL = os.environ.get('AI_BACKEND_URL', 'http://localhost:8001')


# 기존 FOOD_NUTRITION_DB는 더 이상 사용하지 않음
# member_food_nutrition_master 테이블에서 조회
# 아래 딕셔너리는 폴백용으로만 유지
FOOD_NUTRITION_DB_FALLBACK = {
    'apple': {
        'calories': 52, 'carbs': 14, 'protein': 0.3, 'fat': 0.2,
        'sodium': 1, 'iron': 0.1, 'calcium': 6, 'vitamin_c': 4.6,
        'folate': 3, 'vitamin_d': 0, 'omega3': 0, 'sugar': 10,
        'magnesium': 5, 'vitamin_a': 3, 'vitamin_b12': 0, 'dietary_fiber': 2.4, 'potassium': 107
    },
    'banana': {
        'calories': 89, 'carbs': 23, 'protein': 1.1, 'fat': 0.3,
        'sodium': 1, 'iron': 0.3, 'calcium': 5, 'vitamin_c': 8.7,
        'folate': 20, 'vitamin_d': 0, 'omega3': 0, 'sugar': 12,
        'magnesium': 27, 'vitamin_a': 3, 'vitamin_b12': 0, 'dietary_fiber': 2.6, 'potassium': 358
    },
    'sandwich': {
        'calories': 250, 'carbs': 30, 'protein': 12, 'fat': 8,
        'sodium': 500, 'iron': 2, 'calcium': 50, 'vitamin_c': 0,
        'folate': 50, 'vitamin_d': 0.5, 'omega3': 0.1, 'sugar': 3,
        'magnesium': 25, 'vitamin_a': 50, 'vitamin_b12': 0.5, 'dietary_fiber': 2, 'potassium': 150
    },
    'orange': {
        'calories': 47, 'carbs': 12, 'protein': 0.9, 'fat': 0.1,
        'sodium': 0, 'iron': 0.1, 'calcium': 40, 'vitamin_c': 53.2,
        'folate': 30, 'vitamin_d': 0, 'omega3': 0, 'sugar': 9,
        'magnesium': 10, 'vitamin_a': 11, 'vitamin_b12': 0, 'dietary_fiber': 2.4, 'potassium': 181
    },
    'broccoli': {
        'calories': 34, 'carbs': 7, 'protein': 2.8, 'fat': 0.4,
        'sodium': 33, 'iron': 0.7, 'calcium': 47, 'vitamin_c': 89.2,
        'folate': 63, 'vitamin_d': 0, 'omega3': 0, 'sugar': 1.5,
        'magnesium': 21, 'vitamin_a': 31, 'vitamin_b12': 0, 'dietary_fiber': 2.6, 'potassium': 316
    },
    'carrot': {
        'calories': 41, 'carbs': 10, 'protein': 0.9, 'fat': 0.2,
        'sodium': 69, 'iron': 0.3, 'calcium': 33, 'vitamin_c': 5.9,
        'folate': 19, 'vitamin_d': 0, 'omega3': 0, 'sugar': 4.7,
        'magnesium': 12, 'vitamin_a': 835, 'vitamin_b12': 0, 'dietary_fiber': 2.8, 'potassium': 320
    },
    'hot dog': {
        'calories': 290, 'carbs': 2, 'protein': 10, 'fat': 26,
        'sodium': 810, 'iron': 1.2, 'calcium': 10, 'vitamin_c': 0,
        'folate': 5, 'vitamin_d': 0.3, 'omega3': 0, 'sugar': 0,
        'magnesium': 10, 'vitamin_a': 0, 'vitamin_b12': 0.8, 'dietary_fiber': 0, 'potassium': 150
    },
    'pizza': {
        'calories': 266, 'carbs': 33, 'protein': 11, 'fat': 10,
        'sodium': 551, 'iron': 2.3, 'calcium': 140, 'vitamin_c': 0,
        'folate': 30, 'vitamin_d': 0.2, 'omega3': 0, 'sugar': 3,
        'magnesium': 20, 'vitamin_a': 50, 'vitamin_b12': 0.5, 'dietary_fiber': 2, 'potassium': 200
    },
    'donut': {
        'calories': 452, 'carbs': 51, 'protein': 5, 'fat': 25,
        'sodium': 326, 'iron': 2.1, 'calcium': 24, 'vitamin_c': 0,
        'folate': 20, 'vitamin_d': 0, 'omega3': 0, 'sugar': 25,
        'magnesium': 15, 'vitamin_a': 0, 'vitamin_b12': 0.2, 'dietary_fiber': 1.5, 'potassium': 100
    },
    'cake': {
        'calories': 371, 'carbs': 53, 'protein': 5, 'fat': 16,
        'sodium': 315, 'iron': 1.4, 'calcium': 54, 'vitamin_c': 0,
        'folate': 25, 'vitamin_d': 0.1, 'omega3': 0, 'sugar': 35,
        'magnesium': 18, 'vitamin_a': 30, 'vitamin_b12': 0.3, 'dietary_fiber': 1, 'potassium': 120
    },
    # 한국 음식 추가
    '김치찌개': {
        'calories': 120, 'carbs': 8, 'protein': 8, 'fat': 6,
        'sodium': 1200, 'iron': 2.5, 'calcium': 80, 'vitamin_c': 15,
        'folate': 25, 'vitamin_d': 0, 'omega3': 0.1, 'sugar': 2,
        'magnesium': 30, 'vitamin_a': 50, 'vitamin_b12': 0.3, 'dietary_fiber': 2, 'potassium': 250
    },
    '현미밥': {
        'calories': 111, 'carbs': 23, 'protein': 2.3, 'fat': 0.9,
        'sodium': 5, 'iron': 0.4, 'calcium': 10, 'vitamin_c': 0,
        'folate': 8, 'vitamin_d': 0, 'omega3': 0, 'sugar': 0.2,
        'magnesium': 43, 'vitamin_a': 0, 'vitamin_b12': 0, 'dietary_fiber': 1.8, 'potassium': 43
    },
    '녹두전': {
        'calories': 180, 'carbs': 20, 'protein': 6, 'fat': 8,
        'sodium': 400, 'iron': 1.5, 'calcium': 50, 'vitamin_c': 2,
        'folate': 60, 'vitamin_d': 0, 'omega3': 0, 'sugar': 1,
        'magnesium': 50, 'vitamin_a': 5, 'vitamin_b12': 0, 'dietary_fiber': 4, 'potassium': 300
    },
    '된장찌개': {
        'calories': 110, 'carbs': 7, 'protein': 7, 'fat': 5,
        'sodium': 1100, 'iron': 2.0, 'calcium': 70, 'vitamin_c': 10,
        'folate': 20, 'vitamin_d': 0, 'omega3': 0.1, 'sugar': 1,
        'magnesium': 25, 'vitamin_a': 40, 'vitamin_b12': 0.2, 'dietary_fiber': 2, 'potassium': 200
    },
    '불고기': {
        'calories': 250, 'carbs': 15, 'protein': 25, 'fat': 10,
        'sodium': 800, 'iron': 3.0, 'calcium': 30, 'vitamin_c': 0,
        'folate': 10, 'vitamin_d': 0.2, 'omega3': 0.1, 'sugar': 8,
        'magnesium': 20, 'vitamin_a': 0, 'vitamin_b12': 1.5, 'dietary_fiber': 0, 'potassium': 300
    },
}


# get_food_nutrition 함수는 food_nutrition_service.py로 이동
# 이제 food_nutrition_service.get_food_nutrition()을 직접 사용


@csrf_exempt
def analyze_meal_image(request):
    """
    POST /api/meals/analyze/
    이미지를 YOLO로 분석하여 음식 리스트 반환
    
    body: {
        "image_base64": "base64_string",
        "member_id": "firebase_uid"
    }
    """
    if request.method != 'POST':
        return JsonResponse({'error': 'POST only'}, status=405)
    
    try:
        body = json.loads(request.body.decode('utf-8'))
        image_base64 = body.get('image_base64')
        member_id = body.get('member_id')
        
        if not image_base64:
            return JsonResponse({'error': 'image_base64 is required'}, status=400)
        
        print(f'🔄 [analyze_meal_image] YOLO 분석 요청 시작 (이미지 크기: {len(image_base64)} bytes)')
        
        # Django에서 직접 YOLO 분석 수행
        try:
            result = analyze_image_with_yolo(image_base64)
            
            if result.get('success'):
                foods = result.get('foods', [])
                print(f'✅ [analyze_meal_image] YOLO 분석 성공: {len(foods)}개 음식 탐지')
                return JsonResponse({
                    'success': True,
                    'foods': foods,
                    'count': len(foods)
                })
            else:
                error_msg = result.get('error', 'YOLO 분석 실패')
                print(f'⚠️ [analyze_meal_image] YOLO 분석 실패: {error_msg}')
                return JsonResponse({
                    'success': False,
                    'foods': [],
                    'count': 0,
                    'error': error_msg
                })
        except Exception as e:
            print(f'❌ [analyze_meal_image] YOLO 분석 중 예외 발생: {e}')
            import traceback
            traceback.print_exc()
            return JsonResponse({
                'success': False,
                'foods': [],
                'count': 0,
                'error': f'YOLO 분석 오류: {str(e)}'
            }, status=500)
    
    except json.JSONDecodeError as e:
        print(f'❌ [analyze_meal_image] JSON 파싱 오류: {e}')
        return JsonResponse({'error': 'Invalid JSON'}, status=400)
    except Exception as e:
        print(f'❌ [analyze_meal_image] 예상치 못한 오류: {e}')
        import traceback
        traceback.print_exc()
        return JsonResponse({
            'success': False,
            'foods': [],
            'count': 0,
            'error': str(e)
        }, status=500)


@csrf_exempt
def save_meal(request):
    """
    POST /api/meals/
    식사 기록 저장
    
    body: {
        "member_id": "firebase_uid",
        "meal_time": "조식|중식|석식|야식",
        "meal_date": "2024-12-04",
        "image_id": 123,  # optional
        "memo": "메모",  # optional
        "foods": [  # optional, YOLO 분석 결과
            {"name": "apple", "confidence": 0.9},
            {"name": "banana", "confidence": 0.8}
        ]
    }
    """
    if request.method != 'POST':
        return JsonResponse({'error': 'POST only'}, status=405)
    
    try:
        body = json.loads(request.body.decode('utf-8'))
        member_id = body.get('member_id')
        meal_time = body.get('meal_time')
        meal_date_str = body.get('meal_date')
        image_id = body.get('image_id')
        memo = body.get('memo', '')
        foods = body.get('foods', [])  # YOLO 분석 결과
        
        if not member_id or not meal_time or not meal_date_str:
            return JsonResponse({
                'error': 'member_id, meal_time, meal_date are required'
            }, status=400)
        
        # 날짜 파싱
        meal_date = parse_date(meal_date_str)
        if not meal_date:
            return JsonResponse({'error': 'Invalid date format (YYYY-MM-DD)'}, status=400)
        
        # Member 확인
        try:
            member = Member.objects.get(firebase_uid=member_id)
        except Member.DoesNotExist:
            return JsonResponse({'error': 'Member not found'}, status=404)
        
        # Image 확인 (선택사항)
        image = None
        if image_id:
            try:
                image = Image.objects.get(id=image_id)
            except Image.DoesNotExist:
                return JsonResponse({'error': 'Image not found'}, status=404)
        
        # 음식 리스트를 memo에 저장 (JSON 형식으로 저장)
        foods_list_str = ', '.join([food.get('name', '') for food in foods]) if foods else ''
        final_memo = memo if memo else foods_list_str
        
        # Meal 생성 (음식 리스트를 memo에 저장)
        meal = Meal.objects.create(
            member=member,
            image=image,
            meal_time=meal_time,
            meal_date=meal_date,
            memo=final_memo  # 음식 리스트를 memo에 저장
        )
        
        # 영양소 분석 저장 (음식 리스트가 있는 경우)
        # AI 백엔드에서 영양소 분석 수행
        total_nutrition = {
            'calories': 0, 'carbs': 0, 'protein': 0, 'fat': 0,
            'sodium': 0, 'iron': 0, 'calcium': 0, 'vitamin_c': 0,
            'sugar': 0, 'folate': 0, 'magnesium': 0, 'omega3': 0,
            'vitamin_a': 0, 'vitamin_b12': 0, 'vitamin_d': 0,
            'dietary_fiber': 0, 'potassium': 0
        }
        
        if foods:
            # AI 백엔드에 영양소 분석 요청 시도, 실패 시 Django에서 직접 처리
            use_ai_backend = True
            nutrition_results = []
            
            try:
                # AI 백엔드에 영양소 분석 요청
                print(f'🔄 [save_meal] AI 백엔드에 영양소 분석 요청: {len(foods)}개 음식')
                print(f'   AI 백엔드 URL: {AI_BACKEND_URL}')
                ai_response = requests.post(
                    f'{AI_BACKEND_URL}/api/analyze-food-nutrition',
                    json={'foods': foods},
                    timeout=600  # 음식이 많을 경우 분석 시간이 오래 걸릴 수 있으므로 600초(10분)로 증가
                )
                
                print(f'   응답 상태 코드: {ai_response.status_code}')
                
                if ai_response.status_code == 200:
                    ai_result = ai_response.json()
                    if ai_result.get('success'):
                        nutrition_results = ai_result.get('nutrition_results', [])
                        print(f'✅ [save_meal] AI 백엔드 영양소 분석 완료: {len(nutrition_results)}개 결과')
                        # 디버깅: 첫 번째 결과 확인
                        if nutrition_results:
                            first_result = nutrition_results[0]
                            print(f'   📊 첫 번째 결과 확인:')
                            print(f'      food_name: {first_result.get("food_name")}')
                            print(f'      serving_size_gram: {first_result.get("serving_size_gram")}g')
                            print(f'      calories: {first_result.get("calories")}kcal')
                            print(f'      protein: {first_result.get("protein")}g')
                            print(f'      carbs: {first_result.get("carbs")}g')
                    else:
                        error_msg = ai_result.get('error', '알 수 없는 오류')
                        print(f'⚠️ [save_meal] AI 백엔드 영양소 분석 실패: {error_msg}')
                        use_ai_backend = False
                else:
                    print(f'⚠️ [save_meal] AI 백엔드 요청 실패: {ai_response.status_code} - {ai_response.text[:200]}')
                    use_ai_backend = False
            except requests.exceptions.ConnectionError as e:
                print(f'❌ [save_meal] AI 백엔드 연결 실패: {e}')
                print(f'   AI 백엔드가 실행 중인지 확인하세요: {AI_BACKEND_URL}')
                use_ai_backend = False
            except requests.exceptions.ReadTimeout as e:
                print(f'❌ [save_meal] AI 백엔드 응답 타임아웃 (60초 초과): {e}')
                print(f'   AI 백엔드가 응답하는데 시간이 너무 오래 걸립니다. 재시도합니다.')
                use_ai_backend = False
            except Exception as e:
                print(f'❌ [save_meal] AI 백엔드 영양소 분석 중 오류: {e}')
                import traceback
                traceback.print_exc()
                use_ai_backend = False
            
            # AI 백엔드 실패 시 재시도 (폴백)
            # AI 백엔드가 실패해도 DB를 사용하지 않고 AI 백엔드를 다시 호출
            if not use_ai_backend or not nutrition_results:
                print(f'🔄 [save_meal] AI 백엔드 재시도 (개별 음식별로 요청)')
                for food_item in foods:
                    food_name = food_item.get('name', '')
                    if not food_name:
                        continue
                    
                    try:
                        # AI 백엔드에 개별 음식 분석 요청
                        print(f'   🔄 AI 백엔드 재시도: {food_name}')
                        ai_retry_response = requests.post(
                            f'{AI_BACKEND_URL}/api/analyze-food-nutrition',
                            json={'foods': [food_item]},
                            timeout=600  # 음식이 많을 경우 분석 시간이 오래 걸릴 수 있으므로 600초(10분)로 증가
                        )
                        
                        if ai_retry_response.status_code == 200:
                            ai_retry_result = ai_retry_response.json()
                            if ai_retry_result.get('success') and ai_retry_result.get('nutrition_results'):
                                # AI 백엔드에서 계산한 결과를 그대로 사용
                                ai_result_item = ai_retry_result['nutrition_results'][0]
                                nutrition_results.append({
                                    'food_name': ai_result_item.get('food_name', food_name),
                                    'food_id': ai_result_item.get('food_id'),
                                    'calories': ai_result_item.get('calories', 0),  # AI가 계산한 값
                                    'carbs': ai_result_item.get('carbs', 0),  # AI가 계산한 값
                                    'protein': ai_result_item.get('protein', 0),  # AI가 계산한 값
                                    'fat': ai_result_item.get('fat', 0),  # AI가 계산한 값
                                    'sodium': ai_result_item.get('sodium', 0),  # AI가 계산한 값
                                    'iron': ai_result_item.get('iron', 0),  # AI가 계산한 값
                                    'calcium': ai_result_item.get('calcium', 0),  # AI가 계산한 값
                                    'vitamin_c': ai_result_item.get('vitamin_c', 0),  # AI가 계산한 값
                                    'sugar': ai_result_item.get('sugar', 0),  # AI가 계산한 값
                                    'folate': ai_result_item.get('folate', 0),  # AI가 계산한 값
                                    'magnesium': ai_result_item.get('magnesium', 0),  # AI가 계산한 값
                                    'omega3': ai_result_item.get('omega3', 0),  # AI가 계산한 값
                                    'vitamin_a': ai_result_item.get('vitamin_a', 0),  # AI가 계산한 값
                                    'vitamin_b12': ai_result_item.get('vitamin_b12', 0),  # AI가 계산한 값
                                    'vitamin_d': ai_result_item.get('vitamin_d', 0),  # AI가 계산한 값
                                    'dietary_fiber': ai_result_item.get('dietary_fiber', 0),  # AI가 계산한 값
                                    'potassium': ai_result_item.get('potassium', 0),  # AI가 계산한 값
                                    'serving_size_gram': ai_result_item.get('serving_size_gram', 0),  # AI가 추정한 무게
                                })
                                print(f'   ✅ AI 백엔드 재시도 성공: {food_name} - serving_size={ai_result_item.get("serving_size_gram", 0)}g, calories={ai_result_item.get("calories", 0)}kcal')
                            else:
                                print(f'   ⚠️ AI 백엔드 재시도 실패: {food_name} - {ai_retry_result.get("error", "알 수 없는 오류")}')
                        else:
                            print(f'   ⚠️ AI 백엔드 재시도 실패: {food_name} - HTTP {ai_retry_response.status_code}')
                    except requests.exceptions.ReadTimeout as e:
                        print(f'   ❌ AI 백엔드 재시도 타임아웃: {food_name} - {e}')
                        print(f'      AI 백엔드 응답이 60초를 초과했습니다.')
                    except requests.exceptions.ConnectionError as e:
                        print(f'   ❌ AI 백엔드 재시도 연결 실패: {food_name} - {e}')
                    except Exception as e:
                        print(f'   ❌ AI 백엔드 재시도 중 오류: {food_name} - {e}')
                        import traceback
                        traceback.print_exc()
            
            # 각 음식의 영양소를 nutrition_analysis 테이블에 저장 (음식 하나당 하나의 행)
            for nutrition_result in nutrition_results:
                food_name = nutrition_result.get('food_name', '')
                if not food_name:
                    continue
                
                serving_size = nutrition_result.get('serving_size_gram', 100.0)
                calories_value = nutrition_result.get('calories', 0)
                print(f'💾 [save_meal] NutritionAnalysis 저장: meal_id={meal.meal_id}, food_name="{food_name}"')
                print(f'   📊 저장할 값: serving_size_gram={serving_size}g, calories={calories_value}kcal')
                NutritionAnalysis.objects.create(
                    meal=meal,
                    food_name=food_name,
                    food_id=nutrition_result.get('food_id'),
                    calories=calories_value,  # AI가 계산한 값 (이미 multiplier 적용됨)
                    carbs=nutrition_result.get('carbs', 0),
                    protein=nutrition_result.get('protein', 0),
                    fat=nutrition_result.get('fat', 0),
                    sodium=nutrition_result.get('sodium', 0),
                    iron=nutrition_result.get('iron', 0),
                    calcium=nutrition_result.get('calcium', 0),
                    vitamin_c=nutrition_result.get('vitamin_c', 0),
                    sugar=nutrition_result.get('sugar', 0),
                    folate=nutrition_result.get('folate', 0),
                    magnesium=nutrition_result.get('magnesium', 0),
                    omega3=nutrition_result.get('omega3', 0),
                    vitamin_a=nutrition_result.get('vitamin_a', 0),
                    vitamin_b=nutrition_result.get('vitamin_b12', 0),  # vitamin_b12를 vitamin_b 필드에 저장
                    vitamin_d=nutrition_result.get('vitamin_d', 0),
                    dietary_fiber=nutrition_result.get('dietary_fiber', 0),
                    potassium=nutrition_result.get('potassium', 0),
                    serving_size_gram=serving_size,  # AI가 추정한 조리된 상태의 1인분 무게
                )
                
                # 총 영양소 합산
                total_nutrition['calories'] += nutrition_result.get('calories', 0)
                total_nutrition['carbs'] += nutrition_result.get('carbs', 0)
                total_nutrition['protein'] += nutrition_result.get('protein', 0)
                total_nutrition['fat'] += nutrition_result.get('fat', 0)
                total_nutrition['sodium'] += nutrition_result.get('sodium', 0)
                total_nutrition['iron'] += nutrition_result.get('iron', 0)
                total_nutrition['calcium'] += nutrition_result.get('calcium', 0)
                total_nutrition['vitamin_c'] += nutrition_result.get('vitamin_c', 0)
                total_nutrition['sugar'] += nutrition_result.get('sugar', 0)
                total_nutrition['folate'] += nutrition_result.get('folate', 0)
                total_nutrition['magnesium'] += nutrition_result.get('magnesium', 0)
                total_nutrition['omega3'] += nutrition_result.get('omega3', 0)
                total_nutrition['vitamin_a'] += nutrition_result.get('vitamin_a', 0)
                total_nutrition['vitamin_b12'] += nutrition_result.get('vitamin_b12', 0)
                total_nutrition['vitamin_d'] += nutrition_result.get('vitamin_d', 0)
                total_nutrition['dietary_fiber'] += nutrition_result.get('dietary_fiber', 0)
                total_nutrition['potassium'] += nutrition_result.get('potassium', 0)
            
            print(f'✅ [save_meal] 영양소 분석 완료: 총 {len(nutrition_results)}개 음식, 칼로리={total_nutrition["calories"]}kcal')
        
        return JsonResponse({
            'success': True,
            'meal_id': meal.meal_id,
            'total_nutrition': total_nutrition,
            'foods_count': len(foods) if foods else 0
        }, status=201)
    
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON'}, status=400)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
def get_daily_nutrition(request, member_id: str, date_str: str):
    """
    GET /api/meals/daily-nutrition/<member_id>/<date>/
    특정 날짜의 총 섭취 영양소 계산
    
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
        
        # 해당 날짜의 모든 식사 조회
        meals = Meal.objects.filter(
            member=member,
            meal_date=target_date
        )
        
        # 모든 영양소 분석 합산
        total_nutrition = {
            'calories': 0, 'carbs': 0, 'protein': 0, 'fat': 0,
            'sodium': 0, 'iron': 0, 'calcium': 0, 'vitamin_c': 0,
            'sugar': 0, 'folate': 0, 'magnesium': 0, 'omega3': 0,
            'vitamin_a': 0, 'vitamin_b': 0, 'vitamin_d': 0,
            'dietary_fiber': 0, 'potassium': 0
        }
        
        meal_list = []
        for meal in meals:
            # 각 식사의 영양소 분석 조회
            analyses = NutritionAnalysis.objects.filter(meal=meal)
            
            meal_nutrition = {key: 0 for key in total_nutrition}
            foods = []
            
            for analysis in analyses:
                # 영양소 합산
                meal_nutrition['calories'] += analysis.calories or 0
                meal_nutrition['carbs'] += analysis.carbs or 0
                meal_nutrition['protein'] += analysis.protein or 0
                meal_nutrition['fat'] += analysis.fat or 0
                meal_nutrition['sodium'] += analysis.sodium or 0
                meal_nutrition['iron'] += analysis.iron or 0
                meal_nutrition['calcium'] += analysis.calcium or 0
                meal_nutrition['vitamin_c'] += analysis.vitamin_c or 0
                meal_nutrition['sugar'] += analysis.sugar or 0
                meal_nutrition['folate'] += analysis.folate or 0
                meal_nutrition['magnesium'] += analysis.magnesium or 0
                meal_nutrition['omega3'] += analysis.omega3 or 0
                meal_nutrition['vitamin_a'] += analysis.vitamin_a or 0
                meal_nutrition['vitamin_b'] += analysis.vitamin_b or 0
                meal_nutrition['vitamin_d'] += analysis.vitamin_d or 0
                meal_nutrition['dietary_fiber'] += analysis.dietary_fiber or 0
                meal_nutrition['potassium'] += analysis.potassium or 0
                
                if analysis.food_name:
                    foods.append(analysis.food_name)
            
            # 총 영양소에 합산
            for key in total_nutrition:
                total_nutrition[key] += meal_nutrition[key]
            
            meal_list.append({
                'meal_id': meal.meal_id,
                'meal_time': meal.meal_time,
                'memo': meal.memo,
                'foods': foods,
                'nutrition': meal_nutrition
            })
        
        return JsonResponse({
            'success': True,
            'date': date_str,
            'total_nutrition': total_nutrition,
            'meals': meal_list,
            'meals_count': len(meal_list)
        })
    
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
def get_meals(request, member_id: str, date_str: str):
    """
    GET /api/meals/<member_id>/<date>/
    특정 날짜의 식사 기록 목록 조회
    
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
        
        # 해당 날짜의 모든 식사 조회
        meals = Meal.objects.filter(
            member=member,
            meal_date=target_date
        ).order_by('meal_time')
        
        meal_list = []
        for meal in meals:
            # 각 식사의 음식 목록 조회
            analyses = NutritionAnalysis.objects.filter(meal=meal)
            foods = [analysis.food_name for analysis in analyses if analysis.food_name]
            
            meal_list.append({
                'meal_id': meal.meal_id,
                'meal_time': meal.meal_time,
                'memo': meal.memo or '',
                'image_id': meal.image_id,
                'image_url': meal.image.image_url if meal.image else None,
                'foods': foods,
                'created_at': meal.created_at.isoformat() if meal.created_at else None,
            })
        
        return JsonResponse({
            'success': True,
            'date': date_str,
            'meals': meal_list,
            'count': len(meal_list)
        })
    
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
def update_meal_foods(request, member_id: str, date_str: str, meal_time: str):
    """
    PUT /api/meals/<member_id>/<date_str>/<meal_time>/ - meal 음식 목록 업데이트
    DELETE /api/meals/<member_id>/<date_str>/<meal_time>/ - meal 삭제
    
    PUT body: {
        "foods": ["apple", "banana"]  # 최종 음식 목록 (삭제된 음식 제외)
    }
    
    date format: YYYY-MM-DD
    meal_time: "조식", "중식", "석식", "야식"
    """
    # DELETE 요청 처리
    if request.method == 'DELETE':
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
            
            # 해당 날짜와 식사 타입의 모든 meal 조회 및 삭제
            meals = Meal.objects.filter(
                member=member,
                meal_date=target_date,
                meal_time=meal_time
            )
            
            deleted_count = meals.count()
            
            # 관련 NutritionAnalysis도 함께 삭제 (CASCADE로 자동 삭제되지만 명시적으로)
            for meal in meals:
                NutritionAnalysis.objects.filter(meal=meal).delete()
            
            # Meal 삭제
            meals.delete()
            
            print(f'✅ [update_meal_foods] DELETE: meal 삭제 완료: member_id={member_id}, date={date_str}, meal_time={meal_time}, 삭제된 meal 개수={deleted_count}')
            
            return JsonResponse({
                'success': True,
                'date': date_str,
                'meal_time': meal_time,
                'deleted_count': deleted_count,
            })
        except Exception as e:
            import traceback
            traceback.print_exc()
            return JsonResponse({'error': str(e)}, status=500)
    
    # PUT 요청 처리
    if request.method != 'PUT':
        return JsonResponse({'error': 'PUT or DELETE only'}, status=405)
    
    try:
        body = json.loads(request.body.decode('utf-8'))
        foods = body.get('foods', [])  # 최종 음식 목록
        
        print(f'🔄 [update_meal_foods] PUT 요청 수신')
        print(f'   member_id: {member_id}, date: {date_str}, meal_time: {meal_time}')
        print(f'   받은 foods 목록: {foods}')
        print(f'   foods 개수: {len(foods)}')

        target_date = parse_date(date_str)
        if not target_date:
            return JsonResponse({'error': 'Invalid date format (YYYY-MM-DD)'}, status=400)

        try:
            member = Member.objects.get(firebase_uid=member_id)
        except Member.DoesNotExist:
            return JsonResponse({'error': 'Member not found'}, status=404)

        meals = Meal.objects.filter(
            member=member,
            meal_date=target_date,
            meal_time=meal_time
        )

        if not meals.exists():
            return JsonResponse({'error': 'Meal not found'}, status=404)

        meal = meals.first()

        # 기존 NutritionAnalysis 조회
        existing_analyses = NutritionAnalysis.objects.filter(meal=meal)
        existing_food_names = [analysis.food_name for analysis in existing_analyses if analysis.food_name]
        
        print(f'   기존 음식 목록: {existing_food_names}')
        print(f'   기존 음식 개수: {len(existing_food_names)}')
        
        # 삭제된 음식의 NutritionAnalysis만 삭제 (남은 음식은 유지)
        # 같은 이름의 음식이 여러 개일 수 있으므로 개수를 정확히 계산하여 삭제
        
        # 기존 음식 목록에서 각 음식의 개수 계산
        existing_food_count = {}
        for name in existing_food_names:
            existing_food_count[name] = existing_food_count.get(name, 0) + 1
        
        # 현재 음식 목록에서 각 음식의 개수 계산
        current_food_count = {}
        for name in foods:
            current_food_count[name] = current_food_count.get(name, 0) + 1
        
        # 삭제할 음식과 개수 계산
        foods_to_delete = []
        for food_name, existing_count in existing_food_count.items():
            current_count = current_food_count.get(food_name, 0)
            delete_count = existing_count - current_count
            if delete_count > 0:
                foods_to_delete.append((food_name, delete_count))
                # 해당 음식의 NutritionAnalysis를 개수만큼 삭제
                # Django에서는 슬라이싱된 쿼리셋에 delete()를 직접 호출할 수 없으므로
                # 먼저 pk 리스트를 가져온 후 삭제
                analyses_to_delete_pks = list(
                    NutritionAnalysis.objects.filter(
                        meal=meal,
                        food_name=food_name
                    ).values_list('pk', flat=True)[:delete_count]
                )
                if analyses_to_delete_pks:
                    NutritionAnalysis.objects.filter(pk__in=analyses_to_delete_pks).delete()
                print(f'   🗑️ {food_name}: {existing_count}개 → {current_count}개 (삭제: {delete_count}개)')
        
        if foods_to_delete:
            print(f'🔄 [update_meal_foods] 삭제된 음식의 NutritionAnalysis 삭제 완료: 총 {len(foods_to_delete)}종류')
        
        # meal의 memo 업데이트
        meal.memo = ', '.join(foods) if foods else ''
        meal.save()

        # 새로 추가된 음식만 식별 (기존에 없던 음식)
        new_foods = [food for food in foods if food not in existing_food_names]
        
        # 총 영양소 계산 (기존 + 새로 추가된 음식)
        total_nutrition = {
            'calories': 0, 'carbs': 0, 'protein': 0, 'fat': 0,
            'sodium': 0, 'iron': 0, 'calcium': 0, 'vitamin_c': 0,
            'sugar': 0, 'folate': 0, 'magnesium': 0, 'omega3': 0,
            'vitamin_a': 0, 'vitamin_b12': 0, 'vitamin_d': 0,
            'dietary_fiber': 0, 'potassium': 0
        }
        
        # 기존 음식의 영양소 합산 (남은 음식만)
        foods_to_keep = set(foods)  # 남은 음식 목록 (Set으로 변환하여 빠른 조회)
        remaining_analyses = NutritionAnalysis.objects.filter(meal=meal)
        for analysis in remaining_analyses:
            if analysis.food_name in foods_to_keep:  # 남은 음식만 합산
                total_nutrition['calories'] += analysis.calories or 0
                total_nutrition['carbs'] += analysis.carbs or 0
                total_nutrition['protein'] += analysis.protein or 0
                total_nutrition['fat'] += analysis.fat or 0
                total_nutrition['sodium'] += analysis.sodium or 0
                total_nutrition['iron'] += analysis.iron or 0
                total_nutrition['calcium'] += analysis.calcium or 0
                total_nutrition['vitamin_c'] += analysis.vitamin_c or 0
                total_nutrition['sugar'] += analysis.sugar or 0
                total_nutrition['folate'] += analysis.folate or 0
                total_nutrition['magnesium'] += analysis.magnesium or 0
                total_nutrition['omega3'] += analysis.omega3 or 0
                total_nutrition['vitamin_a'] += analysis.vitamin_a or 0
                total_nutrition['vitamin_b12'] += analysis.vitamin_b or 0  # vitamin_b 필드 사용
                total_nutrition['vitamin_d'] += analysis.vitamin_d or 0
                total_nutrition['dietary_fiber'] += analysis.dietary_fiber or 0
                total_nutrition['potassium'] += analysis.potassium or 0

        # 새로 추가된 음식만 분석
        if new_foods:
            foods_for_api = [{'name': food, 'confidence': 0.9} for food in new_foods]
            print(f'🔄 [update_meal_foods] 새로 추가된 음식만 분석: {new_foods}')

            try:
                ai_response = requests.post(
                    f'{AI_BACKEND_URL}/api/analyze-food-nutrition',
                    json={'foods': foods_for_api},
                    timeout=600  # 음식이 많을 경우 분석 시간이 오래 걸릴 수 있으므로 600초(10분)로 증가
                )

                if ai_response.status_code == 200:
                    ai_result = ai_response.json()
                    if ai_result.get('success'):
                        nutrition_results = ai_result.get('nutrition_results', [])
                        print(f'✅ [update_meal_foods] AI 백엔드 영양소 분석 완료: {len(nutrition_results)}개 결과')

                        for nutrition_data in nutrition_results:
                            food_name = nutrition_data.get('food_name', '')
                            omega3_mg = nutrition_data.get('omega3', 0) or 0
                            omega3_g = omega3_mg / 1000.0  # mg를 g으로 변환

                            NutritionAnalysis.objects.create(
                                meal=meal,
                                food_name=food_name,
                                calories=nutrition_data.get('calories', 0) or 0,
                                carbs=nutrition_data.get('carbs', 0) or 0,
                                protein=nutrition_data.get('protein', 0) or 0,
                                fat=nutrition_data.get('fat', 0) or 0,
                                sodium=nutrition_data.get('sodium', 0) or 0,
                                iron=nutrition_data.get('iron', 0) or 0,
                                calcium=nutrition_data.get('calcium', 0) or 0,
                                vitamin_c=nutrition_data.get('vitamin_c', 0) or 0,
                                sugar=nutrition_data.get('sugar', 0) or 0,
                                folate=nutrition_data.get('folate', 0) or 0,
                                magnesium=nutrition_data.get('magnesium', 0) or 0,
                                omega3=omega3_g,  # mg를 g로 변환
                                vitamin_a=nutrition_data.get('vitamin_a', 0) or 0,
                                vitamin_b=nutrition_data.get('vitamin_b12', 0) or 0,  # vitamin_b12를 vitamin_b 필드에 저장
                                vitamin_d=nutrition_data.get('vitamin_d', 0) or 0,
                                dietary_fiber=nutrition_data.get('dietary_fiber', 0) or 0,
                                potassium=nutrition_data.get('potassium', 0) or 0,
                            )

                            total_nutrition['calories'] += nutrition_data.get('calories', 0) or 0
                            total_nutrition['carbs'] += nutrition_data.get('carbs', 0) or 0
                            total_nutrition['protein'] += nutrition_data.get('protein', 0) or 0
                            total_nutrition['fat'] += nutrition_data.get('fat', 0) or 0
                            total_nutrition['sodium'] += nutrition_data.get('sodium', 0) or 0
                            total_nutrition['iron'] += nutrition_data.get('iron', 0) or 0
                            total_nutrition['calcium'] += nutrition_data.get('calcium', 0) or 0
                            total_nutrition['vitamin_c'] += nutrition_data.get('vitamin_c', 0) or 0
                            total_nutrition['sugar'] += nutrition_data.get('sugar', 0) or 0
                            total_nutrition['folate'] += nutrition_data.get('folate', 0) or 0
                            total_nutrition['magnesium'] += nutrition_data.get('magnesium', 0) or 0
                            total_nutrition['omega3'] += omega3_g  # mg를 g으로 변환
                            total_nutrition['vitamin_a'] += nutrition_data.get('vitamin_a', 0) or 0
                            total_nutrition['vitamin_b12'] += nutrition_data.get('vitamin_b12', 0) or 0
                            total_nutrition['vitamin_d'] += nutrition_data.get('vitamin_d', 0) or 0
                            total_nutrition['dietary_fiber'] += nutrition_data.get('dietary_fiber', 0) or 0
                            total_nutrition['potassium'] += nutrition_data.get('potassium', 0) or 0
                    else:
                        print(f'⚠️ [update_meal_foods] AI 백엔드 응답: success=False')
                else:
                    print(f'⚠️ [update_meal_foods] AI 백엔드 응답 실패: {ai_response.status_code}')
            except Exception as e:
                print(f'⚠️ [update_meal_foods] AI 백엔드 영양소 분석 실패: {e}')
                # 폴백: Django에서 직접 처리 (새로 추가된 음식만)
                from .food_nutrition_service import get_food_nutrition
                for food_name in new_foods:
                    nutrition = get_food_nutrition(food_name.lower())
                    if nutrition:
                        omega3_mg = nutrition.get('omega3', 0) or 0
                        omega3_g = omega3_mg / 1000.0  # mg를 g으로 변환

                        NutritionAnalysis.objects.create(
                            meal=meal,
                            food_name=food_name,
                            calories=nutrition.get('calories', 0) or 0,
                            carbs=nutrition.get('carbs', 0) or 0,
                            protein=nutrition.get('protein', 0) or 0,
                            fat=nutrition.get('fat', 0) or 0,
                            sodium=nutrition.get('sodium', 0) or 0,
                            iron=nutrition.get('iron', 0) or 0,
                            calcium=nutrition.get('calcium', 0) or 0,
                            vitamin_c=nutrition.get('vitamin_c', 0) or 0,
                            sugar=nutrition.get('sugar', 0) or 0,
                            folate=nutrition.get('folate', 0) or 0,
                            magnesium=nutrition.get('magnesium', 0) or 0,
                            omega3=omega3_g,  # mg를 g로 변환
                            vitamin_a=nutrition.get('vitamin_a', 0) or 0,
                            vitamin_b=nutrition.get('vitamin_b12', 0) or 0,  # vitamin_b12를 vitamin_b 필드에 저장
                            vitamin_d=nutrition.get('vitamin_d', 0) or 0,
                            dietary_fiber=nutrition.get('dietary_fiber', 0) or 0,
                            potassium=nutrition.get('potassium', 0) or 0,
                        )
                        for key in total_nutrition.keys():
                            if key == 'omega3':
                                total_nutrition[key] += omega3_g
                            else:
                                total_nutrition[key] += nutrition.get(key, 0) or 0
        else:
            print(f'ℹ️ [update_meal_foods] 새로 추가된 음식이 없습니다. (삭제만 수행, 분석 스킵)')

        print(f'✅ [update_meal_foods] meal 업데이트 완료: member_id={member_id}, date={date_str}, meal_time={meal_time}, foods={foods}')
        print(f'   삭제된 음식: {foods_to_delete if foods_to_delete else "없음"}')
        print(f'   새로 추가된 음식: {new_foods if new_foods else "없음"}')

        return JsonResponse({
            'success': True,
            'meal_id': meal.meal_id,
            'date': date_str,
            'meal_time': meal_time,
            'foods': foods,
            'total_nutrition': total_nutrition,
        })

    except Exception as e:
        import traceback
        print(f'❌ [update_meal_foods] 오류: {e}')
        traceback.print_exc()
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
def delete_meals_by_date_and_type(request, member_id: str, date_str: str, meal_time: str):
    """
    DELETE /api/meals/<member_id>/<date_str>/<meal_time>/
    특정 날짜와 식사 타입의 모든 meal 삭제
    
    date format: YYYY-MM-DD
    meal_time: "조식", "중식", "석식", "야식"
    """
    if request.method != 'DELETE':
        return JsonResponse({'error': 'DELETE only'}, status=405)
    
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
        
        # 해당 날짜와 식사 타입의 모든 meal 조회 및 삭제
        meals = Meal.objects.filter(
            member=member,
            meal_date=target_date,
            meal_time=meal_time
        )
        
        deleted_count = meals.count()
        
        # 관련 NutritionAnalysis도 함께 삭제 (CASCADE로 자동 삭제되지만 명시적으로)
        for meal in meals:
            NutritionAnalysis.objects.filter(meal=meal).delete()
        
        # Meal 삭제
        meals.delete()
        
        print(f'✅ [delete_meals_by_date_and_type] meal 삭제 완료: member_id={member_id}, date={date_str}, meal_time={meal_time}, 삭제된 meal 개수={deleted_count}')
        
        return JsonResponse({
            'success': True,
            'date': date_str,
            'meal_time': meal_time,
            'deleted_count': deleted_count,
        })
    
    except Exception as e:
        import traceback
        traceback.print_exc()
        return JsonResponse({'error': str(e)}, status=500)
