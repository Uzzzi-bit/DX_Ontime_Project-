#!/usr/bin/env python
"""
데이터베이스 연결 및 데이터 확인 스크립트
"""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.db import connection
from members.models import Member, MemberPregnancy

print("=" * 60)
print("데이터베이스 연결 정보 확인")
print("=" * 60)

# 데이터베이스 연결 정보
db_info = connection.get_connection_params()
print(f"데이터베이스: {db_info.get('database', 'N/A')}")
print(f"사용자: {db_info.get('user', 'N/A')}")
print(f"호스트: {db_info.get('host', 'N/A')}")
print(f"포트: {db_info.get('port', 'N/A')}")

# 현재 스키마 확인
with connection.cursor() as cursor:
    cursor.execute("SELECT current_schema();")
    current_schema = cursor.fetchone()[0]
    print(f"현재 스키마: {current_schema}")
    
    cursor.execute("SHOW search_path;")
    search_path = cursor.fetchone()[0]
    print(f"Search Path: {search_path}")

print("\n" + "=" * 60)
print("Member 테이블 데이터 확인")
print("=" * 60)

members = Member.objects.all()
print(f"총 Member 수: {members.count()}")

for member in members[:10]:  # 최대 10개만 표시
    print(f"  - ID: {member.id}, UID: {member.firebase_uid}, Email: {member.email}")

print("\n" + "=" * 60)
print("MemberPregnancy 테이블 데이터 확인")
print("=" * 60)

pregnancies = MemberPregnancy.objects.all()
print(f"총 MemberPregnancy 수: {pregnancies.count()}")

for preg in pregnancies[:10]:  # 최대 10개만 표시
    print(f"  - Member ID: {preg.member_id}, Member: {preg.member.firebase_uid}")

print("\n" + "=" * 60)
print("테이블 소유자 확인")
print("=" * 60)

with connection.cursor() as cursor:
    cursor.execute("""
        SELECT schemaname, tablename, tableowner 
        FROM pg_tables 
        WHERE tablename IN ('members_member', 'members_memberpregnancy')
        ORDER BY tablename;
    """)
    for row in cursor.fetchall():
        print(f"  스키마: {row[0]}, 테이블: {row[1]}, 소유자: {row[2]}")

print("\n" + "=" * 60)
print("모든 사용자 데이터 확인 (공용 확인용)")
print("=" * 60)

print("\n[모든 Member 데이터]")
all_members = Member.objects.all().values('id', 'firebase_uid', 'email', 'nickname', 'created_at')
for m in all_members:
    print(f"  ID: {m['id']}, UID: {m['firebase_uid']}, Email: {m['email']}, Nickname: {m['nickname']}, Created: {m['created_at']}")

print("\n[모든 MemberPregnancy 데이터]")
all_preg = MemberPregnancy.objects.all().select_related('member').values('member_id', 'member__firebase_uid', 'birth_year', 'preg_week', 'updated_at')
for p in all_preg:
    print(f"  Member ID: {p['member_id']}, UID: {p['member__firebase_uid']}, Week: {p['preg_week']}, Updated: {p['updated_at']}")

print("\n" + "=" * 60)
print("데이터베이스 연결된 사용자 확인")
print("=" * 60)

with connection.cursor() as cursor:
    cursor.execute("SELECT current_user, session_user;")
    row = cursor.fetchone()
    print(f"현재 연결 사용자: {row[0]}")
    print(f"세션 사용자: {row[1]}")

