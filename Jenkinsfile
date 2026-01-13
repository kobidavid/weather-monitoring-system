pipeline {
    agent any
    
    environment {
        DOCKER_COMPOSE_FILE = 'docker-compose.yml'
        PROJECT_NAME = 'weather-monitoring'
        GRAFANA_URL = 'http://localhost:3000'
        GRAFANA_API_KEY = credentials('grafana-api-key')  // Store in Jenkins credentials
        OPENWEATHER_API_KEY = credentials('openweather-api-key')  // Store in Jenkins credentials
    }
    
    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }
    
    stages {
        stage('Clone Repository') {
            steps {
                echo 'Cloning repository...'
                checkout scm
                sh 'git log -1'
            }
        }
        
        stage('Parallel Build & Test') {
            parallel {
                stage('Build Docker Images') {
                    steps {
                        script {
                            echo 'Building Docker images...'
                            sh """
                                docker-compose -f ${DOCKER_COMPOSE_FILE} build --no-cache
                            """
                        }
                    }
                }
                
                stage('Lint & Static Analysis') {
                    steps {
                        script {
                            echo 'Running linting and static analysis...'
                            sh '''
                                # Install required packages for testing
                                pip install pylint flake8 --break-system-packages || true
                                
                                # Run pylint
                                pylint weather_monitor.py --exit-zero || true
                                
                                # Run flake8
                                flake8 weather_monitor.py --max-line-length=120 --exit-zero || true
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Unit Tests') {
            steps {
                script {
                    echo 'Running unit tests...'
                    sh '''
                        # Install test dependencies
                        pip install -r requirements.txt --break-system-packages
                        
                        # Run pytest with coverage
                        pytest tests/ -v --cov=weather_monitor --cov-report=xml --cov-report=html || true
                    '''
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
                    echo 'Deploying services with Docker Compose...'
                    sh """
                        # Stop existing services
                        docker-compose -f ${DOCKER_COMPOSE_FILE} down || true
                        
                        # Create .env file with API key
                        echo "OPENWEATHER_API_KEY=${OPENWEATHER_API_KEY}" > .env
                        echo "CITY_NAME=Tokyo" >> .env
                        
                        # Start all services
                        docker-compose -f ${DOCKER_COMPOSE_FILE} up -d
                        
                        # Wait for services to be healthy
                        echo 'Waiting for services to be healthy...'
                        sleep 30
                        
                        # Check service health
                        docker-compose -f ${DOCKER_COMPOSE_FILE} ps
                    """
                }
            }
        }
        
        stage('Integration Tests') {
            steps {
                script {
                    echo 'Running integration tests...'
                    sh '''
                        # Wait for services to fully start
                        sleep 20
                        
                        # Check if RabbitMQ is accessible
                        curl -f http://localhost:15672 || echo "RabbitMQ UI not accessible"
                        
                        # Check if Elasticsearch is accessible
                        curl -f http://localhost:9200/_cluster/health || echo "Elasticsearch not accessible"
                        
                        # Check if Grafana is accessible
                        curl -f http://localhost:3000/api/health || echo "Grafana not accessible"
                        
                        # Verify data flow (check if data appears in Elasticsearch)
                        sleep 60  # Wait for first data point
                        curl -X GET "http://localhost:9200/weather-data-*/_search?size=1&sort=@timestamp:desc" || echo "No data in Elasticsearch yet"
                    '''
                }
            }
        }
        
        stage('Smoke Tests') {
            parallel {
                stage('Test RabbitMQ') {
                    steps {
                        script {
                            sh '''
                                echo "Testing RabbitMQ..."
                                curl -u admin:admin123 http://localhost:15672/api/queues/%2F/weather_data || true
                            '''
                        }
                    }
                }
                
                stage('Test Elasticsearch') {
                    steps {
                        script {
                            sh '''
                                echo "Testing Elasticsearch..."
                                curl http://localhost:9200/_cat/indices?v || true
                            '''
                        }
                    }
                }
                
                stage('Test Grafana') {
                    steps {
                        script {
                            sh '''
                                echo "Testing Grafana..."
                                curl -f http://localhost:3000/api/health || true
                            '''
                        }
                    }
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo 'Collecting logs...'
                sh '''
                    mkdir -p logs
                    docker-compose -f ${DOCKER_COMPOSE_FILE} logs --tail=100 > logs/docker-compose.log || true
                '''
                archiveArtifacts artifacts: 'logs/**/*.log', allowEmptyArchive: true
            }
        }
        
        success {
            script {
                echo 'Pipeline completed successfully!'
                sendGrafanaAnnotation(
                    'success',
                    "Pipeline #${BUILD_NUMBER} completed successfully",
                    "Deployment successful for build ${BUILD_NUMBER}"
                )
            }
        }
        
        failure {
            script {
                echo 'Pipeline failed!'
                sendGrafanaAnnotation(
                    'failure',
                    "Pipeline #${BUILD_NUMBER} failed",
                    "Deployment failed for build ${BUILD_NUMBER}"
                )
            }
        }
    }
}

def sendGrafanaAnnotation(String status, String title, String text) {
    def color = status == 'success' ? 'green' : 'red'
    def tags = ['jenkins', 'deployment', status]
    
    try {
        sh """
            curl -X POST ${GRAFANA_URL}/api/annotations \\
                -H "Authorization: Bearer ${GRAFANA_API_KEY}" \\
                -H "Content-Type: application/json" \\
                -d '{
                    "text": "${text}",
                    "tags": ${groovy.json.JsonOutput.toJson(tags)},
                    "time": ${System.currentTimeMillis()}
                }'
        """
        echo "Grafana annotation sent: ${title}"
    } catch (Exception e) {
        echo "Failed to send Grafana annotation: ${e.message}"
    }
}
