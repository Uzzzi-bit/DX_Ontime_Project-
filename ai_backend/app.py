import os
import json
import sys
import asyncio
from typing import Optional, List, Dict, Any

from fastapi import FastAPI, File, UploadFile, Form, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import google.generativeai as genai
import base64
from PIL import Image
import io

# Django 설정을 위한 경로 추가 (AI 백엔드에서 Django DB 접근용)
try:
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    django_backend_path = os.path.join(project_root, 'django_backend')
    if django_backend_path not in sys.path:
        sys.path.insert(0, django_backend_path)
    
    # Django 설정 로드
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
    import django
    django.setup()
    
    # Django 모델 import
    from members.food_nutrition_service import get_food_nutrition, FoodNutritionMaster
    from members.prompts import NUTRITION_PROMPT_TEMPLATE
    DJANGO_AVAILABLE = True
    print("✅ Django 모델 로드 완료")
except Exception as e:
    DJANGO_AVAILABLE = False
    print(f"⚠️ Django 모델 로드 실패: {e}")
    print("   AI 백엔드에서 Django DB 접근이 불가능합니다.")
    # Django 모델이 없어도 AI가 직접 계산할 수 있도록 프롬프트 템플릿 직접 정의
    NUTRITION_PROMPT_TEMPLATE = """
당신은 임산부 영양 데이터 추론 전문가입니다.
주어진 음식 데이터를 바탕으로 **'한국인의 일반적인 1회 제공량(1인분)'**을 합리적으로 추정하고, 임산부에게 중요한 영양소를 꼼꼼히 계산하세요.

[중요 지침]
1. **양(Quantity):** 임산부라고 해서 과도하게 많이 잡지 말고, 식당이나 가정에서 제공되는 **'객관적인 1인분 표준(Standard Serving)'**을 기준으로 추정하세요.
2. **영양소(Nutrients):** 임산부에게 필수적인 **철분(Iron), 엽산(Folic Acid), 칼슘** 정보가 있다면 누락하지 말고 반드시 포함하세요. (값이 없으면 0)
3. **조리 상태:** 면류나 국물 요리는 건더기나 건면이 아닌, **'조리되어 그릇에 담긴 최종 무게(Cooked)'**를 기준으로 하세요.
4. **고기류:** 뼈 무게를 제외한 **'실제 섭취 가능한 살코기(가식부)'** 기준으로 추정하세요.

[참고 기준 (Reference Examples) - 한국 표준 1인분]
- **국/탕류 (갈비탕, 설렁탕):** 국물/건더기 포함 뚝배기 700g~800g (배수: 3.5~4.0)
- **면류 (파스타, 짜장면):** 조리 후 그릇 담김 기준 400g~500g (배수: 2.0~2.5)
- **밥류 (비빔밥, 덮밥):** 밥과 토핑 포함 400g~500g (배수: 2.0~2.5)
- **고기류 (수육, 삼겹살):** 1인분 고기 양 180g~250g (메인 요리 기준)
- **과일 (사과, 배):** 1개 250g~300g (배수: 1.2~1.5)
- **피자/패스트푸드:** 라지 사이즈 피자 2~3조각 또는 햄버거 1개 기준 300g~450g (배수: 1.5~2.2)

[입력 데이터 (DB 기준: {std_amount}g)]
- 음식명: {food_name}
- 영양성분: {nutrients_json}

[수행 과제]
1. 현실적인 1인분 중량(g)을 직접 결정하세요. (serving_size_gram 필드에 숫자로 입력)
2. 결정한 1인분 중량에 맞게 모든 영양소를 직접 계산하세요.
   - DB 데이터가 있으면 참고하되, 최종 1인분에 맞게 재계산하세요.
   - DB 데이터가 없어도 음식명을 바탕으로 전문 지식으로 계산하세요.
3. 모든 영양소 필드를 반드시 채워주세요. (값이 없으면 0)
4. 결과는 JSON으로만 출력하세요.

[JSON 출력 형식]
{{
    "food_name": "{food_name}",
    "serving_desc": "1인분 (약 000g)",
    "serving_size_gram": 0.0,
    "total_calories": 0,
    "nutrients": {{
        "carbs": 0,
        "protein": 0,
        "fat": 0,
        "sugar": 0,
        "sodium": 0,
        "iron": 0,
        "calcium": 0,
        "vitamin_c": 0,
        "folate": 0,
        "magnesium": 0,
        "omega3": 0,
        "vitamin_a": 0,
        "vitamin_b12": 0,
        "vitamin_d": 0,
        "dietary_fiber": 0,
        "potassium": 0
    }}
}}
"""
    # get_food_nutrition 함수도 None 반환 함수로 정의
    def get_food_nutrition(food_name: str):
        return None

# YOLO 모듈 import
try:
    from yolo_detector import detect_food_objects, load_yolo_model
    YOLO_AVAILABLE = True
except ImportError:
    YOLO_AVAILABLE = False
    print("⚠️ YOLO 모듈을 불러올 수 없습니다. YOLO 기능이 비활성화됩니다.")

# =========================
# 0. GEMINI API 키 설정
# =========================

API_KEY = os.environ.get("GEMINI_API_KEY")
if not API_KEY:
    raise ValueError(
        "GEMINI_API_KEY 환경 변수가 없습니다.\n"
        "터미널에서 아래처럼 먼저 설정해 주세요:\n"
        '  export GEMINI_API_KEY="여기에_API_키"\n'
    )

genai.configure(api_key=API_KEY)
MODEL_ID = "gemini-2.5-flash"

# =========================
# 1. 프롬프트 / 룰 / KB 파일 로드
# (app.py와 같은 폴더에 있다고 가정)
# =========================

BASE_DIR = os.path.dirname(os.path.abspath(__file__))


def read_text(filename: str) -> str:
    path = os.path.join(BASE_DIR, filename)
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def read_json(filename: str):
    path = os.path.join(BASE_DIR, filename)
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


CAN_EAT_TEMPLATE = read_text("can_eat_prompt.txt")
RECIPES_TEMPLATE = read_text("recommend_recipes_prompt.txt")
CHAT_TEMPLATE = read_text("can_eat_prompt.txt")  # 채팅도 can_eat_prompt.txt 사용
RULES_JSON = read_json("pregnancy_ai_rules.json")
FOOD_KB_MD = read_text("pregnancy_nutrition_and_food_safety_kb.md")

# =========================
# 2. 아주 단순한 템플릿 치환 함수
# =========================

def render_template(template: str, **kwargs) -> str:
    text = template
    for key, value in kwargs.items():
        placeholder = "{{" + key + "}}"
        if isinstance(value, (dict, list)):
            value = json.dumps(value, ensure_ascii=False, indent=2)
        text = text.replace(placeholder, str(value))
    return text


# =========================
# 3. 요청/응답 모델 정의
# =========================

class CanEatRequest(BaseModel):
    nickname: str = "사용자"
    week: int = 12
    conditions: Optional[str] = "없음"
    user_text_or_image_desc: str


class RecipesRequest(BaseModel):
    nickname: str = "사용자"
    week: int = 20
    bmi: float = 22.0
    conditions: Optional[str] = "없음"
    allergies: Optional[List[str]] = []  # 알러지 리스트 추가

    # 기본 영양소
    today_calories: float = 0
    today_calories_ratio: float = 0
    today_carbs: float = 0
    today_carbs_ratio: float = 0
    today_protein: float = 0
    today_protein_ratio: float = 0
    today_fat: float = 0
    today_fat_ratio: float = 0
    today_sugar: float = 0
    today_sugar_ratio: float = 0  # 프롬프트에는 없지만 Flutter에서 전송함
    today_sodium: float = 0
    today_sodium_ratio: float = 0
    today_calcium: float = 0
    today_calcium_ratio: float = 0
    today_iron: float = 0
    today_iron_ratio: float = 0
    today_folate: float = 0
    today_folate_ratio: float = 0
    today_magnesium: float = 0
    today_magnesium_ratio: float = 0
    today_omega3: float = 0
    today_omega3_ratio: float = 0  # 프롬프트에는 없지만 Flutter에서 전송함
    today_vitamin_a: float = 0
    today_vita_a_ratio: float = 0
    today_vitamin_b: float = 0  # vitamin_b12를 vitamin_b로 매핑
    today_vita_b_ratio: float = 0
    today_vitamin_c: float = 0
    today_vita_c_ratio: float = 0
    today_vitamin_d: float = 0
    today_vita_d_ratio: float = 0
    today_dietary_fiber: float = 0
    today_fiber_ratio: float = 0
    today_potassium: float = 0
    today_potassium_ratio: float = 0


class CanEatResponse(BaseModel):
    status: str
    headline: str
    reason: str
    target_type: str
    item_name: str


class ChatRequest(BaseModel):
    nickname: str = "사용자"
    week: int = 12
    conditions: Optional[str] = "없음"
    user_message: str
    chat_history: Optional[List[Any]] = None
    image_base64: Optional[str] = None  # base64 인코딩된 이미지


class ChatResponse(BaseModel):
    message: str


class AnalyzeNutritionRequest(BaseModel):
    image_base64: str  # base64 인코딩된 이미지


class AnalyzeNutritionResponse(BaseModel):
    success: bool
    foods: List[Dict[str, Any]]  # [{"name": "apple", "confidence": 0.9}, ...]
    count: int
    error: Optional[str] = None


class AnalyzeFoodNutritionRequest(BaseModel):
    foods: List[Dict[str, Any]]  # [{"name": "apple", "confidence": 0.9}, ...]


class FoodNutritionResult(BaseModel):
    food_name: str
    food_id: Optional[int] = None
    calories: float = 0
    carbs: float = 0
    protein: float = 0
    fat: float = 0
    sodium: float = 0
    iron: float = 0
    calcium: float = 0
    vitamin_c: float = 0
    sugar: float = 0
    folate: float = 0
    magnesium: float = 0
    omega3: float = 0
    vitamin_a: float = 0
    vitamin_b12: float = 0
    vitamin_d: float = 0
    dietary_fiber: float = 0
    potassium: float = 0
    serving_size_gram: float = 100.0  # 기본 100g 기준


class AnalyzeFoodNutritionResponse(BaseModel):
    success: bool
    nutrition_results: List[FoodNutritionResult]
    error: Optional[str] = None


# =========================
# 4. FastAPI 앱 생성 + CORS
# =========================

app = FastAPI(title="Pregnancy AI Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 나중에 필요하면 도메인 제한
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Validation 에러 핸들러 추가
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    body = await request.body()
    print(f"❌ [AI Backend] Validation 에러:")
    print(f"  - 요청 경로: {request.url}")
    print(f"  - 에러: {exc.errors()}")
    print(f"  - 요청 본문: {body.decode('utf-8')[:500] if body else 'None'}")
    return JSONResponse(
        status_code=422,
        content={"detail": exc.errors(), "body": body.decode('utf-8')[:500] if body else 'None'},
    )


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/api/can-eat", response_model=CanEatResponse)
async def can_eat(req: CanEatRequest):
    prompt = render_template(
        CAN_EAT_TEMPLATE,
        RULES_JSON=RULES_JSON,
        FOOD_KB_MD=FOOD_KB_MD,
        nickname=req.nickname,
        week=req.week,
        conditions=req.conditions or "없음",
        user_text_or_image_desc=req.user_text_or_image_desc,
    )

    model = genai.GenerativeModel(MODEL_ID)
    gemini_resp = model.generate_content(prompt)
    raw = gemini_resp.text.strip()

    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        raise ValueError(f"모델 JSON 파싱 실패: {raw}")

    return data


@app.post("/api/recommend-recipes")
async def recommend_recipes(req: RecipesRequest):
    try:
        # 알러지 리스트를 문자열로 변환 (콤마로 구분)
        allergies_str = ", ".join(req.allergies) if req.allergies else "없음"
        
        print(f"🔍 [AI Backend] 요청 수신:")
        print(f"  - nickname: {req.nickname}")
        print(f"  - week: {req.week}")
        print(f"  - bmi: {req.bmi}")
        print(f"  - conditions: {req.conditions}")
        print(f"  - allergies: {allergies_str}")
        print(f"  - today_calories: {req.today_calories}")
        print(f"  - today_carbs: {req.today_carbs}")
        print(f"  - today_sugar: {req.today_sugar}, today_sugar_ratio: {req.today_sugar_ratio}")
        print(f"  - today_omega3: {req.today_omega3}, today_omega3_ratio: {req.today_omega3_ratio}")
        
        # 프롬프트에 모든 영양소 데이터 전달
        prompt = render_template(
        RECIPES_TEMPLATE,
        RULES_JSON=RULES_JSON,
        FOOD_KB_MD=FOOD_KB_MD,
        nickname=req.nickname,
        week=req.week,
        bmi=req.bmi,
        conditions=req.conditions or "없음",
        allergies=allergies_str,
        # 기본 영양소
        today_carbs=req.today_carbs,
        today_carbs_ratio=req.today_carbs_ratio,
        today_protein=req.today_protein,
        today_protein_ratio=req.today_protein_ratio,
        today_fat=req.today_fat,
        today_fat_ratio=req.today_fat_ratio,
        today_sugar=req.today_sugar,
        today_sugar_ratio=req.today_sugar_ratio,  # 프롬프트에는 없지만 전달 (에러 방지)
        today_sodium=req.today_sodium,
        today_sodium_ratio=req.today_sodium_ratio,
        today_calcium=req.today_calcium,
        today_calcium_ratio=req.today_calcium_ratio,
        today_iron=req.today_iron,
        today_iron_ratio=req.today_iron_ratio,
        today_folate=req.today_folate,
        today_folate_ratio=req.today_folate_ratio,
        today_magnesium=req.today_magnesium,
        today_magnesium_ratio=req.today_magnesium_ratio,
        today_omega3=req.today_omega3,
        today_omega3_ratio=req.today_omega3_ratio,  # 프롬프트에는 없지만 전달 (에러 방지)
        today_vitamin_a=req.today_vitamin_a,
        today_vita_a_ratio=req.today_vita_a_ratio,
        today_vitamin_b=req.today_vitamin_b,
        today_vita_b_ratio=req.today_vita_b_ratio,
        today_vitamin_c=req.today_vitamin_c,
        today_vita_c_ratio=req.today_vita_c_ratio,
        today_vitamin_d=req.today_vitamin_d,
        today_vita_d_ratio=req.today_vita_d_ratio,
        today_dietary_fiber=req.today_dietary_fiber,
        today_fiber_ratio=req.today_fiber_ratio,
        today_potassium=req.today_potassium,
        today_potassium_ratio=req.today_potassium_ratio,
    )

        model = genai.GenerativeModel(MODEL_ID)
        gemini_resp = model.generate_content(prompt)
        raw = gemini_resp.text.strip()

        # 디버그: Gemini 응답 확인
        print(f"🔍 [AI Backend] Gemini 응답 (처음 500자): {raw[:500]}")
        if len(raw) > 500:
            print(f"🔍 [AI Backend] Gemini 응답 (나머지): ...{raw[-200:]}")

        # 마크다운 코드 블록 제거 (```json ... ``` 형식)
        if raw.startswith("```json"):
            raw = raw[7:]  # "```json" 제거
        elif raw.startswith("```"):
            raw = raw[3:]  # "```" 제거

        if raw.endswith("```"):
            raw = raw[:-3]  # 끝의 "```" 제거

        raw = raw.strip()

        try:
            data = json.loads(raw)
            recipes_count = len(data.get('recipes', []))
            banner_msg = data.get('bannerMessage', '')
            print(f"✅ [AI Backend] JSON 파싱 성공:")
            print(f"  - recipes 개수: {recipes_count}")
            print(f"  - bannerMessage: {banner_msg[:100] if banner_msg else 'None'}")
            
            # 레시피가 3개인지 확인
            if recipes_count != 3:
                print(f"⚠️ [AI Backend] 레시피 개수가 3개가 아닙니다: {recipes_count}개")
            
            # 각 레시피의 필수 필드 확인
            for i, recipe in enumerate(data.get('recipes', [])):
                if not isinstance(recipe, dict):
                    print(f"❌ [AI Backend] 레시피 {i+1}이 dict가 아닙니다: {type(recipe)}")
                    continue
                required_fields = ['title', 'fullTitle', 'ingredients', 'cookingSteps', 'calories']
                missing_fields = [f for f in required_fields if f not in recipe]
                if missing_fields:
                    print(f"⚠️ [AI Backend] 레시피 {i+1}에 필수 필드 누락: {missing_fields}")
                else:
                    print(f"✅ [AI Backend] 레시피 {i+1} 필수 필드 확인 완료: {recipe.get('title', 'N/A')}")
            
            return data
        except json.JSONDecodeError as e:
            print(f"❌ [AI Backend] JSON 파싱 실패:")
            print(f"  - 에러: {e}")
            print(f"  - 원본 응답: {raw[:1000]}")
            raise ValueError(f"모델 JSON 파싱 실패: {e}\n원본 응답: {raw[:500]}")
    except Exception as e:
        import traceback
        error_trace = traceback.format_exc()
        print(f"❌ [AI Backend] recommend_recipes 에러:")
        print(f"  - 에러 타입: {type(e).__name__}")
        print(f"  - 에러 메시지: {str(e)}")
        print(f"  - 스택 트레이스:\n{error_trace}")
        # FastAPI 에러 응답
        from fastapi import HTTPException
        raise HTTPException(
            status_code=500,
            detail=f"서버 내부 오류: {str(e)}"
        )


@app.post("/api/chat", response_model=ChatResponse)
async def chat(req: ChatRequest):
    """일반 대화형 채팅 엔드포인트 - can_eat_prompt.txt 사용 (이미지 지원)"""
    # 프롬프트 생성 (can_eat_prompt.txt 사용)
    prompt = render_template(
        CAN_EAT_TEMPLATE,  # can_eat_prompt.txt 사용
        RULES_JSON=RULES_JSON,
        FOOD_KB_MD=FOOD_KB_MD,
        nickname=req.nickname,
        week=req.week,
        conditions=req.conditions or "없음",
        user_text_or_image_desc=req.user_message,
    )

    model = genai.GenerativeModel(MODEL_ID)

    # 이미지가 있으면 이미지와 함께 전송
    if req.image_base64:
        try:
            # base64 디코딩
            image_data = base64.b64decode(req.image_base64)
            image = Image.open(io.BytesIO(image_data))

            # 이미지와 텍스트를 함께 전송
            gemini_resp = model.generate_content([prompt, image])
        except Exception as e:
            # 이미지 처리 실패 시 텍스트만 전송
            print(f"이미지 처리 오류: {e}")
            gemini_resp = model.generate_content(prompt)
    else:
        # 이미지가 없으면 텍스트만 전송
        gemini_resp = model.generate_content(prompt)

    raw = gemini_resp.text.strip()

    # 마크다운 코드 블록 제거 (```json ... ``` 형식)
    if raw.startswith("```json"):
        raw = raw[7:]  # "```json" 제거
    elif raw.startswith("```"):
        raw = raw[3:]  # "```" 제거

    if raw.endswith("```"):
        raw = raw[:-3]  # 끝의 "```" 제거

    raw = raw.strip()

    try:
        # JSON 형식으로 파싱 시도
        data = json.loads(raw)
        # JSON이면 headline과 reason을 합쳐서 반환
        response_text = f"{data.get('headline', '')}\n\n{data.get('reason', '')}"
        return ChatResponse(message=response_text)
    except json.JSONDecodeError:
        # JSON이 아니면 그대로 텍스트로 반환
        return ChatResponse(message=raw)


@app.post("/api/analyze-nutrition", response_model=AnalyzeNutritionResponse)
async def analyze_nutrition(req: AnalyzeNutritionRequest):
    """
    YOLO를 사용하여 이미지에서 음식 객체 탐지
    반환: 음식 리스트 (JSON 형식)
    """
    if not YOLO_AVAILABLE:
        print("⚠️ YOLO 모듈을 사용할 수 없습니다.")
        return AnalyzeNutritionResponse(
            success=False,
            foods=[],
            count=0,
            error="YOLO 모듈을 사용할 수 없습니다."
        )
    
    try:
        print(f"🔄 YOLO 분석 시작 (이미지 크기: {len(req.image_base64)} bytes)")
        
        # YOLO로 음식 객체 탐지 (여러 모델 버전 시도)
        result = None
        model_versions = ["v3-spp", "v3", "v8"]
        
        for model_version in model_versions:
            try:
                print(f"   {model_version} 모델로 시도 중...")
                result = detect_food_objects(
                    image_base64=req.image_base64,
                    model_version=model_version,
                    confidence_threshold=0.25  # 더 낮은 임계값으로 더 많은 음식 탐지
                )
                
                if result.get("success"):
                    print(f"✅ {model_version} 모델로 탐지 성공!")
                    break
                else:
                    print(f"   ⚠️ {model_version} 모델 탐지 실패: {result.get('error')}")
            except Exception as e:
                print(f"   ⚠️ {model_version} 모델 오류: {e}")
                continue
        
        if result is None or not result.get("success"):
            error_msg = result.get("error", "YOLO 탐지 실패") if result else "모든 YOLO 모델 로드 실패"
            print(f"❌ YOLO 분석 실패: {error_msg}")
            return AnalyzeNutritionResponse(
                success=False,
                foods=[],
                count=0,
                error=error_msg
            )
        
        # 탐지된 객체를 음식 리스트로 변환
        detections = result.get("detections", [])
        foods = []
        
        for det in detections:
            foods.append({
                "name": det.get("class", ""),
                "confidence": det.get("confidence", 0.0)
            })
        
        print(f"✅ YOLO 분석 완료: {len(foods)}개 음식 탐지")
        return AnalyzeNutritionResponse(
            success=True,
            foods=foods,
            count=len(foods)
        )
    
    except Exception as e:
        print(f"❌ YOLO 분석 중 예외 발생: {e}")
        import traceback
        traceback.print_exc()
        return AnalyzeNutritionResponse(
            success=False,
            foods=[],
            count=0,
            error=f"YOLO 분석 오류: {str(e)}"
        )


async def estimate_serving_size_only(food_name: str) -> float:
    """
    AI가 1인분 무게만 추정 (DB에 있는 음식용)
    """
    prompt = f"""음식 이름: "{food_name}"

다음 규칙에 따라 조리된 상태(Cooked)의 한국 여성 1인분 무게(그램)를 추정해주세요:

**중요 규칙:**
1. 반드시 '조리된 상태(Cooked)'의 무게로 추정하세요.
2. 특히 면류(파스타, 국수, 라면, 우동 등)는 건면 무게가 아니라 소스와 국물을 포함한 '최종 섭취 무게'를 기준으로 한국 여성 1인분을 계산하세요.
3. 한국 여성의 평균 1인분 섭취량을 기준으로 하세요.
4. 숫자만 반환하세요 (예: 250, 300, 400 등). 단위나 설명 없이 숫자만.

예시:
- 파스타: 건면 100g → 조리 후 + 소스 포함 → 약 250g
- 라면: 건면 100g → 조리 후 + 국물 포함 → 약 400g
- 밥: 약 200g
- 국수: 건면 100g → 조리 후 + 국물 포함 → 약 350g

음식: {food_name}
한국 여성 1인분 무게 (그램, 숫자만):"""
    
    try:
        model = genai.GenerativeModel(MODEL_ID)
        response = model.generate_content(prompt)
        result_text = response.text.strip()
        
        # 숫자만 추출
        import re
        numbers = re.findall(r'\d+', result_text)
        if numbers:
            estimated_gram = float(numbers[0])
            print(f"   🤖 AI 무게 추정: {food_name} → {estimated_gram}g")
            return estimated_gram
        else:
            print(f"   ⚠️ AI 응답에서 숫자를 찾을 수 없음: {result_text}, 기본값 200g 사용")
            return 200.0
    except Exception as e:
        print(f"   ⚠️ AI 무게 추정 실패: {e}, 기본값 200g 사용")
        return 200.0


async def analyze_nutrition_with_ai(food_name: str, nutrition: Optional[Dict] = None) -> Dict:
    """
    prompts.py의 NUTRITION_PROMPT_TEMPLATE을 사용하여 AI로 영양소 분석
    AI가 직접 무게와 모든 영양소를 계산합니다.
    
    Args:
        food_name: 음식 이름
        nutrition: DB에서 가져온 영양소 정보 (참고용, 선택적)
    
    Returns:
        {
            'serving_size_gram': float,  # AI가 추정한 1인분 무게
            'calculated_nutrition': Dict  # AI가 계산한 모든 영양소 값들
        }
    """
    try:
        # DB 기준량 (100g) - 참고용
        std_amount = 100.0
        
        # DB 영양소 정보가 있으면 참고용으로 제공 (없어도 AI가 직접 계산)
        nutrients_json = "{}"
        if nutrition:
            nutrients_data = {
                'calories': nutrition.get('calories', 0),
                'carbs': nutrition.get('carbs', 0),
                'protein': nutrition.get('protein', 0),
                'fat': nutrition.get('fat', 0),
                'sugar': nutrition.get('sugar', 0),
                'sodium': nutrition.get('sodium', 0),
                'iron': nutrition.get('iron', 0),
                'calcium': nutrition.get('calcium', 0),
                'vitamin_c': nutrition.get('vitamin_c', 0),
                'folate': nutrition.get('folate', 0),
                'magnesium': nutrition.get('magnesium', 0),
                'omega3': nutrition.get('omega3', 0),
                'vitamin_a': nutrition.get('vitamin_a', 0),
                'vitamin_b12': nutrition.get('vitamin_b12', 0),
                'vitamin_d': nutrition.get('vitamin_d', 0),
                'dietary_fiber': nutrition.get('dietary_fiber', 0),
                'potassium': nutrition.get('potassium', 0),
            }
            nutrients_json = json.dumps(nutrients_data, ensure_ascii=False, indent=2)
        
        # 프롬프트 템플릿에 데이터 채우기
        prompt = NUTRITION_PROMPT_TEMPLATE.format(
            std_amount=std_amount,
            food_name=food_name,
            nutrients_json=nutrients_json
        )
        
        print(f"   🤖 AI 영양소 분석 요청: '{food_name}' (AI가 직접 계산)")
        model = genai.GenerativeModel(MODEL_ID)
        response = model.generate_content(prompt)
        result_text = response.text.strip()
        
        print(f"   📝 AI 응답 (원본): {result_text[:500]}...")
        
        # JSON 파싱 시도
        try:
            # JSON 코드 블록 제거 (```json ... ``` 형식)
            import re
            json_match = re.search(r'\{[\s\S]*\}', result_text)
            if json_match:
                result_text = json_match.group(0)
            
            ai_result = json.loads(result_text)
            
            # AI가 추정한 무게 추출
            serving_size_gram = ai_result.get('serving_size_gram', 0.0)
            serving_desc = ai_result.get('serving_desc', '')
            
            # serving_size_gram이 없으면 serving_desc에서 추출
            if serving_size_gram == 0.0 and serving_desc:
                numbers = re.findall(r'\d+', serving_desc)
                if numbers:
                    serving_size_gram = float(numbers[0])
            
            # serving_size_gram이 여전히 0이면 기본값 사용하지 않고 에러
            if serving_size_gram == 0.0:
                raise ValueError(f"AI가 무게를 추정하지 못했습니다. serving_desc: {serving_desc}")
            
            print(f"   ✅ AI 분석 결과:")
            print(f"      - serving_desc: {serving_desc}")
            print(f"      - serving_size_gram: {serving_size_gram}g")
            
            # AI가 계산한 모든 영양소 값 사용
            calculated_nutrition = {}
            if 'nutrients' in ai_result:
                ai_nutrients = ai_result['nutrients']
                # AI가 계산한 모든 영양소 값 사용 (없으면 0)
                calculated_nutrition = {
                    'calories': ai_result.get('total_calories', 0),
                    'carbs': ai_nutrients.get('carbs', 0),
                    'protein': ai_nutrients.get('protein', 0),
                    'fat': ai_nutrients.get('fat', 0),
                    'sugar': ai_nutrients.get('sugar', 0),
                    'sodium': ai_nutrients.get('sodium', 0),
                    'iron': ai_nutrients.get('iron', 0),
                    'calcium': ai_nutrients.get('calcium', 0),
                    'vitamin_c': ai_nutrients.get('vitamin_c', 0),
                    'folate': ai_nutrients.get('folate', 0),  # folic_acid -> folate 매핑
                    'magnesium': ai_nutrients.get('magnesium', 0),
                    'omega3': ai_nutrients.get('omega3', 0),
                    'vitamin_a': ai_nutrients.get('vitamin_a', 0),
                    'vitamin_b12': ai_nutrients.get('vitamin_b12', 0),
                    'vitamin_d': ai_nutrients.get('vitamin_d', 0),
                    'dietary_fiber': ai_nutrients.get('dietary_fiber', 0),
                    'potassium': ai_nutrients.get('potassium', 0),
                }
                # folic_acid가 있으면 folate로 매핑
                if 'folic_acid' in ai_nutrients and calculated_nutrition['folate'] == 0:
                    calculated_nutrition['folate'] = ai_nutrients.get('folic_acid', 0)
            else:
                raise ValueError("AI 응답에 'nutrients' 필드가 없습니다.")
            
            print(f"      - 계산된 영양소: calories={calculated_nutrition.get('calories', 0):.1f}kcal, protein={calculated_nutrition.get('protein', 0):.1f}g, carbs={calculated_nutrition.get('carbs', 0):.1f}g")
            
            return {
                'serving_size_gram': serving_size_gram,
                'calculated_nutrition': calculated_nutrition
            }
            
        except json.JSONDecodeError as e:
            print(f"   ⚠️ AI 응답 JSON 파싱 실패: {e}")
            print(f"   응답 텍스트: {result_text}")
            raise ValueError(f"AI 응답을 JSON으로 파싱할 수 없습니다: {e}")
            
    except Exception as e:
        print(f"   ⚠️ AI 영양소 분석 실패: {e}")
        import traceback
        traceback.print_exc()
        raise  # 에러를 상위로 전달하여 처리


@app.post("/api/analyze-food-nutrition", response_model=AnalyzeFoodNutritionResponse)
async def analyze_food_nutrition(req: AnalyzeFoodNutritionRequest):
    """
    음식 리스트를 받아서 member_food_nutrition_master 테이블을 기반으로
    각 음식의 영양소를 분석하여 반환
    
    AI를 사용하여 조리된 상태의 한국 여성 1인분 무게를 추정하고,
    그에 맞게 영양소를 계산합니다.
    """
    print(f"🔄 [analyze_food_nutrition] 요청 수신: {len(req.foods)}개 음식")
    print(f"   DJANGO_AVAILABLE: {DJANGO_AVAILABLE}")
    
    # Django 모델이 없어도 AI가 직접 계산할 수 있으므로 계속 진행
    if not DJANGO_AVAILABLE:
        print(f"⚠️ [analyze_food_nutrition] Django 모델을 사용할 수 없지만, AI가 직접 계산합니다.")
    
    try:
        print(f"🔄 [analyze_food_nutrition] 영양소 분석 시작: {len(req.foods)}개 음식")
        
        # 각 음식 분석을 위한 비동기 함수 정의
        async def analyze_single_food(food_item: Dict) -> FoodNutritionResult:
            food_name = food_item.get('name', '')
            if not food_name:
                print(f"   ⚠️ 음식 이름이 없습니다: {food_item}")
                return FoodNutritionResult(
                    food_name="알 수 없음",
                    calories=0, carbs=0, protein=0, fat=0, sodium=0, iron=0, calcium=0,
                    vitamin_c=0, sugar=0, folate=0, magnesium=0, omega3=0, vitamin_a=0,
                    vitamin_b12=0, vitamin_d=0, dietary_fiber=0, potassium=0,
                    serving_size_gram=200.0
                )
            
            print(f"   📊 영양소 조회: '{food_name}'")
            
            try:
                # 1. DB에서 영양소 정보 조회 (member_food_nutrition_master 테이블 참고)
                nutrition = None
                food_id = None
                db_found = False
                
                if DJANGO_AVAILABLE:
                    try:
                        nutrition = get_food_nutrition(food_name)
                        # get_food_nutrition이 기본값(모두 0)을 반환했는지 확인
                        if nutrition and nutrition.get('calories', 0) > 0:
                            food_id = nutrition.get('food_id')
                            db_found = True
                            print(f"   ✅ '{food_name}' DB에서 찾음 (food_id={food_id})")
                        else:
                            print(f"   ⚠️ '{food_name}' DB에 없음 (AI로 분석 필요)")
                    except Exception as e:
                        print(f"   ⚠️ '{food_name}' DB 조회 실패: {e}")
                else:
                    print(f"   ⚠️ Django 모델 없음, AI로 직접 계산")
                
                # 2. DB에 있는 경우: DB 값(100g 기준) + AI가 1인분 무게 추정 → 계산
                #    DB에 없는 경우: AI가 prompts.py 프롬프트로 전체 분석
                if db_found and nutrition:
                    # DB에 있는 음식: AI가 1인분 무게만 추정하고, DB 값으로 계산
                    print(f"   📊 DB 값 사용 + AI 무게 추정: '{food_name}'")
                    
                    # AI가 1인분 무게만 추정 (간단한 프롬프트)
                    estimated_serving_gram = await estimate_serving_size_only(food_name)
                    multiplier = estimated_serving_gram / 100.0
                    
                    print(f"      - DB 값 (100g 기준): calories={nutrition.get('calories', 0)}kcal")
                    print(f"      - AI 추정 1인분: {estimated_serving_gram}g")
                    print(f"      - 계산 배수: {multiplier}x")
                    
                    # DB 값 × 배수로 계산
                    calculated_nutrition = {
                        'calories': nutrition.get('calories', 0) * multiplier,
                        'carbs': nutrition.get('carbs', 0) * multiplier,
                        'protein': nutrition.get('protein', 0) * multiplier,
                        'fat': nutrition.get('fat', 0) * multiplier,
                        'sodium': nutrition.get('sodium', 0) * multiplier,
                        'iron': nutrition.get('iron', 0) * multiplier,
                        'calcium': nutrition.get('calcium', 0) * multiplier,
                        'vitamin_c': nutrition.get('vitamin_c', 0) * multiplier,
                        'sugar': nutrition.get('sugar', 0) * multiplier,
                        'folate': nutrition.get('folate', 0) * multiplier,
                        'magnesium': nutrition.get('magnesium', 0) * multiplier,
                        'omega3': nutrition.get('omega3', 0) * multiplier,
                        'vitamin_a': nutrition.get('vitamin_a', 0) * multiplier,
                        'vitamin_b12': nutrition.get('vitamin_b12', 0) * multiplier,
                        'vitamin_d': nutrition.get('vitamin_d', 0) * multiplier,
                        'dietary_fiber': nutrition.get('dietary_fiber', 0) * multiplier,
                        'potassium': nutrition.get('potassium', 0) * multiplier,
                    }
                else:
                    # DB에 없는 음식: AI가 prompts.py 프롬프트로 전체 분석
                    print(f"   🤖 AI 전체 분석: '{food_name}' (DB에 없음)")
                    ai_analysis = await analyze_nutrition_with_ai(food_name, None)
                    estimated_serving_gram = ai_analysis['serving_size_gram']
                    calculated_nutrition = ai_analysis['calculated_nutrition']
                
                print(f"   📊 최종 분석 결과:")
                print(f"      - 1인분 무게: {estimated_serving_gram}g")
                print(f"      - 영양소: calories={calculated_nutrition.get('calories', 0):.1f}kcal, protein={calculated_nutrition.get('protein', 0):.1f}g, carbs={calculated_nutrition.get('carbs', 0):.1f}g")
                
                # 3. FoodNutritionResult 생성
                result = FoodNutritionResult(
                    food_name=food_name,
                    food_id=food_id,  # DB에서 가져온 food_id (있으면)
                    calories=calculated_nutrition.get('calories', 0),
                    carbs=calculated_nutrition.get('carbs', 0),
                    protein=calculated_nutrition.get('protein', 0),
                    fat=calculated_nutrition.get('fat', 0),
                    sodium=calculated_nutrition.get('sodium', 0),
                    iron=calculated_nutrition.get('iron', 0),
                    calcium=calculated_nutrition.get('calcium', 0),
                    vitamin_c=calculated_nutrition.get('vitamin_c', 0),
                    sugar=calculated_nutrition.get('sugar', 0),
                    folate=calculated_nutrition.get('folate', 0),
                    magnesium=calculated_nutrition.get('magnesium', 0),
                    omega3=calculated_nutrition.get('omega3', 0),
                    vitamin_a=calculated_nutrition.get('vitamin_a', 0),
                    vitamin_b12=calculated_nutrition.get('vitamin_b12', 0),
                    vitamin_d=calculated_nutrition.get('vitamin_d', 0),
                    dietary_fiber=calculated_nutrition.get('dietary_fiber', 0),
                    potassium=calculated_nutrition.get('potassium', 0),
                    serving_size_gram=estimated_serving_gram
                )
                
                print(f"   ✅ '{food_name}' 영양소 분석 완료:")
                print(f"      - 1인분 무게: {estimated_serving_gram}g")
                print(f"      - 최종 영양소: calories={result.calories:.1f}kcal, protein={result.protein:.1f}g, carbs={result.carbs:.1f}g")
                return result
            except Exception as e:
                print(f"   ❌ '{food_name}' 영양소 조회 실패: {e}")
                import traceback
                traceback.print_exc()
                # 실패해도 기본값으로 반환
                return FoodNutritionResult(
                    food_name=food_name,
                    calories=0,
                    carbs=0,
                    protein=0,
                    fat=0,
                    sodium=0,
                    iron=0,
                    calcium=0,
                    vitamin_c=0,
                    sugar=0,
                    folate=0,
                    magnesium=0,
                    omega3=0,
                    vitamin_a=0,
                    vitamin_b12=0,
                    vitamin_d=0,
                    dietary_fiber=0,
                    potassium=0,
                    serving_size_gram=200.0  # 기본값
                )
        
        # 모든 음식을 병렬로 처리 (asyncio.gather 사용)
        print(f"🚀 [analyze_food_nutrition] {len(req.foods)}개 음식을 병렬로 분석 시작")
        tasks = [analyze_single_food(food_item) for food_item in req.foods]
        nutrition_results = await asyncio.gather(*tasks)
        nutrition_results = list(nutrition_results)  # tuple을 list로 변환
        
        print(f"✅ [analyze_food_nutrition] 전체 영양소 분석 완료: {len(nutrition_results)}개")
        return AnalyzeFoodNutritionResponse(
            success=True,
            nutrition_results=nutrition_results
        )
    
    except Exception as e:
        print(f"❌ [analyze_food_nutrition] 영양소 분석 중 예외 발생: {e}")
        import traceback
        traceback.print_exc()
        return AnalyzeFoodNutritionResponse(
            success=False,
            nutrition_results=[],
            error=f"영양소 분석 오류: {str(e)}"
        )


@app.on_event("startup")
async def startup_event():
    """서버 시작 시 YOLO 모델 미리 로드"""
    print("🚀 AI 백엔드 서버 시작 중...")
    if YOLO_AVAILABLE:
        print("🔄 YOLO 모델 사전 로드 중...")
        try:
            # 여러 모델 버전 시도
            model_versions = ["v3-spp", "v3", "v8"]
            loaded = False
            
            for model_version in model_versions:
                try:
                    print(f"   {model_version} 모델 로드 시도 중...")
                    load_yolo_model(model_version)
                    print(f"✅ {model_version} 모델 사전 로드 완료!")
                    loaded = True
                    break
                except Exception as e:
                    print(f"   ⚠️ {model_version} 모델 로드 실패: {e}")
                    continue
            
            if not loaded:
                print("⚠️ 모든 YOLO 모델 로드 실패. 첫 요청 시 다시 시도합니다.")
            else:
                print("✅ YOLO 모델 사전 로드 완료!")
        except Exception as e:
            print(f"⚠️ YOLO 모델 사전 로드 실패: {e}")
            print("   첫 요청 시 로드됩니다.")
    else:
        print("⚠️ YOLO 모듈을 사용할 수 없습니다.")
    print("✅ AI 백엔드 서버 준비 완료!")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app:app", host="0.0.0.0", port=8001, reload=True)
