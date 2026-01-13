#!/bin/bash

# Health Check Script for Weather Monitoring System
# Verifies all services are running and data is flowing

set +e  # Don't exit on errors, we want to check all services

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
PASSED=0
FAILED=0

print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

check_service() {
    local service_name=$1
    local check_command=$2
    local expected_output=$3
    
    echo -n "Checking $service_name... "
    
    if eval "$check_command" | grep -q "$expected_output"; then
        echo -e "${GREEN}✓ PASS${NC}"
        PASSED=$((PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

print_header "Weather Monitoring System - Health Check"

# 1. Docker Services
print_header "1. Docker Services Status"
echo "Checking running containers..."
docker-compose ps
echo ""

# 2. RabbitMQ
print_header "2. RabbitMQ Health"
check_service "RabbitMQ API" \
    "curl -s http://localhost:15672/api/overview -u admin:admin123" \
    "rabbitmq_version"

check_service "RabbitMQ Queue" \
    "curl -s http://localhost:15672/api/queues/%2F/weather_data -u admin:admin123" \
    "weather_data"

# Check if queue has messages
QUEUE_MESSAGES=$(curl -s http://localhost:15672/api/queues/%2F/weather_data -u admin:admin123 | grep -o '"messages":[0-9]*' | cut -d':' -f2)
if [ ! -z "$QUEUE_MESSAGES" ]; then
    echo -e "  └─ Queue has $QUEUE_MESSAGES messages"
fi

# 3. Elasticsearch
print_header "3. Elasticsearch Health"
check_service "Elasticsearch Cluster" \
    "curl -s http://localhost:9200/_cluster/health" \
    "cluster_name"

check_service "Elasticsearch Indices" \
    "curl -s http://localhost:9200/_cat/indices" \
    "weather-data"

# Check document count
DOC_COUNT=$(curl -s "http://localhost:9200/weather-data-*/_count" 2>/dev/null | grep -o '"count":[0-9]*' | cut -d':' -f2)
if [ ! -z "$DOC_COUNT" ]; then
    echo -e "  └─ Total documents: $DOC_COUNT"
fi

# Get latest weather data
echo ""
echo "Latest weather data:"
curl -s "http://localhost:9200/weather-data-*/_search?size=1&sort=@timestamp:desc" 2>/dev/null | \
    python3 -c "import sys, json; data = json.load(sys.stdin); hit = data['hits']['hits'][0]['_source'] if data['hits']['hits'] else {}; print(f\"  └─ City: {hit.get('city', 'N/A')}, Temp: {hit.get('temperature', 'N/A')}°C, Time: {hit.get('timestamp', 'N/A')}\")" 2>/dev/null || echo "  └─ No data available yet"

# 4. Logstash
print_header "4. Logstash Health"
check_service "Logstash API" \
    "curl -s http://localhost:9600" \
    "version"

check_service "Logstash Pipeline" \
    "curl -s http://localhost:9600/_node/stats/pipelines" \
    "weather"

# 5. Grafana
print_header "5. Grafana Health"
check_service "Grafana API" \
    "curl -s http://localhost:3000/api/health" \
    "ok"

check_service "Grafana Datasource" \
    "curl -s http://localhost:3000/api/datasources -u admin:admin123" \
    "Elasticsearch"

check_service "Grafana Dashboards" \
    "curl -s http://localhost:3000/api/search -u admin:admin123" \
    "Weather"

# 6. Weather Monitor Application
print_header "6. Weather Monitor Application"
APP_STATUS=$(docker-compose ps weather-monitor | grep -c "Up")
if [ $APP_STATUS -eq 1 ]; then
    echo -e "Weather Monitor: ${GREEN}✓ Running${NC}"
    PASSED=$((PASSED + 1))
    
    # Show recent logs
    echo ""
    echo "Recent application logs:"
    docker-compose logs --tail=5 weather-monitor 2>/dev/null | sed 's/^/  /'
else
    echo -e "Weather Monitor: ${RED}✗ Not Running${NC}"
    FAILED=$((FAILED + 1))
fi

# 7. Data Flow Verification
print_header "7. Data Flow Verification"

# Check if data is flowing
echo "Checking data flow from API → RabbitMQ → Logstash → Elasticsearch..."
echo ""

# Check last data timestamp
LAST_TIMESTAMP=$(curl -s "http://localhost:9200/weather-data-*/_search?size=1&sort=@timestamp:desc" 2>/dev/null | \
    python3 -c "import sys, json; data = json.load(sys.stdin); print(data['hits']['hits'][0]['_source']['timestamp'] if data['hits']['hits'] else 'No data')" 2>/dev/null)

if [ "$LAST_TIMESTAMP" != "No data" ]; then
    echo -e "Last data received: ${GREEN}$LAST_TIMESTAMP${NC}"
    PASSED=$((PASSED + 1))
    
    # Calculate data age
    LAST_TS_EPOCH=$(date -d "$LAST_TIMESTAMP" +%s 2>/dev/null || echo 0)
    CURRENT_EPOCH=$(date +%s)
    DATA_AGE=$((CURRENT_EPOCH - LAST_TS_EPOCH))
    
    if [ $DATA_AGE -lt 3600 ]; then
        echo -e "Data freshness: ${GREEN}✓ Fresh (${DATA_AGE}s ago)${NC}"
    elif [ $DATA_AGE -lt 7200 ]; then
        echo -e "Data freshness: ${YELLOW}⚠ Acceptable (${DATA_AGE}s ago)${NC}"
    else
        echo -e "Data freshness: ${RED}✗ Stale (${DATA_AGE}s ago)${NC}"
    fi
else
    echo -e "Last data received: ${RED}✗ No data yet${NC}"
    FAILED=$((FAILED + 1))
    echo -e "${YELLOW}Note: If this is a fresh deployment, wait up to 1 hour for first data${NC}"
fi

# 8. Connectivity Tests
print_header "8. Network Connectivity"
check_service "Internet Connection" \
    "curl -s -o /dev/null -w '%{http_code}' https://www.google.com" \
    "200"

check_service "OpenWeatherMap API" \
    "curl -s 'http://api.openweathermap.org/data/2.5/weather?q=Tokyo&appid=test'" \
    "Invalid API key"

# Summary
print_header "Health Check Summary"

TOTAL=$((PASSED + FAILED))
SUCCESS_RATE=$((PASSED * 100 / TOTAL))

echo "Total Checks: $TOTAL"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""
echo -e "Success Rate: ${BLUE}$SUCCESS_RATE%${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                       ║${NC}"
    echo -e "${GREEN}║     ✓ All Systems Operational!                       ║${NC}"
    echo -e "${GREEN}║                                                       ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
    exit 0
elif [ $SUCCESS_RATE -ge 80 ]; then
    echo -e "${YELLOW}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║                                                       ║${NC}"
    echo -e "${YELLOW}║     ⚠ System Mostly Operational                      ║${NC}"
    echo -e "${YELLOW}║     Some issues detected, review above                ║${NC}"
    echo -e "${YELLOW}║                                                       ║${NC}"
    echo -e "${YELLOW}╚═══════════════════════════════════════════════════════╝${NC}"
    exit 1
else
    echo -e "${RED}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                                                       ║${NC}"
    echo -e "${RED}║     ✗ System Has Issues                               ║${NC}"
    echo -e "${RED}║     Review logs: docker-compose logs                  ║${NC}"
    echo -e "${RED}║                                                       ║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════╝${NC}"
    exit 2
fi
