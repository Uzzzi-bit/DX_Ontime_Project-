from django.db import models

class Member(models.Model):   # 👈 클래스 이름 정확히 Member
    member_id = models.CharField(max_length=50, primary_key=True)
    password = models.CharField(max_length=255)
    nickname = models.CharField(max_length=50)
    birth_date = models.CharField(max_length=8)   # 'YYYYMMDD'
    phone = models.CharField(max_length=20)
    address = models.CharField(max_length=300)
    is_pregnant_mode = models.CharField(max_length=1, default='N')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'MEMBER'  # 오라클 실제 테이블 이름

    def __str__(self):
        return f"{self.member_id} ({self.nickname})"
class HealthRecord(models.Model):
    id = models.AutoField(primary_key=True)
    member = models.ForeignKey(Member, on_delete=models.CASCADE, related_name='health_records')
    record_date = models.DateField()
    weight = models.FloatField(null=True, blank=True)
    blood_pressure_high = models.IntegerField(null=True, blank=True)
    blood_pressure_low = models.IntegerField(null=True, blank=True)
    blood_sugar = models.FloatField(null=True, blank=True)
    memo = models.CharField(max_length=500, blank=True)
    image_url = models.CharField(max_length=500, blank=True)

    class Meta:
        db_table = 'HEALTH_RECORD'
