#!/bin/bash

# Docker Management Script for Django Health Celery App
# Usage: ./docker-scripts.sh [command]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Function to check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
}

# Function to check if docker-compose is available
check_docker_compose() {
    if ! command -v docker-compose &> /dev/null; then
        print_error "docker-compose is not installed. Please install it and try again."
        exit 1
    fi
}

# Development environment commands
dev_start() {
    print_header "Starting Development Environment"
    check_docker
    check_docker_compose
    
    print_status "Building and starting development services..."
    docker-compose -f docker-compose.dev.yml up --build -d
    
    print_status "Waiting for services to be ready..."
    sleep 10
    
    print_status "Running migrations..."
    docker-compose -f docker-compose.dev.yml exec web python manage.py migrate
    
    print_status "Setting up Celery Beat schedules..."
    docker-compose -f docker-compose.dev.yml exec web python manage.py setup_celery_beat
    
    print_status "Development environment is ready!"
    echo -e "${GREEN}Access points:${NC}"
    echo "  Django Admin: http://localhost:8000/admin/"
    echo "  Health API: http://localhost:8000/app/health/"
    echo "  Flower (Celery): http://localhost:5555/"
}

dev_stop() {
    print_header "Stopping Development Environment"
    docker-compose -f docker-compose.dev.yml down
    print_status "Development environment stopped."
}

dev_logs() {
    print_header "Development Logs"
    docker-compose -f docker-compose.dev.yml logs -f
}

dev_shell() {
    print_header "Opening Django Shell"
    docker-compose -f docker-compose.dev.yml exec web python manage.py shell
}

# Production environment commands
prod_start() {
    print_header "Starting Production Environment"
    check_docker
    check_docker_compose
    
    print_status "Building and starting production services..."
    docker-compose up --build -d
    
    print_status "Waiting for services to be ready..."
    sleep 15
    
    print_status "Running migrations..."
    docker-compose exec web python manage.py migrate
    
    print_status "Collecting static files..."
    docker-compose exec web python manage.py collectstatic --noinput
    
    print_status "Setting up Celery Beat schedules..."
    docker-compose exec web python manage.py setup_celery_beat
    
    print_status "Production environment is ready!"
    echo -e "${GREEN}Access points:${NC}"
    echo "  Nginx: http://localhost/"
    echo "  Django Admin: http://localhost/admin/"
    echo "  Health API: http://localhost/app/health/"
    echo "  Flower (Celery): http://localhost:5555/"
}

prod_stop() {
    print_header "Stopping Production Environment"
    docker-compose down
    print_status "Production environment stopped."
}

prod_logs() {
    print_header "Production Logs"
    docker-compose logs -f
}

# Utility commands
status() {
    print_header "Service Status"
    if [ -f "docker-compose.dev.yml" ]; then
        echo -e "${BLUE}Development Services:${NC}"
        docker-compose -f docker-compose.dev.yml ps
        echo
    fi
    
    if [ -f "docker-compose.yml" ]; then
        echo -e "${BLUE}Production Services:${NC}"
        docker-compose ps
    fi
}

cleanup() {
    print_header "Cleaning Up Docker Resources"
    print_warning "This will remove all containers, networks, and volumes!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker-compose -f docker-compose.dev.yml down -v 2>/dev/null || true
        docker-compose down -v 2>/dev/null || true
        docker system prune -f
        docker volume prune -f
        print_status "Cleanup completed."
    else
        print_status "Cleanup cancelled."
    fi
}

backup() {
    print_header "Creating Backup"
    BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    print_status "Backing up PostgreSQL data..."
    docker-compose exec postgres pg_dump -U django_user django_health_celery > "$BACKUP_DIR/database.sql" 2>/dev/null || print_warning "PostgreSQL backup failed (service might not be running)"
    
    print_status "Backing up Redis data..."
    docker run --rm -v django_app_redis_data:/data -v "$(pwd)/$BACKUP_DIR":/backup alpine tar czf /backup/redis_backup.tar.gz -C /data . 2>/dev/null || print_warning "Redis backup failed"
    
    print_status "Backup completed: $BACKUP_DIR"
}

restore() {
    print_header "Restoring from Backup"
    if [ -z "$1" ]; then
        print_error "Please specify backup directory: ./docker-scripts.sh restore <backup_dir>"
        exit 1
    fi
    
    BACKUP_DIR="$1"
    if [ ! -d "$BACKUP_DIR" ]; then
        print_error "Backup directory not found: $BACKUP_DIR"
        exit 1
    fi
    
    print_warning "This will overwrite existing data!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f "$BACKUP_DIR/database.sql" ]; then
            print_status "Restoring PostgreSQL data..."
            docker-compose exec -T postgres psql -U django_user django_health_celery < "$BACKUP_DIR/database.sql" 2>/dev/null || print_warning "PostgreSQL restore failed"
        fi
        
        if [ -f "$BACKUP_DIR/redis_backup.tar.gz" ]; then
            print_status "Restoring Redis data..."
            docker run --rm -v django_app_redis_data:/data -v "$(pwd)/$BACKUP_DIR":/backup alpine tar xzf /backup/redis_backup.tar.gz -C /data 2>/dev/null || print_warning "Redis restore failed"
        fi
        
        print_status "Restore completed."
    else
        print_status "Restore cancelled."
    fi
}

# Health check
health() {
    print_header "Health Check"
    
    # Check if services are running
    if docker-compose ps | grep -q "Up"; then
        print_status "Services are running."
        
        # Test health endpoint
        if curl -f http://localhost:8000/app/health/ > /dev/null 2>&1; then
            print_status "Health endpoint is responding."
        else
            print_warning "Health endpoint is not responding."
        fi
        
        # Test Redis
        if docker-compose exec redis redis-cli ping > /dev/null 2>&1; then
            print_status "Redis is responding."
        else
            print_warning "Redis is not responding."
        fi
    else
        print_warning "No services are running."
    fi
}

# Show help
show_help() {
    print_header "Docker Management Script"
    echo "Usage: $0 [command]"
    echo
    echo "Development Commands:"
    echo "  dev-start    Start development environment"
    echo "  dev-stop     Stop development environment"
    echo "  dev-logs     Show development logs"
    echo "  dev-shell    Open Django shell"
    echo
    echo "Production Commands:"
    echo "  prod-start   Start production environment"
    echo "  prod-stop    Stop production environment"
    echo "  prod-logs    Show production logs"
    echo
    echo "Utility Commands:"
    echo "  status       Show service status"
    echo "  health       Check service health"
    echo "  cleanup      Clean up Docker resources"
    echo "  backup       Create backup"
    echo "  restore <dir> Restore from backup"
    echo "  help         Show this help"
}

# Main script logic
case "${1:-help}" in
    "dev-start")
        dev_start
        ;;
    "dev-stop")
        dev_stop
        ;;
    "dev-logs")
        dev_logs
        ;;
    "dev-shell")
        dev_shell
        ;;
    "prod-start")
        prod_start
        ;;
    "prod-stop")
        prod_stop
        ;;
    "prod-logs")
        prod_logs
        ;;
    "status")
        status
        ;;
    "health")
        health
        ;;
    "cleanup")
        cleanup
        ;;
    "backup")
        backup
        ;;
    "restore")
        restore "$2"
        ;;
    "help"|*)
        show_help
        ;;
esac 