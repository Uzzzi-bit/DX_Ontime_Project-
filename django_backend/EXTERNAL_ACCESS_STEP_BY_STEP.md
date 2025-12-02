# 외부 접속 설정 단계별 가이드

## 현재 상태: ✅ PostgreSQL 서비스 정상 작동

## 다음 단계: 외부 접속 허용 설정

### 1단계: postgresql.conf 파일 수정

1. **파일 위치 찾기:**
   - pgAdmin에서: `PostgreSQL 16` 우클릭 → `Properties` → `Config file` 경로 확인
   - 또는: `C:\Program Files\PostgreSQL\16\data\postgresql.conf`

2. **파일 열기:**
   - 메모장으로 열기 (관리자 권한 필요할 수 있음)

3. **수정할 부분 찾기:**
   - `Ctrl + F`로 `listen_addresses` 검색

4. **수정:**
   ```conf
   # 찾기:
   listen_addresses = 'localhost'
   
   # 변경:
   listen_addresses = '*'
   ```
   ⚠️ **중요**: 따옴표 안에 `*` 만 입력 (공백 없이)

5. **저장**

### 2단계: pg_hba.conf 파일 수정

1. **파일 위치:**
   - `postgresql.conf`와 같은 폴더에 있음
   - `C:\Program Files\PostgreSQL\16\data\pg_hba.conf`

2. **파일 열기:**
   - 메모장으로 열기 (관리자 권한 필요)

3. **파일 맨 아래에 추가:**
   ```
   # 외부 접속 허용
   host    all             all             0.0.0.0/0               md5
   ```
   ⚠️ **중요**: 
   - 공백은 스페이스로 (탭 아님)
   - 정확히 위와 같이 입력
   - 파일 맨 아래 줄에 추가

4. **저장**

### 3단계: 서비스 재시작

1. **Windows 키 + R**
2. **`services.msc`** 입력
3. **`postgresql-x64-16` 찾기**
4. **우클릭 → 다시 시작**

### 4단계: 방화벽 설정

**PowerShell (관리자 권한):**
```powershell
New-NetFirewallRule -DisplayName "PostgreSQL" -Direction Inbound -LocalPort 5432 -Protocol TCP -Action Allow
```

또는 **Windows 방화벽 고급 설정**:
1. Windows 방화벽 고급 설정 열기
2. 인바운드 규칙 → 새 규칙
3. 포트 → TCP → 5432
4. 연결 허용
5. 모든 프로필
6. 이름: "PostgreSQL"

### 5단계: IP 주소 확인 및 공유

```powershell
ipconfig
```

**IPv4 주소** 확인 (예: `192.168.0.100`)

이 IP 주소를 다른 사람들에게 공유하세요!

### 6단계: 연결 테스트

**다른 컴퓨터에서 (또는 같은 컴퓨터에서):**

```powershell
# test_db_connection.py 실행
python test_db_connection.py
```

또는 `settings.py`에서 `HOST`를 IP 주소로 변경하고 테스트:
```python
'HOST': '192.168.0.100',  # 서버 IP 주소
```

## 완료! 🎉

이제 다른 사람들이 이 IP 주소로 접속할 수 있습니다!

