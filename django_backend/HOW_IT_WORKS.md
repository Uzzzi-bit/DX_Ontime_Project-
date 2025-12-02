# Django와 PostgreSQL 연동 작동 방식

## ✅ 네, 맞습니다!

### 1. 다른 사람들도 사용할 수 있습니다

**작동 방식:**
```
[DB 서버 컴퓨터]
  PostgreSQL 실행 (포트 5432)
  ↓
[같은 네트워크 (WiFi)]
  ↓
[다른 사람들의 컴퓨터]
  settings.py에서 서버 IP로 접속
  → 같은 PostgreSQL 데이터베이스 사용
```

**예시:**
- A가 회원가입 → `members_member` 테이블에 데이터 저장
- B가 로그인 → A가 만든 데이터를 볼 수 있음
- C가 건강정보 입력 → 모든 사람이 볼 수 있음

### 2. Django 마이그레이션 = pgAdmin4에 적용됨

**작동 방식:**
```
Django 마이그레이션 (python manage.py migrate)
  ↓
PostgreSQL 데이터베이스에 테이블 생성
  ↓
pgAdmin4에서 테이블 확인 가능
```

**예시:**
1. Django에서 `python manage.py makemigrations` 실행
2. `python manage.py migrate` 실행
3. PostgreSQL 데이터베이스에 실제 테이블 생성됨
4. pgAdmin4에서 `dx_ontime_db` → `Tables` 클릭하면 테이블 보임

## 실제 사용 시나리오

### 시나리오 1: 팀원 A가 회원가입
1. A의 Flutter 앱에서 회원가입
2. Django API 호출 → PostgreSQL `members_member` 테이블에 저장
3. **모든 팀원이 pgAdmin4에서 확인 가능**
4. **다른 팀원들의 앱에서도 A의 데이터 확인 가능**

### 시나리오 2: 팀원 B가 건강정보 입력
1. B의 Flutter 앱에서 건강정보 입력
2. Django API 호출 → PostgreSQL `members_memberpregnancy` 테이블에 저장
3. **모든 팀원이 pgAdmin4에서 확인 가능**
4. **다른 팀원들의 앱에서도 B의 데이터 확인 가능**

### 시나리오 3: 새로운 테이블 추가
1. Django `models.py`에 새 모델 추가
2. `python manage.py makemigrations`
3. `python manage.py migrate`
4. **pgAdmin4에서 새 테이블 확인 가능**

## 확인 방법

### pgAdmin4에서 확인:
1. `dx_ontime_db` → `Schemas` → `public` → `Tables`
2. 테이블 우클릭 → `View/Edit Data` → `All Rows`
3. Django에서 저장한 데이터 확인 가능!

### Django에서 확인:
```python
# Django shell에서
python manage.py shell

from members.models import Member
Member.objects.all()  # 모든 회원 데이터 확인
```

## 요약

✅ **다른 사람들도 사용 가능** - 같은 네트워크 + 같은 IP 주소로 접속
✅ **Django 마이그레이션 = pgAdmin4 적용** - 같은 데이터베이스이므로 실시간 반영
✅ **데이터 공유** - 한 사람이 입력하면 모든 사람이 볼 수 있음
✅ **실시간 동기화** - pgAdmin4에서 데이터 확인 가능

## 주의사항

⚠️ **같은 네트워크 필수** - 같은 WiFi에 연결되어 있어야 함
⚠️ **DB 서버 켜져 있어야 함** - 서버 컴퓨터가 켜져 있어야 다른 사람들이 접속 가능
⚠️ **IP 주소 변경 가능** - WiFi 재연결 시 IP가 바뀔 수 있음 (다시 확인 필요)

