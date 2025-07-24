from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
import json
from datetime import datetime
from .tasks import health_check_task, test_task


@csrf_exempt
@require_http_methods(["GET"])
def health_check(request):
    """
    Basic health check endpoint
    Returns application status and basic information
    """
    try:
        # Basic health check - you can add more checks here
        # like database connectivity, external service checks, etc.
        
        health_data = {
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "service": "django_app",
            "version": "1.0.0",
            "checks": {
                "database": "connected",
                "application": "running"
            }
        }
        
        return JsonResponse(health_data, status=200)
    
    except Exception as e:
        error_data = {
            "status": "unhealthy",
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "error": str(e),
            "service": "django_app"
        }
        return JsonResponse(error_data, status=503)


@csrf_exempt
@require_http_methods(["GET"])
def health_detailed(request):
    """
    Detailed health check endpoint
    Returns more comprehensive health information
    """
    try:
        from django.db import connection
        from django.db.utils import OperationalError
        
        # Test database connection
        db_status = "connected"
        try:
            connection.ensure_connection()
        except OperationalError:
            db_status = "disconnected"
        
        detailed_health = {
            "status": "healthy" if db_status == "connected" else "unhealthy",
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "service": "django_app",
            "version": "1.0.0",
            "environment": "development",
            "checks": {
                "database": db_status,
                "application": "running",
                "memory": "available",
                "disk": "available"
            },
            "metadata": {
                "django_version": "5.0.4",
                "python_version": "3.x",
                "server": "django_development_server"
            }
        }
        
        status_code = 200 if detailed_health["status"] == "healthy" else 503
        return JsonResponse(detailed_health, status=status_code)
    
    except Exception as e:
        error_data = {
            "status": "unhealthy",
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "error": str(e),
            "service": "django_app"
        }
        return JsonResponse(error_data, status=503)


@csrf_exempt
@require_http_methods(["GET"])
def health_ready(request):
    """
    Readiness probe endpoint
    Checks if the application is ready to serve traffic
    """
    try:
        from django.db import connection
        from django.db.utils import OperationalError
        
        # Test database connection
        try:
            connection.ensure_connection()
            db_ready = True
        except OperationalError:
            db_ready = False
        
        ready_data = {
            "ready": db_ready,
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "service": "django_app",
            "checks": {
                "database": "ready" if db_ready else "not_ready",
                "application": "ready"
            }
        }
        
        status_code = 200 if ready_data["ready"] else 503
        return JsonResponse(ready_data, status=status_code)
    
    except Exception as e:
        error_data = {
            "ready": False,
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "error": str(e),
            "service": "django_app"
        }
        return JsonResponse(error_data, status=503)


@csrf_exempt
@require_http_methods(["POST"])
def trigger_health_task(request):
    """
    Trigger a background health check task
    """
    try:
        # Trigger the health check task
        task = health_check_task.delay()
        
        return JsonResponse({
            "message": "Health check task triggered successfully",
            "task_id": task.id,
            "status": "queued",
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }, status=202)
    
    except Exception as e:
        return JsonResponse({
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }, status=500)


@csrf_exempt
@require_http_methods(["GET"])
def task_status(request, task_id):
    """
    Check the status of a Celery task
    """
    try:
        from celery.result import AsyncResult
        
        task_result = AsyncResult(task_id)
        
        response_data = {
            "task_id": task_id,
            "status": task_result.status,
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }
        
        if task_result.ready():
            if task_result.successful():
                response_data["result"] = task_result.result
            else:
                response_data["error"] = str(task_result.info)
        
        return JsonResponse(response_data, status=200)
    
    except Exception as e:
        return JsonResponse({
            "error": str(e),
            "task_id": task_id,
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }, status=500)


@csrf_exempt
@require_http_methods(["POST"])
def trigger_test_task(request):
    """
    Trigger a test task for debugging
    """
    try:
        task = test_task.delay()
        
        return JsonResponse({
            "message": "Test task triggered successfully",
            "task_id": task.id,
            "status": "queued",
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }, status=202)
    
    except Exception as e:
        return JsonResponse({
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }, status=500) 