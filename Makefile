.PHONY: help setup build up down restart logs test health clean deploy

# Default target
help:
	@echo "Weather Monitoring System - Available Commands"
	@echo ""
	@echo "Setup & Deployment:"
	@echo "  make setup       - Run automated setup script"
	@echo "  make build       - Build Docker images"
	@echo "  make up          - Start all services"
	@echo "  make down        - Stop all services"
	@echo "  make restart     - Restart all services"
	@echo "  make deploy      - Full deployment (build + up)"
	@echo ""
	@echo "Monitoring:"
	@echo "  make logs        - Show all service logs"
	@echo "  make logs-app    - Show application logs only"
	@echo "  make health      - Run health check"
	@echo "  make ps          - Show running containers"
	@echo ""
	@echo "Testing:"
	@echo "  make test        - Run unit tests"
	@echo "  make test-cov    - Run tests with coverage"
	@echo "  make lint        - Run code linting"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean       - Remove containers and volumes"
	@echo "  make clean-all   - Remove everything including images"
	@echo ""
	@echo "Data:"
	@echo "  make check-data  - Check latest weather data"
	@echo "  make check-queue - Check RabbitMQ queue status"
	@echo ""

# Setup
setup:
	@bash setup.sh

# Build images
build:
	@echo "Building Docker images..."
	@docker-compose build --no-cache

# Start services
up:
	@echo "Starting services..."
	@docker-compose up -d
	@echo "Services started. Run 'make logs' to view logs"

# Stop services
down:
	@echo "Stopping services..."
	@docker-compose down

# Restart services
restart: down up

# Show logs
logs:
	@docker-compose logs -f

logs-app:
	@docker-compose logs -f weather-monitor

# Check container status
ps:
	@docker-compose ps

# Run health check
health:
	@bash health-check.sh

# Run tests
test:
	@echo "Running unit tests..."
	@pip install -r requirements.txt --break-system-packages --quiet
	@pytest tests/ -v

test-cov:
	@echo "Running tests with coverage..."
	@pip install -r requirements.txt --break-system-packages --quiet
	@pytest tests/ -v --cov=weather_monitor --cov-report=html --cov-report=term
	@echo "Coverage report generated in htmlcov/index.html"

# Linting
lint:
	@echo "Running pylint..."
	@pip install pylint flake8 --break-system-packages --quiet
	@pylint weather_monitor.py --exit-zero
	@echo ""
	@echo "Running flake8..."
	@flake8 weather_monitor.py --max-line-length=120 --exit-zero

# Full deployment
deploy: build up
	@echo ""
	@echo "Waiting for services to start..."
	@sleep 10
	@make health

# Clean up
clean:
	@echo "Cleaning up containers and volumes..."
	@docker-compose down -v

clean-all: clean
	@echo "Removing images..."
	@docker-compose down -v --rmi all

# Check latest data
check-data:
	@echo "Fetching latest weather data from Elasticsearch..."
	@curl -s "http://localhost:9200/weather-data-*/_search?size=1&sort=@timestamp:desc" | \
		python3 -c "import sys, json; data = json.load(sys.stdin); hit = data['hits']['hits'][0]['_source'] if data['hits']['hits'] else {}; print(f\"City: {hit.get('city', 'N/A')}\"); print(f\"Temperature: {hit.get('temperature', 'N/A')}°C\"); print(f\"Weather: {hit.get('weather', 'N/A')}\"); print(f\"Humidity: {hit.get('humidity', 'N/A')}%\"); print(f\"Time: {hit.get('timestamp', 'N/A')}\")" 2>/dev/null || echo "No data available"

# Check RabbitMQ queue
check-queue:
	@echo "Checking RabbitMQ queue status..."
	@curl -s http://localhost:15672/api/queues/%2F/weather_data -u admin:admin123 | \
		python3 -c "import sys, json; data = json.load(sys.stdin); print(f\"Queue: {data.get('name', 'N/A')}\"); print(f\"Messages: {data.get('messages', 0)}\"); print(f\"Consumers: {data.get('consumers', 0)}\")" 2>/dev/null || echo "RabbitMQ not accessible"

# Install development dependencies
dev-setup:
	@echo "Installing development dependencies..."
	@pip install -r requirements.txt --break-system-packages
	@pip install pylint flake8 pytest-cov --break-system-packages
	@echo "Development environment ready!"

# Show Grafana URL
grafana:
	@echo "Grafana Dashboard:"
	@echo "URL: http://localhost:3000"
	@echo "Username: admin"
	@echo "Password: admin123"

# Show all service URLs
urls:
	@echo "Service URLs:"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Grafana:         http://localhost:3000"
	@echo "RabbitMQ:        http://localhost:15672"
	@echo "Elasticsearch:   http://localhost:9200"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
