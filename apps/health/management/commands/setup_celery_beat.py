from django.core.management.base import BaseCommand
from django_celery_beat.models import PeriodicTask, IntervalSchedule
from apps.health.tasks import health_check_task, cleanup_old_health_logs, send_health_report


class Command(BaseCommand):
    help = 'Set up Celery Beat periodic tasks for health monitoring'

    def handle(self, *args, **options):
        self.stdout.write('Setting up Celery Beat periodic tasks...')
        
        # Create interval schedules
        health_check_schedule, created = IntervalSchedule.objects.get_or_create(
            every=5,
            period=IntervalSchedule.MINUTES,
        )
        if created:
            self.stdout.write('Created health check schedule (every 5 minutes)')
        
        cleanup_schedule, created = IntervalSchedule.objects.get_or_create(
            every=1,
            period=IntervalSchedule.HOURS,
        )
        if created:
            self.stdout.write('Created cleanup schedule (every 1 hour)')
        
        report_schedule, created = IntervalSchedule.objects.get_or_create(
            every=24,
            period=IntervalSchedule.HOURS,
        )
        if created:
            self.stdout.write('Created report schedule (every 24 hours)')
        
        # Create periodic tasks
        health_task, created = PeriodicTask.objects.get_or_create(
            name='Health Check Task',
            defaults={
                'task': 'apps.health.tasks.health_check_task',
                'interval': health_check_schedule,
                'enabled': True,
            }
        )
        if created:
            self.stdout.write('Created health check periodic task')
        
        cleanup_task, created = PeriodicTask.objects.get_or_create(
            name='Cleanup Old Health Logs',
            defaults={
                'task': 'apps.health.tasks.cleanup_old_health_logs',
                'interval': cleanup_schedule,
                'enabled': True,
            }
        )
        if created:
            self.stdout.write('Created cleanup periodic task')
        
        report_task, created = PeriodicTask.objects.get_or_create(
            name='Send Health Report',
            defaults={
                'task': 'apps.health.tasks.send_health_report',
                'interval': report_schedule,
                'enabled': True,
            }
        )
        if created:
            self.stdout.write('Created health report periodic task')
        
        self.stdout.write(
            self.style.SUCCESS('Successfully set up Celery Beat periodic tasks!')
        ) 