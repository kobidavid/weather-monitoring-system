#!/bin/bash

echo "╔════════════════════════════════════════════════════════════╗"
echo "║   Weather Monitoring System - Complete Setup              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

cd "$(dirname "$0")"

# Check .env
if [ ! -f .env ]; then
    echo -e "${YELLOW}⚠️  .env file not found${NC}"
    echo "Creating from .env.example..."
    cp .env.example .env
    echo ""
    echo -e "${YELLOW}Please edit .env and add your OPENWEATHER_API_KEY${NC}"
    echo "Get one from: https://openweathermap.org/api"
    echo ""
    read -p "Press Enter after you've added your API key..."
fi

# Start services
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Starting all services..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

docker-compose up -d

echo ""
echo "⏳ Waiting for services to start (60 seconds)..."
sleep 60

# Check status
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Service Status:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker-compose ps

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Setup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🌐 Access your services:"
echo "   • Grafana:      http://localhost:3000  (admin/admin123)"
echo "   • RabbitMQ:     http://localhost:15672 (admin/admin123)"
echo "   • Elasticsearch: http://localhost:9200"
echo ""
echo "📊 To see weather data in Grafana:"
echo "   1. Open http://localhost:3000"
echo "   2. Login with admin/admin123"
echo "   3. Go to Dashboards → Weather Monitoring"
echo ""
echo "🔄 To check if data is flowing:"
echo "   curl http://localhost:9200/weather-data-*/_count"
echo ""
echo "📝 To stop all services:"
echo "   docker-compose down"
echo ""
echo "🔧 For CI/CD setup with GitHub Actions:"
echo "   See: COMPLETE_SETUP_GUIDE.md"
echo ""
