# Docker Management Script for Django Health Celery App (PowerShell)
# Usage: .\docker-scripts.ps1 [command]

param(
    [Parameter(Position=0)]
    [string]$Command = "help",
    
    [Parameter(Position=1)]
    [string]$BackupDir
)

# Colors for output
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Blue = "Blue"

# Function to print colored output
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor $Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Red
}

function Write-Header {
    param([string]$Message)
    Write-Host "=== $Message ===" -ForegroundColor $Blue
}

# Function to check if Docker is running
function Test-Docker {
    try {
        docker info | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# Function to check if docker-compose is available
function Test-DockerCompose {
    try {
        docker-compose --version | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# Development environment commands
function Start-DevEnvironment {
    Write-Header "Starting Development Environment"
    
    if (-not (Test-Docker)) {
        Write-Error "Docker is not running. Please start Docker and try again."
        exit 1
    }
    
    if (-not (Test-DockerCompose)) {
        Write-Error "docker-compose is not installed. Please install it and try again."
        exit 1
    }
    
    Write-Status "Building and starting development services..."
    docker-compose -f docker-compose.dev.yml up --build -d
    
    Write-Status "Waiting for services to be ready..."
    Start-Sleep -Seconds 10
    
    Write-Status "Running migrations..."
    docker-compose -f docker-compose.dev.yml exec web python manage.py migrate
    
    Write-Status "Setting up Celery Beat schedules..."
    docker-compose -f docker-compose.dev.yml exec web python manage.py setup_celery_beat
    
    Write-Status "Development environment is ready!"
    Write-Host "Access points:" -ForegroundColor $Green
    Write-Host "  Django Admin: http://localhost:8000/admin/"
    Write-Host "  Health API: http://localhost:8000/app/health/"
    Write-Host "  Flower (Celery): http://localhost:5555/"
}

function Stop-DevEnvironment {
    Write-Header "Stopping Development Environment"
    docker-compose -f docker-compose.dev.yml down
    Write-Status "Development environment stopped."
}

function Show-DevLogs {
    Write-Header "Development Logs"
    docker-compose -f docker-compose.dev.yml logs -f
}

function Open-DevShell {
    Write-Header "Opening Django Shell"
    docker-compose -f docker-compose.dev.yml exec web python manage.py shell
}

# Production environment commands
function Start-ProdEnvironment {
    Write-Header "Starting Production Environment"
    
    if (-not (Test-Docker)) {
        Write-Error "Docker is not running. Please start Docker and try again."
        exit 1
    }
    
    if (-not (Test-DockerCompose)) {
        Write-Error "docker-compose is not installed. Please install it and try again."
        exit 1
    }
    
    Write-Status "Building and starting production services..."
    docker-compose up --build -d
    
    Write-Status "Waiting for services to be ready..."
    Start-Sleep -Seconds 15
    
    Write-Status "Running migrations..."
    docker-compose exec web python manage.py migrate
    
    Write-Status "Collecting static files..."
    docker-compose exec web python manage.py collectstatic --noinput
    
    Write-Status "Setting up Celery Beat schedules..."
    docker-compose exec web python manage.py setup_celery_beat
    
    Write-Status "Production environment is ready!"
    Write-Host "Access points:" -ForegroundColor $Green
    Write-Host "  Nginx: http://localhost/"
    Write-Host "  Django Admin: http://localhost/admin/"
    Write-Host "  Health API: http://localhost/app/health/"
    Write-Host "  Flower (Celery): http://localhost:5555/"
}

function Stop-ProdEnvironment {
    Write-Header "Stopping Production Environment"
    docker-compose down
    Write-Status "Production environment stopped."
}

function Show-ProdLogs {
    Write-Header "Production Logs"
    docker-compose logs -f
}

# Utility commands
function Show-Status {
    Write-Header "Service Status"
    if (Test-Path "docker-compose.dev.yml") {
        Write-Host "Development Services:" -ForegroundColor $Blue
        docker-compose -f docker-compose.dev.yml ps
        Write-Host ""
    }
    
    if (Test-Path "docker-compose.yml") {
        Write-Host "Production Services:" -ForegroundColor $Blue
        docker-compose ps
    }
}

function Invoke-Cleanup {
    Write-Header "Cleaning Up Docker Resources"
    Write-Warning "This will remove all containers, networks, and volumes!"
    $confirmation = Read-Host "Are you sure? (y/N)"
    if ($confirmation -eq 'y' -or $confirmation -eq 'Y') {
        docker-compose -f docker-compose.dev.yml down -v 2>$null
        docker-compose down -v 2>$null
        docker system prune -f
        docker volume prune -f
        Write-Status "Cleanup completed."
    }
    else {
        Write-Status "Cleanup cancelled."
    }
}

function New-Backup {
    Write-Header "Creating Backup"
    $backupDir = "backups\$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    
    Write-Status "Backing up PostgreSQL data..."
    try {
        docker-compose exec postgres pg_dump -U django_user django_health_celery > "$backupDir\database.sql"
    }
    catch {
        Write-Warning "PostgreSQL backup failed (service might not be running)"
    }
    
    Write-Status "Backing up Redis data..."
    try {
        docker run --rm -v django_app_redis_data:/data -v "${PWD}\$backupDir":/backup alpine tar czf /backup/redis_backup.tar.gz -C /data .
    }
    catch {
        Write-Warning "Redis backup failed"
    }
    
    Write-Status "Backup completed: $backupDir"
}

function Restore-Backup {
    Write-Header "Restoring from Backup"
    if (-not $BackupDir) {
        Write-Error "Please specify backup directory: .\docker-scripts.ps1 restore <backup_dir>"
        exit 1
    }
    
    if (-not (Test-Path $BackupDir)) {
        Write-Error "Backup directory not found: $BackupDir"
        exit 1
    }
    
    Write-Warning "This will overwrite existing data!"
    $confirmation = Read-Host "Are you sure? (y/N)"
    if ($confirmation -eq 'y' -or $confirmation -eq 'Y') {
        if (Test-Path "$BackupDir\database.sql") {
            Write-Status "Restoring PostgreSQL data..."
            try {
                Get-Content "$BackupDir\database.sql" | docker-compose exec -T postgres psql -U django_user django_health_celery
            }
            catch {
                Write-Warning "PostgreSQL restore failed"
            }
        }
        
        if (Test-Path "$BackupDir\redis_backup.tar.gz") {
            Write-Status "Restoring Redis data..."
            try {
                docker run --rm -v django_app_redis_data:/data -v "${PWD}\$BackupDir":/backup alpine tar xzf /backup/redis_backup.tar.gz -C /data
            }
            catch {
                Write-Warning "Redis restore failed"
            }
        }
        
        Write-Status "Restore completed."
    }
    else {
        Write-Status "Restore cancelled."
    }
}

function Test-Health {
    Write-Header "Health Check"
    
    # Check if services are running
    $services = docker-compose ps
    if ($services -match "Up") {
        Write-Status "Services are running."
        
        # Test health endpoint
        try {
            Invoke-WebRequest -Uri "http://localhost:8000/app/health/" -UseBasicParsing | Out-Null
            Write-Status "Health endpoint is responding."
        }
        catch {
            Write-Warning "Health endpoint is not responding."
        }
        
        # Test Redis
        try {
            docker-compose exec redis redis-cli ping | Out-Null
            Write-Status "Redis is responding."
        }
        catch {
            Write-Warning "Redis is not responding."
        }
    }
    else {
        Write-Warning "No services are running."
    }
}

# Show help
function Show-Help {
    Write-Header "Docker Management Script"
    Write-Host "Usage: .\docker-scripts.ps1 [command]"
    Write-Host ""
    Write-Host "Development Commands:"
    Write-Host "  dev-start    Start development environment"
    Write-Host "  dev-stop     Stop development environment"
    Write-Host "  dev-logs     Show development logs"
    Write-Host "  dev-shell    Open Django shell"
    Write-Host ""
    Write-Host "Production Commands:"
    Write-Host "  prod-start   Start production environment"
    Write-Host "  prod-stop    Stop production environment"
    Write-Host "  prod-logs    Show production logs"
    Write-Host ""
    Write-Host "Utility Commands:"
    Write-Host "  status       Show service status"
    Write-Host "  health       Check service health"
    Write-Host "  cleanup      Clean up Docker resources"
    Write-Host "  backup       Create backup"
    Write-Host "  restore <dir> Restore from backup"
    Write-Host "  help         Show this help"
}

# Main script logic
switch ($Command.ToLower()) {
    "dev-start" { Start-DevEnvironment }
    "dev-stop" { Stop-DevEnvironment }
    "dev-logs" { Show-DevLogs }
    "dev-shell" { Open-DevShell }
    "prod-start" { Start-ProdEnvironment }
    "prod-stop" { Stop-ProdEnvironment }
    "prod-logs" { Show-ProdLogs }
    "status" { Show-Status }
    "health" { Test-Health }
    "cleanup" { Invoke-Cleanup }
    "backup" { New-Backup }
    "restore" { Restore-Backup }
    default { Show-Help }
} 