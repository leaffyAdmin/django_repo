from django.urls import path
from . import views

app_name = 'health'

urlpatterns = [
    path('', views.health_check, name='health_check'),
    path('detailed/', views.health_detailed, name='health_detailed'),
    path('ready/', views.health_ready, name='health_ready'),
    path('task/trigger/', views.trigger_health_task, name='trigger_health_task'),
    path('task/test/', views.trigger_test_task, name='trigger_test_task'),
    path('task/status/<str:task_id>/', views.task_status, name='task_status'),
] 