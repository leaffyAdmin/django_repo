# Celery and Celery Beat Setup

This Django application is configured with Celery for background task processing and Celery Beat for scheduled tasks

## Prerequisites

1. **Redis Server** - Required as the message brokers
2. **Python Dependencies** - Install from requirements.txt

## Installations

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Install and Start Redis

**On Windows:**
```bash
# Download Redis for Windows from https://github.com/microsoftarchive/redis/releases
# Or use WSL2 with Redis
# Or use Docker:
docker run -d -p 6379:6379 redis:alpine
```

**On macOS:**
```bash
brew install redis
brew services start redis
```

**On Linux:**
```bash
sudo apt-get install redis-server
sudo systemctl start redis-server
```

### 3. Run Django Migrations

```bash
python manage.py migrate
```

### 4. Set up Celery Beat Schedules

```bash
python manage.py setup_celery_beat
```

## Running the Application

### 1. Start Django Development Server

```bash
python manage.py runserver
```

### 2. Start Celery Worker

In a new terminal:
```bash
celery -A core worker -l info
```

### 3. Start Celery Beat (Scheduler)

In another new terminal:
```bash
celery -A core beat -l info
```

## Available Tasks

### Health Check Tasks

1. **health_check_task** - Performs background health checks
2. **cleanup_old_health_logs** - Cleans up old health check logs
3. **send_health_report** - Sends periodic health reports
4. **test_task** - Simple test task for debugging

### Scheduled Tasks (via Celery Beat)

- **Health Check**: Every 5 minutes
- **Cleanup**: Every 1 hour
- **Health Report**: Every 24 hours

## API Endpoints

### Health API with Celery Integration

1. **Basic Health Check**: `GET /app/health/`
2. **Detailed Health Check**: `GET /app/health/detailed/`
3. **Readiness Probe**: `GET /app/health/ready/`
4. **Trigger Health Task**: `POST /app/health/task/trigger/`
5. **Trigger Test Task**: `POST /app/health/task/test/`
6. **Check Task Status**: `GET /app/health/task/status/<task_id>/`

## Testing Celery

### 1. Trigger a Task via API

```bash
# Trigger health check task
curl -X POST http://localhost:8000/app/health/task/trigger/

# Trigger test task
curl -X POST http://localhost:8000/app/health/task/test/
```

### 2. Check Task Status

```bash
# Replace <task_id> with the actual task ID from the response
curl http://localhost:8000/app/health/task/status/<task_id>/
```

### 3. Monitor Celery Workers

```bash
# Check worker status
celery -A core inspect active

# Check registered tasks
celery -A core inspect registered

# Check scheduled tasks
celery -A core inspect scheduled
```

## Configuration

### Celery Settings (core/settings.py)

```python
# Broker and Result Backend
CELERY_BROKER_URL = 'redis://localhost:6379/0'
CELERY_RESULT_BACKEND = 'redis://localhost:6379/0'

# Serialization
CELERY_ACCEPT_CONTENT = ['json']
CELERY_TASK_SERIALIZER = 'json'
CELERY_RESULT_SERIALIZER = 'json'

# Beat Scheduler
CELERY_BEAT_SCHEDULER = 'django_celery_beat.schedulers:DatabaseScheduler'

# Task Routing
CELERY_TASK_ROUTES = {
    'apps.health.tasks.*': {'queue': 'health'},
}

# Worker Configuration
CELERY_WORKER_CONCURRENCY = 4
CELERY_WORKER_MAX_TASKS_PER_CHILD = 1000
```

## Development vs Production

### Development
- Use `CELERY_TASK_ALWAYS_EAGER = True` for testing without Redis
- Tasks run synchronously in the same process

### Production
- Set `CELERY_TASK_ALWAYS_EAGER = False`
- Use Redis or RabbitMQ as message broker
- Run workers in separate processes/containers
- Use supervisor or systemd to manage Celery processes

## Troubleshooting

### Common Issues

1. **Redis Connection Error**
   - Ensure Redis is running: `redis-cli ping`
   - Check Redis URL in settings

2. **Task Not Executing**
   - Check worker is running: `celery -A core inspect active`
   - Check task routing and queue configuration

3. **Beat Not Scheduling**
   - Ensure Celery Beat is running
   - Check database migrations are applied
   - Verify periodic tasks are created

### Debug Commands

```bash
# Check Redis connection
redis-cli ping

# Check Celery configuration
celery -A core inspect conf

# Monitor task execution
celery -A core events

# Check worker logs
celery -A core worker -l debug
```

## Monitoring

### Celery Monitoring Tools

1. **Flower** - Web-based monitoring tool
   ```bash
   pip install flower
   celery -A core flower
   ```

2. **Celery Events** - Real-time monitoring
   ```bash
   celery -A core events
   ```

3. **Django Admin** - Manage periodic tasks
   - Access `/admin/` to manage Celery Beat schedules

## Security Considerations

1. **Redis Security**
   - Use authentication for Redis in production
   - Bind Redis to localhost only
   - Use SSL/TLS for Redis connections

2. **Task Security**
   - Validate task inputs
   - Use task routing for isolation
   - Monitor task execution times

3. **Worker Security**
   - Run workers with minimal privileges
   - Use virtual environments
   - Regular security updates 
