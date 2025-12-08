# django_backend/members/food_nutrition_service.py
"""
음식 영양소 정보 조회 서비스
member_food_nutrition_master 테이블에서 영양소 데이터를 가져옵니다.
"""
from typing import Dict, Optional, List
from django.db import models
from django.db.models import Q
import re


class FoodNutritionMaster(models.Model):
    """
    음식 영양소 마스터 테이블 (실제 DB 구조에 맞춤)
    """
    class Meta:
        db_table = 'member_food_nutrition_master'
        managed = False  # 이미 존재하는 테이블이므로 Django가 관리하지 않음

    # 실제 테이블 구조
    food_id = models.IntegerField(primary_key=True, db_column='food_id')
    food_name = models.CharField(max_length=255, null=True, blank=True, db_column='food_name')
    food_name_ko = models.CharField(max_length=255, null=True, blank=True, db_column='food_name_ko')
    food_name_en = models.CharField(max_length=255, null=True, blank=True, db_column='food_name_en')
    serving_size_gram = models.CharField(max_length=50, null=True, blank=True, db_column='serving_size_gram')
    
    # 영양소 필드들 (실제 DB 컬럼명에 맞춤)
    calories = models.FloatField(null=True, blank=True, db_column='calories')
    carbs = models.FloatField(null=True, blank=True, db_column='carbs')
    protein = models.FloatField(null=True, blank=True, db_column='protein')
    fat = models.FloatField(null=True, blank=True, db_column='fat')
    sugar = models.FloatField(null=True, blank=True, db_column='sugar')
    sodium = models.FloatField(null=True, blank=True, db_column='sodium')
    iron = models.FloatField(null=True, blank=True, db_column='iron')
    folate = models.FloatField(null=True, blank=True, db_column='folate')
    magnesium = models.FloatField(null=True, blank=True, db_column='magnesium')
    omega3 = models.FloatField(null=True, blank=True, db_column='omega3')
    calcium = models.FloatField(null=True, blank=True, db_column='calcium')
    vitamin_a = models.FloatField(null=True, blank=True, db_column='vitamin_a')
    vitamin_b = models.FloatField(null=True, blank=True, db_column='vitamin_b')  # DB에는 vitamin_b로 되어 있음
    vitiamin_c = models.FloatField(null=True, blank=True, db_column='vitiamin_c')  # DB에 오타로 vitiamin_c로 되어 있음
    vitamin_d = models.FloatField(null=True, blank=True, db_column='vitamin_d')
    dietary_fiber = models.FloatField(null=True, blank=True, db_column='dietary_fiber')
    potassium = models.FloatField(null=True, blank=True, db_column='potassium')
    
    # 기타 필드
    source = models.CharField(max_length=255, null=True, blank=True, db_column='source')
    source_food_code = models.IntegerField(null=True, blank=True, db_column='source_food_code')
    last_updated = models.IntegerField(null=True, blank=True, db_column='last_updated')


def get_food_nutrition_from_db(food_name: str) -> Optional[Dict]:
    """
    DB에서 음식 이름으로 영양소 정보 조회
    정확히 일치하는 경우만 반환
    """
    try:
        print(f"🔍 [food_nutrition_service] DB 조회 시작: '{food_name}'")
        
        # food_name, food_name_ko, food_name_en 모두 검색
        food = FoodNutritionMaster.objects.filter(
            Q(food_name__iexact=food_name) |
            Q(food_name_ko__iexact=food_name) |
            Q(food_name_en__iexact=food_name)
        ).first()
        
        if food:
            print(f"✅ [food_nutrition_service] DB에서 찾음: food_id={food.food_id}, food_name={food.food_name}")
            print(f"   원본 영양소 (100g 기준): calories={food.calories}, protein={food.protein}, carbs={food.carbs}")
            
            # DB는 100g 기준이므로 그대로 사용 (변환 없음)
            multiplier = 1.0
            print(f"   DB 기준 그대로 사용: 100g 기준, 배수: {multiplier}x")
            
            # DB의 실제 컬럼명에 맞춰서 반환 (100g 기준 그대로) (vitiamin_c는 DB 오타)
            nutrition = {
                'food_id': food.food_id,  # food_id 추가
                'calories': (food.calories or 0) * multiplier,
                'carbs': (food.carbs or 0) * multiplier,
                'protein': (food.protein or 0) * multiplier,
                'fat': (food.fat or 0) * multiplier,
                'sodium': (food.sodium or 0) * multiplier,
                'iron': (food.iron or 0) * multiplier,
                'calcium': (food.calcium or 0) * multiplier,
                'vitamin_c': (food.vitiamin_c or 0) * multiplier,  # DB 컬럼명이 vitiamin_c (오타)
                'folate': (food.folate or 0) * multiplier,
                'vitamin_d': (food.vitamin_d or 0) * multiplier,
                'omega3': (food.omega3 or 0) * multiplier,
                'sugar': (food.sugar or 0) * multiplier,
                'magnesium': (food.magnesium or 0) * multiplier,
                'vitamin_a': (food.vitamin_a or 0) * multiplier,
                'vitamin_b12': (food.vitamin_b or 0) * multiplier,  # DB에는 vitamin_b로 되어 있음
                'dietary_fiber': (food.dietary_fiber or 0) * multiplier,
                'potassium': (food.potassium or 0) * multiplier,
            }
            print(f"   반환된 영양소 (100g 기준): calories={nutrition['calories']}, protein={nutrition['protein']}, carbs={nutrition['carbs']}")
            return nutrition
        else:
            print(f"⚠️ [food_nutrition_service] DB에서 찾지 못함: '{food_name}'")
    except Exception as e:
        print(f"❌ [food_nutrition_service] DB 조회 오류: {e}")
        import traceback
        traceback.print_exc()
    
    return None


def find_similar_food(food_name: str) -> Optional[Dict]:
    """
    유사 음식 찾기 (예: "딸기케이크" → "케이크")
    
    전략:
    1. 음식 이름에서 접두사/접미사 제거 (딸기, 초콜릿, 바닐라 등)
    2. 카테고리 키워드 추출 (케이크, 빵, 국, 찌개 등)
    3. DB에서 유사한 음식 검색
    """
    if not food_name:
        return None
    
    # 1. 정확히 일치하는 경우 먼저 확인
    exact_match = get_food_nutrition_from_db(food_name)
    if exact_match:
        return exact_match
    
    # 2. 음식 이름에서 카테고리 키워드 추출
    category_keywords = [
        '케이크', '빵', '국', '찌개', '볶음', '구이', '튀김', '전', '죽', '밥',
        '면', '떡', '과자', '사탕', '아이스크림', '요거트', '샐러드', '샌드위치',
        '버거', '피자', '파스타', '스테이크', '치킨', '돈까스', '회', '초밥',
        '라면', '우동', '냉면', '비빔밥', '김밥', '떡볶이', '순대', '어묵',
        '만두', '수제비', '칼국수', '잔치국수', '냉면', '물냉면', '비빔냉면',
    ]
    
    # 영어 카테고리 키워드
    english_keywords = [
        'cake', 'bread', 'soup', 'stew', 'fried', 'grilled', 'pancake', 'rice',
        'noodle', 'pasta', 'pizza', 'burger', 'sandwich', 'salad', 'ice cream',
        'yogurt', 'cookie', 'candy', 'chicken', 'steak', 'sushi', 'ramen',
    ]
    
    # 음식 이름에서 카테고리 키워드 찾기
    found_keywords = []
    food_lower = food_name.lower()
    
    for keyword in category_keywords + english_keywords:
        if keyword in food_lower:
            found_keywords.append(keyword)
    
    # 3. 카테고리 키워드로 DB 검색
    if found_keywords:
        # 가장 긴 키워드부터 시도 (더 구체적인 매칭)
        found_keywords.sort(key=len, reverse=True)
        
        for keyword in found_keywords:
            try:
                # 키워드가 포함된 음식 검색 (food_name, food_name_ko, food_name_en 모두 검색)
                similar_foods = FoodNutritionMaster.objects.filter(
                    Q(food_name__icontains=keyword) |
                    Q(food_name_ko__icontains=keyword) |
                    Q(food_name_en__icontains=keyword)
                ).order_by('food_name')
                
                if similar_foods.exists():
                    # 첫 번째 유사 음식 반환
                    food = similar_foods.first()
                    print(f"🔍 [food_nutrition_service] 유사 음식 찾음: '{food_name}' → '{food.food_name}' (키워드: {keyword})")
                    
                    # DB는 100g 기준이므로 그대로 사용 (변환 없음)
                    multiplier = 1.0
                    return {
                        'food_id': food.food_id,  # food_id 추가
                        'calories': (food.calories or 0) * multiplier,
                        'carbs': (food.carbs or 0) * multiplier,
                        'protein': (food.protein or 0) * multiplier,
                        'fat': (food.fat or 0) * multiplier,
                        'sodium': (food.sodium or 0) * multiplier,
                        'iron': (food.iron or 0) * multiplier,
                        'calcium': (food.calcium or 0) * multiplier,
                        'vitamin_c': (food.vitiamin_c or 0) * multiplier,  # DB 컬럼명이 vitiamin_c (오타)
                        'folate': (food.folate or 0) * multiplier,
                        'vitamin_d': (food.vitamin_d or 0) * multiplier,
                        'omega3': (food.omega3 or 0) * multiplier,
                        'sugar': (food.sugar or 0) * multiplier,
                        'magnesium': (food.magnesium or 0) * multiplier,
                        'vitamin_a': (food.vitamin_a or 0) * multiplier,
                        'vitamin_b12': (food.vitamin_b or 0) * multiplier,  # DB에는 vitamin_b로 되어 있음
                        'dietary_fiber': (food.dietary_fiber or 0) * multiplier,
                        'potassium': (food.potassium or 0) * multiplier,
                    }
            except Exception as e:
                print(f"⚠️ [food_nutrition_service] 유사 음식 검색 오류: {e}")
                continue
    
    # 4. 부분 일치 검색 (마지막 시도)
    try:
        # 음식 이름의 일부로 검색 (food_name, food_name_ko, food_name_en 모두 검색)
        if len(food_name) >= 3:
            partial_match = FoodNutritionMaster.objects.filter(
                Q(food_name__icontains=food_name[:3]) |
                Q(food_name_ko__icontains=food_name[:3]) |
                Q(food_name_en__icontains=food_name[:3])
            ).first()
        else:
            partial_match = None
        
        if partial_match:
            # DB는 100g 기준이므로 그대로 사용 (변환 없음)
            multiplier = 1.0
            return {
                'food_id': partial_match.food_id,  # food_id 추가
                'calories': (partial_match.calories or 0) * multiplier,
                'carbs': (partial_match.carbs or 0) * multiplier,
                'protein': (partial_match.protein or 0) * multiplier,
                'fat': (partial_match.fat or 0) * multiplier,
                'sodium': (partial_match.sodium or 0) * multiplier,
                'iron': (partial_match.iron or 0) * multiplier,
                'calcium': (partial_match.calcium or 0) * multiplier,
                'vitamin_c': (partial_match.vitiamin_c or 0) * multiplier,  # DB 컬럼명이 vitiamin_c (오타)
                'folate': (partial_match.folate or 0) * multiplier,
                'vitamin_d': (partial_match.vitamin_d or 0) * multiplier,
                'omega3': (partial_match.omega3 or 0) * multiplier,
                'sugar': (partial_match.sugar or 0) * multiplier,
                'magnesium': (partial_match.magnesium or 0) * multiplier,
                'vitamin_a': (partial_match.vitamin_a or 0) * multiplier,
                'vitamin_b12': (partial_match.vitamin_b or 0) * multiplier,  # DB에는 vitamin_b로 되어 있음
                'dietary_fiber': (partial_match.dietary_fiber or 0) * multiplier,
                'potassium': (partial_match.potassium or 0) * multiplier,
            }
    except Exception as e:
        print(f"⚠️ [food_nutrition_service] 부분 일치 검색 오류: {e}")
    
    return None


def get_food_nutrition(food_name: str) -> Dict:
    """
    음식 이름으로 영양소 정보 조회 (메인 함수)
    
    1. 정확히 일치하는 경우: 해당 값 반환
    2. 유사 음식 찾기: 비슷한 카테고리 음식 반환
    3. 없으면 기본값 반환
    """
    if not food_name:
        return _get_default_nutrition()
    
    # 1. 정확히 일치하는 경우
    exact_match = get_food_nutrition_from_db(food_name)
    if exact_match:
        print(f"✅ [food_nutrition_service] 정확히 일치: {food_name}")
        return exact_match
    
    # 2. 유사 음식 찾기
    similar_match = find_similar_food(food_name)
    if similar_match:
        print(f"🔍 [food_nutrition_service] 유사 음식 매칭: {food_name} → (유사 음식)")
        return similar_match
    
    # 3. 기본값 반환
    print(f"⚠️ [food_nutrition_service] 영양소 정보 없음: {food_name}")
    return _get_default_nutrition()


def _get_default_nutrition() -> Dict:
    """기본 영양소 값 (모두 0)"""
    return {
        'calories': 0, 'carbs': 0, 'protein': 0, 'fat': 0,
        'sodium': 0, 'iron': 0, 'calcium': 0, 'vitamin_c': 0,
        'folate': 0, 'vitamin_d': 0, 'omega3': 0, 'sugar': 0,
        'magnesium': 0, 'vitamin_a': 0, 'vitamin_b12': 0,
        'dietary_fiber': 0, 'potassium': 0
    }

