# Quick Start Guide 🚀

Get the Weather Monitoring System running in under 5 minutes!

## Prerequisites

- Docker & Docker Compose installed
- OpenWeatherMap API key ([Get one free here](https://openweathermap.org/api))

## 3-Step Setup

### 1️⃣ Clone & Configure

```bash
git clone https://github.com/yourusername/weather-monitoring.git
cd weather-monitoring
cp .env.example .env
```

Edit `.env` and add your API key:
```bash
OPENWEATHER_API_KEY=your_api_key_here
CITY_NAME=Tokyo
```

### 2️⃣ Deploy

**Option A - Automated (Recommended)**
```bash
bash setup.sh
```

**Option B - Manual**
```bash
docker-compose up -d
```

**Option C - Using Make**
```bash
make deploy
```

### 3️⃣ Access Dashboards

| Service | URL | Credentials |
|---------|-----|-------------|
| 🎨 **Grafana** | http://localhost:3000 | admin / admin123 |
| 🐰 **RabbitMQ** | http://localhost:15672 | admin / admin123 |
| 🔍 **Elasticsearch** | http://localhost:9200 | No auth |

## Verify Installation

```bash
# Check all services
make health

# View logs
make logs

# Check latest weather data
make check-data
```

## What's Next?

1. **View Dashboard**: Open http://localhost:3000
2. **Configure Alerts**: Go to Grafana > Alerting
3. **Monitor Data**: Watch real-time updates every hour
4. **Check Documentation**: See [README.md](README.md) for full details

## Useful Commands

```bash
make help          # Show all commands
make logs          # View logs
make restart       # Restart services
make test          # Run tests
make clean         # Stop and clean up
```

## First Data Point

⏰ **Note**: The system samples weather data **every hour**. 

- First data will appear within **5 minutes** of startup
- Then hourly updates automatically
- Check dashboard after 5-10 minutes

## Troubleshooting

### Services won't start?
```bash
docker-compose logs
```

### No data in Grafana?
```bash
# Wait 5-10 minutes for first sample
# Then check:
make check-data
make check-queue
```

### API errors?
```bash
# Verify API key in .env
# Test API:
curl "http://api.openweathermap.org/data/2.5/weather?q=Tokyo&appid=YOUR_KEY&units=metric"
```

## Getting Help

- 📖 Full docs: [README.md](README.md)
- 🐛 Issues: [GitHub Issues](https://github.com/yourusername/weather-monitoring/issues)
- 💬 Questions: Create a discussion

---

**Ready to monitor some weather? Let's go! 🌤️**
