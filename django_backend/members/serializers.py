from rest_framework import serializers
from .models import Member, MemberPregnancy

class MemberSerializer(serializers.ModelSerializer):
    class Meta:
        model = Member
        fields = '__all__'

class MemberPregnancySerializer(serializers.ModelSerializer):
    class Meta:
        model = MemberPregnancy
        fields = '__all__'
