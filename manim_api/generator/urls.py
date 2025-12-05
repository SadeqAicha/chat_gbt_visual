from django.urls import path
from .views import generate_animation

urlpatterns = [
    path('generate/', generate_animation, name='generate_animation'),
]
