# Use Ubuntu 22.04 as base image
FROM ubuntu:20.04

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV DEBIAN_FRONTEND=noninteractive

ARG PS_VERSION=7.0.11
ARG PS_PACKAGE=powershell-lts_${PS_VERSION}-1.ubuntu.20.04_amd64.deb
ARG PS_PACKAGE_URL=https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/powershell-lts_${PS_VERSION}-1.ubuntu.20.04_amd64.deb

ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    PSModuleAnalysisCachePath=/var/cache/microsoft/powershell/PSModuleAnalysisCache/ModuleAnalysisCache \
    POWERSHELL_DISTRIBUTION_CHANNEL=PSDocker-Ubuntu-20.04


# Set work directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    libpq-dev \
    curl \
    git \
    supervisor \
    nginx \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
        wget \
        less \
        locales \
        ca-certificates \
        gss-ntlmssp \
        libicu66 \
        libssl1.1 \
        libc6 \
        libgcc1 \
        libgssapi-krb5-2 \
        liblttng-ust0 \
        libstdc++6 \
        zlib1g \
        openssh-client \
        apt-transport-https \
    && apt-get dist-upgrade -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && locale-gen $LANG && update-locale


RUN wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y dotnet-sdk-6.0 \
    && rm packages-microsoft-prod.deb

# Install PowerShell
RUN echo ${PS_PACKAGE_URL} \
    && curl -sSL ${PS_PACKAGE_URL} -o /tmp/powershell.deb \
    && apt-get install --no-install-recommends -y /tmp/powershell.deb \
    && rm /tmp/powershell.deb

# Install MicrosoftTeams module
RUN pwsh -Command "Install-Module -Name MicrosoftTeams -Force -AllowClobber"

# Create virtual environment
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Upgrade pip
RUN pip install --upgrade pip

# Copy requirements files
COPY requirements.txt requirements-dev.txt requirements-minimal.txt ./

# Install Python dependencies
RUN pip install -r requirements.txt

# Copy project
COPY . .

# Create necessary directories
RUN mkdir -p /app/logs /app/static /app/media

# Set permissions
RUN chmod +x /app/manage.py

# Collect static files
RUN python manage.py collectstatic --noinput

# Create non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 8000

# Default command
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]