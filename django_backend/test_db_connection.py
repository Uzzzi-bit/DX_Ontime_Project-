"""
데이터베이스 연결 테스트 스크립트
이 파일을 실행해서 PostgreSQL 연결이 제대로 되는지 확인하세요.
"""
import os
import django

# Django 설정 로드
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.db import connection

try:
    # 데이터베이스 연결 테스트
    with connection.cursor() as cursor:
        cursor.execute("SELECT 1")
        result = cursor.fetchone()
        print("✅ 데이터베이스 연결 성공!")
        print(f"✅ 사용 중인 DB: {connection.settings_dict['ENGINE']}")
        print(f"✅ 데이터베이스 이름: {connection.settings_dict['NAME']}")
        print(f"✅ 사용자: {connection.settings_dict['USER']}")
        print(f"✅ 호스트: {connection.settings_dict['HOST']}")
        
        # 테이블 목록 확인
        if 'postgresql' in connection.settings_dict['ENGINE']:
            cursor.execute("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public'
                ORDER BY table_name;
            """)
            tables = cursor.fetchall()
            print(f"\n📋 생성된 테이블 목록 ({len(tables)}개):")
            for table in tables:
                print(f"  - {table[0]}")
        else:
            print("\n⚠️ SQLite를 사용 중입니다. PostgreSQL을 사용하려면 settings.py를 확인하세요.")
            
except Exception as e:
    print(f"❌ 데이터베이스 연결 실패: {e}")
    print("\n확인 사항:")
    print("1. settings.py에서 USE_POSTGRESQL = True 인지 확인")
    print("2. PASSWORD가 올바르게 입력되었는지 확인")
    print("3. PostgreSQL 서비스가 실행 중인지 확인")
    print("4. pgAdmin에서 dx_user와 dx_ontime_db가 생성되었는지 확인")

