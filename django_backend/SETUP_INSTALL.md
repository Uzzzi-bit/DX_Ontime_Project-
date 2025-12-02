# Django 환경 설정 가이드

## 1단계: 가상 환경 생성 및 활성화

### Windows PowerShell에서:
```powershell
# 가상 환경 생성
python -m venv venv

# 가상 환경 활성화
.\venv\Scripts\Activate.ps1

# 만약 실행 정책 오류가 나면:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Windows CMD에서:
```cmd
# 가상 환경 생성
python -m venv venv

# 가상 환경 활성화
venv\Scripts\activate.bat
```

### Mac/Linux에서:
```bash
# 가상 환경 생성
python3 -m venv venv

# 가상 환경 활성화
source venv/bin/activate
```

## 2단계: 필요한 패키지 설치

가상 환경이 활성화된 상태에서 (프롬프트 앞에 `(venv)` 표시가 보여야 함):

```bash
# requirements.txt가 있는 경우
pip install -r requirements.txt

# 또는 직접 설치
pip install Django>=5.2.8
pip install djangorestframework
pip install django-cors-headers
pip install psycopg2-binary
```

## 3단계: 환경 변수 설정

### Windows PowerShell:
```powershell
$env:DB_ENGINE="postgresql"
$env:DB_NAME="dx_ontime_db"
$env:DB_USER="dx_user"
$env:DB_PASSWORD="설정한_비밀번호"
$env:DB_HOST="localhost"
$env:DB_PORT="5432"
```

### Windows CMD:
```cmd
set DB_ENGINE=postgresql
set DB_NAME=dx_ontime_db
set DB_USER=dx_user
set DB_PASSWORD=설정한_비밀번호
set DB_HOST=localhost
set DB_PORT=5432
```

### Mac/Linux:
```bash
export DB_ENGINE=postgresql
export DB_NAME=dx_ontime_db
export DB_USER=dx_user
export DB_PASSWORD=설정한_비밀번호
export DB_HOST=localhost
export DB_PORT=5432
```

## 4단계: 마이그레이션 실행

```bash
python manage.py makemigrations
python manage.py migrate
```

## 5단계: 서버 실행

```bash
python manage.py runserver
```

## 문제 해결

### "python이 인식되지 않습니다" 오류
- `python3` 또는 `py` 명령어 사용 시도
- Python이 설치되어 있는지 확인: `python --version`

### 가상 환경 활성화가 안 될 때
- `venv` 폴더가 생성되었는지 확인
- 다른 터미널에서 다시 시도

### 패키지 설치 오류
- 인터넷 연결 확인
- `pip install --upgrade pip` 실행 후 다시 시도

