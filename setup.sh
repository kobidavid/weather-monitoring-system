#!/bin/bash

# Weather Monitoring System - Setup Script
# This script automates the initial setup and deployment

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo "========================================"
    echo "$1"
    echo "========================================"
    echo ""
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    print_info "✓ Docker found: $(docker --version)"
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    print_info "✓ Docker Compose found: $(docker-compose --version)"
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running. Please start Docker."
        exit 1
    fi
    print_info "✓ Docker daemon is running"
}

# Setup environment file
setup_environment() {
    print_header "Setting Up Environment"
    
    if [ -f ".env" ]; then
        print_warning ".env file already exists. Skipping creation."
        read -p "Do you want to update the API key? (y/n): " update_env
        if [ "$update_env" == "y" ]; then
            read -p "Enter your OpenWeatherMap API key: " api_key
            sed -i.bak "s/OPENWEATHER_API_KEY=.*/OPENWEATHER_API_KEY=$api_key/" .env
            print_info "✓ API key updated in .env file"
        fi
    else
        print_info "Creating .env file..."
        cp .env.example .env
        
        echo ""
        print_info "Please enter your OpenWeatherMap API key."
        print_info "Get one for free at: https://openweathermap.org/api"
        read -p "API Key: " api_key
        
        if [ -z "$api_key" ]; then
            print_error "API key is required!"
            exit 1
        fi
        
        sed -i.bak "s/OPENWEATHER_API_KEY=.*/OPENWEATHER_API_KEY=$api_key/" .env
        
        read -p "Which city do you want to monitor? [Tokyo]: " city
        city=${city:-Tokyo}
        sed -i.bak "s/CITY_NAME=.*/CITY_NAME=$city/" .env
        
        print_info "✓ Environment file created with city: $city"
    fi
}

# Stop existing services
stop_services() {
    print_header "Stopping Existing Services"
    
    if docker-compose ps | grep -q "Up"; then
        print_info "Stopping running services..."
        docker-compose down
        print_info "✓ Services stopped"
    else
        print_info "No services running"
    fi
}

# Build images
build_images() {
    print_header "Building Docker Images"
    
    print_info "Building weather monitor application..."
    docker-compose build --no-cache
    print_info "✓ Images built successfully"
}

# Start services
start_services() {
    print_header "Starting Services"
    
    print_info "Starting all services with docker-compose..."
    docker-compose up -d
    
    print_info "Waiting for services to be ready..."
    sleep 10
    
    # Wait for services to be healthy
    print_info "Checking service health..."
    
    max_attempts=30
    attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if docker-compose ps | grep -q "(healthy)"; then
            print_info "✓ Services are healthy"
            break
        fi
        
        attempt=$((attempt + 1))
        if [ $attempt -eq $max_attempts ]; then
            print_warning "Some services may not be fully ready yet"
            print_warning "You can check status with: docker-compose ps"
        else
            echo -n "."
            sleep 2
        fi
    done
    echo ""
}

# Verify deployment
verify_deployment() {
    print_header "Verifying Deployment"
    
    # Check RabbitMQ
    if curl -s -f http://localhost:15672 > /dev/null; then
        print_info "✓ RabbitMQ Management UI is accessible"
    else
        print_warning "✗ RabbitMQ Management UI not accessible yet"
    fi
    
    # Check Elasticsearch
    if curl -s -f http://localhost:9200/_cluster/health > /dev/null; then
        print_info "✓ Elasticsearch is accessible"
    else
        print_warning "✗ Elasticsearch not accessible yet"
    fi
    
    # Check Grafana
    if curl -s -f http://localhost:3000/api/health > /dev/null; then
        print_info "✓ Grafana is accessible"
    else
        print_warning "✗ Grafana not accessible yet"
    fi
    
    # Show running containers
    echo ""
    print_info "Running containers:"
    docker-compose ps
}

# Display access information
display_info() {
    print_header "Setup Complete!"
    
    echo "Your Weather Monitoring System is now running!"
    echo ""
    echo "Access the services:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📊 Grafana Dashboard:"
    echo "   URL: http://localhost:3000"
    echo "   Username: admin"
    echo "   Password: admin123"
    echo "   Dashboard: Weather Monitoring Dashboard"
    echo ""
    echo "🐰 RabbitMQ Management:"
    echo "   URL: http://localhost:15672"
    echo "   Username: admin"
    echo "   Password: admin123"
    echo ""
    echo "🔍 Elasticsearch:"
    echo "   URL: http://localhost:9200"
    echo "   No authentication required"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Useful commands:"
    echo "  View logs:           docker-compose logs -f"
    echo "  Stop services:       docker-compose down"
    echo "  Restart services:    docker-compose restart"
    echo "  Check status:        docker-compose ps"
    echo ""
    echo "For detailed documentation, see README.md"
    echo ""
}

# Run unit tests
run_tests() {
    print_header "Running Tests (Optional)"
    
    read -p "Do you want to run unit tests? (y/n): " run_test
    if [ "$run_test" == "y" ]; then
        print_info "Installing test dependencies..."
        pip install -r requirements.txt --break-system-packages 2>&1 | grep -v "WARNING"
        
        print_info "Running pytest..."
        if pytest tests/ -v; then
            print_info "✓ All tests passed"
        else
            print_warning "Some tests failed, but deployment continues"
        fi
    fi
}

# Main execution
main() {
    clear
    
    cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║     Weather Monitoring System - Setup Script         ║
║                                                       ║
║     This script will:                                 ║
║     1. Check prerequisites                            ║
║     2. Setup environment variables                    ║
║     3. Build Docker images                            ║
║     4. Deploy all services                            ║
║     5. Verify deployment                              ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
    
    echo ""
    read -p "Press Enter to continue..."
    
    check_prerequisites
    setup_environment
    stop_services
    build_images
    start_services
    
    sleep 5  # Give services a moment to fully start
    
    verify_deployment
    run_tests
    display_info
}

# Run main function
main
