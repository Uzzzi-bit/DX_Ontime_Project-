# 공용 DB 설정 가이드 - 다른 사람들과 함께 사용하기

## 전체 구조

```
[DB 서버 컴퓨터] ← PostgreSQL 실행
     ↓
[다른 사람들의 컴퓨터] → 같은 네트워크 → DB 서버에 접속
```

## 1단계: DB 서버 컴퓨터 설정 (한 사람이 담당)

### 1-1. PostgreSQL 외부 접속 허용

#### Windows에서:
1. **PostgreSQL 설정 파일 찾기:**
   - 보통 `C:\Program Files\PostgreSQL\16\data\postgresql.conf`
   - 또는 pgAdmin에서: `PostgreSQL 16` 우클릭 → `Properties` → `Config file` 경로 확인

2. **`postgresql.conf` 파일 수정:**
   ```conf
   # 찾기: listen_addresses
   listen_addresses = '*'  # 'localhost' → '*' 로 변경
   ```

3. **`pg_hba.conf` 파일 수정:**
   - 같은 폴더에 있는 `pg_hba.conf` 파일 열기
   - 파일 맨 아래에 추가:
   ```
   # 외부 접속 허용
   host    all             all             0.0.0.0/0               md5
   ```

4. **PostgreSQL 서비스 재시작:**
   ```powershell
   # 서비스 관리자에서
   # 또는 PowerShell에서 (관리자 권한 필요)
   Restart-Service postgresql-x64-16
   ```

#### Mac/Linux에서:
```bash
# postgresql.conf 수정
sudo nano /etc/postgresql/16/main/postgresql.conf
# listen_addresses = '*' 로 변경

# pg_hba.conf 수정
sudo nano /etc/postgresql/16/main/pg_hba.conf
# host    all    all    0.0.0.0/0    md5 추가

# PostgreSQL 재시작
sudo systemctl restart postgresql
```

### 1-2. 방화벽 설정

#### Windows 방화벽:
1. **Windows 방화벽 고급 설정** 열기
2. **인바운드 규칙** → **새 규칙**
3. **포트** 선택 → **다음**
4. **TCP** 선택, **특정 로컬 포트**: `5432` 입력
5. **연결 허용** 선택
6. **모든 프로필** 선택
7. 이름: "PostgreSQL" 입력

#### 또는 PowerShell에서 (관리자 권한):
```powershell
New-NetFirewallRule -DisplayName "PostgreSQL" -Direction Inbound -LocalPort 5432 -Protocol TCP -Action Allow
```

### 1-3. 서버 IP 주소 확인 및 공유

```powershell
# Windows
ipconfig
# IPv4 주소 확인 (예: 192.168.0.100)

# Mac/Linux
ifconfig
# 또는
ip addr
```

**이 IP 주소를 다른 사람들에게 공유하세요!**

## 2단계: DB 서버 컴퓨터의 settings.py

```python
USE_POSTGRESQL = True

if USE_POSTGRESQL:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.postgresql',
            'NAME': 'dx_ontime_db',
            'USER': 'dx_user',
            'PASSWORD': 'mypass1234',
            'HOST': 'localhost',  # 서버 컴퓨터는 localhost 사용
            'PORT': '5432',
        }
    }
```

## 3단계: 다른 사람들의 컴퓨터 설정

### 3-1. settings.py 수정

```python
USE_POSTGRESQL = True

if USE_POSTGRESQL:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.postgresql',
            'NAME': 'dx_ontime_db',
            'USER': 'dx_user',
            'PASSWORD': 'mypass1234',  # DB 서버와 동일한 비밀번호
            'HOST': '192.168.0.100',    # ⚠️ DB 서버의 IP 주소로 변경
            'PORT': '5432',
        }
    }
```

### 3-2. 같은 네트워크에 연결

- **같은 WiFi에 연결**되어 있어야 합니다
- 또는 같은 유선 네트워크

### 3-3. 마이그레이션 실행

```powershell
# 가상 환경 활성화
.\venv\Scripts\Activate.ps1

# 패키지 설치 (처음 한 번만)
pip install -r requirements.txt

# 마이그레이션 (처음 한 번만)
python manage.py migrate
```

## 4단계: 연결 테스트

### DB 서버에서:
```powershell
python manage.py runserver 0.0.0.0:8000
```

### 다른 사람들의 컴퓨터에서:
```powershell
# 연결 테스트
python test_db_connection.py

# 서버 실행
python manage.py runserver
```

## 문제 해결

### 연결이 안 될 때:

1. **같은 네트워크인지 확인**
   ```powershell
   # 다른 사람의 컴퓨터에서
   ping 192.168.0.100  # DB 서버 IP
   ```

2. **PostgreSQL이 실행 중인지 확인**
   - DB 서버 컴퓨터에서 pgAdmin으로 연결 확인

3. **방화벽 확인**
   - DB 서버 컴퓨터의 방화벽에서 포트 5432 열려있는지 확인

4. **IP 주소 확인**
   - WiFi를 다시 연결하면 IP가 바뀔 수 있음
   - `ipconfig`로 다시 확인

### 보안 주의사항

- 프로덕션 환경에서는 특정 IP만 허용하도록 설정
- 비밀번호는 강력하게 설정
- 가능하면 VPN 사용 권장

