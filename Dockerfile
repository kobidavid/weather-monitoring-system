FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY weather_monitor.py .

# Run the application
CMD ["python", "-u", "weather_monitor.py"]
