from setuptools import setup, find_packages
import os

# Read the README file
def read_readme():
    readme_path = os.path.join(os.path.dirname(__file__), 'README.md')
    if os.path.exists(readme_path):
        with open(readme_path, 'r', encoding='utf-8') as f:
            return f.read()
    return ""

# Read requirements
def read_requirements(filename):
    requirements_path = os.path.join(os.path.dirname(__file__), filename)
    if os.path.exists(requirements_path):
        with open(requirements_path, 'r', encoding='utf-8') as f:
            return [line.strip() for line in f if line.strip() and not line.startswith('#')]
    return []

setup(
    name="django-health-celery-app",
    version="1.0.0",
    description="Django application with health check API and Celery integration",
    long_description=read_readme(),
    long_description_content_type="text/markdown",
    author="Your Name",
    author_email="your.email@example.com",
    url="https://github.com/yourusername/django-health-celery-app",
    packages=find_packages(),
    include_package_data=True,
    python_requires=">=3.8",
    install_requires=read_requirements('requirements.txt'),
    extras_require={
        'dev': read_requirements('requirements-dev.txt'),
        'minimal': read_requirements('requirements-minimal.txt'),
    },
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Framework :: Django",
        "Framework :: Django :: 4.2",
        "Framework :: Django :: 5.0",
        "Topic :: Internet :: WWW/HTTP :: Dynamic Content",
        "Topic :: Software Development :: Libraries :: Python Modules",
    ],
    keywords="django celery health api monitoring",
    project_urls={
        "Bug Reports": "https://github.com/yourusername/django-health-celery-app/issues",
        "Source": "https://github.com/yourusername/django-health-celery-app",
        "Documentation": "https://github.com/yourusername/django-health-celery-app#readme",
    },
) 