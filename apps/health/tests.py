from django.test import TestCase, Client
from django.urls import reverse
import json


class HealthAPITestCase(TestCase):
    def setUp(self):
        self.client = Client()

    def test_health_check_endpoint(self):
        """Test the basic health check endpoint"""
        response = self.client.get('/app/health/')
        self.assertEqual(response.status_code, 200)
        
        data = json.loads(response.content)
        self.assertIn('status', data)
        self.assertIn('timestamp', data)
        self.assertIn('service', data)
        self.assertEqual(data['status'], 'healthy')
        self.assertEqual(data['service'], 'django_app')

    def test_health_detailed_endpoint(self):
        """Test the detailed health check endpoint"""
        response = self.client.get('/app/health/detailed/')
        self.assertEqual(response.status_code, 200)
        
        data = json.loads(response.content)
        self.assertIn('status', data)
        self.assertIn('checks', data)
        self.assertIn('metadata', data)
        self.assertIn('database', data['checks'])

    def test_health_ready_endpoint(self):
        """Test the readiness probe endpoint"""
        response = self.client.get('/app/health/ready/')
        self.assertEqual(response.status_code, 200)
        
        data = json.loads(response.content)
        self.assertIn('ready', data)
        self.assertIn('checks', data)
        self.assertTrue(data['ready'])

    def test_health_endpoints_method_not_allowed(self):
        """Test that POST requests are not allowed"""
        response = self.client.post('/app/health/')
        self.assertEqual(response.status_code, 405)
        
        response = self.client.post('/app/health/detailed/')
        self.assertEqual(response.status_code, 405)
        
        response = self.client.post('/app/health/ready/')
        self.assertEqual(response.status_code, 405) 