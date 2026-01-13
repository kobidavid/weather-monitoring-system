# Contributing to Weather Monitoring System

Thank you for your interest in contributing to the Weather Monitoring System! This document provides guidelines and instructions for contributing.

## 🤝 How to Contribute

### Reporting Bugs

If you find a bug, please create an issue with:
- Clear description of the bug
- Steps to reproduce
- Expected vs actual behavior
- Environment details (OS, Docker version, etc.)
- Relevant logs

### Suggesting Enhancements

For feature requests:
- Describe the feature and its benefits
- Explain the use case
- Provide examples if possible

### Pull Requests

1. **Fork the repository**
   ```bash
   git clone https://github.com/yourusername/weather-monitoring.git
   cd weather-monitoring
   ```

2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**
   - Follow the coding standards
   - Add tests for new features
   - Update documentation

4. **Test your changes**
   ```bash
   # Run unit tests
   pytest tests/ -v
   
   # Run health checks
   ./health-check.sh
   
   # Test with Docker
   docker-compose up -d
   ```

5. **Commit your changes**
   ```bash
   git add .
   git commit -m "Add feature: description of your feature"
   ```

6. **Push and create PR**
   ```bash
   git push origin feature/your-feature-name
   ```
   Then create a Pull Request on GitHub.

## 📝 Coding Standards

### Python Code
- Follow PEP 8 style guide
- Use meaningful variable names
- Add docstrings to functions
- Keep functions focused and small
- Maximum line length: 120 characters

### Docker
- Use official base images
- Minimize layers
- Add health checks
- Use multi-stage builds when appropriate

### Documentation
- Update README.md for major changes
- Add inline comments for complex logic
- Keep documentation up-to-date

## 🧪 Testing Requirements

All contributions must include:

1. **Unit Tests**
   - Test new functions
   - Maintain >80% code coverage
   - Use pytest framework

2. **Integration Tests**
   - Test service interactions
   - Verify data flow

3. **Documentation Tests**
   - Verify README instructions work
   - Test setup scripts

## 📋 Code Review Process

1. Automated checks must pass:
   - Linting (pylint, flake8)
   - Unit tests
   - Docker build
   
2. Manual review by maintainers:
   - Code quality
   - Test coverage
   - Documentation
   
3. At least one approval required

## 🎯 Development Setup

1. **Prerequisites**
   ```bash
   # Install development dependencies
   pip install -r requirements.txt
   pip install pylint flake8 pytest-cov
   ```

2. **Environment Setup**
   ```bash
   cp .env.example .env
   # Add your API key to .env
   ```

3. **Run Development Environment**
   ```bash
   docker-compose up -d
   ```

4. **Watch Logs**
   ```bash
   docker-compose logs -f
   ```

## 🐛 Debugging Tips

### View Service Logs
```bash
docker-compose logs [service-name]
```

### Enter Container
```bash
docker-compose exec [service-name] bash
```

### Check Service Health
```bash
./health-check.sh
```

### Reset Everything
```bash
docker-compose down -v
docker-compose up -d
```

## 📚 Project Structure

```
weather-monitoring/
├── weather_monitor.py      # Main application
├── tests/                  # Unit tests
├── docker-compose.yml      # Services definition
├── Jenkinsfile            # CI/CD pipeline
├── logstash/              # Logstash config
├── grafana/               # Grafana dashboards
└── README.md              # Documentation
```

## 🏷️ Commit Message Format

Use conventional commits:

```
type(scope): subject

body

footer
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting
- `refactor`: Code restructuring
- `test`: Adding tests
- `chore`: Maintenance

Example:
```
feat(monitor): add support for multiple cities

- Added city configuration
- Updated dashboard to show city selector
- Added tests for multi-city support

Closes #123
```

## 🔒 Security

- Never commit API keys or secrets
- Use environment variables
- Review dependencies for vulnerabilities
- Follow security best practices

## 📞 Questions?

- Create an issue for questions
- Check existing issues first
- Join discussions

## 🙏 Thank You!

Your contributions make this project better for everyone!
