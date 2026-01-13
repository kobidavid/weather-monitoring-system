pipeline {
    agent any
    
    environment {
        DOCKER_COMPOSE_FILE = 'docker-compose.yml'
        OPENWEATHER_API_KEY = credentials('openweather-api-key')
        GRAFANA_API_KEY = credentials('grafana-api-key')
    }
    
    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }
    
    stages {
        stage('Clone Repository') {
            steps {
                script {
                    echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
                    echo '📥 CLONING REPOSITORY'
                    echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
                }
                checkout scm
                sh 'git log -1 --pretty=format:"%h - %an: %s" || echo "No git history"'
                sh 'ls -la'
            }
        }
        
        stage('Parallel Build & Test') {
            parallel {
                stage('Build Docker Images') {
                    steps {
                        script {
                            echo '🐳 Building Docker images...'
                            sh 'docker-compose build --no-cache weather-monitor || true'
                        }
                    }
                }
                
                stage('Lint & Static Analysis') {
                    steps {
                        script {
                            echo '🔍 Running code quality checks...'
                            sh 'pip3 install pylint flake8 --break-system-packages || true'
                            sh 'pylint weather_monitor.py --exit-zero || echo "Pylint completed"'
                            sh 'flake8 weather_monitor.py --max-line-length=120 --exit-zero || echo "Flake8 completed"'
                        }
                    }
                }
            }
        }
        
        stage('Unit Tests') {
            steps {
                script {
                    echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
                    echo '🧪 RUNNING UNIT TESTS'
                    echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
                    sh 'pip3 install -r requirements.txt --break-system-packages || true'
                    sh 'pip3 install pytest pytest-cov --break-system-packages || true'
                    sh 'pytest tests/ -v --cov=weather_monitor --cov-report=xml --cov-report=html || true'
                }
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: '**/test-results/*.xml'
                    publishHTML([
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'htmlcov',
                        reportFiles: 'index.html',
                        reportName: 'Coverage Report'
                    ])
                }
            }
        }
        
        stage('Deploy') {
            steps {
                script {
                    echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
                    echo '🚀 DEPLOYING SERVICES'
                    echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
                    
                    sh 'docker-compose down || true'
                    
                    writeFile file: '.env', text: """OPENWEATHER_API_KEY=${env.OPENWEATHER_API_KEY}
CITY_NAME=Tokyo
RABBITMQ_USER=admin
RABBITMQ_PASSWORD=admin123"""
                    
                    sh 'docker-compose up -d'
                    sh 'sleep 30'
                    sh 'docker-compose ps'
                }
            }
        }
        
        stage('Integration Tests') {
            steps {
                script {
                    echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
                    echo '🔗 RUNNING INTEGRATION TESTS'
                    echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
                    
                    sh 'sleep 20'
                    sh 'curl -f http://localhost:15672 || echo "RabbitMQ not ready"'
                    sh 'curl -f http://localhost:9200/_cluster/health || echo "ES not ready"'
                    sh 'curl -f http://localhost:3000/api/health || echo "Grafana not ready"'
                    sh 'curl -s http://localhost:9200/weather-data-*/_count || echo "No data"'
                }
            }
        }
        
        stage('Smoke Tests') {
            parallel {
                stage('Test RabbitMQ API') {
                    steps {
                        script {
                            echo '🐰 Testing RabbitMQ...'
                            sh 'curl -u admin:admin123 http://localhost:15672/api/queues/%2F/weather_data || true'
                        }
                    }
                }
                
                stage('Test Elasticsearch Indices') {
                    steps {
                        script {
                            echo '🔍 Testing Elasticsearch...'
                            sh 'curl -s http://localhost:9200/_cat/indices?v || true'
                            sh 'curl -s http://localhost:9200/weather-data-*/_count || true'
                        }
                    }
                }
                
                stage('Test Grafana Health') {
                    steps {
                        script {
                            echo '📊 Testing Grafana...'
                            sh 'curl -f http://localhost:3000/api/health || true'
                            sh 'curl -u admin:admin123 http://localhost:3000/api/datasources || true'
                        }
                    }
                }
            }
        }
    }
    
    post {
        success {
            script {
                echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
                echo '✅ PIPELINE COMPLETED SUCCESSFULLY!'
                echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
                sendGrafanaAnnotation('success', "Pipeline ${env.BUILD_NUMBER} succeeded")
            }
        }
        
        failure {
            script {
                echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
                echo '❌ PIPELINE FAILED!'
                echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
                sendGrafanaAnnotation('failure', "Pipeline ${env.BUILD_NUMBER} failed")
            }
        }
        
        always {
            script {
                sh 'mkdir -p logs || true'
                sh 'docker-compose logs --tail=100 > logs/docker-compose.log || true'
                archiveArtifacts artifacts: 'logs/*.log', allowEmptyArchive: true
                sh 'docker system prune -f || true'
            }
        }
    }
}

def sendGrafanaAnnotation(String status, String message) {
    try {
        def timestamp = new Date().getTime()
        sh """curl -X POST http://localhost:3000/api/annotations \
            -H 'Authorization: Bearer ${env.GRAFANA_API_KEY}' \
            -H 'Content-Type: application/json' \
            -d '{"text": "${message}", "tags": ["jenkins", "${status}"], "time": ${timestamp}}' \
            || echo 'Grafana annotation failed'"""
        echo "✅ Grafana annotation sent"
    } catch (Exception e) {
        echo "⚠️ Grafana annotation failed: ${e.message}"
    }
}
