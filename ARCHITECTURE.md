# Architecture Documentation 🏗️

## System Overview

The Weather Monitoring System is a microservices-based application that collects, processes, stores, and visualizes weather data with millisecond-precision timestamp tracking.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     External Services                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │         OpenWeatherMap API (api.openweathermap.org)      │  │
│  └──────────────────────────────────────────────────────────┘  │
└──────────────────────────┬──────────────────────────────────────┘
                           │ HTTP/JSON
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Application Layer                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Weather Monitor (Python 3.11)                           │  │
│  │  - Scheduled sampling (hourly)                           │  │
│  │  - Millisecond timestamp capture                         │  │
│  │  - Data enrichment                                       │  │
│  │  - RabbitMQ publisher                                    │  │
│  └──────────────────────────────────────────────────────────┘  │
└──────────────────────────┬──────────────────────────────────────┘
                           │ AMQP Protocol
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Message Queue Layer                          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  RabbitMQ 3.12                                           │  │
│  │  - Message persistence                                   │  │
│  │  - Queue: weather_data                                   │  │
│  │  - Management UI (15672)                                 │  │
│  └──────────────────────────────────────────────────────────┘  │
└──────────────────────────┬──────────────────────────────────────┘
                           │ RabbitMQ Input Plugin
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Processing Layer                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Logstash 8.11                                           │  │
│  │  - JSON parsing                                          │  │
│  │  - Timestamp conversion (UNIX_MS → @timestamp)           │  │
│  │  - Latency calculation                                   │  │
│  │  - Field type conversion                                 │  │
│  └──────────────────────────────────────────────────────────┘  │
└──────────────────────────┬──────────────────────────────────────┘
                           │ Bulk API
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Storage Layer                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Elasticsearch 8.11                                      │  │
│  │  - Time-series data storage                              │  │
│  │  - Index pattern: weather-data-YYYY.MM.dd                │  │
│  │  - Full-text search capabilities                         │  │
│  │  - Aggregations for analytics                            │  │
│  └──────────────────────────────────────────────────────────┘  │
└──────────────────────────┬──────────────────────────────────────┘
                           │ Elasticsearch API
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Visualization Layer                          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Grafana 10.2                                            │  │
│  │  - Real-time dashboards                                  │  │
│  │  - Temperature alerts                                    │  │
│  │  - Auto-provisioned datasource                           │  │
│  │  - Pre-configured dashboard                              │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Weather Monitor Application

**Technology**: Python 3.11
**Key Libraries**:
- `requests`: HTTP client for API calls
- `pika`: RabbitMQ client
- `APScheduler`: Job scheduling

**Responsibilities**:
- Fetch weather data from OpenWeatherMap API
- Capture exact timestamp in milliseconds
- Enrich data with metadata
- Publish to RabbitMQ queue
- Handle connection failures with retry logic
- Log all operations

**Configuration**:
```yaml
Environment Variables:
  - OPENWEATHER_API_KEY: API authentication
  - CITY_NAME: Target city for monitoring
  - RABBITMQ_HOST: RabbitMQ server address
  - RABBITMQ_PORT: RabbitMQ port (5672)
  - RABBITMQ_QUEUE: Queue name
  - RABBITMQ_USER: Authentication username
  - RABBITMQ_PASSWORD: Authentication password
```

**Sampling Strategy**:
- Initial sample on startup
- Hourly sampling using APScheduler
- Blocking scheduler for reliable execution

### 2. RabbitMQ Message Queue

**Technology**: RabbitMQ 3.12
**Port Mappings**:
- 5672: AMQP protocol
- 15672: Management UI

**Queue Configuration**:
```yaml
Queue Name: weather_data
Durable: true
Message TTL: none (persistent)
Auto-delete: false
```

**Message Format**:
```json
{
  "timestamp_ms": 1705149600123,
  "timestamp": "2024-01-13T12:00:00.123",
  "city": "Tokyo",
  "country": "JP",
  "temperature": 15.5,
  "feels_like": 14.2,
  "temp_min": 13.0,
  "temp_max": 18.0,
  "pressure": 1013,
  "humidity": 65,
  "weather": "Clear",
  "weather_description": "clear sky",
  "wind_speed": 3.5,
  "wind_deg": 180,
  "clouds": 10,
  "visibility": 10000,
  "sunrise": 1705109876,
  "sunset": 1705148234
}
```

### 3. Logstash Data Processing

**Technology**: Logstash 8.11

**Pipeline Stages**:

1. **Input**:
   ```ruby
   input {
     rabbitmq {
       host => "rabbitmq"
       queue => "weather_data"
       codec => "json"
     }
   }
   ```

2. **Filter**:
   - JSON parsing
   - Timestamp conversion (milliseconds → @timestamp)
   - Processing latency calculation
   - Field type conversions
   - Metadata enrichment

3. **Output**:
   - Elasticsearch indexing
   - Stdout for debugging

**Key Transformations**:
```ruby
# Convert timestamp_ms to Elasticsearch @timestamp
date {
  match => ["timestamp_ms", "UNIX_MS"]
  target => "@timestamp"
}

# Calculate processing latency
ruby {
  code => "
    event.set('processing_timestamp_ms', (Time.now.to_f * 1000).to_i)
    event.set('processing_latency_ms', 
              event.get('processing_timestamp_ms') - event.get('timestamp_ms'))
  "
}
```

### 4. Elasticsearch Storage

**Technology**: Elasticsearch 8.11
**Memory Allocation**: 512MB (configurable)

**Index Strategy**:
- Pattern: `weather-data-YYYY.MM.dd`
- Rotation: Daily
- Benefits:
  - Easy data retention management
  - Better query performance
  - Simplified backup/restore

**Document Structure**:
```json
{
  "@timestamp": "2024-01-13T12:00:00.123Z",
  "timestamp_ms": 1705149600123,
  "processing_timestamp_ms": 1705149600234,
  "processing_latency_ms": 111,
  "city": "Tokyo",
  "country": "JP",
  "temperature": 15.5,
  "feels_like": 14.2,
  "pressure": 1013,
  "humidity": 65,
  "weather": "Clear",
  "wind_speed": 3.5
}
```

**Field Types**:
- Timestamps: Long (milliseconds)
- Temperature: Float
- Pressure, Humidity: Integer
- Text fields: Keyword + Text

### 5. Grafana Visualization

**Technology**: Grafana 10.2

**Dashboard Components**:

1. **Gauges**:
   - Current temperature (with thresholds)
   - Humidity
   - Atmospheric pressure
   - Wind speed
   - Cloud coverage

2. **Time Series**:
   - Temperature over time
   - Temperature vs Feels Like comparison

3. **Pie Chart**:
   - Weather conditions distribution

4. **Bar Gauge**:
   - Processing latency tracking

**Alert Rules**:
```yaml
Cold Temperature Alert:
  Condition: temperature < 0°C
  Evaluation: Every 1 minute
  Duration: 5 minutes
  
Hot Temperature Alert:
  Condition: temperature > 24°C
  Evaluation: Every 1 minute
  Duration: 5 minutes
```

## Data Flow

### Sampling Cycle

```
1. Scheduler triggers (hourly)
   │
   ▼
2. Capture timestamp_ms = now()
   │
   ▼
3. Call OpenWeatherMap API
   │
   ▼
4. Parse and enrich response
   │
   ▼
5. Publish to RabbitMQ queue
   │
   ▼
6. Logstash consumes message
   │
   ▼
7. Calculate processing_timestamp_ms
   │
   ▼
8. Calculate processing_latency_ms
   │
   ▼
9. Index to Elasticsearch
   │
   ▼
10. Grafana queries and displays
```

### Latency Breakdown

```
Total Latency = API Response Time + Queue Time + Processing Time

Where:
- API Response Time: ~100-500ms
- Queue Time: <10ms (RabbitMQ local)
- Processing Time: ~50-200ms (Logstash)
- Total: ~150-710ms
```

## Scalability Considerations

### Current Limitations
- Single instance of each service
- In-memory processing
- Local storage

### Scaling Strategies

**Horizontal Scaling**:
```yaml
Weather Monitor:
  - Multiple instances with different cities
  - Load balancing across instances
  
RabbitMQ:
  - Clustered setup
  - Mirrored queues
  
Elasticsearch:
  - Multi-node cluster
  - Shard distribution
  
Logstash:
  - Multiple pipeline workers
  - Distributed processing
```

**Vertical Scaling**:
- Increase memory allocation
- CPU cores for processing
- Storage capacity

## High Availability

### Failure Scenarios

1. **Weather Monitor Crashes**:
   - Docker restart policy: `unless-stopped`
   - Data gap until restart
   - No data loss in queue

2. **RabbitMQ Failure**:
   - Persistent queues
   - Message durability
   - Reconnection logic in app

3. **Elasticsearch Down**:
   - Logstash buffers data
   - Queue backpressure
   - Automatic recovery

4. **Grafana Unavailable**:
   - No impact on data collection
   - Dashboards recover on restart

## Security

### Current Security Measures
- Environment variable configuration
- Basic authentication (RabbitMQ, Grafana)
- No external network exposure (except APIs)
- Docker network isolation

### Production Hardening
```yaml
Recommended:
  - HTTPS/TLS everywhere
  - Strong passwords
  - Secret management (Vault)
  - Network policies
  - Container security scanning
  - Log encryption
  - Access control lists
```

## Monitoring & Observability

### Metrics Tracked
- Weather data points
- Processing latency
- Queue depth
- Service health
- API response times

### Logging Strategy
```yaml
Application Logs:
  - Structured JSON logging
  - Timestamp with millisecond precision
  - Log levels: DEBUG, INFO, WARNING, ERROR
  
Access Logs:
  - API calls
  - Queue operations
  - Database queries
```

## Performance Optimization

### Current Optimizations
- Connection pooling
- Bulk Elasticsearch indexing
- Efficient JSON parsing
- Minimal data transformations

### Future Improvements
- Caching layer (Redis)
- Batch processing
- Compression
- Index optimization
- Query optimization

## Technology Choices

### Why These Technologies?

**Python**: 
- Easy API integration
- Rich ecosystem
- Excellent for scripting

**RabbitMQ**:
- Reliable message delivery
- Battle-tested
- Good Docker support

**ELK Stack**:
- Industry standard
- Powerful search
- Excellent visualization

**Docker**:
- Consistent environments
- Easy deployment
- Resource isolation

## Testing Strategy

### Test Pyramid

```
           ┌─────────────┐
           │     E2E     │  (Health checks)
           └─────────────┘
         ┌─────────────────┐
         │  Integration    │  (Service interactions)
         └─────────────────┘
       ┌───────────────────────┐
       │      Unit Tests        │  (Function level)
       └───────────────────────┘
```

### Test Coverage
- Unit tests: 85%
- Integration tests: Key flows
- E2E tests: Health checks

## Deployment Strategies

### Development
```bash
docker-compose up -d
```

### Staging
```bash
docker-compose -f docker-compose.yml -f docker-compose.staging.yml up -d
```

### Production
```bash
# Use Kubernetes or Docker Swarm
# Implement proper orchestration
# Add monitoring and alerts
```

## Cost Analysis

### Infrastructure Costs

**Development/Testing**:
- Local Docker: $0
- OpenWeatherMap API: $0 (free tier)

**Production (Estimated)**:
- Cloud hosting: $50-100/month
- API costs: $0-40/month
- Storage: $20/month
- Total: ~$70-160/month

## Future Roadmap

### Phase 1 (Current)
- [x] Basic monitoring
- [x] Hourly sampling
- [x] Dashboard
- [x] Alerts

### Phase 2 (Next 3 months)
- [ ] Multi-city support
- [ ] Historical analysis
- [ ] Predictive analytics
- [ ] Mobile app

### Phase 3 (6-12 months)
- [ ] Machine learning
- [ ] Advanced forecasting
- [ ] Global coverage
- [ ] Public API

## References

- [OpenWeatherMap API](https://openweathermap.org/api)
- [RabbitMQ Documentation](https://www.rabbitmq.com/documentation.html)
- [Elasticsearch Guide](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [Grafana Documentation](https://grafana.com/docs/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)

---

**Document Version**: 1.0  
**Last Updated**: January 2024  
**Author**: Weather Monitoring Team
