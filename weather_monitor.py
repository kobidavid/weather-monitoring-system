#!/usr/bin/env python3
"""
Weather Monitoring Application
Samples OpenWeatherMap API and sends data to RabbitMQ
"""

import os
import time
import json
import logging
from datetime import datetime
import requests
import pika
from apscheduler.schedulers.blocking import BlockingScheduler

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configuration from environment variables
OPENWEATHER_API_KEY = os.getenv('OPENWEATHER_API_KEY', 'YOUR_API_KEY_HERE')
CITY_NAME = os.getenv('CITY_NAME', 'Tokyo')  # City to monitor
RABBITMQ_HOST = os.getenv('RABBITMQ_HOST', 'rabbitmq')
RABBITMQ_PORT = int(os.getenv('RABBITMQ_PORT', 5672))
RABBITMQ_QUEUE = os.getenv('RABBITMQ_QUEUE', 'weather_data')
RABBITMQ_USER = os.getenv('RABBITMQ_USER', 'guest')
RABBITMQ_PASSWORD = os.getenv('RABBITMQ_PASSWORD', 'guest')


class WeatherMonitor:
    """Weather monitoring service that samples OpenWeatherMap API"""
    
    def __init__(self):
        self.api_key = OPENWEATHER_API_KEY
        self.city = CITY_NAME
        self.rabbitmq_connection = None
        self.rabbitmq_channel = None
        self.setup_rabbitmq()
    
    def setup_rabbitmq(self):
        """Setup RabbitMQ connection and channel"""
        max_retries = 5
        retry_count = 0
        
        while retry_count < max_retries:
            try:
                credentials = pika.PlainCredentials(RABBITMQ_USER, RABBITMQ_PASSWORD)
                parameters = pika.ConnectionParameters(
                    host=RABBITMQ_HOST,
                    port=RABBITMQ_PORT,
                    credentials=credentials,
                    heartbeat=600,
                    blocked_connection_timeout=300
                )
                
                self.rabbitmq_connection = pika.BlockingConnection(parameters)
                self.rabbitmq_channel = self.rabbitmq_connection.channel()
                
                # Declare queue
                self.rabbitmq_channel.queue_declare(queue=RABBITMQ_QUEUE, durable=True)
                
                logger.info(f"Successfully connected to RabbitMQ at {RABBITMQ_HOST}:{RABBITMQ_PORT}")
                return
                
            except Exception as e:
                retry_count += 1
                logger.error(f"Failed to connect to RabbitMQ (attempt {retry_count}/{max_retries}): {e}")
                if retry_count < max_retries:
                    time.sleep(5)
                else:
                    raise
    
    def get_weather_data(self):
        """Fetch weather data from OpenWeatherMap API"""
        try:
            # Capture exact timestamp in milliseconds
            timestamp_ms = int(datetime.now().timestamp() * 1000)
            timestamp_iso = datetime.now().isoformat()
            
            url = f"http://api.openweathermap.org/data/2.5/weather?q={self.city}&appid={self.api_key}&units=metric"
            
            logger.info(f"Fetching weather data for {self.city}...")
            response = requests.get(url, timeout=10)
            response.raise_for_status()
            
            data = response.json()
            
            # Extract relevant weather information
            weather_info = {
                'timestamp_ms': timestamp_ms,
                'timestamp': timestamp_iso,
                'city': data['name'],
                'country': data['sys']['country'],
                'temperature': data['main']['temp'],
                'feels_like': data['main']['feels_like'],
                'temp_min': data['main']['temp_min'],
                'temp_max': data['main']['temp_max'],
                'pressure': data['main']['pressure'],
                'humidity': data['main']['humidity'],
                'weather': data['weather'][0]['main'],
                'weather_description': data['weather'][0]['description'],
                'wind_speed': data['wind']['speed'],
                'wind_deg': data['wind'].get('deg', 0),
                'clouds': data['clouds']['all'],
                'visibility': data.get('visibility', 0),
                'sunrise': data['sys']['sunrise'],
                'sunset': data['sys']['sunset'],
            }
            
            # Add rain and snow if available
            if 'rain' in data:
                weather_info['rain_1h'] = data['rain'].get('1h', 0)
            if 'snow' in data:
                weather_info['snow_1h'] = data['snow'].get('1h', 0)
            
            logger.info(f"Weather data retrieved: {data['name']}, {weather_info['temperature']}°C, {weather_info['weather']}")
            return weather_info
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Error fetching weather data: {e}")
            return None
        except Exception as e:
            logger.error(f"Unexpected error: {e}")
            return None
    
    def send_to_rabbitmq(self, data):
        """Send weather data to RabbitMQ queue"""
        try:
            if not self.rabbitmq_channel or self.rabbitmq_connection.is_closed:
                logger.warning("RabbitMQ connection lost, reconnecting...")
                self.setup_rabbitmq()
            
            message = json.dumps(data)
            
            self.rabbitmq_channel.basic_publish(
                exchange='',
                routing_key=RABBITMQ_QUEUE,
                body=message,
                properties=pika.BasicProperties(
                    delivery_mode=2,  # Make message persistent
                    content_type='application/json'
                )
            )
            
            logger.info(f"Data sent to RabbitMQ queue '{RABBITMQ_QUEUE}'")
            return True
            
        except Exception as e:
            logger.error(f"Error sending data to RabbitMQ: {e}")
            return False
    
    def sample_and_send(self):
        """Sample weather data and send to RabbitMQ"""
        logger.info("=" * 60)
        logger.info(f"Starting weather sampling at {datetime.now().isoformat()}")
        
        weather_data = self.get_weather_data()
        
        if weather_data:
            success = self.send_to_rabbitmq(weather_data)
            if success:
                logger.info(f"Successfully processed weather data for {weather_data['city']}")
            else:
                logger.error("Failed to send data to RabbitMQ")
        else:
            logger.error("Failed to retrieve weather data")
        
        logger.info("=" * 60)
    
    def run(self):
        """Run the weather monitoring service with hourly sampling"""
        logger.info(f"Starting Weather Monitor for {self.city}")
        logger.info(f"Sampling interval: Every hour")
        logger.info(f"RabbitMQ: {RABBITMQ_HOST}:{RABBITMQ_PORT}, Queue: {RABBITMQ_QUEUE}")
        
        # Sample immediately on startup
        self.sample_and_send()
        
        # Schedule hourly sampling
        scheduler = BlockingScheduler()
        scheduler.add_job(self.sample_and_send, 'interval', minutes=10)
        
        try:
            scheduler.start()
        except (KeyboardInterrupt, SystemExit):
            logger.info("Shutting down weather monitor...")
            if self.rabbitmq_connection and not self.rabbitmq_connection.is_closed:
                self.rabbitmq_connection.close()
            logger.info("Weather monitor stopped")


def main():
    """Main entry point"""
    # Validate API key
    if OPENWEATHER_API_KEY == 'YOUR_API_KEY_HERE':
        logger.error("Please set OPENWEATHER_API_KEY environment variable")
        logger.info("Get your API key from: https://openweathermap.org/api")
        return
    
    monitor = WeatherMonitor()
    monitor.run()


if __name__ == '__main__':
    main()
