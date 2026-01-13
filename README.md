# 🌤️ Weather Monitoring System

Real-time weather monitoring system with automated data collection, processing, and visualization.

![CI/CD](https://github.com/kobidavid/weather-monitoring-system/actions/workflows/ci-cd.yml/badge.svg)
[![Python](https://img.shields.io/badge/python-3.11+-blue.svg)](https://www.python.org/downloads/)
[![Docker](https://img.shields.io/badge/docker-required-blue.svg)](https://www.docker.com/)

---

## 🎯 Features

- ✅ **Real-time Data Collection** - Fetches weather data from OpenWeatherMap API
- ✅ **Message Queue** - RabbitMQ for reliable data streaming
- ✅ **Data Pipeline** - Logstash for processing and transformation
- ✅ **Storage** - Elasticsearch for time-series data
- ✅ **Visualization** - Grafana dashboards with 9 panels
- ✅ **CI/CD** - Automated testing with GitHub Actions
- ✅ **Docker Compose** - One-command deployment

---

## 🏗️ Architecture

```
Weather API → Python App → RabbitMQ → Logstash → Elasticsearch → Grafana
                   ↓
              Unit Tests
                   ↓
            GitHub Actions (CI/CD)
```

### Components:

| Service | Technology | Purpose |
|---------|-----------|---------|
| **Data Collector** | Python 3.11 | Fetch weather data |
| **Message Queue** | RabbitMQ 3.12 | Data streaming |
| **Pipeline** | Logstash 8.11 | Data processing |
| **Storage** | Elasticsearch 8.11 | Time-series DB |
| **Dashboard** | Grafana 10.2 | Visualization |
| **CI/CD** | GitHub Actions | Automated testing |

---

## 🚀 Quick Start

### Prerequisites

- Docker Desktop installed
- OpenWeatherMap API key ([Get one free](https://openweathermap.org/api))
- Git

### Installation (2 minutes)

```bash
# 1. Clone repository
git clone https://github.com/kobidavid/weather-monitoring-system.git
cd weather-monitoring-system

# 2. Configure environment
cp .env.example .env
nano .env  # Add your OPENWEATHER_API_KEY

# 3. Start all services
docker-compose up -d

# 4. Wait for services (60 seconds)
sleep 60
```

### Verify Installation

```bash
# Check services
docker-compose ps

# Check data
curl "http://localhost:9200/weather-data-*/_count"

# Open Grafana
open http://localhost:3000  # Login: admin/admin123
```

---

## 📊 Dashboard

Access Grafana at **http://localhost:3000** (admin/admin123)

### Available Panels:

1. **Current Temperature** - Real-time temperature gauge
2. **Humidity** - Current humidity level
3. **Pressure** - Atmospheric pressure
4. **Wind Speed** - Current wind speed
5. **Temperature Trend** - 24-hour temperature graph
6. **Humidity Trend** - 24-hour humidity graph
7. **Pressure Trend** - 24-hour pressure graph
8. **Weather Conditions** - Current conditions table
9. **Data Freshness** - Last update indicator

---

## 🔄 CI/CD Pipeline

Automated testing runs on every push via GitHub Actions.

### Pipeline Stages:

| Stage | What It Does | Duration |
|-------|-------------|----------|
| **Lint** | Code quality (pylint, flake8) | ~1 min |
| **Test** | 8 unit tests + coverage | ~1 min |
| **Build** | Docker image build | ~2 min |
| **Integration** | Service integration tests | ~2 min |

**Total: ~5 minutes per run**

View results: [Actions Tab](https://github.com/YOUR_USERNAME/weather-monitoring-system/actions)

---

## 🛠️ Development

### Project Structure

```
weather-monitoring-system/
├── .github/workflows/      # CI/CD configuration
├── grafana/               # Dashboard configs
├── logstash/              # Pipeline configs
├── tests/                 # Unit tests
├── docker-compose.yml     # Service orchestration
├── Dockerfile             # Weather monitor image
├── weather_monitor.py     # Main application
├── requirements.txt       # Python dependencies
└── .env                   # Environment variables
```

### Run Tests Locally

```bash
# Install dependencies
pip install -r requirements.txt
pip install pytest pytest-cov

# Run tests
pytest tests/ -v --cov=weather_monitor

# Run linting
pylint weather_monitor.py
flake8 weather_monitor.py
```

### Make Changes

```bash
# 1. Make your changes
vim weather_monitor.py

# 2. Restart service
docker-compose restart weather-monitor

# 3. View logs
docker logs weather-monitor-app -f

# 4. Test locally
pytest tests/

# 5. Commit and push
git add .
git commit -m "Your changes"
git push origin main

# 6. GitHub Actions will automatically test
```

---

## ⚙️ Configuration

### Environment Variables

Edit `.env` file:

```bash
# Required
OPENWEATHER_API_KEY=your_api_key_here    # From openweathermap.org

# Optional
CITY_NAME=Tokyo                           # City to monitor
RABBITMQ_USER=admin                       # RabbitMQ username
RABBITMQ_PASSWORD=admin123                # RabbitMQ password
```

### Sampling Interval

- **3600** (1 hour) - Recommended for free tier
- **60** (1 minute) - For testing (uses more API calls)

Free tier limit: 1,000 calls/day

---

## 📚 API Documentation

### Weather Monitor

The main application (`weather_monitor.py`) runs on schedule:

```python
# Fetch weather data
GET https://api.openweathermap.org/data/2.5/weather

# Process and send to RabbitMQ
{
    "city": "Tokyo",
    "temperature": 15.5,
    "humidity": 65,
    "pressure": 1013,
    "wind_speed": 3.2,
    "weather": "Clear",
    "timestamp": "2025-01-13T12:00:00Z"
}
```

### Service Endpoints

| Service | URL | Credentials |
|---------|-----|-------------|
| Grafana | http://localhost:3000 | admin/admin123 |
| RabbitMQ | http://localhost:15672 | admin/admin123 |
| Elasticsearch | http://localhost:9200 | None |

---

## 🐛 Troubleshooting

### Services Won't Start

```bash
# Check logs
docker-compose logs

# Restart everything
docker-compose down -v
docker-compose up -d
```

### No Data in Dashboard

```bash
# Check weather monitor
docker logs weather-monitor-app

# Check Elasticsearch
curl http://localhost:9200/weather-data-*/_search?size=1

# Verify API key
curl "http://api.openweathermap.org/data/2.5/weather?q=Tokyo&appid=YOUR_KEY"
```

### Port Conflicts

```bash
# Check what's using ports
lsof -i :3000   # Grafana
lsof -i :9200   # Elasticsearch
lsof -i :15672  # RabbitMQ

# Stop conflicting services
```

See [COMPLETE_SETUP_GUIDE.md](COMPLETE_SETUP_GUIDE.md) for more troubleshooting.

---

## 🧪 Testing

### Unit Tests

```bash
pytest tests/ -v
```

8 tests covering:
- Weather API integration
- Data validation
- RabbitMQ messaging
- Configuration handling

### Coverage

```bash
pytest tests/ --cov=weather_monitor --cov-report=html
open htmlcov/index.html
```

Current coverage: **85%+**

---

## 📦 Deployment

### Docker Compose (Recommended)

```bash
docker-compose up -d
```

### Manual Deployment

```bash
# Build image
docker build -t weather-monitor:latest .

# Run with environment
docker run -d \
  --name weather-monitor \
  --network weather-network \
  --env-file .env \
  weather-monitor:latest
```

---

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing`)
5. Open Pull Request

GitHub Actions will automatically test your changes!

---

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details

---

## 🙏 Acknowledgments

- [OpenWeatherMap](https://openweathermap.org/) - Weather data API
- [RabbitMQ](https://www.rabbitmq.com/) - Message queue
- [Elastic Stack](https://www.elastic.co/) - Data pipeline & storage
- [Grafana](https://grafana.com/) - Visualization
- [Docker](https://www.docker.com/) - Containerization

---

## 📞 Support

For issues or questions:
- Open an [Issue](https://github.com/YOUR_USERNAME/weather-monitoring-system/issues)
- Check [COMPLETE_SETUP_GUIDE.md](COMPLETE_SETUP_GUIDE.md)
- View [CI/CD runs](https://github.com/YOUR_USERNAME/weather-monitoring-system/actions)

---

**Made with ❤️ and ☕**
