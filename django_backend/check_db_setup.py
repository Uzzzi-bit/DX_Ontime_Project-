"""
DB 설정 확인 스크립트
다른 사람들이 이 스크립트를 실행해서 설정이 올바른지 확인할 수 있습니다.
"""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.db import connection
from django.conf import settings

print("=" * 50)
print("DB 설정 확인")
print("=" * 50)

# settings.py 확인
print(f"\n1. USE_POSTGRESQL: {getattr(settings, 'USE_POSTGRESQL', 'NOT SET')}")

if hasattr(settings, 'DATABASES'):
    db = settings.DATABASES['default']
    print(f"2. ENGINE: {db.get('ENGINE', 'NOT SET')}")
    print(f"3. NAME: {db.get('NAME', 'NOT SET')}")
    print(f"4. USER: {db.get('USER', 'NOT SET')}")
    print(f"5. HOST: {db.get('HOST', 'NOT SET')}")
    print(f"6. PORT: {db.get('PORT', 'NOT SET')}")
    print(f"7. PASSWORD: {'***' if db.get('PASSWORD') else 'NOT SET'}")

# 연결 테스트
print("\n" + "=" * 50)
print("연결 테스트")
print("=" * 50)

try:
    with connection.cursor() as cursor:
        cursor.execute("SELECT 1")
        result = cursor.fetchone()
        print("✅ 데이터베이스 연결 성공!")
        
        # 테이블 확인
        if 'postgresql' in db.get('ENGINE', ''):
            cursor.execute("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public'
                ORDER BY table_name;
            """)
            tables = cursor.fetchall()
            print(f"\n📋 생성된 테이블 ({len(tables)}개):")
            for table in tables:
                print(f"  - {table[0]}")
        
        # 데이터 저장 테스트
        print("\n" + "=" * 50)
        print("데이터 저장 테스트")
        print("=" * 50)
        
        from members.models import Member
        test_count = Member.objects.count()
        print(f"현재 회원 수: {test_count}")
        
        if test_count > 0:
            print("✅ 데이터베이스에 데이터가 있습니다!")
            latest = Member.objects.order_by('-id').first()
            if latest:
                print(f"최근 회원: {latest.email} (UID: {latest.firebase_uid})")
        
except Exception as e:
    print(f"❌ 데이터베이스 연결 실패: {e}")
    print("\n확인 사항:")
    print("1. USE_POSTGRESQL = True 인지 확인")
    print("2. HOST가 DB 서버 IP 주소인지 확인 (localhost 아님!)")
    print("3. PASSWORD가 올바른지 확인")
    print("4. 같은 네트워크에 연결되어 있는지 확인")
    print("5. DB 서버가 켜져 있는지 확인")
    print("6. python manage.py migrate 실행했는지 확인")

print("\n" + "=" * 50)

