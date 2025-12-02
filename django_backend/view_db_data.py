"""
공용 DB 데이터 확인 스크립트
이 스크립트를 실행해서 공용 DB에 저장된 모든 데이터를 확인할 수 있습니다.
"""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from members.models import Member, MemberPregnancy

print("=" * 50)
print("공용 DB 데이터 확인")
print("=" * 50)

# 회원 정보
print("\n📋 회원 정보:")
members = Member.objects.all()
print(f"총 회원 수: {members.count()}\n")

if members.count() == 0:
    print("❌ 데이터가 없습니다.")
else:
    for member in members:
        print(f"ID: {member.id}")
        print(f"  Email: {member.email}")
        print(f"  Firebase UID: {member.firebase_uid}")
        print(f"  닉네임: {member.nickname}")
        print(f"  임신모드: {'ON ✅' if member.is_pregnant_mode else 'OFF ❌'}")
        print(f"  가입일: {member.created_at}")
        
        # 임신 정보 확인
        try:
            preg = member.pregnancy
            print(f"  ✅ 임신 정보:")
            print(f"     - 출생연도: {preg.birth_year}")
            print(f"     - 키: {preg.height_cm}cm")
            print(f"     - 몸무게: {preg.weight_kg}kg")
            print(f"     - 출산예정일: {preg.due_date}")
            print(f"     - 임신주차: {preg.preg_week}주")
            print(f"     - 임신성당뇨: {'예' if preg.gestational_diabetes else '아니오'}")
            if preg.allergies:
                allergies = [a.strip() for a in preg.allergies.split(',') if a.strip()]
                print(f"     - 알러지: {', '.join(allergies)}")
        except MemberPregnancy.DoesNotExist:
            print(f"  ❌ 임신 정보 없음")
        
        print()

print("=" * 50)
print("데이터 확인 완료!")
print("=" * 50)

