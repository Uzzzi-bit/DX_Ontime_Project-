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
        primary_key=True,
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

    @property
    def id(self):
        """
        Django의 기본 id 필드 대신 member_id를 반환
        Serializer와 다른 코드에서 .id를 사용할 수 있도록 함
        """
        return self.member_id

    def __str__(self):
        return f"Pregnancy info of {self.member.firebase_uid}"


class FamilyRelation(models.Model):
    """
    가족 구성원 관계 테이블
    임산부(member_id)와 보호자(guardian_member_id)의 관계를 저장
    """
    id = models.AutoField(primary_key=True, db_column='id')
    member_id = models.CharField(
        max_length=128,
        db_column='member_id',
        help_text="임산부의 Firebase UID (MEMBER.id 참조)",
    )
    guardian_member_id = models.CharField(
        max_length=128,
        db_column='guardian_member_id',
        help_text="보호자의 Firebase UID (MEMBER.id 참조)",
    )
    relation_type = models.CharField(
        max_length=50,
        db_column='relation_type',
        help_text="관계 타입 (배우자, 부모님, 가족, 형제자매, 지인 등)",
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        db_column='created_at',
    )

    class Meta:
        db_table = 'FAMILY_RELATION'
        managed = True
        # 같은 임산부와 보호자 조합은 중복 방지
        unique_together = [['member_id', 'guardian_member_id']]
        indexes = [
            models.Index(fields=['member_id']),
            models.Index(fields=['guardian_member_id']),
        ]

    def __str__(self):
        return f"{self.member_id} - {self.relation_type} - {self.guardian_member_id}"


class Image(models.Model):
    """
    이미지 정보 테이블 (IMAGES)
    - Firebase Storage URL 저장
    - SAM3/분류모델 결과(JSON) 저장
    """
    id = models.AutoField(primary_key=True, db_column='id')
    member_id = models.CharField(
        max_length=128,
        db_column='member_id',
        help_text="업로드한 사용자의 Firebase UID (MEMBER.id 참조)",
    )
    image_url = models.TextField(
        db_column='image_url',
        help_text="Firebase Storage URL",
    )
    ingredient_info = models.TextField(
        null=True,
        blank=True,
        db_column='ingredient_info',
        help_text="SAM3/분류모델 결과(JSON)",
    )
    image_type = models.CharField(
        max_length=50,
        db_column='image_type',
        help_text="이미지 타입: 'meal', 'chat', 'recipe' 등",
    )
    source = models.CharField(
        max_length=50,
        db_column='source',
        help_text="이미지 소스: 'ai_chat', 'meal_form', 'system' 등",
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        db_column='created_at',
    )

    class Meta:
        db_table = 'images'
        managed = True
        indexes = [
            models.Index(fields=['member_id']),
            models.Index(fields=['image_type']),
            models.Index(fields=['created_at']),
        ]
        ordering = ['-created_at']

    @property
    def image_id(self):
        """image_id는 id와 동일하게 사용"""
        return self.id

    def __str__(self):
        return f"Image {self.id} - {self.member_id} - {self.image_type}"


class AiChatSession(models.Model):
    """
    AI 채팅 세션 테이블 (AI_CHAT_SESSION)
    - 대화 세션 정보 저장
    - id를 session_id로 사용 (Django는 하나의 PK만 허용)
    """
    id = models.AutoField(primary_key=True, db_column='id')
    # session_id는 id와 동일하게 사용 (property로 제공)
    member_id = models.CharField(
        max_length=128,
        db_column='member_id',
        help_text="대화 주인의 Firebase UID (MEMBER.id 참조)",
    )
    started_at = models.DateTimeField(
        db_column='started_at',
        help_text="대화 시작 시간",
        auto_now_add=True,
    )
    ended_at = models.DateTimeField(
        null=True,
        blank=True,
        db_column='ended_at',
        help_text="대화 종료 시간",
    )

    class Meta:
        db_table = 'AI_CHAT_SESSION'
        managed = True
        indexes = [
            models.Index(fields=['member_id']),
            models.Index(fields=['started_at']),
        ]
        ordering = ['-started_at']

    @property
    def session_id(self):
        """session_id는 id와 동일"""
        return self.id

    def __str__(self):
        return f"Session {self.id} - {self.member_id}"


class AiChat(models.Model):
    """
    AI 채팅 대화 내용 테이블 (AI_CHAT)
    - 실제 대화 메시지 저장
    - id를 chat_id로 사용 (Django는 하나의 PK만 허용)
    """
    id = models.AutoField(primary_key=True, db_column='id')
    # chat_id는 id와 동일하게 사용 (property로 제공)
    member_id = models.CharField(
        max_length=128,
        db_column='member_id',
        help_text="사용자 Firebase UID (MEMBER.id 참조)",
    )
    session = models.ForeignKey(
        AiChatSession,
        on_delete=models.CASCADE,
        related_name='chats',
        db_column='session_id',
        to_field='id',
        help_text="대화방 세션 ID",
    )
    type = models.CharField(
        max_length=10,
        db_column='type',
        help_text="메시지 타입: 'user' 또는 'ai'",
        choices=[
            ('user', '사용자'),
            ('ai', 'AI'),
        ],
    )
    content = models.TextField(
        db_column='content',
        help_text="실제 대화 내용",
    )
    image = models.ForeignKey(
        Image,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='ai_chats',
        db_column='image_pk',
        to_field='id',
        help_text="이미지 포함 여부 (IMAGES.image_id 참조)",
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        db_column='created_at',
    )

    class Meta:
        db_table = 'AI_CHAT'
        managed = True
        indexes = [
            models.Index(fields=['member_id']),
            models.Index(fields=['session_id']),
            models.Index(fields=['type']),
            models.Index(fields=['created_at']),
        ]
        ordering = ['created_at']

    @property
    def chat_id(self):
        """chat_id는 id와 동일"""
        return self.id

    @property
    def session_id(self):
        """session_id는 session의 id를 반환"""
        return self.session.id if self.session else None

    @property
    def image_pk(self):
        """image_pk는 image의 id를 반환"""
        return self.image.id if self.image else None

    def __str__(self):
        return f"Chat {self.id} - {self.type} - {self.member_id}"


class MemberNutritionTarget(models.Model):
    """
    임신 주차별 영양소 하루 권장량 테이블 (member_nutrition_target)
    - 1분기: 1-13주차
    - 2분기: 14-27주차
    - 3분기: 28-40주차
    """
    trimester = models.IntegerField(
        db_column='trimester',
        primary_key=True,
        help_text="임신 분기 (1, 2, 3)",
    )
    calories = models.IntegerField(
        db_column='calories',
        help_text="칼로리 (kcal)",
    )
    carb = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        db_column='carbs',  # 실제 DB 컬럼명은 carbs (복수형)
        help_text="탄수화물 (g)",
    )
    protein = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        db_column='protein',
        help_text="단백질 (g)",
    )
    fat = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        db_column='fat',
        help_text="지방 (g)",
    )
    sodium = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        db_column='sodium',
        help_text="나트륨 (mg)",
    )
    iron = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        db_column='iron',
        help_text="철분 (mg)",
    )
    folate = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        db_column='folate',
        help_text="엽산 (ug)",
    )
    calcium = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        db_column='calcium',
        help_text="칼슘 (mg)",
    )
    vitamin_d = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        db_column='vitamin_d',
        help_text="비타민 D (ug)",
    )
    omega3 = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        db_column='omega3',
        help_text="오메가3 (mg)",
    )
    sugar = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        db_column='sugar',
        help_text="당 (g)",
        null=True,
        blank=True,
    )
    magnesium = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        db_column='magnesium',
        help_text="마그네슘 (mg)",
        null=True,
        blank=True,
    )
    vitamin_a = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        db_column='vitamin_a',
        help_text="비타민 A (μg)",
        null=True,
        blank=True,
    )
    vitamin_b12 = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        db_column='vitamin_b12',
        help_text="비타민 B12 (μg)",
        null=True,
        blank=True,
    )
    vitamin_c = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        db_column='vitamin_c',
        help_text="비타민 C (mg)",
        null=True,
        blank=True,
    )
    dietary_fiber = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        db_column='dietary_fiber',
        help_text="식이섬유 (g)",
        null=True,
        blank=True,
    )
    potassium = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        db_column='potassium',
        help_text="칼륨 (mg)",
        null=True,
        blank=True,
    )

    class Meta:
        db_table = 'member_nutrition_targets'
        managed = True
        indexes = [
            models.Index(fields=['trimester']),
        ]

    def __str__(self):
        return f"Trimester {self.trimester} - {self.calories} kcal"


class Meal(models.Model):
    """
    식사 기록 테이블 (meals)
    """
    meal_id = models.AutoField(primary_key=True, db_column='meal_id')
    member = models.ForeignKey(
        Member,
        on_delete=models.CASCADE,
        related_name='meals',
        db_column='member_id',
        to_field='firebase_uid',
    )
    image = models.ForeignKey(
        Image,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='meals',
        db_column='image_id',
    )
    meal_time = models.CharField(
        max_length=20,
        help_text="조식/중식/석식/야식",
        db_column='meal_time',
    )
    meal_date = models.DateField(
        db_column='meal_date',
        help_text="달력 기준 날짜",
    )
    memo = models.TextField(
        null=True,
        blank=True,
        db_column='memo',
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        db_column='created_at',
    )

    class Meta:
        db_table = 'meals'
        managed = True
        indexes = [
            models.Index(fields=['member', 'meal_date']),
            models.Index(fields=['meal_date']),
        ]

    def __str__(self):
        return f"{self.member.nickname} - {self.meal_date} {self.meal_time}"


class NutritionAnalysis(models.Model):
    """
    영양소 분석 테이블 (nutrition_analysis)
    """
    id = models.AutoField(primary_key=True)
    analysis_id = models.IntegerField(
        null=True,
        blank=True,
        db_column='analysis_id',
        help_text="필요시 UNIQUE/INDEX 추가해서 사용",
    )
    meal = models.ForeignKey(
        Meal,
        on_delete=models.CASCADE,
        related_name='nutrition_analyses',
        db_column='meal_id',
    )
    food_id = models.IntegerField(
        null=True,
        blank=True,
        db_column='food_id',
        help_text="FOOD_NUTRITION_MASTER.food_id (FK 아님)",
    )
    food_name = models.CharField(
        max_length=255,
        null=True,
        blank=True,
        db_column='food_name',
        help_text="AI가 인식한 원본 음식명",
    )
    # 영양소 필드들
    calories = models.FloatField(null=True, blank=True, db_column='calories')  # kcal
    carbs = models.FloatField(null=True, blank=True, db_column='carbs')  # g
    protein = models.FloatField(null=True, blank=True, db_column='protein')  # g
    fat = models.FloatField(null=True, blank=True, db_column='fat')  # g
    sugar = models.FloatField(null=True, blank=True, db_column='sugar')  # g
    sodium = models.FloatField(null=True, blank=True, db_column='sodium')  # mg
    iron = models.FloatField(null=True, blank=True, db_column='iron')  # mg
    folate = models.FloatField(null=True, blank=True, db_column='folate')  # mg
    magnesium = models.FloatField(null=True, blank=True, db_column='magnesium')  # mg
    omega3 = models.FloatField(null=True, blank=True, db_column='omega3')  # g
    calcium = models.FloatField(null=True, blank=True, db_column='calcium')  # mg
    vitamin_a = models.FloatField(null=True, blank=True, db_column='vitamin_a')  # μg
    vitamin_b = models.FloatField(null=True, blank=True, db_column='vitamin_b')  # μg
    vitamin_c = models.FloatField(null=True, blank=True, db_column='vitamin_c')  # mg
    vitamin_d = models.FloatField(null=True, blank=True, db_column='vitamin_d')  # μg
    dietary_fiber = models.FloatField(null=True, blank=True, db_column='dietary_fiber')  # g
    potassium = models.FloatField(null=True, blank=True, db_column='potassium')  # mg
    serving_size_gram = models.FloatField(
        null=True,
        blank=True,
        db_column='serving_size_gram',
        help_text="분석 기준 섭취량(예: 230g)",
    )
    base_per_gram = models.FloatField(
        null=True,
        blank=True,
        db_column='base_per_gram',
        help_text="내부 계산용",
    )
    ai_risk_level = models.CharField(
        max_length=50,
        null=True,
        blank=True,
        db_column='ai_risk_level',
        help_text="예: LOW/MEDIUM/HIGH",
    )
    ai_recommendation = models.TextField(
        null=True,
        blank=True,
        db_column='ai_recommendation',
        help_text="AI 코멘트",
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        db_column='created_at',
    )

    class Meta:
        db_table = 'nutrition_analysis'
        managed = True
        indexes = [
            models.Index(fields=['meal']),
            models.Index(fields=['food_id']),
            models.Index(fields=['analysis_id']),
        ]

    def __str__(self):
        return f"Analysis {self.id} - {self.food_name} ({self.meal})"


class Recommendation(models.Model):
    """
    추천 메뉴 테이블 (recommendations)
    """
    rec_id = models.AutoField(primary_key=True, db_column='rec_id')
    member = models.ForeignKey(
        Member,
        on_delete=models.CASCADE,
        related_name='recommendations',
        db_column='member_id',
        to_field='firebase_uid',
    )
    meal = models.ForeignKey(
        Meal,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='recommendations',
        db_column='meal_id',
        help_text="어떤 식단에서 나왔는지 (없으면 단독 추천)",
    )
    recipe_pk = models.IntegerField(
        null=True,
        blank=True,
        db_column='recipe_pk',
        help_text="RECIPES.recipe_id (FK 아님, 소프트 레퍼런스)",
    )
    recommended_food = models.CharField(
        max_length=255,
        db_column='recommended_food',
        help_text="추천 메뉴명/타이틀",
    )
    reason = models.TextField(
        null=True,
        blank=True,
        db_column='reason',
        help_text="추천 이유 설명",
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        db_column='created_at',
    )

    class Meta:
        db_table = 'recommendations'
        managed = True
        indexes = [
            models.Index(fields=['member', 'created_at']),
            models.Index(fields=['meal']),
        ]

    def __str__(self):
        return f"{self.member.nickname} - {self.recommended_food}"


class Notification(models.Model):
    """
    알림 테이블 (notifications)
    """
    noti_id = models.AutoField(primary_key=True, db_column='noti_id')
    member = models.ForeignKey(
        Member,
        on_delete=models.CASCADE,
        related_name='notifications',
        db_column='member_id',
        to_field='firebase_uid',
        help_text="알림 주체(임산부)",
    )
    guardian_member = models.ForeignKey(
        Member,
        on_delete=models.CASCADE,
        related_name='guardian_notifications',
        null=True,
        blank=True,
        db_column='guardian_member_id',
        to_field='firebase_uid',
        help_text="보호자",
    )
    recommendation = models.ForeignKey(
        Recommendation,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='notifications',
        db_column='rec_id',
        help_text="어떤 추천 기반인지",
    )
    message = models.TextField(
        db_column='message',
        help_text="알림 내용",
    )
    is_read = models.BooleanField(
        default=False,
        db_column='is_read',
        help_text="읽음 여부",
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        db_column='created_at',
    )

    class Meta:
        db_table = 'notifications'
        managed = True
        indexes = [
            models.Index(fields=['member', 'is_read', 'created_at']),
            models.Index(fields=['guardian_member', 'is_read']),
        ]

    def __str__(self):
        return f"Notification {self.noti_id} - {self.member.nickname}"
