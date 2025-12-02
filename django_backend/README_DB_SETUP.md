# 공용 DB 설정 가이드

여러 사람이 각자의 노트북에서 같은 데이터베이스에 접속하여 데이터를 공유할 수 있도록 설정하는 방법입니다.

## 방법 1: PostgreSQL 사용 (권장)

### 1단계: DB 서버 설정 (한 사람이 담당)

#### Windows에서 PostgreSQL 설치
1. https://www.postgresql.org/download/windows/ 에서 설치
2. 설치 시 포트는 기본값 5432 사용
3. postgres 사용자의 비밀번호 설정

#### PostgreSQL에서 데이터베이스 생성
```bash
# PostgreSQL 명령줄 도구 실행
psql -U postgres

# 데이터베이스 및 사용자 생성
CREATE DATABASE dx_ontime_db;
CREATE USER dx_user WITH PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE dx_ontime_db TO dx_user;
\q
```

#### PostgreSQL 설정 파일 수정 (외부 접속 허용)
1. `postgresql.conf` 파일 찾기 (보통 `C:\Program Files\PostgreSQL\15\data\postgresql.conf`)
2. `listen_addresses = '*'` 로 변경
3. `pg_hba.conf` 파일에 다음 추가:
   ```
   host    all             all             0.0.0.0/0               md5
   ```
4. PostgreSQL 서비스 재시작

#### 서버 IP 주소 확인
```bash
# Windows
ipconfig

# Mac/Linux
ifconfig
```
예: `192.168.0.100` 같은 내부 IP 주소를 확인

### 2단계: Django 설정 변경

#### 필요한 패키지 설치
```bash
cd django_backend
pip install psycopg2-binary
```

#### settings.py 수정
`django_backend/config/settings.py` 파일의 DATABASES 부분을 다음과 같이 변경:

```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'dx_ontime_db',
        'USER': 'dx_user',
        'PASSWORD': 'your_secure_password',  # 위에서 설정한 비밀번호
        'HOST': '192.168.0.100',  # DB 서버의 IP 주소
        'PORT': '5432',
    }
}
```

#### 마이그레이션 실행
```bash
python manage.py makemigrations
python manage.py migrate
```

### 3단계: 다른 사람들의 설정

다른 사람들도 같은 설정을 사용하면 됩니다:
1. `settings.py`에서 같은 DB 설정 사용
2. 같은 네트워크(WiFi)에 연결되어 있어야 함
3. `pip install psycopg2-binary` 설치
4. `python manage.py migrate` 실행

## 방법 2: 클라우드 DB 사용 (더 안정적)

### AWS RDS, Google Cloud SQL 등 사용
- 장점: 항상 접속 가능, 백업 자동화
- 단점: 비용 발생, 설정이 복잡함

## 방법 3: 간단한 방법 - SQLite를 네트워크 공유 폴더에 두기

### Windows 네트워크 공유
1. 한 사람의 컴퓨터에 공유 폴더 생성
2. `db.sqlite3` 파일을 그 폴더에 두기
3. 다른 사람들이 네트워크 경로로 접속

**주의**: SQLite는 동시 접속에 약하므로 여러 사람이 동시에 사용하면 문제가 발생할 수 있습니다.

## 추천 방법

**소규모 팀 (2-5명)**: PostgreSQL 사용 (방법 1)
**대규모 팀 또는 프로덕션**: 클라우드 DB 사용 (방법 2)

## 문제 해결

### 연결 오류가 발생하는 경우
1. 방화벽 설정 확인 (PostgreSQL 포트 5432 열기)
2. 같은 네트워크에 연결되어 있는지 확인
3. DB 서버가 실행 중인지 확인

### 보안 주의사항
- 프로덕션 환경에서는 환경 변수로 비밀번호 관리
- 외부 접속 시 SSL 사용 권장

