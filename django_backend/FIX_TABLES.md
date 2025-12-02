# 테이블이 안 보이는 문제 해결

## 문제 원인
`settings.py`에서 `USE_POSTGRESQL = False`로 되어 있어서 SQLite를 사용하고 있습니다.
PostgreSQL에 테이블을 생성하려면 설정을 변경해야 합니다.

## 해결 방법

### 1단계: settings.py 수정

`django_backend/config/settings.py` 파일을 열고:

```python
# 74번째 줄 근처
USE_POSTGRESQL = True  # False → True로 변경

if USE_POSTGRESQL:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.postgresql',
            'NAME': 'dx_ontime_db',
            'USER': 'dx_user',
            'PASSWORD': '여기에_비밀번호_입력',  # ⚠️ 중요: pgAdmin에서 설정한 비밀번호
            'HOST': 'localhost',
            'PORT': '5432',
        }
    }
```

### 2단계: 마이그레이션 다시 실행

```powershell
# 기존 마이그레이션 파일 삭제 (선택사항)
# 또는 그냥 migrate만 실행해도 됩니다

python manage.py migrate
```

### 3단계: pgAdmin에서 확인

1. pgAdmin에서 `dx_ontime_db` → `Schemas` → `public` → `Tables` 클릭
2. 새로고침 (F5)
3. 테이블 목록 확인:
   - `members_member`
   - `members_memberpregnancy`
   - `django_migrations`
   - 기타 Django 테이블들

## 주의사항

- 비밀번호는 pgAdmin에서 `dx_user`를 생성할 때 설정한 비밀번호를 입력해야 합니다
- 비밀번호에 특수문자가 있으면 따옴표 안에 그대로 입력하세요

