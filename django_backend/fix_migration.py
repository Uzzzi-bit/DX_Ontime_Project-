"""
마이그레이션 오류 수정 스크립트
이 스크립트를 실행해서 데이터베이스 스키마를 수정하세요.
"""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.db import connection

print("=" * 50)
print("데이터베이스 스키마 수정")
print("=" * 50)

try:
    with connection.cursor() as cursor:
        # 현재 테이블 구조 확인
        cursor.execute("""
            SELECT column_name, data_type, is_nullable
            FROM information_schema.columns
            WHERE table_name = 'members_memberpregnancy'
            ORDER BY ordinal_position;
        """)
        
        columns = cursor.fetchall()
        print("\n현재 members_memberpregnancy 테이블 구조:")
        for col in columns:
            print(f"  - {col[0]} ({col[1]})")
        
        # id 컬럼이 있는지 확인
        has_id = any(col[0] == 'id' for col in columns)
        has_member_id = any(col[0] == 'member_id' for col in columns)
        
        print(f"\nid 컬럼 존재: {has_id}")
        print(f"member_id 컬럼 존재: {has_member_id}")
        
        # Primary key 확인
        cursor.execute("""
            SELECT a.attname
            FROM pg_index i
            JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
            WHERE i.indrelid = 'members_memberpregnancy'::regclass
            AND i.indisprimary;
        """)
        
        pk_columns = [row[0] for row in cursor.fetchall()]
        print(f"Primary Key: {pk_columns}")
        
        # 수정 필요 여부 확인
        if has_id and 'member_id' in pk_columns:
            print("\n⚠️ id 컬럼이 있지만 primary key는 member_id입니다.")
            print("id 컬럼을 제거합니다...")
            
            # id 컬럼 제거
            cursor.execute("ALTER TABLE members_memberpregnancy DROP COLUMN IF EXISTS id;")
            print("✅ id 컬럼 제거 완료")
            
        elif not has_id and 'member_id' not in pk_columns:
            print("\n⚠️ id 컬럼도 없고 member_id가 primary key도 아닙니다.")
            print("member_id를 primary key로 설정합니다...")
            
            # member_id를 primary key로 설정
            cursor.execute("""
                ALTER TABLE members_memberpregnancy 
                ADD CONSTRAINT members_memberpregnancy_pkey PRIMARY KEY (member_id);
            """)
            print("✅ member_id를 primary key로 설정 완료")
            
        elif not has_id and 'member_id' in pk_columns:
            print("\n✅ 테이블 구조가 올바릅니다!")
            print("   - id 컬럼 없음")
            print("   - member_id가 primary key")
        else:
            print("\n⚠️ 예상치 못한 상태입니다.")
            print("마이그레이션을 다시 실행하세요:")
            print("  python manage.py migrate members zero")
            print("  python manage.py migrate")
        
        # 최종 확인
        cursor.execute("""
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_name = 'members_memberpregnancy'
            ORDER BY ordinal_position;
        """)
        
        final_columns = cursor.fetchall()
        print("\n최종 테이블 구조:")
        for col in final_columns:
            print(f"  - {col[0]} ({col[1]})")
        
        print("\n" + "=" * 50)
        print("수정 완료!")
        print("=" * 50)
        
except Exception as e:
    print(f"\n❌ 오류 발생: {e}")
    print("\n수동으로 수정하세요:")
    print("1. pgAdmin에서 members_memberpregnancy 테이블 확인")
    print("2. id 컬럼이 있으면 제거")
    print("3. member_id를 primary key로 설정")

