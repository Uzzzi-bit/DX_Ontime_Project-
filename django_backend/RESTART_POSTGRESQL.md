# PostgreSQL 서비스 재시작 방법

## 방법 1: Windows 서비스 관리자 사용 (가장 간단) ⭐ 추천

1. **Windows 키 + R** 누르기
2. **`services.msc`** 입력하고 Enter
3. **서비스 목록에서 `postgresql-x64-16` 찾기** (또는 `PostgreSQL`로 시작하는 서비스)
4. **우클릭 → 다시 시작**

pgAdmin은 그대로 열어둬도 됩니다!

## 방법 2: PowerShell 사용 (관리자 권한 필요)

1. **Windows 키** 누르기
2. **"PowerShell" 검색**
3. **"Windows PowerShell" 우클릭 → "관리자 권한으로 실행"**
4. 다음 명령어 실행:

```powershell
# 서비스 이름 확인 (버전에 따라 다를 수 있음)
Get-Service | Where-Object {$_.Name -like "*postgresql*"}

# 서비스 재시작 (서비스 이름을 위에서 확인한 이름으로 변경)
Restart-Service postgresql-x64-16
# 또는
Restart-Service postgresql-x64-15
```

## 방법 3: CMD 사용 (관리자 권한 필요)

1. **Windows 키** 누르기
2. **"cmd" 검색**
3. **"명령 프롬프트" 우클릭 → "관리자 권한으로 실행"**
4. 다음 명령어 실행:

```cmd
net stop postgresql-x64-16
net start postgresql-x64-16
```

## 방법 4: pgAdmin에서 설정 파일 수정만 하고 재시작 안 하기

실제로는 설정 파일을 수정한 후에만 재시작이 필요합니다.

**설정 파일 수정 순서:**
1. `postgresql.conf` 수정 → `listen_addresses = '*'`
2. `pg_hba.conf` 수정 → 외부 접속 규칙 추가
3. **그 다음에** 서비스 재시작

## 추천 방법

**가장 쉬운 방법: 방법 1 (서비스 관리자)**

pgAdmin은 그대로 두고, 서비스 관리자에서만 재시작하면 됩니다!

