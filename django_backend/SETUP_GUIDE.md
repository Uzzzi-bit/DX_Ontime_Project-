# 공용 DB 설정 빠른 가이드

## 🚀 빠른 시작 (PostgreSQL 사용)

### 1단계: DB 서버 컴퓨터에서 설정

#### PostgreSQL 설치 및 설정
```bash
# Windows: https://www.postgresql.org/download/windows/ 에서 설치
# Mac: brew install postgresql
# Linux: sudo apt-get install postgresql postgresql-contrib
```

#### 데이터베이스 생성
```bash
# PostgreSQL 접속
psql -U postgres

# 데이터베이스 및 사용자 생성
CREATE DATABASE dx_ontime_db;
CREATE USER dx_user WITH PASSWORD 'your_password_here';
GRANT ALL PRIVILEGES ON DATABASE dx_ontime_db TO dx_user;
\q
```

#### 외부 접속 허용 설정
1. `postgresql.conf` 파일 찾기
   - Windows: `C:\Program Files\PostgreSQL\15\data\postgresql.conf`
   - Mac/Linux: `/etc/postgresql/15/main/postgresql.conf`

2. `listen_addresses = '*'` 로 변경

3. `pg_hba.conf` 파일에 추가:
   ```
   host    all             all             0.0.0.0/0               md5
   ```

4. PostgreSQL 재시작

#### 서버 IP 주소 확인
```bash
# Windows
ipconfig
# IPv4 주소 확인 (예: 192.168.0.100)

# Mac/Linux
ifconfig
```

### 2단계: Django 설정

#### 필요한 패키지 설치
```bash
cd django_backend
pip install -r requirements.txt
```

#### 환경 변수 설정 (Windows)
```cmd
set DB_ENGINE=postgresql
set DB_NAME=dx_ontime_db
set DB_USER=dx_user
set DB_PASSWORD=your_password_here
set DB_HOST=192.168.0.100
set DB_PORT=5432
```

#### 환경 변수 설정 (Mac/Linux)
```bash
export DB_ENGINE=postgresql
export DB_NAME=dx_ontime_db
export DB_USER=dx_user
export DB_PASSWORD=your_password_here
export DB_HOST=192.168.0.100
export DB_PORT=5432
```

#### 마이그레이션 실행
```bash
python manage.py makemigrations
python manage.py migrate
```

### 3단계: 다른 사람들도 같은 설정 사용

1. 같은 네트워크(WiFi)에 연결
2. 환경 변수 설정 (위와 동일)
3. `pip install -r requirements.txt`
4. `python manage.py migrate` 실행

## 💡 팁

### 환경 변수를 영구적으로 설정하려면

**Windows:**
- 시스템 환경 변수에서 추가하거나
- 배치 파일(.bat) 만들어서 실행:
```bat
@echo off
set DB_ENGINE=postgresql
set DB_NAME=dx_ontime_db
set DB_USER=dx_user
set DB_PASSWORD=your_password
set DB_HOST=192.168.0.100
set DB_PORT=5432
python manage.py runserver
```

**Mac/Linux:**
- `~/.bashrc` 또는 `~/.zshrc`에 추가:
```bash
export DB_ENGINE=postgresql
export DB_NAME=dx_ontime_db
export DB_USER=dx_user
export DB_PASSWORD=your_password
export DB_HOST=192.168.0.100
export DB_PORT=5432
```

### SQLite로 되돌리려면
환경 변수를 설정하지 않으면 자동으로 SQLite를 사용합니다.

## ⚠️ 문제 해결

### 연결 오류
1. 방화벽에서 포트 5432 열기
2. 같은 네트워크에 연결되어 있는지 확인
3. DB 서버 IP 주소가 맞는지 확인

### 권한 오류
```sql
-- PostgreSQL에서 다시 권한 부여
GRANT ALL PRIVILEGES ON DATABASE dx_ontime_db TO dx_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO dx_user;
```

