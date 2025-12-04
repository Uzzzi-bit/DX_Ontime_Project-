import os
import json
from typing import Optional

from fastapi import FastAPI, File, UploadFile, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import google.generativeai as genai
# ★ [추가 1] 안전 설정 타입 임포트 (이게 없으면 에러 납니다)
from google.generativeai.types import HarmCategory, HarmBlockThreshold
import base64
from PIL import Image
import io


# =========================
# 0. GEMINI API 키 설정
# =========================

API_KEY = os.environ.get("GEMINI_API_KEY")
if not API_KEY:
    # 로컬 테스트용 (환경변수 없을 때)
    # API_KEY = "여기에_키를_넣으셔도_됩니다"
    pass

if API_KEY:
    genai.configure(api_key=API_KEY)

MODEL_ID = "gemini-2.0-flash"


# ★ [설정] 붉은 음식(육회, 찌개) 인식을 위해 필수
SAFETY_SETTINGS = {
    HarmCategory.HARM_CATEGORY_HARASSMENT: HarmBlockThreshold.BLOCK_NONE,
    HarmCategory.HARM_CATEGORY_HATE_SPEECH: HarmBlockThreshold.BLOCK_NONE,
    HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT: HarmBlockThreshold.BLOCK_NONE,
    HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT: HarmBlockThreshold.BLOCK_NONE,
}

# ★ [설정] 구글 검색 도구
TOOLS = 'google_search_retrieval'


# =========================
# 1. 프롬프트 / 룰 / KB 파일 로드
# =========================

BASE_DIR = os.path.dirname(os.path.abspath(__file__))


def read_text(filename: str) -> str:
    path = os.path.join(BASE_DIR, filename)
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    except FileNotFoundError:
        return ""


def read_json(filename: str):
    path = os.path.join(BASE_DIR, filename)
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return {}


CAN_EAT_TEMPLATE = read_text("can_eat_prompt.txt")
RECIPES_TEMPLATE = read_text("recommend_recipes_prompt.txt")
CHAT_TEMPLATE = read_text("can_eat_prompt.txt")
RULES_JSON = read_json("pregnancy_ai_rules.json")
FOOD_KB_MD = read_text("pregnancy_nutrition_and_food_safety_kb.md")


# =========================
# 2. 템플릿 치환 함수
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
# (기존 모델 클래스들 그대로 유지)

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
    image_base64: Optional[str] = None


class ChatResponse(BaseModel):
    message: str


# =========================
# 4. FastAPI 앱 생성
# =========================

app = FastAPI(title="Pregnancy AI Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health():
    return {"status": "ok"}


# [헬퍼 함수] JSON 추출 로직 (중복 제거)
def extract_json_from_gemini(text: str):
    text = text.strip()
    if text.startswith("```json"):
        text = text[7:]
    elif text.startswith("```"):
        text = text[3:]
    if text.endswith("```"):
        text = text[:-3]
    return text.strip()


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

    # ★ [수정 1] tools=TOOLS 추가 (검색 활성화)
    model = genai.GenerativeModel(MODEL_ID, tools=TOOLS)
    
    # 프롬프트에 검색 유도 힌트 추가
    final_prompt = prompt + "\n\n(정보가 불확실하면 Google Search 도구를 사용하여 확인하세요.)"

    try:
        # ★ [수정 2] safety_settings 전달 (붉은 음식 차단 방지)
        gemini_resp = model.generate_content(final_prompt, safety_settings=SAFETY_SETTINGS)
        
        raw = extract_json_from_gemini(gemini_resp.text)
        data = json.loads(raw)
        return data

    except Exception as e:
        print(f"Can-Eat Error: {e}")
        return {
            "status": "unknown",
            "headline": "분석에 실패했어요.",
            "reason": "잠시 후 다시 시도해 주세요.",
            "target_type": "food",
            "item_name": ""
        }


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

    # 레시피 추천은 검색 불필요 -> tools 제거하여 속도 향상
    model = genai.GenerativeModel(MODEL_ID)
    
    # ★ [수정] 안전 설정 추가
    gemini_resp = model.generate_content(prompt, safety_settings=SAFETY_SETTINGS)
    raw = extract_json_from_gemini(gemini_resp.text)

    try:
        data = json.loads(raw)
        return data
    except json.JSONDecodeError:
        return []


@app.post("/api/chat", response_model=ChatResponse)
async def chat(req: ChatRequest):
    prompt = render_template(
        CAN_EAT_TEMPLATE,
        RULES_JSON=RULES_JSON,
        FOOD_KB_MD=FOOD_KB_MD,
        nickname=req.nickname,
        week=req.week,
        conditions=req.conditions or "없음",
        user_text_or_image_desc=req.user_message,
    )

    # ★ [수정 1] 채팅에서도 검색 기능 활성화 (이미지 분석 도움)
    model = genai.GenerativeModel(MODEL_ID, tools=TOOLS)
    
    content_payload = [prompt]

    if req.image_base64:
        try:
            image_data = base64.b64decode(req.image_base64)
            image = Image.open(io.BytesIO(image_data))
            
            # 검색 유도 멘트와 함께 이미지 추가
            content_payload = [
                prompt + "\n\n(이미지 식별이 어려우면 Google Search를 사용하여 정확히 분석하세요.)",
                image
            ]
        except Exception as e:
            print(f"이미지 처리 오류: {e}")

    try:
        # ★ [수정 2] 안전 설정 전달
        gemini_resp = model.generate_content(content_payload, safety_settings=SAFETY_SETTINGS)
        raw = extract_json_from_gemini(gemini_resp.text)
        
        data = json.loads(raw)
        
        response_text = f"{data.get('headline', '')}\n\n{data.get('reason', '')}"
        return ChatResponse(message=response_text)

    except Exception as e:
        print(f"Chat Error: {e}")
        return ChatResponse(message="죄송해요, 답변을 생성하는 중 문제가 생겼어요.")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app:app", host="0.0.0.0", port=8001, reload=True)