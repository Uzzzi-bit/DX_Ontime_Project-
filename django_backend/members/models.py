# django_backend/members/models.py
from django.db import models


class Member(models.Model):
    """
    Firebase 인증으로 받은 uid 기준 회원 테이블
    (회원가입 API에서 저장 / 조회에 사용하는 테이블)
    """
    uid = models.CharField(max_length=128, primary_key=True)  # Firebase uid
    email = models.EmailField(unique=True)
    nickname = models.CharField(max_length=100, blank=True)
    phone = models.CharField(max_length=20, blank=True)
    address = models.CharField(max_length=255, blank=True)
    is_pregnant_mode = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "MEMBER"   # 이미 만들어둔 오라클 MEMBER 테이블과 매핑

    def __str__(self):
        return f"{self.nickname or self.email}({self.uid})"


class MemberPregnancy(models.Model):
    """
    건강 정보(health_info_pages.dart) 저장용 테이블
    한 명의 회원(Member)당 1개 (1:1)
    """
    member = models.OneToOneField(
        Member,
        on_delete=models.CASCADE,
        related_name="pregnancy",
        primary_key=True,          # PK = member_id 처럼 쓰기
        db_column="member_id",     # 오라클 MEMBER_PREGNANCY.member_id와 매핑
    )

    birth_year = models.IntegerField()
    height_cm = models.FloatField()
    weight_kg = models.FloatField()
    due_date = models.DateField()
    preg_week = models.IntegerField()
    gestational_diabetes = models.BooleanField(default=False)

    # 오라클에 JSONField가 애매해서, 알러지는 문자열로 저장 (예: "우유,땅콩")
    allergies = models.TextField(blank=True)

    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "MEMBER_PREGNANCY"

    def __str__(self):
        return f"Pregnancy info of {self.member.uid}"
