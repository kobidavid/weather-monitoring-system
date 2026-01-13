"""
Unit tests for Weather Monitor Application
"""

import os
import json
import pytest
from unittest.mock import Mock, patch, MagicMock
from datetime import datetime

# Set test environment variables
os.environ['OPENWEATHER_API_KEY'] = 'test_api_key'
os.environ['CITY_NAME'] = 'TestCity'
os.environ['RABBITMQ_HOST'] = 'localhost'
os.environ['RABBITMQ_PORT'] = '5672'
os.environ['RABBITMQ_QUEUE'] = 'test_queue'

# Import after setting environment variables
import weather_monitor


class TestWeatherMonitor:
    """Test cases for WeatherMonitor class"""
    
    @pytest.fixture
    def mock_rabbitmq(self):
        """Mock RabbitMQ connection"""
        with patch('weather_monitor.pika.BlockingConnection') as mock_conn:
            mock_channel = Mock()
            mock_conn.return_value.channel.return_value = mock_channel
            mock_conn.return_value.is_closed = False
            yield mock_channel
    
    @pytest.fixture
    def weather_monitor_instance(self, mock_rabbitmq):
        """Create a WeatherMonitor instance with mocked RabbitMQ"""
        monitor = weather_monitor.WeatherMonitor()
        return monitor
    
    def test_init(self, weather_monitor_instance):
        """Test WeatherMonitor initialization"""
        assert weather_monitor_instance.api_key == 'test_api_key'
        assert weather_monitor_instance.city == 'TestCity'
        assert weather_monitor_instance.rabbitmq_channel is not None
    
    @patch('weather_monitor.requests.get')
    def test_get_weather_data_success(self, mock_get, weather_monitor_instance):
        """Test successful weather data retrieval"""
        # Mock successful API response
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            'name': 'TestCity',
            'sys': {'country': 'TC', 'sunrise': 1234567890, 'sunset': 1234567890},
            'main': {
                'temp': 20.5,
                'feels_like': 19.0,
                'temp_min': 18.0,
                'temp_max': 22.0,
                'pressure': 1013,
                'humidity': 65
            },
            'weather': [
                {'main': 'Clear', 'description': 'clear sky'}
            ],
            'wind': {'speed': 3.5, 'deg': 180},
            'clouds': {'all': 10},
            'visibility': 10000
        }
        mock_get.return_value = mock_response
        
        weather_data = weather_monitor_instance.get_weather_data()
        
        assert weather_data is not None
        assert weather_data['city'] == 'TestCity'
        assert weather_data['temperature'] == 20.5
        assert weather_data['humidity'] == 65
        assert weather_data['weather'] == 'Clear'
        assert 'timestamp_ms' in weather_data
        assert 'timestamp' in weather_data
    
    @patch('weather_monitor.requests.get')
    def test_get_weather_data_api_error(self, mock_get, weather_monitor_instance):
        """Test weather data retrieval with API error"""
        mock_get.side_effect = Exception("API Error")
        
        weather_data = weather_monitor_instance.get_weather_data()
        
        assert weather_data is None
    
    def test_send_to_rabbitmq_success(self, weather_monitor_instance):
        """Test successful data sending to RabbitMQ"""
        test_data = {
            'timestamp_ms': 1234567890000,
            'temperature': 20.5,
            'city': 'TestCity'
        }
        
        result = weather_monitor_instance.send_to_rabbitmq(test_data)
        
        assert result is True
        weather_monitor_instance.rabbitmq_channel.basic_publish.assert_called_once()
    
    @patch('weather_monitor.requests.get')
    def test_sample_and_send(self, mock_get, weather_monitor_instance):
        """Test complete sample and send workflow"""
        # Mock API response
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            'name': 'TestCity',
            'sys': {'country': 'TC', 'sunrise': 1234567890, 'sunset': 1234567890},
            'main': {
                'temp': 20.5,
                'feels_like': 19.0,
                'temp_min': 18.0,
                'temp_max': 22.0,
                'pressure': 1013,
                'humidity': 65
            },
            'weather': [
                {'main': 'Clear', 'description': 'clear sky'}
            ],
            'wind': {'speed': 3.5, 'deg': 180},
            'clouds': {'all': 10},
            'visibility': 10000
        }
        mock_get.return_value = mock_response
        
        # Execute sample_and_send
        weather_monitor_instance.sample_and_send()
        
        # Verify RabbitMQ publish was called
        assert weather_monitor_instance.rabbitmq_channel.basic_publish.called
    
    def test_weather_data_structure(self, weather_monitor_instance):
        """Test that weather data has all required fields"""
        with patch('weather_monitor.requests.get') as mock_get:
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.json.return_value = {
                'name': 'TestCity',
                'sys': {'country': 'TC', 'sunrise': 1234567890, 'sunset': 1234567890},
                'main': {
                    'temp': 20.5,
                    'feels_like': 19.0,
                    'temp_min': 18.0,
                    'temp_max': 22.0,
                    'pressure': 1013,
                    'humidity': 65
                },
                'weather': [
                    {'main': 'Clear', 'description': 'clear sky'}
                ],
                'wind': {'speed': 3.5, 'deg': 180},
                'clouds': {'all': 10},
                'visibility': 10000
            }
            mock_get.return_value = mock_response
            
            weather_data = weather_monitor_instance.get_weather_data()
            
            required_fields = [
                'timestamp_ms', 'timestamp', 'city', 'country',
                'temperature', 'feels_like', 'temp_min', 'temp_max',
                'pressure', 'humidity', 'weather', 'weather_description',
                'wind_speed', 'wind_deg', 'clouds', 'visibility'
            ]
            
            for field in required_fields:
                assert field in weather_data, f"Missing required field: {field}"
    
    def test_timestamp_precision(self, weather_monitor_instance):
        """Test that timestamp is captured with millisecond precision"""
        with patch('weather_monitor.requests.get') as mock_get:
            mock_response = Mock()
            mock_response.json.return_value = {
                'name': 'TestCity',
                'sys': {'country': 'TC', 'sunrise': 1234567890, 'sunset': 1234567890},
                'main': {
                    'temp': 20.5,
                    'feels_like': 19.0,
                    'temp_min': 18.0,
                    'temp_max': 22.0,
                    'pressure': 1013,
                    'humidity': 65
                },
                'weather': [{'main': 'Clear', 'description': 'clear sky'}],
                'wind': {'speed': 3.5},
                'clouds': {'all': 10}
            }
            mock_get.return_value = mock_response
            
            weather_data = weather_monitor_instance.get_weather_data()
            
            # Check timestamp_ms is in milliseconds (13 digits)
            assert len(str(weather_data['timestamp_ms'])) == 13
            
            # Check timestamp is ISO format
            assert 'T' in weather_data['timestamp']


class TestConfiguration:
    """Test configuration and environment variables"""
    
    def test_environment_variables(self):
        """Test that environment variables are properly set"""
        assert os.getenv('OPENWEATHER_API_KEY') == 'test_api_key'
        assert os.getenv('CITY_NAME') == 'TestCity'
        assert os.getenv('RABBITMQ_HOST') == 'localhost'


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
