import os
import json
from typing import Optional, List, Dict

from fastapi import FastAPI, File, UploadFile, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import google.generativeai as genai
import base64
from PIL import Image
import io

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

    today_carbs: float = 0
    today_carbs_ratio: float = 0
    today_protein: float = 0
    today_protein_ratio: float = 0
    today_fat: float = 0
    today_fat_ratio: float = 0
    today_sodium: float = 0
    today_sodium_ratio: float = 0
    today_calcium: float = 0
    today_calcium_ratio: float = 0
    today_iron: float = 0
    today_iron_ratio: float = 0


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
    chat_history: Optional[list] = None
    image_base64: Optional[str] = None  # base64 인코딩된 이미지


class ChatResponse(BaseModel):
    message: str


class AnalyzeNutritionRequest(BaseModel):
    image_base64: str  # base64 인코딩된 이미지


class AnalyzeNutritionResponse(BaseModel):
    success: bool
    foods: List[Dict[str, any]]  # [{"name": "apple", "confidence": 0.9}, ...]
    count: int
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
    prompt = render_template(
        RECIPES_TEMPLATE,
        RULES_JSON=RULES_JSON,
        FOOD_KB_MD=FOOD_KB_MD,
        nickname=req.nickname,
        week=req.week,
        bmi=req.bmi,
        conditions=req.conditions or "없음",
        today_carbs=req.today_carbs,
        today_carbs_ratio=req.today_carbs_ratio,
        today_protein=req.today_protein,
        today_protein_ratio=req.today_protein_ratio,
        today_fat=req.today_fat,
        today_fat_ratio=req.today_fat_ratio,
        today_sodium=req.today_sodium,
        today_sodium_ratio=req.today_sodium_ratio,
        today_calcium=req.today_calcium,
        today_calcium_ratio=req.today_calcium_ratio,
        today_iron=req.today_iron,
        today_iron_ratio=req.today_iron_ratio,
    )

    model = genai.GenerativeModel(MODEL_ID)
    gemini_resp = model.generate_content(prompt)
    raw = gemini_resp.text.strip()

    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        raise ValueError(f"모델 JSON 파싱 실패: {raw}")

    return data


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
