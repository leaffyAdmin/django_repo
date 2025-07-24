# Health API

This Django app provides health check endpoints for monitoring the application status and includes Celery integration for background tasks.

## Endpoints

### 1. Basic Health Check
- **URL**: `/app/health/`
- **Method**: GET
- **Description**: Basic health check that returns application status
- **Response**: JSON with status, timestamp, and basic checks

**Example Response:**
```json
{
    "status": "healthy",
    "timestamp": "2024-01-15T10:30:00.000000Z",
    "service": "django_app",
    "version": "1.0.0",
    "checks": {
        "database": "connected",
        "application": "running"
    }
}
```

### 2. Detailed Health Check
- **URL**: `/app/health/detailed/`
- **Method**: GET
- **Description**: Comprehensive health check with detailed information
- **Response**: JSON with detailed status, checks, and metadata

**Example Response:**
```json
{
    "status": "healthy",
    "timestamp": "2024-01-15T10:30:00.000000Z",
    "service": "django_app",
    "version": "1.0.0",
    "environment": "development",
    "checks": {
        "database": "connected",
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
```

### 3. Readiness Probe
- **URL**: `/app/health/ready/`
- **Method**: GET
- **Description**: Checks if the application is ready to serve traffic
- **Response**: JSON with readiness status

**Example Response:**
```json
{
    "ready": true,
    "timestamp": "2024-01-15T10:30:00.000000Z",
    "service": "django_app",
    "checks": {
        "database": "ready",
        "application": "ready"
    }
}
```

### 4. Trigger Health Task (Celery)
- **URL**: `/app/health/task/trigger/`
- **Method**: POST
- **Description**: Triggers a background health check task
- **Response**: JSON with task ID and status

**Example Response:**
```json
{
    "message": "Health check task triggered successfully",
    "task_id": "12345678-1234-5678-9abc-123456789abc",
    "status": "queued",
    "timestamp": "2024-01-15T10:30:00.000000Z"
}
```

### 5. Trigger Test Task (Celery)
- **URL**: `/app/health/task/test/`
- **Method**: POST
- **Description**: Triggers a simple test task for debugging
- **Response**: JSON with task ID and status

**Example Response:**
```json
{
    "message": "Test task triggered successfully",
    "task_id": "87654321-4321-8765-cba9-987654321cba",
    "status": "queued",
    "timestamp": "2024-01-15T10:30:00.000000Z"
}
```

### 6. Check Task Status (Celery)
- **URL**: `/app/health/task/status/<task_id>/`
- **Method**: GET
- **Description**: Checks the status of a Celery task
- **Response**: JSON with task status and result (if completed)

**Example Response:**
```json
{
    "task_id": "12345678-1234-5678-9abc-123456789abc",
    "status": "SUCCESS",
    "timestamp": "2024-01-15T10:30:00.000000Z",
    "result": {
        "status": "completed",
        "timestamp": "2024-01-15T10:30:00.000000Z",
        "database_status": "healthy",
        "task_id": "12345678-1234-5678-9abc-123456789abc"
    }
}
```

## Usage

### Testing the endpoints:

1. **Start the Django server:**
   ```bash
   python manage.py runserver
   ```

2. **Test the health endpoints:**
   ```bash
   # Basic health check
   curl http://localhost:8000/app/health/
   
   # Detailed health check
   curl http://localhost:8000/app/health/detailed/
   
   # Readiness probe
   curl http://localhost:8000/app/health/ready/
   ```

3. **Test Celery task endpoints:**
   ```bash
   # Trigger health check task
   curl -X POST http://localhost:8000/app/health/task/trigger/
   
   # Trigger test task
   curl -X POST http://localhost:8000/app/health/task/test/
   
   # Check task status (replace <task_id> with actual ID)
   curl http://localhost:8000/app/health/task/status/<task_id>/
   ```

### Running tests:
```bash
python manage.py test apps.health
```

## Status Codes

- **200**: Application is healthy and ready / Task completed successfully
- **202**: Task accepted and queued
- **503**: Application is unhealthy or not ready
- **405**: Method not allowed (only GET/POST requests are supported)
- **500**: Internal server error

## Celery Integration

This health app includes Celery integration for background task processing:

### Available Tasks

1. **health_check_task** - Performs background health checks
2. **cleanup_old_health_logs** - Cleans up old health check logs
3. **send_health_report** - Sends periodic health reports
4. **test_task** - Simple test task for debugging

### Scheduled Tasks (via Celery Beat)

- **Health Check**: Every 5 minutes
- **Cleanup**: Every 1 hour
- **Health Report**: Every 24 hours

### Running Celery

1. **Start Celery Worker:**
   ```bash
   celery -A core worker -l info
   ```

2. **Start Celery Beat (Scheduler):**
   ```bash
   celery -A core beat -l info
   ```

3. **Set up periodic tasks:**
   ```bash
   python manage.py setup_celery_beat
   ```

## Customization

You can extend the health checks by modifying the views in `views.py`:

- Add database connectivity checks
- Check external service dependencies
- Monitor system resources
- Add custom business logic checks

You can also add new Celery tasks in `tasks.py`:

- Background data processing
- External API calls
- File operations
- Email notifications

## Deployment

These endpoints are commonly used for:
- Kubernetes liveness and readiness probes
- Load balancer health checks
- Monitoring system integration
- CI/CD pipeline health verification
- Background task processing
- Scheduled maintenance tasks 