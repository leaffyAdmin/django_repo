# Docker Setup and Deployment

This Django application is fully containerized using Docker with Ubuntu base images, Redis, and optional PostgreSQL.

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Nginx (80)    │    │  Django Web     │    │   Redis (6379)  │
│   (Reverse      │◄──►│   (8000)        │◄──►│   (Message      │
│    Proxy)       │    │                 │    │    Broker)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │  PostgreSQL     │
                       │   (5432)        │
                       │  (Optional)     │
                       └─────────────────┘
                                │
                                ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Celery Worker   │    │ Celery Beat     │    │   Flower        │
│ (Background     │    │ (Scheduler)     │    │ (Monitoring)    │
│  Tasks)         │    │                 │    │   (5555)        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- At least 4GB RAM available

## Quick Start

### 1. Development Environment

```bash
# Build and start development environment
docker-compose -f docker-compose.dev.yml up --build

# Or run in background
docker-compose -f docker-compose.dev.yml up -d --build
```

### 2. Production Environment

```bash
# Build and start production environment
docker-compose up --build

# Or run in background
docker-compose up -d --build
```

## Services

### Core Services

| Service | Port | Description | Image |
|---------|------|-------------|-------|
| **web** | 8000 | Django Web Application | Ubuntu 22.04 |
| **redis** | 6379 | Message Broker | Redis 7 Alpine |
| **postgres** | 5432 | Database (Optional) | PostgreSQL 15 |
| **nginx** | 80 | Reverse Proxy | Nginx Alpine |

### Celery Services

| Service | Port | Description |
|---------|------|-------------|
| **celery_worker** | - | Background Task Worker |
| **celery_beat** | - | Task Scheduler |
| **flower** | 5555 | Celery Monitoring |

## Access Points

### Web Interfaces

- **Django Admin**: http://localhost:8000/admin/
- **Health API**: http://localhost:8000/app/health/
- **Flower (Celery)**: http://localhost:5555/
- **Nginx**: http://localhost/ (if using production setup)

### API Endpoints

```bash
# Health Check
curl http://localhost:8000/app/health/

# Detailed Health
curl http://localhost:8000/app/health/detailed/

# Trigger Celery Task
curl -X POST http://localhost:8000/app/health/task/trigger/

# Check Task Status
curl http://localhost:8000/app/health/task/status/<task_id>/
```

## Docker Commands

### Development

```bash
# Start development environment
docker-compose -f docker-compose.dev.yml up

# Start specific services
docker-compose -f docker-compose.dev.yml up web redis

# View logs
docker-compose -f docker-compose.dev.yml logs -f web

# Execute commands in container
docker-compose -f docker-compose.dev.yml exec web python manage.py shell
docker-compose -f docker-compose.dev.yml exec web python manage.py migrate

# Stop services
docker-compose -f docker-compose.dev.yml down
```

### Production

```bash
# Start production environment
docker-compose up -d

# Scale services
docker-compose up -d --scale celery_worker=3

# View logs
docker-compose logs -f

# Execute commands
docker-compose exec web python manage.py collectstatic

# Stop and remove everything
docker-compose down -v
```

## Environment Variables

### Core Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DEBUG` | `True` | Django debug mode |
| `SECRET_KEY` | Auto-generated | Django secret key |
| `ALLOWED_HOSTS` | `localhost,127.0.0.1,0.0.0.0` | Allowed hosts |
| `DATABASE_URL` | SQLite | Database connection URL |

### Celery Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CELERY_BROKER_URL` | `redis://redis:6379/0` | Redis broker URL |
| `CELERY_RESULT_BACKEND` | `redis://redis:6379/0` | Result backend URL |
| `CELERY_WORKER_CONCURRENCY` | `4` | Worker concurrency |
| `CELERY_TASK_ALWAYS_EAGER` | `False` | Run tasks synchronously |

## Database Configuration

### SQLite (Development)
```yaml
# No DATABASE_URL set - uses SQLite by default
```

### PostgreSQL (Production)
```yaml
environment:
  - DATABASE_URL=postgresql://django_user:django_password@postgres:5432/django_health_celery
```

## Volumes

| Volume | Purpose | Location |
|--------|---------|----------|
| `redis_data` | Redis persistence | `/data` |
| `postgres_data` | PostgreSQL data | `/var/lib/postgresql/data` |
| `static_volume` | Static files | `/app/static` |
| `media_volume` | Media files | `/app/media` |

## Health Checks

All services include health checks:

```bash
# Check service health
docker-compose ps

# View health check logs
docker-compose logs web | grep health
```

## Monitoring

### Flower (Celery Monitoring)
- **URL**: http://localhost:5555
- **Features**: Task monitoring, worker status, task history

### Django Admin
- **URL**: http://localhost:8000/admin/
- **Features**: Database management, Celery Beat schedules

### Logs
```bash
# View all logs
docker-compose logs

# View specific service logs
docker-compose logs web
docker-compose logs celery_worker
docker-compose logs redis

# Follow logs in real-time
docker-compose logs -f
```

## Troubleshooting

### Common Issues

1. **Port Already in Use**
   ```bash
   # Check what's using the port
   netstat -tulpn | grep :8000
   
   # Stop conflicting services
   sudo systemctl stop apache2  # if using Apache
   ```

2. **Permission Issues**
   ```bash
   # Fix file permissions
   sudo chown -R $USER:$USER .
   chmod +x manage.py
   ```

3. **Redis Connection Issues**
   ```bash
   # Test Redis connection
   docker-compose exec redis redis-cli ping
   
   # Check Redis logs
   docker-compose logs redis
   ```

4. **Database Migration Issues**
   ```bash
   # Run migrations
   docker-compose exec web python manage.py migrate
   
   # Create superuser
   docker-compose exec web python manage.py createsuperuser
   ```

### Debug Commands

```bash
# Check container status
docker-compose ps

# Inspect container
docker-compose exec web bash

# Check network connectivity
docker-compose exec web ping redis

# View container resources
docker stats
```

## Production Deployment

### 1. Environment Setup
```bash
# Create production environment file
cp .env.example .env.prod

# Edit production variables
nano .env.prod
```

### 2. Build and Deploy
```bash
# Build production images
docker-compose build

# Start production services
docker-compose -f docker-compose.yml up -d

# Run migrations
docker-compose exec web python manage.py migrate

# Collect static files
docker-compose exec web python manage.py collectstatic --noinput
```

### 3. SSL/HTTPS Setup
```bash
# Add SSL certificates
mkdir -p ssl/
# Copy your certificates to ssl/ directory

# Update nginx.conf for SSL
# Add SSL configuration to nginx.conf
```

## Security Considerations

1. **Change Default Passwords**
   - Update PostgreSQL password
   - Change Django secret key
   - Use strong passwords for admin users

2. **Network Security**
   - Use internal Docker networks
   - Expose only necessary ports
   - Implement rate limiting

3. **Data Protection**
   - Use encrypted volumes
   - Regular backups
   - Secure environment variables

## Backup and Restore

### Database Backup
```bash
# PostgreSQL backup
docker-compose exec postgres pg_dump -U django_user django_health_celery > backup.sql

# Restore
docker-compose exec -T postgres psql -U django_user django_health_celery < backup.sql
```

### Volume Backup
```bash
# Backup volumes
docker run --rm -v django_app_postgres_data:/data -v $(pwd):/backup alpine tar czf /backup/postgres_backup.tar.gz -C /data .

# Restore volumes
docker run --rm -v django_app_postgres_data:/data -v $(pwd):/backup alpine tar xzf /backup/postgres_backup.tar.gz -C /data
```

## Performance Optimization

1. **Resource Limits**
   ```yaml
   services:
     web:
       deploy:
         resources:
           limits:
             memory: 1G
             cpus: '0.5'
   ```

2. **Caching**
   - Redis for session storage
   - Static file caching
   - Database query optimization

3. **Scaling**
   ```bash
   # Scale workers
   docker-compose up -d --scale celery_worker=4
   
   # Load balancing with nginx
   # Configure multiple web instances
   ``` 