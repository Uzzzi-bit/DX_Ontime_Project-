# 데이터베이스 연결 확인하기

## 1단계: 서버 실행

```powershell
python manage.py runserver
```

서버가 정상적으로 실행되면 다음과 같은 메시지가 나타납니다:
```
Starting development server at http://127.0.0.1:8000/
Quit the server with CTRL-BREAK.
```

## 2단계: pgAdmin에서 테이블 확인

1. **pgAdmin 4 열기**
2. **왼쪽 사이드바에서:**
   - `PostgreSQL 16` → `Databases` → `dx_ontime_db` → `Schemas` → `public` → `Tables`
3. **생성된 테이블 확인:**
   - `members_member` - 회원 정보 테이블
   - `members_memberpregnancy` - 임신 정보 테이블
   - `django_migrations` - 마이그레이션 기록 테이블
   - 기타 Django 기본 테이블들

## 3단계: API 테스트

브라우저에서 다음 URL 접속:
- http://127.0.0.1:8000/ - 헬스 체크
- http://127.0.0.1:8000/admin/ - Django 관리자 페이지

## 4단계: 다른 사람들이 접속하려면

### DB 서버 컴퓨터에서:
1. **서버 IP 주소 확인:**
   ```powershell
   ipconfig
   # IPv4 주소 확인 (예: 192.168.0.100)
   ```

2. **settings.py에서 HOST 변경:**
   ```python
   'HOST': '0.0.0.0',  # 모든 인터페이스에서 접속 허용
   # 또는
   'HOST': '192.168.0.100',  # 특정 IP만 허용
   ```

3. **서버 실행:**
   ```powershell
   python manage.py runserver 0.0.0.0:8000
   ```

### 다른 사람들의 컴퓨터에서:
1. **settings.py에서 HOST를 서버 IP로 변경:**
   ```python
   'HOST': '192.168.0.100',  # DB 서버의 IP 주소
   ```

2. **마이그레이션 실행:**
   ```powershell
   python manage.py migrate
   ```

## 완료! 🎉

이제 여러 사람이 같은 데이터베이스를 공유할 수 있습니다!

