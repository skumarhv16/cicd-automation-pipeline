pipeline {
    agent any
    
    environment {
        DOCKER_REGISTRY = 'docker.io'
        DOCKER_IMAGE = 'sandeep/my-app'
        DOCKER_CREDENTIALS_ID = 'docker-hub-credentials'
        DEPLOYMENT_SERVER = 'production-server.example.com'
        NOTIFICATION_EMAIL = 'kumarhvsandeep@gmail.com'
    }
    
    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['development', 'staging', 'production'],
            description: 'Deployment environment'
        )
        booleanParam(
            name: 'RUN_TESTS',
            defaultValue: true,
            description: 'Run test suite'
        )
        booleanParam(
            name: 'SKIP_DEPLOYMENT',
            defaultValue: false,
            description: 'Skip deployment stage'
        )
    }
    
    stages {
        stage('Checkout') {
            steps {
                script {
                    echo '📥 Checking out code...'
                    checkout scm
                    
                    // Get commit info
                    env.GIT_COMMIT_MSG = sh(
                        script: 'git log -1 --pretty=%B',
                        returnStdout: true
                    ).trim()
                    env.GIT_AUTHOR = sh(
                        script: 'git log -1 --pretty=%an',
                        returnStdout: true
                    ).trim()
                }
            }
        }
        
        stage('Build') {
            steps {
                script {
                    echo '🔨 Building application...'
                    sh '''
                        chmod +x scripts/build.sh
                        ./scripts/build.sh
                    '''
                }
            }
        }
        
        stage('Test') {
            when {
                expression { params.RUN_TESTS == true }
            }
            steps {
                script {
                    echo '🧪 Running tests...'
                    sh '''
                        chmod +x scripts/test.sh
                        ./scripts/test.sh
                    '''
                }
            }
            post {
                always {
                    junit '**/test-results/*.xml'
                    publishHTML([
                        reportDir: 'coverage',
                        reportFiles: 'index.html',
                        reportName: 'Coverage Report'
                    ])
                }
            }
        }
        
        stage('Code Quality') {
            steps {
                script {
                    echo '📊 Running code quality checks...'
                    sh '''
                        # Run linting
                        pylint src/ || true
                        
                        # Run code complexity analysis
                        radon cc src/ -a || true
                    '''
                }
            }
        }
        
        stage('Security Scan') {
            steps {
                script {
                    echo '🔒 Running security scan...'
                    sh '''
                        # Dependency check
                        safety check || true
                        
                        # Container scanning
                        trivy image ${DOCKER_IMAGE}:${BUILD_NUMBER} || true
                    '''
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    echo '🐳 Building Docker image...'
                    docker.build(
                        "${DOCKER_IMAGE}:${BUILD_NUMBER}",
                        "--build-arg BUILD_NUMBER=${BUILD_NUMBER} ."
                    )
                    
                    // Tag as latest for development
                    if (params.ENVIRONMENT == 'development') {
                        sh "docker tag ${DOCKER_IMAGE}:${BUILD_NUMBER} ${DOCKER_IMAGE}:latest"
                    }
                }
            }
        }
        
        stage('Push to Registry') {
            steps {
                script {
                    echo '📤 Pushing Docker image to registry...'
                    docker.withRegistry("https://${DOCKER_REGISTRY}", DOCKER_CREDENTIALS_ID) {
                        docker.image("${DOCKER_IMAGE}:${BUILD_NUMBER}").push()
                        
                        if (params.ENVIRONMENT == 'development') {
                            docker.image("${DOCKER_IMAGE}:latest").push()
                        }
                    }
                }
            }
        }
        
        stage('Deploy') {
            when {
                expression { params.SKIP_DEPLOYMENT == false }
            }
            steps {
                script {
                    echo "🚀 Deploying to ${params.ENVIRONMENT}..."
                    
                    withCredentials([
                        sshUserPrivateKey(
                            credentialsId: 'deployment-ssh-key',
                            keyFileVariable: 'SSH_KEY'
                        )
                    ]) {
                        sh """
                            chmod +x scripts/deploy.sh
                            ./scripts/deploy.sh ${params.ENVIRONMENT} ${BUILD_NUMBER}
                        """
                    }
                }
            }
        }
        
        stage('Health Check') {
            when {
                expression { params.SKIP_DEPLOYMENT == false }
            }
            steps {
                script {
                    echo '🏥 Running health checks...'
                    retry(3) {
                        sleep 10
                        sh '''
                            curl -f http://${DEPLOYMENT_SERVER}/health || exit 1
                        '''
                    }
                }
            }
        }
        
        stage('Smoke Tests') {
            when {
                expression { params.SKIP_DEPLOYMENT == false }
            }
            steps {
                script {
                    echo '💨 Running smoke tests...'
                    sh '''
                        chmod +x scripts/smoke-tests.sh
                        ./scripts/smoke-tests.sh ${DEPLOYMENT_SERVER}
                    '''
                }
            }
        }
    }
    
    post {
        success {
            script {
                echo '✅ Pipeline completed successfully!'
                emailext(
                    to: "${NOTIFICATION_EMAIL}",
                    subject: "✅ BUILD SUCCESS: ${env.JOB_NAME} - Build #${env.BUILD_NUMBER}",
                    body: """
                        <h2>Build Successful!</h2>
                        <p><strong>Job:</strong> ${env.JOB_NAME}</p>
                        <p><strong>Build Number:</strong> ${env.BUILD_NUMBER}</p>
                        <p><strong>Environment:</strong> ${params.ENVIRONMENT}</p>
                        <p><strong>Commit:</strong> ${env.GIT_COMMIT_MSG}</p>
                        <p><strong>Author:</strong> ${env.GIT_AUTHOR}</p>
                        <p><strong>Duration:</strong> ${currentBuild.durationString}</p>
                        <p><a href="${env.BUILD_URL}">View Build</a></p>
                    """,
                    mimeType: 'text/html'
                )
            }
        }
        
        failure {
            script {
              echo '❌ Pipeline failed!'
                emailext(
                    to: "${NOTIFICATION_EMAIL}",
                    subject: "❌ BUILD FAILED: ${env.JOB_NAME} - Build #${env.BUILD_NUMBER}",
                    body: """
                        <h2>Build Failed!</h2>
                        <p><strong>Job:</strong> ${env.JOB_NAME}</p>
                        <p><strong>Build Number:</strong> ${env.BUILD_NUMBER}</p>
                        <p><strong>Environment:</strong> ${params.ENVIRONMENT}</p>
                        <p><strong>Failed Stage:</strong> ${env.STAGE_NAME}</p>
                        <p><strong>Commit:</strong> ${env.GIT_COMMIT_MSG}</p>
                        <p><strong>Author:</strong> ${env.GIT_AUTHOR}</p>
                        <p><a href="${env.BUILD_URL}console">View Console Output</a></p>
                    """,
                    mimeType: 'text/html'
                )
            }
        }
        
        always {
            // Clean up workspace
            cleanWs()
        }
    }
}
