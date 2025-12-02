# django_backend/members/models.py

from django.db import models


class Member(models.Model):
    """
    앱 기본 사용자 정보
    - PK: id (Django가 자동 생성)
    - firebase_uid: Firebase Auth UID
    """
    firebase_uid = models.CharField(
        max_length=128,
        unique=True,
        help_text="Firebase Authentication에서 받은 UID",
    )
    email = models.EmailField(
        unique=True,
    )
    password = models.CharField(
        max_length=255,
        null=True,
        blank=True,
    )
    nickname = models.CharField(
        max_length=50,
    )
    birth_date = models.DateField(
        null=True,
        blank=True,
    )
    phone_number = models.CharField(
        max_length=20,
        null=True,
        blank=True,
    )
    address = models.CharField(
        max_length=300,
        null=True,
        blank=True,
    )
    is_pregnant_mode = models.BooleanField(
        default=False,
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
    )
    updated_at = models.DateTimeField(
        auto_now=True,
    )

    def __str__(self):
        return f"{self.id} / {self.nickname} ({self.firebase_uid})"


class MemberPregnancy(models.Model):
    """
    임산부 추가 건강 정보 (Member와 1:1)
    """
    member = models.OneToOneField(
        Member,
        on_delete=models.CASCADE,
        related_name='pregnancy',
    )

    birth_year = models.IntegerField(
        null=True,
        blank=True,
    )
    height_cm = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        null=True,
        blank=True,
    )
    weight_kg = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        null=True,
        blank=True,
    )
    due_date = models.DateField(
        null=True,
        blank=True,
    )
    preg_week = models.IntegerField(
        null=True,
        blank=True,
    )

    gestational_diabetes = models.BooleanField(
        default=False,
    )

    # 콤마로 이어붙여 저장하는 문자열 (뷰에서 리스트로 변환)
    allergies = models.TextField(
        null=True,
        blank=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    def __str__(self):
        return f"Pregnancy info of {self.member.firebase_uid}"
