# 인코딩 오류 빠른 해결 방법

## 방법 1: settings.py에서 직접 설정 (가장 간단)

`django_backend/config/settings.py` 파일을 열고, 아래 부분을 찾아서 수정하세요:

```python
# 72번째 줄 근처에 있는 부분을 찾아서:

USE_POSTGRESQL = True  # True로 변경
```

그리고 아래 부분에서 비밀번호를 직접 입력:

```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'dx_ontime_db',
        'USER': 'dx_user',
        'PASSWORD': '여기에_비밀번호_입력',  # pgAdmin에서 설정한 비밀번호
        'HOST': 'localhost',  # 또는 서버 IP 주소
        'PORT': '5432',
    }
}
```

## 방법 2: 환경 변수 사용 (UTF-8 문제 해결)

PowerShell에서 다음과 같이 설정:

```powershell
# UTF-8 인코딩으로 설정
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$env:DB_ENGINE="postgresql"
$env:DB_NAME="dx_ontime_db"
$env:DB_USER="dx_user"
$env:DB_PASSWORD="비밀번호"
$env:DB_HOST="localhost"
$env:DB_PORT="5432"
```

## 추천: 방법 1 사용

가장 간단하고 확실한 방법은 `settings.py`에서 직접 설정하는 것입니다.

