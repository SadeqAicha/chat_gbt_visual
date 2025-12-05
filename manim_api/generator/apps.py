# generator/apps.py
from django.apps import AppConfig

class GeneratorConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'generator' # تأكد من أن هذا هو اسم المجلد الذي يحتوي على التطبيق
