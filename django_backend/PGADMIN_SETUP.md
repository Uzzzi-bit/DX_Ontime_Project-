# pgAdmin 4에서 데이터베이스 설정하기

## 1단계: 데이터베이스 생성

1. **왼쪽 사이드바에서 "PostgreSQL 16" 확장**
2. **"Databases" 우클릭 → "Create" → "Database..."**
3. **다음 정보 입력:**
   - **Database**: `dx_ontime_db`
   - **Owner**: `postgres` (기본값)
   - 나머지는 기본값 유지
4. **"Save" 클릭**

## 2단계: 사용자(Role) 생성

1. **왼쪽 사이드바에서 "Login/Group Roles" 우클릭 → "Create" → "Login/Group Role..."**
2. **"General" 탭:**
   - **Name**: `dx_user`
3. **"Definition" 탭:**
   - **Password**: 원하는 비밀번호 입력 (예: `dx_password_123`)
   - **Password expiration**: 체크 해제 (선택사항)
4. **"Privileges" 탭:**
   - **Can login?**: ✅ 체크
   - **Create databases?**: ✅ 체크 (선택사항)
   - **Create roles?**: 체크 해제
5. **"Save" 클릭**

## 3단계: 권한 부여

1. **생성한 데이터베이스 `dx_ontime_db` 우클릭 → "Query Tool"**
2. **다음 SQL 명령어 실행:**

```sql
-- 데이터베이스에 대한 권한 부여
GRANT ALL PRIVILEGES ON DATABASE dx_ontime_db TO dx_user;

-- public 스키마에 대한 권한 부여
\c dx_ontime_db
GRANT ALL PRIVILEGES ON SCHEMA public TO dx_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO dx_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO dx_user;

-- 앞으로 생성될 테이블에 대한 권한도 자동 부여
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO dx_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO dx_user;
```

## 4단계: 서버 IP 주소 확인

### Windows에서 IP 주소 확인:
1. **명령 프롬프트(cmd) 열기**
2. **`ipconfig` 입력**
3. **"IPv4 주소" 찾기** (예: `192.168.0.100`)

### Mac/Linux에서 IP 주소 확인:
```bash
ifconfig
# 또는
ip addr
```

## 5단계: Django 설정

### 환경 변수 설정 (Windows)
```cmd
set DB_ENGINE=postgresql
set DB_NAME=dx_ontime_db
set DB_USER=dx_user
set DB_PASSWORD=위에서_설정한_비밀번호
set DB_HOST=localhost
set DB_PORT=5432
```

### 환경 변수 설정 (Mac/Linux)
```bash
export DB_ENGINE=postgresql
export DB_NAME=dx_ontime_db
export DB_USER=dx_user
export DB_PASSWORD=위에서_설정한_비밀번호
export DB_HOST=localhost
export DB_PORT=5432
```

### 패키지 설치 및 마이그레이션
```bash
cd django_backend
pip install psycopg2-binary
python manage.py makemigrations
python manage.py migrate
```

## 6단계: 다른 사람들이 접속하려면

### DB 서버 컴퓨터에서:
1. **PostgreSQL 설정 파일 수정:**
   - `postgresql.conf`: `listen_addresses = '*'`
   - `pg_hba.conf`: 외부 접속 허용 규칙 추가
2. **방화벽에서 포트 5432 열기**
3. **서버 IP 주소 공유**

### 다른 사람들의 컴퓨터에서:
1. **환경 변수에서 `DB_HOST`를 서버 IP로 변경:**
   ```cmd
   set DB_HOST=192.168.0.100  # 서버 IP 주소
   ```
2. **나머지 설정은 동일**

## 문제 해결

### 연결 오류가 발생하면:
1. PostgreSQL 서비스가 실행 중인지 확인
2. `pg_hba.conf`에서 외부 접속 허용 확인
3. 방화벽 설정 확인
4. IP 주소가 올바른지 확인

