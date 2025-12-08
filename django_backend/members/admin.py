from django.contrib import admin
from .models import BodyMeasurement


@admin.register(BodyMeasurement)
class BodyMeasurementAdmin(admin.ModelAdmin):
    list_display = ['id', 'member', 'measurement_date', 'weight_kg', 'blood_sugar_fasting', 'blood_sugar_postprandial', 'created_at']
    list_filter = ['measurement_date', 'created_at']
    search_fields = ['member__nickname', 'member__firebase_uid']
    date_hierarchy = 'measurement_date'
