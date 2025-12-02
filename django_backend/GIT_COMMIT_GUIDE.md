# Git 커밋 가이드 - 데이터베이스 파일

## ⚠️ 중요: db.sqlite3는 커밋하지 마세요!

### 이유:
1. **바이너리 파일** - Git에 적합하지 않음 (용량 큼, 변경 추적 어려움)
2. **데이터베이스 파일** - 실제 데이터가 들어있어서 보안 문제
3. **불필요함** - 이미 PostgreSQL을 공용 DB로 사용 중

## ✅ 올바른 방법

### 1. .gitignore에 추가 (이미 추가됨)

`.gitignore` 파일에 다음이 추가되어 있습니다:
```
*.sqlite3
django_backend/db.sqlite3
```

### 2. 커밋할 파일들

**커밋해야 할 것:**
- ✅ `settings.py` (비밀번호 제외)
- ✅ `models.py`
- ✅ `views.py`
- ✅ `urls.py`
- ✅ `requirements.txt`
- ✅ 마이그레이션 파일 (`migrations/` 폴더)

**커밋하면 안 되는 것:**
- ❌ `db.sqlite3` (SQLite 데이터베이스 파일)
- ❌ `.env` (환경 변수 파일)
- ❌ `venv/` (가상 환경)
- ❌ `__pycache__/` (Python 캐시)

### 3. 다른 사람들이 받는 방법

**다른 사람들이 프로젝트를 받으면:**

1. **프로젝트 클론:**
   ```bash
   git clone [저장소 URL]
   ```

2. **가상 환경 생성:**
   ```bash
   python -m venv venv
   .\venv\Scripts\Activate.ps1
   ```

3. **패키지 설치:**
   ```bash
   pip install -r requirements.txt
   ```

4. **PostgreSQL 연결:**
   - `settings.py`에서 `USE_POSTGRESQL = True`
   - 서버 IP 주소로 `HOST` 설정

5. **마이그레이션:**
   ```bash
   python manage.py migrate
   ```
   → PostgreSQL에 테이블이 생성됨 (SQLite 파일 불필요!)

## 만약 정말 db.sqlite3를 커밋해야 한다면 (권장하지 않음)

### 방법 1: 강제로 추가
```bash
git add -f django_backend/db.sqlite3
git commit -m "Add SQLite database"
git push
```

### 방법 2: .gitignore에서 제외
`.gitignore`에서 해당 줄 삭제 후:
```bash
git add django_backend/db.sqlite3
git commit -m "Add SQLite database"
git push
```

## ⚠️ 주의사항

1. **용량 문제**: SQLite 파일이 크면 Git 저장소가 무거워짐
2. **충돌 문제**: 여러 사람이 같은 파일을 수정하면 충돌 발생
3. **보안 문제**: 민감한 데이터가 들어있을 수 있음
4. **불필요함**: PostgreSQL을 사용 중이므로 SQLite 파일은 필요 없음

## 추천 방법

**PostgreSQL을 공용 DB로 사용하므로:**
- ✅ `db.sqlite3`는 `.gitignore`에 추가 (이미 완료)
- ✅ 다른 사람들은 PostgreSQL에 직접 연결
- ✅ SQLite 파일은 로컬 개발용으로만 사용

이렇게 하면 모든 사람이 같은 PostgreSQL 데이터베이스를 공유할 수 있습니다!

