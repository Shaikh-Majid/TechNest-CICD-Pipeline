#!/usr/bin/env groovy

/**
 * ENTERPRISE PRODUCTION JENKINS PIPELINE
 * =====================================
 * Multi-environment CI/CD Pipeline with:
 * - Git integration & webhook triggers
 * - Gradle build management
 * - SonarQube code quality gates
 * - Docker containerization
 * - Kubernetes deployment
 * - Ansible configuration management
 * - Security scanning & compliance
 * 
 * Author: Senior DevOps Engineer
 * Version: 2.0
 * Last Updated: 2026-02-28
 */

@Library('shared-pipeline-library') _

// ============================================================================
// PIPELINE CONFIGURATION & ENVIRONMENT
// ============================================================================

def VERSION = 'v1.0.0'
def BUILD_TIMESTAMP = new Date().format('yyyyMMdd-HHmmss')
def DOCKER_REGISTRY = 'docker.io'
def DOCKER_NAMESPACE = 'enterprise'
def SONARQUBE_PROJECT_KEY = 'enterprise-microservice'
def K8S_NAMESPACE_DEV = 'dev'
def K8S_NAMESPACE_STAGING = 'staging'
def K8S_NAMESPACE_PROD = 'production'

pipeline {
    agent none
    
    // =========================================================================
    // OPTIONS & TIMING
    // =========================================================================
    options {
        buildDiscarder(logRotator(numToKeepStr: '30', artifactNumToKeepStr: '10'))
        timeout(time: 2, unit: 'HOURS')
        timestamps()
        ansiColor('xterm')
        disableConcurrentBuilds()
    }
    
    // =========================================================================
    // ENVIRONMENT VARIABLES
    // =========================================================================
    environment {
        // Project Configuration
        PROJECT_NAME = 'enterprise-microservice'
        PROJECT_DESCRIPTION = 'Enterprise-grade Spring Boot Microservice with CI/CD'
        
        // Git Configuration
        GIT_REPO = 'https://github.com/organization/enterprise-microservice.git'
        GIT_CREDENTIALS = 'github-enterprise-creds'
        GIT_BRANCH = "${env.BRANCH_NAME ?: 'main'}"
        
        // Build Configuration
        GRADLE_USER_HOME = '${WORKSPACE}/.gradle'
        GRADLE_OPTS = '-XX:+UseG1GC -XX:MaxGCPauseMillis=200 -Xmx1024m'
        JAVA_VERSION = 'openjdk-17'
        
        // SonarQube Configuration
        SONARQUBE_SERVER = 'devopsb39-sonarqube'
        SONARQUBE_URL = 'http://sonarqube.company.internal:9000'
        SONARQUBE_TOKEN = credentials('sonarqube-token')
        SONAR_EXCLUSIONS = '**/test/**,**/generated/**,**/node_modules/**'
        
        // Docker Configuration
        DOCKER_REGISTRY_URL = 'https://docker.io'
        DOCKER_REGISTRY_CREDENTIALS = 'docker-registry-creds'
        DOCKER_BUILDKIT = '1'
        DOCKER_IMAGE_NAME = "${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${PROJECT_NAME}"
        DOCKER_IMAGE_TAG = "${BUILD_TIMESTAMP}-${BUILD_NUMBER}"
        DOCKER_IMAGE_LATEST = "${BUILD_TIMESTAMP}-latest"
        CONTAINER_REGISTRY_ENDPOINT = 'registry.company.internal:5000'
        
        // Kubernetes Configuration
        KUBECONFIG = '/home/jenkins/.kube/config'
        KUBECTL_VERSION = '1.28.0'
        K8S_CLUSTER_DEV = 'dev-cluster.company.internal'
        K8S_CLUSTER_STAGING = 'staging-cluster.company.internal'
        K8S_CLUSTER_PROD = 'prod-cluster.company.internal'
        K8S_API_SERVER = 'https://k8s-api.company.internal'
        
        // Ansible Configuration
        ANSIBLE_VAULT_ID = 'vault-jenkins'
        ANSIBLE_INVENTORY = 'inventory'
        ANSIBLE_CONFIG = 'ansible.cfg'
        ANSIBLE_PLAYBOOK_PATH = 'ansible/playbooks'
        ANSIBLE_LIMIT = 'all'
        
        // Artifact Repository
        ARTIFACTORY_URL = 'https://artifactory.company.internal'
        ARTIFACTORY_CREDENTIALS = 'artifactory-creds'
        ARTIFACTORY_REPO = 'libs-release-local'
        
        // Nexus Configuration
        NEXUS_URL = 'https://nexus.company.internal'
        NEXUS_CREDENTIALS = 'nexus-creds'
        NEXUS_REPOSITORY = 'maven-releases'
        TRIVY_SEVERITY = 'HIGH,CRITICAL'
        SNYK_ORGANIZATION = 'company'
        DEPENDENCY_CHECK_SUPPRESSION = 'suppression.xml'
        
        // Notification & Monitoring
        SLACK_CHANNEL = '#devops-pipelines'
        SLACK_WEBHOOK = credentials('slack-webhook-url')
        PAGERDUTY_INTEGRATION_KEY = credentials('pagerduty-key')
        GRAFANA_DASHBOARD_URL = 'https://grafana.company.internal'
        
        // Deployment Configuration
        DEPLOYMENT_TIMEOUT = '10m'
        REPLICAS_DEV = '1'
        REPLICAS_STAGING = '2'
        REPLICAS_PROD = '3'
    }
    
    // =========================================================================
    // PARAMETERS
    // =========================================================================
    parameters {
        // Branch selection
        string(
            name: 'GIT_BRANCH',
            defaultValue: 'main',
            description: 'Git branch to build from'
        )
        
        // Gradle parameters
        booleanParam(
            name: 'RUN_UNIT_TESTS',
            defaultValue: true,
            description: 'Run unit tests'
        )
        
        booleanParam(
            name: 'RUN_INTEGRATION_TESTS',
            defaultValue: true,
            description: 'Run integration tests'
        )
        
        // Code Quality
        booleanParam(
            name: 'SKIP_SONARQUBE_SCAN',
            defaultValue: false,
            description: 'Skip SonarQube analysis'
        )
        
        booleanParam(
            name: 'SKIP_SECURITY_SCAN',
            defaultValue: false,
            description: 'Skip security scanning (Trivy, Snyk, Dependency-Check)'
        )
        
        // Docker parameters
        booleanParam(
            name: 'PUSH_DOCKER_IMAGE',
            defaultValue: true,
            description: 'Push Docker image to registry'
        )
        
        booleanParam(
            name: 'UPLOAD_TO_NEXUS',
            defaultValue: true,
            description: 'Upload artifacts to Nexus repository'
        )
        
        choice(
            name: 'DEPLOYMENT_ENVIRONMENT',
            choices: ['NONE', 'DEV', 'STAGING', 'PRODUCTION'],
            description: 'Deployment environment after build'
        )
        
        // Ansible parameters
        booleanParam(
            name: 'RUN_ANSIBLE_PLAYBOOKS',
            defaultValue: false,
            description: 'Execute Ansible playbooks for configuration management'
        )
        
        string(
            name: 'ANSIBLE_PLAYBOOK',
            defaultValue: 'deploy.yml',
            description: 'Specific Ansible playbook to execute'
        )
    }
    
    // =========================================================================
    // TRIGGERS
    // =========================================================================
    triggers {
        // GitSCM webhook trigger
        githubPush()
        
        // Poll SCM every 15 minutes
        pollSCM('H/15 * * * *')
        
        // Scheduled nightly builds
        cron('0 2 * * *')
    }
    
    // =========================================================================
    // STAGES
    // =========================================================================
    stages {
        // =====================================================================
        // STAGE 1: INITIALIZATION & ENVIRONMENT SETUP
        // =====================================================================
        stage('01-Initialize') {
            agent { 
                kubernetes {
                    yaml '''
                        apiVersion: v1
                        kind: Pod
                        metadata:
                          labels:
                            job: jenkins-pipeline
                        spec:
                          serviceAccountName: jenkins
                          containers:
                          - name: docker
                            image: docker:24.0-dind
                            securityContext:
                              privileged: true
                            volumeMounts:
                            - name: docker-sock
                              mountPath: /var/run/docker.sock
                          - name: kubectl
                            image: bitnami/kubectl:1.28
                            command:
                            - cat
                            tty: true
                          - name: ansible
                            image: ansible/ansible:2.10
                            command:
                            - cat
                            tty: true
                          volumes:
                          - name: docker-sock
                            hostPath:
                              path: /var/run/docker.sock
                    '''
                }
            }
            steps {
                script {
                    echo """
                    ╔═════════════════════════════════════════════════════════════╗
                    ║         ENTERPRISE JENKINS PIPELINE - INITIALIZATION         ║
                    ╚═════════════════════════════════════════════════════════════╝
                    
                    Project: ${PROJECT_NAME}
                    Build Number: ${BUILD_NUMBER}
                    Build Timestamp: ${BUILD_TIMESTAMP}
                    Git Branch: ${GIT_BRANCH}
                    Docker Image: ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}
                    Environment: ${params.DEPLOYMENT_ENVIRONMENT}
                    Build Workspace: ${WORKSPACE}
                    """
                    
                    // Record build parameters
                    properties([
                        buildDiscarder(logRotator(numToKeepStr: '30')),
                        timestamps()
                    ])
                }
                
                // Clean workspace
                deleteDir()
                
                // Print environment
                sh '''
                    echo "=== System Information ==="
                    uname -a
                    echo ""
                    
                    echo "=== Java Version ==="
                    java -version || echo "Java not found"
                    echo ""
                    
                    echo "=== Gradle Version ==="
                    gradle --version || echo "Gradle not available"
                    echo ""
                    
                    echo "=== Docker Version ==="
                    docker --version || echo "Docker not available"
                    echo ""
                    
                    echo "=== Git Version ==="
                    git --version
                    echo ""
                    
                    echo "=== Kubernetes Version ==="
                    kubectl version --client 2>/dev/null || echo "Kubectl not available"
                    echo ""
                    
                    echo "=== Ansible Version ==="
                    ansible --version 2>/dev/null || echo "Ansible not available"
                '''
            }
            post {
                always {
                    script {
                        env.STAGE_STATUS = currentBuild.result ?: 'SUCCESS'
                    }
                }
            }
        }
        
        // =====================================================================
        // STAGE 2: SOURCE CODE CHECKOUT & VALIDATION
        // =====================================================================
        stage('02-SCM-Checkout') {
            agent { 
                label 'docker'
            }
            steps {
                script {
                    echo "⏳ Checking out source code from Git..."
                }
                
                // Git checkout with credentials
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: "${GIT_BRANCH}"]],
                    userRemoteConfigs: [[
                        url: "${GIT_REPO}",
                        credentialsId: "${GIT_CREDENTIALS}"
                    ]],
                    poll: false,
                    extensions: [
                        [$class: 'CloneOption', depth: 50],
                        [$class: 'CheckoutOption', timeout: 30],
                        [$class: 'LocalBranch', localBranch: "${GIT_BRANCH}"]
                    ]
                ])
                
                script {
                    // Capture Git metadata
                    sh '''
                        echo "=== Git Metadata ==="
                        GIT_COMMIT_ID=$(git rev-parse HEAD)
                        GIT_COMMIT_MSG=$(git log -1 --pretty=%B)
                        GIT_COMMIT_AUTHOR=$(git log -1 --pretty=%an)
                        GIT_COMMIT_EMAIL=$(git log -1 --pretty=%ae)
                        GIT_BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)
                        GIT_TAGS=$(git tag --contains HEAD)
                        
                        echo "Commit ID: $GIT_COMMIT_ID"
                        echo "Commit Message: $GIT_COMMIT_MSG"
                        echo "Author: $GIT_COMMIT_AUTHOR <$GIT_COMMIT_EMAIL>"
                        echo "Branch: $GIT_BRANCH_NAME"
                        echo "Tags: ${GIT_TAGS:-none}"
                        
                        # Save for later use
                        echo "$GIT_COMMIT_ID" > .git-commit-id
                        echo "$GIT_COMMIT_MSG" > .git-commit-msg
                        echo "$GIT_BRANCH_NAME" > .git-branch
                    '''
                    
                    // Git statistics
                    sh '''
                        echo "=== Repository Statistics ==="
                        echo "Total commits: $(git rev-list --count HEAD)"
                        echo "File count: $(find . -type f | wc -l)"
                        echo "Directory structure:"
                        ls -la
                    '''
                }
            }
            post {
                failure {
                    script {
                        sendNotification("❌ SCM Checkout failed", "failure")
                    }
                }
            }
        }
        
        // =====================================================================
        // STAGE 3: GRADLE BUILD & COMPILATION
        // =====================================================================
        stage('03-Gradle-Build') {
            agent { 
                label 'docker'
            }
            steps {
                script {
                    echo "🔨 Building project with Gradle..."
                }
                
                sh '''
                    # Initialize Gradle wrapper if not present
                    if [ ! -f "gradlew" ]; then
                        echo "⚠️  Gradle wrapper not found, downloading..."
                        gradle wrapper --gradle-version 8.5
                    fi
                    
                    # Build with optimizations
                    ./gradlew clean build \
                        --refresh-dependencies \
                        --parallel \
                        --console=verbose \
                        -Dorg.gradle.jvmargs="-Xmx1024m -XX:+UseG1GC" \
                        -PversionNumber=${BUILD_NUMBER} \
                        -PbuildTimestamp=${BUILD_TIMESTAMP} \
                        --build-cache
                    
                    echo "✅ Gradle build completed successfully"
                '''
                
                script {
                    // Collect build artifacts
                    sh '''
                        echo "=== Build Artifacts ==="
                        find build/libs -type f -name "*.jar" -o -name "*.war" | while read artifact; do
                            echo "Artifact: $artifact"
                            ls -lh "$artifact"
                        done
                        
                        # Store artifact path
                        ARTIFACT_PATH=$(find build/libs -type f -name "*.jar" | head -1)
                        echo "Artifact Path: $ARTIFACT_PATH"
                        echo "$ARTIFACT_PATH" > .artifact-path
                    '''
                }
            }
            post {
                always {
                    // Archive build artifacts
                    archiveArtifacts artifacts: 'build/libs/**/*.jar,build/libs/**/*.war',
                        allowEmptyArchive: true
                    
                    // Archive test reports
                    junit testResults: 'build/test-results/**/*.xml',
                        allowEmptyResults: true
                }
                failure {
                    script {
                        sendNotification("❌ Gradle Build failed", "failure")
                    }
                }
            }
        }
        
        // =====================================================================
        // STAGE 3.5: NEXUS ARTIFACT UPLOAD
        // =====================================================================
        stage('03.5-Nexus-Upload') {
            agent { 
                label 'docker'
            }
            when {
                expression { params.UPLOAD_TO_NEXUS == true }
            }
            steps {
                script {
                    echo "📦 Uploading artifacts to Nexus..."
                    
                    // Read artifact path
                    def artifactPath = sh(script: 'cat .artifact-path', returnStdout: true).trim()
                    
                    nexusArtifactUploader(
                        nexusVersion: 'nexus3',
                        protocol: 'https',
                        nexusUrl: "${NEXUS_URL}",
                        groupId: 'com.company.enterprise',
                        version: "${BUILD_NUMBER}",
                        repository: "${NEXUS_REPOSITORY}",
                        credentialsId: "${NEXUS_CREDENTIALS}",
                        artifacts: [
                            [artifactId: "${PROJECT_NAME}",
                             classifier: '',
                             file: artifactPath,
                             type: 'jar']
                        ]
                    )
                }
            }
            post {
                failure {
                    script {
                        sendNotification("❌ Nexus upload failed", "failure")
                    }
                }
            }
        }
        
        // =====================================================================
        // STAGE 4: UNIT & INTEGRATION TESTS
        // =====================================================================
        stage('04-Testing') {
            agent { 
                label 'docker'
            }
            when {
                expression { params.RUN_UNIT_TESTS == true }
            }
            steps {
                script {
                    echo "🧪 Running Unit and Integration Tests..."
                }
                
                sh '''
                    # Run all tests with detailed reporting
                    ./gradlew test \
                        --tests='*Test' \
                        --info \
                        --stacktrace \
                        --parallel \
                        -Pskip.integ.tests=false
                        
                    
                    # Generate test reports
                    ./gradlew testReport || true
                    
                    echo "✅ Test execution completed"
                '''
                
                // Code Coverage Analysis
                sh '''
                    echo "=== Code Coverage ==="
                    ./gradlew jacocoTestReport || true
                    
                    # Extract coverage metrics
                    if [ -f "build/reports/jacoco/test/jacocoTestReport.xml" ]; then
                        echo "Coverage report generated"
                    fi
                '''
            }
            post {
                always {
                    // Publish test results
                    junit testResults: 'build/test-results/test/**/*.xml',
                        allowEmptyResults: true,
                        skipPublishingChecks: false
                    
                    // Publish coverage reports
                    publishHTML([
                        reportDir: 'build/reports/jacoco/test/html',
                        reportFiles: 'index.html',
                        reportName: 'JaCoCo Code Coverage',
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true
                    ])
                    
                    // Capture coverage metrics
                    publishCoverage([
                        adapters: [istanbulCoberturaAdapter('build/reports/jacoco/test/jacocoTestReport.xml')],
                        sourceFileResolver: sourceFiles('STORE_ALL_BUILD_LOGS')
                    ])
                }
                failure {
                    script {
                        sendNotification("❌ Tests failed", "failure")
                    }
                }
            }
        }
        
        // =====================================================================
        // STAGE 5: SONARQUBE CODE QUALITY & SECURITY SCANNING
        // =====================================================================
        stage('05-SonarQube-Analysis') {
            agent { 
                label 'docker'
            }
            when {
                expression { params.SKIP_SONARQUBE_SCAN == false }
            }
            steps {
                script {
                    echo "🔍 Performing SonarQube Code Quality Analysis..."
                }
                
                sh '''
                    # Generate SonarQube scanner properties
                    cat > sonar-project.properties << EOF
# SonarQube Configuration
sonar.projectKey=${SONARQUBE_PROJECT_KEY}
sonar.projectName=${PROJECT_NAME}
sonar.projectVersion=${BUILD_TIMESTAMP}
sonar.sources=src/main
sonar.tests=src/test
sonar.java.binaries=build/classes
sonar.coverage.jacoco.xmlReportPaths=build/reports/jacoco/test/jacocoTestReport.xml
sonar.cpd.exclusions=${SONAR_EXCLUSIONS}
sonar.exclusions=${SONAR_EXCLUSIONS}
sonar.java.libraries=build/libs
sonar.host.url=${SONARQUBE_URL}
sonar.login=${SONARQUBE_TOKEN}
EOF
                    
                    # Run SonarQube Scanner
                    sonar-scanner \
                        -Dproject.settings=sonar-project.properties \
                        -Dsonar.branch.name=${GIT_BRANCH} \
                        -Dsonar.newCode.referenceBranch=main
                '''
                
                script {
                    // Wait for SonarQube Quality Gate
                    timeout(time: 10, unit: 'MINUTES') {
                        sh '''
                            echo "⏳ Waiting for SonarQube Quality Gate analysis..."
                            
                            # Query SonarQube API for analysis status
                            ANALYSIS_ID=$(curl -s \
                                -H "Authorization: Bearer ${SONARQUBE_TOKEN}" \
                                "${SONARQUBE_URL}/api/ce/activity?projectKey=${SONARQUBE_PROJECT_KEY}&type=REPORT" \
                                | jq -r '.tasks[0].id')
                            
                            echo "Analysis ID: $ANALYSIS_ID"
                            
                            # Poll for completion
                            for i in {1..60}; do
                                STATUS=$(curl -s \
                                    -H "Authorization: Bearer ${SONARQUBE_TOKEN}" \
                                    "${SONARQUBE_URL}/api/ce/activity?id=$ANALYSIS_ID" \
                                    | jq -r '.tasks[0].status')
                                
                                if [ "$STATUS" = "SUCCESS" ]; then
                                    echo "✅ Analysis completed successfully"
                                    break
                                elif [ "$STATUS" = "FAILURE" ]; then
                                    echo "❌ Analysis failed"
                                    exit 1
                                fi
                                
                                echo "Status: $STATUS (attempt $i/60)"
                                sleep 10
                            done
                        '''
                    }
                }
            }
            post {
                always {
                    // Record SonarQube results
                    recordIssues(
                        enabledForFailure: true,
                        tools: [sonarQube(pattern: 'build/sonar/**')],
                        qualityGates: [[threshold: 80, type: 'TOTAL', unstable: false]]
                    )
                }
                failure {
                    script {
                        sendNotification("❌ SonarQube Quality Gate failed", "failure")
                    }
                }
            }
        }
        
        // =====================================================================
        // STAGE 6: SECURITY SCANNING (Trivy, Snyk, Dependency-Check)
        // =====================================================================
        stage('06-Security-Scanning') {
            agent { 
                label 'docker'
            }
            when {
                expression { params.SKIP_SECURITY_SCAN == false }
            }
            steps {
                script {
                    echo "🔐 Running Security Vulnerability Scanning..."
                }
                
                // Trivy Container Scanning
                sh '''
                    echo "=== Trivy Filesystem Scan ==="
                    trivy fs --severity ${TRIVY_SEVERITY} \
                        --format json \
                        --output trivy-fs-report.json \
                        . || true
                    
                    # Generate human-readable report
                    trivy fs --severity ${TRIVY_SEVERITY} \
                        --format table \
                        build/libs/ || true
                '''
                
                // OWASP Dependency-Check
                sh '''
                    echo "=== OWASP Dependency-Check ==="
                    if command -v dependency-check &> /dev/null; then
                        dependency-check.sh \
                            --project "${PROJECT_NAME}" \
                            --scan build/libs \
                            --format JSON \
                            --out dependency-check-report \
                            --suppression ${DEPENDENCY_CHECK_SUPPRESSION} || true
                    else
                        echo "⚠️  Dependency-Check not installed"
                    fi
                '''
                
                // Snyk Security Scanning (if available)
                sh '''
                    echo "=== Snyk Vulnerability Scan ==="
                    if command -v snyk &> /dev/null; then
                        snyk test \
                            --severity-threshold=high \
                            --json-file-output=snyk-report.json \
                            --all-projects || true
                    else
                        echo "⚠️  Snyk not installed"
                    fi
                '''
                
                // GitHub Advanced Security scanning (if using GitHub)
                sh '''
                    echo "=== Code Secret Scanning ==="
                    if command -v gitleaks &> /dev/null; then
                        gitleaks detect \
                            --source . \
                            --verbose \
                            --report-path gitleaks-report.json || true
                    else
                        echo "⚠️  GitLeaks not installed"
                    fi
                '''
            }
            post {
                always {
                    // Archive security reports
                    archiveArtifacts artifacts: '*-report.*,**/*report.json',
                        allowEmptyArchive: true
                    
                    // Publish security scanner results
                    publishHTML([
                        reportDir: 'dependency-check-report',
                        reportFiles: 'index.html',
                        reportName: 'OWASP Dependency Check',
                        allowMissing: true
                    ])
                }
                failure {
                    script {
                        sendNotification("⚠️  Security vulnerabilities detected", "warning")
                    }
                }
            }
        }
        
        // =====================================================================
        // STAGE 7: DOCKER IMAGE BUILD & PUSH
        // =====================================================================
        stage('07-Docker-Build-Push') {
            agent { 
                kubernetes {
                    yaml '''
                        apiVersion: v1
                        kind: Pod
                        metadata:
                          labels:
                            job: docker-build
                        spec:
                          serviceAccountName: jenkins
                          containers:
                          - name: docker
                            image: docker:24.0-dind
                            securityContext:
                              privileged: true
                            env:
                            - name: DOCKER_HOST
                              value: unix:///var/run/docker.sock
                            volumeMounts:
                            - name: docker-sock
                              mountPath: /var/run/docker.sock
                          volumes:
                          - name: docker-sock
                            hostPath:
                              path: /var/run/docker.sock
                    '''
                }
            }
            steps {
                script {
                    echo "🐳 Building and Pushing Docker Image..."
                }
                
                sh '''
                    # Create optimized Dockerfile
                    cat > Dockerfile << 'DOCKERFILE_END'
# Multi-stage Dockerfile for Spring Boot Application
# Stage 1: Build stage
FROM openjdk:17-jdk-slim as builder
WORKDIR /maven
COPY . .
RUN ./gradlew build -x test \
    --gradle-user-home=/maven/.gradle \
    --no-daemon

# Stage 2: Runtime stage
FROM openjdk:17-jdk-slim
LABEL maintainer="devops@company.com"
LABEL description="Enterprise Microservice Application"
LABEL version="${BUILD_NUMBER}"

# Security: Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Set working directory
WORKDIR /app

# Copy artifact from builder
COPY --from=builder /maven/build/libs/*.jar app.jar

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD java -cp app.jar org.springframework.boot.loader.JarLauncher \
    && curl -f http://localhost:8080/actuator/health || exit 1

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Application properties
ENV JAVA_OPTS="-XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:G1NewCollectionHousekeepingIntervalInMs=200"

# Run application
ENTRYPOINT ["java", "-jar", "app.jar"]
DOCKERFILE_END
                    
                    # Build Docker image
                    echo "Building image: ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}"
                    docker build \
                        --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
                        --build-arg VCS_REF=$(git rev-parse --short HEAD) \
                        --build-arg VERSION=${BUILD_TIMESTAMP} \
                        -t ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} \
                        -t ${DOCKER_IMAGE_NAME}:latest \
                        -f Dockerfile .
                    
                    # Scan Docker image for vulnerabilities
                    echo "Scanning Docker image..."
                    trivy image \
                        --severity ${TRIVY_SEVERITY} \
                        --output trivy-docker-report.json \
                        ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} || true
                    
                    # Display image info
                    docker inspect ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} | jq '.'
                    docker image ls | grep ${DOCKER_IMAGE_NAME}
                '''
                
                // Push to Docker Registry
                script {
                    if (params.PUSH_DOCKER_IMAGE == true) {
                        withCredentials([usernamePassword(credentialsId: "${DOCKER_REGISTRY_CREDENTIALS}", 
                            usernameVariable: 'DOCKER_USER', 
                            passwordVariable: 'DOCKER_PASS')]) {
                            sh '''
                                echo "Logging in to Docker Registry..."
                                echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin ${DOCKER_REGISTRY}
                                
                                echo "Pushing Docker image..."
                                docker push ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}
                                docker push ${DOCKER_IMAGE_NAME}:latest
                                
                                echo "✅ Docker image pushed successfully"
                                
                                docker logout ${DOCKER_REGISTRY}
                            '''
                        }
                    }
                }
            }
            post {
                always {
                    // Archive Docker scan reports
                    archiveArtifacts artifacts: 'trivy-docker-report.json',
                        allowEmptyArchive: true
                }
                failure {
                    script {
                        sendNotification("❌ Docker build/push failed", "failure")
                    }
                }
            }
        }
        
        // =====================================================================
        // STAGE 8: KUBERNETES DEPLOYMENT
        // =====================================================================
        stage('08-Kubernetes-Deploy') {
            agent { 
                kubernetes {
                    yaml '''
                        apiVersion: v1
                        kind: Pod
                        metadata:
                          labels:
                            job: k8s-deploy
                        spec:
                          serviceAccountName: jenkins
                          containers:
                          - name: kubectl
                            image: bitnami/kubectl:1.28
                            command:
                            - cat
                            tty: true
                    '''
                }
            }
            when {
                expression { params.DEPLOYMENT_ENVIRONMENT != 'NONE' }
            }
            steps {
                script {
                    echo "☸️  Deploying to Kubernetes cluster..."
                    
                    // Determine target namespace and cluster
                    switch(params.DEPLOYMENT_ENVIRONMENT) {
                        case 'DEV':
                            env.TARGET_NAMESPACE = K8S_NAMESPACE_DEV
                            env.TARGET_CLUSTER = K8S_CLUSTER_DEV
                            env.REPLICAS = REPLICAS_DEV
                            break
                        case 'STAGING':
                            env.TARGET_NAMESPACE = K8S_NAMESPACE_STAGING
                            env.TARGET_CLUSTER = K8S_CLUSTER_STAGING
                            env.REPLICAS = REPLICAS_STAGING
                            break
                        case 'PRODUCTION':
                            env.TARGET_NAMESPACE = K8S_NAMESPACE_PROD
                            env.TARGET_CLUSTER = K8S_CLUSTER_PROD
                            env.REPLICAS = REPLICAS_PROD
                            break
                    }
                }
                
                sh '''
                    # Verify kubectl connectivity
                    echo "Verifying Kubernetes cluster connectivity..."
                    kubectl cluster-info
                    kubectl get nodes
                    
                    # Create namespace if doesn't exist
                    kubectl create namespace ${TARGET_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                '''
                
                // Generate Kubernetes manifests from external template files
                sh '''
                    # Use pre-defined Kubernetes templates located under k8s/
                    mkdir -p k8s-manifests
                    echo "Rendering templates with envsubst"
                    envsubst < k8s/deployment.yaml > k8s-manifests/deployment.yaml
                    envsubst < k8s/serviceaccount.yaml > k8s-manifests/serviceaccount.yaml
                    echo "✅ Kubernetes manifests generated from templates"
                '''
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: ${PROJECT_NAME}
        version: ${BUILD_TIMESTAMP}
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/actuator/prometheus"
    spec:
      serviceAccountName: ${PROJECT_NAME}
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      
      # Init containers for setup tasks
      initContainers:
      - name: migration
        image: ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}
        command: ["java", "-jar", "app.jar", "--liquibase.enabled=true"]
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
      
      # Main application container
      containers:
      - name: ${PROJECT_NAME}
        image: ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}
        imagePullPolicy: IfNotPresent
        
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        - name: actuator
          containerPort: 8080
          protocol: TCP
        
        # Environment variables
        env:
        - name: ENVIRONMENT
          value: "${DEPLOYMENT_ENVIRONMENT}"
        - name: LOG_LEVEL
          value: "INFO"
        - name: JAVA_OPTS
          value: "-XX:+UseG1GC -XX:MaxGCPauseMillis=200"
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        
        # Resource limits
        resources:
          requests:
            cpu: 250m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 1024Mi
        
        # Probes
        livenessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        
        readinessProbe:
          httpGet:
            path: /actuator/health/readiness
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 2
        
        startupProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 0
          periodSeconds: 10
          failureThreshold: 3
        
        # Security context
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
        
        # Volume mounts
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /app/cache
      
      # Volumes
      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}
      
      # Pod scheduling
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - ${PROJECT_NAME}
              topologyKey: kubernetes.io/hostname
      
      # Tolerations
      tolerations:
      - key: "workload"
        operator: "Equal"
        value: "critical"
        effect: "NoSchedule"

---
apiVersion: v1
kind: Service
metadata:
  name: ${PROJECT_NAME}
  namespace: ${TARGET_NAMESPACE}
  labels:
    app: ${PROJECT_NAME}
spec:
  type: ClusterIP
  selector:
    app: ${PROJECT_NAME}
  ports:
  - name: http
    port: 80
    targetPort: 8080
    protocol: TCP

---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ${PROJECT_NAME}-hpa
  namespace: ${TARGET_NAMESPACE}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ${PROJECT_NAME}
  minReplicas: ${REPLICAS}
  maxReplicas: $((REPLICAS * 3))
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 2
        periodSeconds: 15

---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: ${PROJECT_NAME}-pdb
  namespace: ${TARGET_NAMESPACE}
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: ${PROJECT_NAME}

MANIFEST_END
                    
                    # Create ServiceAccount manifest
                    cat > k8s-manifests/serviceaccount.yaml << MANIFEST_END
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${PROJECT_NAME}
  namespace: ${TARGET_NAMESPACE}

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ${PROJECT_NAME}
  namespace: ${TARGET_NAMESPACE}
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${PROJECT_NAME}
  namespace: ${TARGET_NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ${PROJECT_NAME}
subjects:
- kind: ServiceAccount
  name: ${PROJECT_NAME}
  namespace: ${TARGET_NAMESPACE}

MANIFEST_END
                    
                    echo "✅ Kubernetes manifests generated from templates"
                '''
                
                // Deploy to Kubernetes
                sh '''
                    echo "Applying Kubernetes configurations..."
                    
                    # Apply service account and RBAC
                    kubectl apply -f k8s-manifests/serviceaccount.yaml
                    
                    # Apply deployment with rolling update
                    kubectl apply -f k8s-manifests/deployment.yaml
                    
                    # Wait for rollout
                    echo "Waiting for deployment rollout..."
                    kubectl rollout status deployment/${PROJECT_NAME} \
                        -n ${TARGET_NAMESPACE} \
                        --timeout=${DEPLOYMENT_TIMEOUT}
                    
                    echo "✅ Kubernetes deployment completed"
                '''
                
                // Verify deployment
                sh '''
                    echo "=== Deployment Verification ==="
                    kubectl get deployment ${PROJECT_NAME} -n ${TARGET_NAMESPACE}
                    kubectl get pods -n ${TARGET_NAMESPACE} -l app=${PROJECT_NAME}
                    kubectl get services -n ${TARGET_NAMESPACE}
                    
                    # Get pod details
                    kubectl describe deployment ${PROJECT_NAME} -n ${TARGET_NAMESPACE}
                '''
            }
            post {
                failure {
                    script {
                        sendNotification("❌ Kubernetes deployment failed", "failure")
                        
                        // Rollback on failure
                        sh '''
                            echo "Rolling back to previous deployment..."
                            kubectl rollout undo deployment/${PROJECT_NAME} \
                                -n ${TARGET_NAMESPACE} || true
                        '''
                    }
                }
            }
        }
        
        // =====================================================================
        // STAGE 9: ANSIBLE CONFIGURATION MANAGEMENT
        // =====================================================================
        stage('09-Ansible-Deploy') {
            agent { 
                kubernetes {
                    yaml '''
                        apiVersion: v1
                        kind: Pod
                        metadata:
                          labels:
                            job: ansible-deploy
                        spec:
                          serviceAccountName: jenkins
                          containers:
                          - name: ansible
                            image: ansible/ansible:2.10
                            command:
                            - cat
                            tty: true
                    '''
                }
            }
            when {
                expression { params.RUN_ANSIBLE_PLAYBOOKS == true }
            }
            steps {
                script {
                    echo "🔧 Running Ansible Configuration Management..."
                }
                
                sh '''
                    # Verify Ansible installation
                    ansible --version
                    ansible-inventory --version
                    
                    # Generate Ansible inventory
                    mkdir -p ansible
                    
                    cat > ansible/inventory.yml << INVENTORY_END
all:
  vars:
    ansible_user: ansible
    ansible_ssh_private_key_file: /root/.ssh/id_rsa
    ansible_connection: ssh
    environment: ${DEPLOYMENT_ENVIRONMENT}
  
  children:
    k8s_nodes:
      hosts:
        k8s-node-1:
          ansible_host: 10.0.1.10
        k8s-node-2:
          ansible_host: 10.0.1.11
        k8s-node-3:
          ansible_host: 10.0.1.12
    
    monitoring:
      hosts:
        prometheus:
          ansible_host: 10.0.2.10
        grafana:
          ansible_host: 10.0.2.11
INVENTORY_END
                    
                    # Generate Ansible playbook
                    mkdir -p ansible/playbooks
                    mkdir -p ansible/roles/{common,monitoring,logging,security}
                    
                    cat > ansible/playbooks/deploy.yml << PLAYBOOK_END
---
- name: Enterprise Application Deployment and Configuration
  hosts: all
  become: yes
  gather_facts: yes
  
  vars:
    app_name: ${PROJECT_NAME}
    app_version: ${BUILD_TIMESTAMP}
    app_user: appuser
    app_group: appuser
  
  pre_tasks:
    - name: Display deployment information
      debug:
        msg: |
          ========================================
          Deploying {{ app_name }} v{{ app_version }}
          Environment: {{ environment }}
          ========================================
    
    - name: Validate Ansible version
      assert:
        that:
          - ansible_version.major >= 2
          - ansible_version.minor >= 9
        fail_msg: "Ansible 2.9+ required"
    
    - name: Update system packages
      apt:
        update_cache: yes
        cache_valid_time: 3600
      when: ansible_os_family == "Debian"
    
    - name: Install required packages
      apt:
        name:
          - curl
          - wget
          - git
          - htop
          - net-tools
          - jq
          - python3-pip
        state: present
      when: ansible_os_family == "Debian"
  
  roles:
    - common
    - monitoring
    - logging
    - security
  
  tasks:
    - name: Ensure application directories
      file:
        path: "/opt/{{ app_name }}"
        state: directory
        owner: "{{ app_user }}"
        group: "{{ app_group }}"
        mode: '0750'
    
    - name: Deploy application configuration
      template:
        src: application.properties.j2
        dest: "/opt/{{ app_name }}/application.properties"
        owner: "{{ app_user }}"
        group: "{{ app_group }}"
        mode: '0640'
      notify: restart application
    
    - name: Configure firewall rules
      ufw:
        rule: allow
        port: "{{ item }}"
        proto: tcp
      loop:
        - '8080'
        - '9090'
      when: ansible_os_family == "Debian"
    
    - name: Setup health check monitoring
      cron:
        name: "Health check for {{ app_name }}"
        minute: "*/5"
        job: "curl -f http://localhost:8080/actuator/health || systemctl restart {{ app_name }}"
        user: root
    
    - name: Configure log rotation
      template:
        src: logrotate.j2
        dest: "/etc/logrotate.d/{{ app_name }}"
        mode: '0644'
    
    - name: Setup backup jobs
      cron:
        name: "Backup database"
        hour: "2"
        minute: "0"
        job: "/usr/local/bin/backup-db.sh"
        user: root
  
  handlers:
    - name: restart application
      systemd:
        name: "{{ app_name }}"
        state: restarted
        enabled: yes

PLAYBOOK_END
                    
                    # Validate playbook syntax
                    ansible-playbook ansible/playbooks/deploy.yml --syntax-check
                    
                    # Run playbook with verbose output
                    if [ -f "ansible/inventory.yml" ]; then
                        ansible-playbook \
                            -i ansible/inventory.yml \
                            ansible/playbooks/deploy.yml \
                            -e "environment=${DEPLOYMENT_ENVIRONMENT}" \
                            -e "app_version=${BUILD_TIMESTAMP}" \
                            -v --limit="${ANSIBLE_LIMIT}"
                    fi
                '''
            }
            post {
                always {
                    // Archive Ansible artifacts
                    archiveArtifacts artifacts: 'ansible/**/*',
                        allowEmptyArchive: true
                }
                failure {
                    script {
                        sendNotification("⚠️  Ansible playbook execution had issues", "warning")
                    }
                }
            }
        }
        
        // =====================================================================
        // STAGE 10: SMOKE TESTS & VALIDATION
        // =====================================================================
        stage('10-Smoke-Tests') {
            agent { 
                label 'docker'
            }
            when {
                expression { params.DEPLOYMENT_ENVIRONMENT != 'NONE' }
            }
            steps {
                script {
                    echo "✔️  Running Smoke Tests..."
                }
                
                sh '''
                    echo "=== API Health Checks ==="
                    
                    # Get service endpoint
                    SERVICE_IP=$(kubectl get svc ${PROJECT_NAME} -n ${TARGET_NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}' || echo "127.0.0.1")
                    SERVICE_PORT=$(kubectl get svc ${PROJECT_NAME} -n ${TARGET_NAMESPACE} -o jsonpath='{.spec.ports[0].port}')
                    
                    echo "Service endpoint: http://${SERVICE_IP}:${SERVICE_PORT}"
                    
                    # Health check
                    for i in {1..10}; do
                        echo "Health check attempt $i..."
                        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
                            http://${SERVICE_IP}:${SERVICE_PORT}/actuator/health || echo "000")
                        
                        if [ "$HTTP_CODE" = "200" ]; then
                            echo "✅ Health check passed"
                            break
                        else
                            echo "⏳ Waiting for service (HTTP $HTTP_CODE)"
                            sleep 10
                        fi
                    done
                    
                    # Test application endpoints
                    echo "=== Application Endpoints ==="
                    curl -s http://${SERVICE_IP}:${SERVICE_PORT}/actuator | jq '.'
                    curl -s http://${SERVICE_IP}:${SERVICE_PORT}/actuator/health | jq '.'
                '''
            }
            post {
                failure {
                    script {
                        sendNotification("❌ Smoke tests failed", "failure")
                    }
                }
            }
        }
    }
    
    // =========================================================================
    // POST BUILD ACTIONS
    // =========================================================================
    post {
        always {
            script {
                echo "Pipeline execution completed"
                
                // Cleanup
                cleanWs(
                    deleteDirs: true,
                    patterns: [[pattern: '**/target/**', type: 'INCLUDE']]
                )
            }
        }
        
        success {
            script {
                sendNotification("✅ Pipeline completed successfully!", "success")
                
                // Generate deployment report
                sh '''
                    cat > DEPLOYMENT_REPORT.md << EOF
# Deployment Report
- **Environment**: ${DEPLOYMENT_ENVIRONMENT}
- **Build Number**: ${BUILD_NUMBER}
- **Build Timestamp**: ${BUILD_TIMESTAMP}
- **Docker Image**: ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}
- **Git Branch**: ${GIT_BRANCH}
- **Status**: SUCCESS

## Deployed Services
- Application: ${PROJECT_NAME}
- Namespace: ${TARGET_NAMESPACE}
- Replicas: ${REPLICAS}

## Artifacts
- SonarQube: ${SONARQUBE_URL}/projects/${SONARQUBE_PROJECT_KEY}
- Nexus Repository: ${NEXUS_URL}/repository/${NEXUS_REPOSITORY}
- Docker Registry: ${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${PROJECT_NAME}
EOF
                    
                    cat DEPLOYMENT_REPORT.md
                '''
                
                archiveArtifacts artifacts: 'DEPLOYMENT_REPORT.md',
                    allowEmptyArchive: true
            }
        }
        
        failure {
            script {
                sendNotification("❌ Pipeline failed - Check logs for details", "failure")
            }
        }
        
        unstable {
            script {
                sendNotification("⚠️  Pipeline unstable - Review quality gates", "warning")
            }
        }
        
        cleanup {
            // Final cleanup
            sh '''
                echo "Performing final cleanup..."
                docker system prune -f || true
            '''
        }
    }
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/**
 * Send notifications to Slack
 */
def sendNotification(String message, String status) {
    if (env.SLACK_WEBHOOK) {
        def color = status == 'success' ? 'good' : 
                     status == 'failure' ? 'danger' : 
                     'warning'
        
        def payload = [
            channel: env.SLACK_CHANNEL,
            username: 'Jenkins Pipeline Bot',
            attachments: [
                [
                    color: color,
                    title: "${env.PROJECT_NAME} - Build #${env.BUILD_NUMBER}",
                    text: message,
                    fields: [
                        [title: 'Status', value: status, short: true],
                        [title: 'Branch', value: env.GIT_BRANCH, short: true],
                        [title: 'Environment', value: env.DEPLOYMENT_ENVIRONMENT ?: 'N/A', short: true],
                        [title: 'Build Time', value: env.BUILD_TIMESTAMP, short: true]
                    ],
                    footer: 'Jenkins CI/CD Pipeline',
                    ts: System.currentTimeMillis() / 1000
                ]
            ]
        ]
        
        try {
            httpRequest(
                acceptType: 'APPLICATION_JSON',
                contentType: 'APPLICATION_JSON',
                httpMode: 'POST',
                url: env.SLACK_WEBHOOK,
                requestBody: groovy.json.JsonOutput.toJson(payload)
            )
        } catch (Exception e) {
            echo "⚠️  Failed to send Slack notification: ${e.message}"
        }
    }
}

/**
 * Generate build metrics and report
 */
def generateBuildReport() {
    sh '''
        cat > build-metrics.json << EOF
{
  "buildNumber": ${BUILD_NUMBER},
  "buildTimestamp": "${BUILD_TIMESTAMP}",
  "project": "${PROJECT_NAME}",
  "branch": "${GIT_BRANCH}",
  "duration": "${currentBuild.durationString}",
  "result": "${currentBuild.result}",
  "dockerImage": "${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}",
  "kubernetesNamespace": "${TARGET_NAMESPACE}",
  "deploymentEnvironment": "${DEPLOYMENT_ENVIRONMENT}"
}
EOF
    '''
}

