#!/usr/bin/env groovy

pipeline {
    agent none

    options {
        buildDiscarder(logRotator(numToKeepStr: '30', artifactNumToKeepStr: '10'))
        timeout(time: 2, unit: 'HOURS')
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        PROJECT_NAME       = 'enterprise-microservice'
        GIT_REPO           = 'https://github.com/Shaikh-Majid/TechNest-CICD-Pipeline.git'
        GIT_CREDENTIALS    = 'Github-Jenkins'
        GIT_BRANCH         = "${env.BRANCH_NAME ?: 'master'}"

        SONARQUBE_SERVER   = 'devopsb39-sonarqube'

        DOCKER_REGISTRY    = 'docker.io'
        DOCKER_IMAGE       = "docker.io/enterprise/${PROJECT_NAME}"
        DOCKER_IMAGE_TAG   = "${BUILD_NUMBER}"
        DOCKER_CREDENTIALS = 'docker-registry-creds'

        NEXUS_URL          = 'https://nexus.company.internal'
        NEXUS_CREDENTIALS  = 'nexus-creds'
        NEXUS_REPOSITORY   = 'maven-releases'

        K8S_NAMESPACE_DEV      = 'dev'
        K8S_NAMESPACE_STAGING  = 'staging'
        K8S_NAMESPACE_PROD     = 'production'
        REPLICAS_DEV       = '1'
        REPLICAS_STAGING   = '2'
        REPLICAS_PROD      = '3'
        DEPLOYMENT_TIMEOUT = '10m'

        SLACK_CHANNEL      = '#devops-pipelines'
       // SLACK_WEBHOOK      = credentials('slack-webhook-url')
    }

    parameters {
        string(name: 'GIT_BRANCH', defaultValue: 'master', description: 'Branch to build')
        booleanParam(name: 'RUN_TESTS', defaultValue: true, description: 'Run unit tests')
        booleanParam(name: 'SKIP_SONARQUBE', defaultValue: false, description: 'Skip SonarQube scan')
        booleanParam(name: 'PUSH_DOCKER_IMAGE', defaultValue: true, description: 'Push Docker image to registry')
        booleanParam(name: 'UPLOAD_TO_NEXUS', defaultValue: true, description: 'Upload artifact to Nexus')
        choice(name: 'DEPLOY_ENV', choices: ['NONE', 'DEV', 'STAGING', 'PRODUCTION'], description: 'Deployment target')
    }

    triggers {
        githubPush()
    }

    stages {
        stage('Checkout') {
            agent any
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: "${GIT_BRANCH}"]],
                    userRemoteConfigs: [[url: "${GIT_REPO}", credentialsId: "${GIT_CREDENTIALS}"]],
                    extensions: [[$class: 'CloneOption', depth: 50]]
                ])
            }
        }
}

 /*       stage('Build') {
            agent { label 'docker' }
            steps {
                sh '''
                    [ ! -f gradlew ] && gradle wrapper --gradle-version 8.5
                    ./gradlew clean build -x test \
                        --parallel --build-cache \
                        -Dorg.gradle.jvmargs="-Xmx1024m -XX:+UseG1GC" \
                        -PversionNumber=${BUILD_NUMBER}
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'build/libs/*.jar', allowEmptyArchive: true
                }
                failure {
                    script { sendNotification("Build failed", "failure") }
                }
            }
        }

        stage('Nexus Upload') {
            agent { label 'docker' }
            when { expression { params.UPLOAD_TO_NEXUS } }
            steps {
                script {
                    def artifactPath = sh(script: 'find build/libs -name "*.jar" | head -1', returnStdout: true).trim()
                    nexusArtifactUploader(
                        nexusVersion: 'nexus3',
                        protocol: 'https',
                        nexusUrl: "${NEXUS_URL}",
                        groupId: 'com.company.enterprise',
                        version: "${BUILD_NUMBER}",
                        repository: "${NEXUS_REPOSITORY}",
                        credentialsId: "${NEXUS_CREDENTIALS}",
                        artifacts: [[artifactId: "${PROJECT_NAME}", classifier: '', file: artifactPath, type: 'jar']]
                    )
                }
            }
            post {
                failure {
                    script { sendNotification("Nexus upload failed", "failure") }
                }
            }
        }

        stage('Test') {
            agent { label 'docker' }
            when { expression { params.RUN_TESTS } }
            steps {
                sh './gradlew test --parallel'
                sh './gradlew jacocoTestReport || true'
            }
            post {
                always {
                    junit testResults: 'build/test-results/test/*.xml', allowEmptyResults: true
                    publishHTML([
                        reportDir: 'build/reports/jacoco/test/html',
                        reportFiles: 'index.html',
                        reportName: 'JaCoCo Coverage',
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true
                    ])
                }
                failure {
                    script { sendNotification("Tests failed", "failure") }
                }
            }
        }

        stage('SonarQube') {
            agent { label 'docker' }
            when { expression { !params.SKIP_SONARQUBE } }
            steps {
                withSonarQubeEnv("${SONARQUBE_SERVER}") {
                    sh './gradlew sonarqube -Dsonar.branch.name=${GIT_BRANCH}'
                }
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
            post {
                failure {
                    script { sendNotification("SonarQube quality gate failed", "failure") }
                }
            }
        }

        stage('Docker Build & Push') {
            agent {
                kubernetes {
                    yaml '''
                        apiVersion: v1
                        kind: Pod
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
                          volumes:
                          - name: docker-sock
                            hostPath:
                              path: /var/run/docker.sock
                    '''
                }
            }
            steps {
                sh "docker build -t ${DOCKER_IMAGE}:${DOCKER_IMAGE_TAG} -t ${DOCKER_IMAGE}:latest ."
                script {
                    if (params.PUSH_DOCKER_IMAGE) {
                        withCredentials([usernamePassword(credentialsId: "${DOCKER_CREDENTIALS}",
                            usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                            sh '''
                                echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin ${DOCKER_REGISTRY}
                                docker push ${DOCKER_IMAGE}:${DOCKER_IMAGE_TAG}
                                docker push ${DOCKER_IMAGE}:latest
                                docker logout ${DOCKER_REGISTRY}
                            '''
                        }
                    }
                }
            }
            post {
                failure {
                    script { sendNotification("Docker build/push failed", "failure") }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            agent {
                kubernetes {
                    yaml '''
                        apiVersion: v1
                        kind: Pod
                        spec:
                          serviceAccountName: jenkins
                          containers:
                          - name: kubectl
                            image: bitnami/kubectl:1.28
                            command: [cat]
                            tty: true
                    '''
                }
            }
            when { expression { params.DEPLOY_ENV != 'NONE' } }
            steps {
                script {
                    switch (params.DEPLOY_ENV) {
                        case 'DEV':
                            env.TARGET_NAMESPACE = K8S_NAMESPACE_DEV
                            env.REPLICAS = REPLICAS_DEV
                            break
                        case 'STAGING':
                            env.TARGET_NAMESPACE = K8S_NAMESPACE_STAGING
                            env.REPLICAS = REPLICAS_STAGING
                            break
                        case 'PRODUCTION':
                            env.TARGET_NAMESPACE = K8S_NAMESPACE_PROD
                            env.REPLICAS = REPLICAS_PROD
                            break
                    }
                }
                sh '''
                    kubectl create namespace ${TARGET_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                    envsubst < k8s/serviceaccount.yaml | kubectl apply -f -
                    envsubst < k8s/deployment.yaml | kubectl apply -f -
                    kubectl rollout status deployment/${PROJECT_NAME} \
                        -n ${TARGET_NAMESPACE} --timeout=${DEPLOYMENT_TIMEOUT}
                '''
            }
            post {
                failure {
                    script {
                        sendNotification("Kubernetes deployment failed", "failure")
                        sh 'kubectl rollout undo deployment/${PROJECT_NAME} -n ${TARGET_NAMESPACE} || true'
                    }
                }
            }
        }

        stage('Smoke Tests') {
            agent { label 'docker' }
            when { expression { params.DEPLOY_ENV != 'NONE' } }
            steps {
                sh '''
                    SERVICE_IP=$(kubectl get svc ${PROJECT_NAME} -n ${TARGET_NAMESPACE} \
                        -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "127.0.0.1")
                    SERVICE_PORT=$(kubectl get svc ${PROJECT_NAME} -n ${TARGET_NAMESPACE} \
                        -o jsonpath='{.spec.ports[0].port}')

                    for i in {1..10}; do
                        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
                            "http://${SERVICE_IP}:${SERVICE_PORT}/actuator/health" || echo "000")
                        [ "$HTTP_CODE" = "200" ] && echo "Health check passed" && break
                        echo "Waiting for service (attempt $i/10)..."
                        sleep 10
                    done
                '''
            }
            post {
                failure {
                    script { sendNotification("Smoke tests failed", "failure") }
                }
            }
        }
    }

    post {
        always {
            cleanWs(deleteDirs: true, patterns: [[pattern: 'target/**', type: 'INCLUDE']])
        }
        success {
            script { sendNotification("Pipeline completed successfully", "success") }
        }
        failure {
            script { sendNotification("Pipeline failed - check logs", "failure") }
        }
        unstable {
            script { sendNotification("Pipeline unstable - review quality gates", "warning") }
        }
        cleanup {
            sh 'docker system prune -f || true'
        }
    }
}

def sendNotification(String message, String status) {
    if (!env.SLACK_WEBHOOK) return
    def color = status == 'success' ? 'good' : status == 'failure' ? 'danger' : 'warning'
    def payload = [
        channel: env.SLACK_CHANNEL,
        username: 'Jenkins Pipeline Bot',
        attachments: [[
            color: color,
            title: "${env.PROJECT_NAME} - Build #${env.BUILD_NUMBER}",
            text: message,
            fields: [
                [title: 'Branch', value: env.GIT_BRANCH, short: true],
                [title: 'Environment', value: env.DEPLOY_ENV ?: 'N/A', short: true]
            ]
        ]]
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
        echo "Failed to send Slack notification: ${e.message}"
    }
}*/

}
