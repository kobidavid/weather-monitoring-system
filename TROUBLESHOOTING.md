# Troubleshooting Guide 🔧

Common issues and their solutions for the Weather Monitoring System.

## Table of Contents
- [Services Won't Start](#services-wont-start)
- [No Data in Grafana](#no-data-in-grafana)
- [API Connection Issues](#api-connection-issues)
- [RabbitMQ Problems](#rabbitmq-problems)
- [Elasticsearch Issues](#elasticsearch-issues)
- [Grafana Dashboard Problems](#grafana-dashboard-problems)
- [Performance Issues](#performance-issues)
- [Docker Issues](#docker-issues)

---

## Services Won't Start

### Symptom
```bash
docker-compose up -d
# Services exit immediately or show unhealthy status
```

### Solution 1: Check Logs
```bash
docker-compose logs
docker-compose logs [service-name]
```

### Solution 2: Port Conflicts
```bash
# Check if ports are already in use
sudo lsof -i :3000  # Grafana
sudo lsof -i :5672  # RabbitMQ
sudo lsof -i :9200  # Elasticsearch
sudo lsof -i :15672 # RabbitMQ Management

# Stop conflicting services or change ports in docker-compose.yml
```

### Solution 3: Insufficient Resources
```bash
# Check Docker resources
docker stats

# Increase Docker memory/CPU in Docker Desktop settings
# Recommended: 4GB RAM, 2 CPUs minimum
```

### Solution 4: Clean Start
```bash
# Remove everything and start fresh
docker-compose down -v
docker-compose up -d
```

---

## No Data in Grafana

### Symptom
Dashboard is empty or shows "No Data"

### Solution 1: Wait for First Sample
```bash
# System samples every hour
# First data point takes 5-10 minutes after startup
# Wait at least 10 minutes, then check
make check-data
```

### Solution 2: Verify Data Flow
```bash
# Check 1: Weather monitor is running
docker-compose logs weather-monitor

# Check 2: Data in RabbitMQ
curl -u admin:admin123 http://localhost:15672/api/queues/%2F/weather_data

# Check 3: Data in Elasticsearch
curl http://localhost:9200/weather-data-*/_count

# Check 4: Query latest data
curl "http://localhost:9200/weather-data-*/_search?size=1&sort=@timestamp:desc"
```

### Solution 3: Check Datasource
```bash
# Login to Grafana (admin/admin123)
# Go to: Configuration > Data Sources > Elasticsearch
# Click "Save & Test"
# Should show: "Data source is working"
```

### Solution 4: Refresh Dashboard
```bash
# In Grafana dashboard:
# 1. Click the refresh icon
# 2. Check time range (default: Last 24 hours)
# 3. Try "Last 7 days" to see more data
```

---

## API Connection Issues

### Symptom
```
Error fetching weather data: Connection refused
Error: Invalid API key
```

### Solution 1: Verify API Key
```bash
# Check API key is set
grep OPENWEATHER_API_KEY .env

# Test API key manually
API_KEY="your_key_here"
curl "http://api.openweathermap.org/data/2.5/weather?q=Tokyo&appid=$API_KEY&units=metric"
```

### Solution 2: Check API Key Status
- Go to: https://home.openweathermap.org/api_keys
- Verify key is active
- Check usage limits (free tier: 60 calls/minute, 1,000/day)
- New keys take 10-30 minutes to activate

### Solution 3: Network Issues
```bash
# Test internet connectivity
curl https://www.google.com

# Test OpenWeatherMap connectivity
curl http://api.openweathermap.org

# Check Docker network
docker network ls
docker network inspect weather-network
```

### Solution 4: Firewall/Proxy
```bash
# If behind corporate firewall/proxy:
# Add proxy settings to docker-compose.yml:
environment:
  - http_proxy=http://proxy.company.com:8080
  - https_proxy=http://proxy.company.com:8080
```

---

## RabbitMQ Problems

### Symptom
```
Connection refused to RabbitMQ
Queue not found
```

### Solution 1: Check RabbitMQ Status
```bash
docker-compose ps rabbitmq
docker-compose logs rabbitmq

# Access management UI
open http://localhost:15672
# Login: admin/admin123
```

### Solution 2: Restart RabbitMQ
```bash
docker-compose restart rabbitmq

# Wait for health check
sleep 10
docker-compose ps rabbitmq
```

### Solution 3: Check Queue
```bash
# Verify queue exists
curl -u admin:admin123 http://localhost:15672/api/queues/%2F/weather_data

# Recreate queue if needed
# Queue is auto-created by application
docker-compose restart weather-monitor
```

### Solution 4: Connection Settings
```bash
# Verify environment variables
docker-compose exec weather-monitor env | grep RABBITMQ
```

---

## Elasticsearch Issues

### Symptom
```
Cluster health: RED
Index not found
Out of memory
```

### Solution 1: Check Cluster Health
```bash
curl http://localhost:9200/_cluster/health?pretty

# Expected: status: "green" or "yellow"
# Red means problems
```

### Solution 2: Increase Memory
```bash
# Edit docker-compose.yml
# Change ES_JAVA_OPTS to:
- "ES_JAVA_OPTS=-Xms1g -Xmx1g"  # Increase from 512m

# Restart
docker-compose restart elasticsearch
```

### Solution 3: Clear Old Data
```bash
# Delete old indices (keep last 7 days)
curl -X DELETE http://localhost:9200/weather-data-2024.01.01

# Or delete all data
curl -X DELETE http://localhost:9200/weather-data-*
```

### Solution 4: Reset Elasticsearch
```bash
# Complete reset (DELETES ALL DATA)
docker-compose stop elasticsearch
docker volume rm weather-monitoring_elasticsearch_data
docker-compose up -d elasticsearch
```

---

## Grafana Dashboard Problems

### Symptom
- Dashboard not showing
- Panels show errors
- Alerts not working

### Solution 1: Re-provision Dashboard
```bash
# Restart Grafana to reload configs
docker-compose restart grafana

# Check provisioning logs
docker-compose logs grafana | grep provision
```

### Solution 2: Manual Dashboard Import
1. Login to Grafana: http://localhost:3000
2. Click "+ Import"
3. Copy content from `grafana/dashboards/weather-dashboard.json`
4. Paste and import

### Solution 3: Fix Datasource
```bash
# Check datasource config
cat grafana/provisioning/datasources/elasticsearch.yml

# Restart Grafana
docker-compose restart grafana
```

### Solution 4: Alerts Not Firing
1. Go to: Alerting > Alert Rules
2. Check alert status
3. Verify alert conditions match data
4. Check notification channels configured

---

## Performance Issues

### Symptom
- Slow dashboard loading
- High CPU usage
- Out of memory errors

### Solution 1: Monitor Resources
```bash
# Check container resources
docker stats

# Check system resources
top
htop  # if installed
```

### Solution 2: Optimize Elasticsearch
```bash
# Reduce index retention
# Delete indices older than 30 days
curl -X DELETE http://localhost:9200/weather-data-2023.*

# Optimize indices
curl -X POST http://localhost:9200/_forcemerge?max_num_segments=1
```

### Solution 3: Limit Dashboard Query Range
```bash
# In Grafana:
# Change time range from "Last 30 days" to "Last 7 days"
# Reduces query load
```

### Solution 4: Increase Resources
```bash
# Edit docker-compose.yml to increase limits:
services:
  elasticsearch:
    mem_limit: 2g
  logstash:
    mem_limit: 1g
```

---

## Docker Issues

### Symptom
```
Docker daemon not running
Permission denied
Disk space issues
```

### Solution 1: Docker Not Running
```bash
# Start Docker daemon
sudo systemctl start docker  # Linux
# Or start Docker Desktop (Mac/Windows)

# Enable auto-start
sudo systemctl enable docker
```

### Solution 2: Permission Issues
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Logout and login again
# Or reboot
```

### Solution 3: Disk Space
```bash
# Check disk usage
df -h
docker system df

# Clean up
docker system prune -a
docker volume prune
```

### Solution 4: Docker Compose Issues
```bash
# Reinstall docker-compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

---

## Common Error Messages

### "API rate limit exceeded"
**Cause**: Too many API calls
**Solution**: 
- Free tier allows 60/minute, 1,000/day
- System uses 24 calls/day (hourly sampling)
- Check if multiple instances running

### "Connection reset by peer"
**Cause**: Network interruption
**Solution**:
- Check internet connection
- Restart network: `sudo systemctl restart NetworkManager`

### "Elasticsearch circuit breaker"
**Cause**: Query too large
**Solution**:
- Reduce query time range
- Increase Elasticsearch memory
- Add more nodes

### "RabbitMQ connection timeout"
**Cause**: RabbitMQ not ready
**Solution**:
- Wait longer for startup (30-60 seconds)
- Check RabbitMQ logs
- Verify health check passes

---

## Debug Mode

### Enable Debug Logging

**Weather Monitor**:
```python
# Edit weather_monitor.py
logging.basicConfig(level=logging.DEBUG)
```

**Logstash**:
```bash
# Edit logstash/config/logstash.yml
log.level: debug
```

**Elasticsearch**:
```bash
# Edit docker-compose.yml
environment:
  - "ELASTIC_LOG_LEVEL=debug"
```

---

## Health Check Script

```bash
# Run comprehensive health check
./health-check.sh

# Expected output:
# ✓ All Systems Operational!
```

---

## Still Having Issues?

### Collect Debug Information
```bash
# Save all logs
docker-compose logs > debug-logs.txt

# Save configuration
cat docker-compose.yml > debug-compose.yml
cat .env > debug-env.txt

# System info
docker version > debug-system.txt
docker-compose version >> debug-system.txt
uname -a >> debug-system.txt
```

### Get Help
1. **Check Documentation**: [README.md](README.md)
2. **GitHub Issues**: Search existing issues
3. **Create New Issue**: Include:
   - Error message
   - Steps to reproduce
   - Debug logs
   - System info

---

## Prevention Tips

1. **Regular Backups**
   ```bash
   # Backup Elasticsearch data
   docker run --rm -v weather-monitoring_elasticsearch_data:/data \
     -v $(pwd)/backup:/backup \
     alpine tar czf /backup/es-data.tar.gz /data
   ```

2. **Monitor Disk Space**
   ```bash
   # Add to crontab
   0 */6 * * * df -h | grep -v loop | mail -s "Disk Usage" admin@example.com
   ```

3. **Automated Health Checks**
   ```bash
   # Run daily
   0 0 * * * /path/to/health-check.sh
   ```

4. **Keep Updated**
   ```bash
   # Update images regularly
   docker-compose pull
   docker-compose up -d
   ```

---

**Last Updated**: January 2024
**Maintainer**: Weather Monitoring Team
