#!/usr/bin/env groovy

pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '30', artifactNumToKeepStr: '10'))
        timeout(time: 2, unit: 'HOURS')
        timestamps()
        disableConcurrentBuilds()
    }

    environment {

       //----------------------GitHub-------------------------------------
        PROJECT_NAME         = 'enterprise-microservice'
        GIT_REPO_CICD        = 'https://github.com/Shaikh-Majid/TechNest-CICD-Pipeline.git'
        GIT_REPO_DEVEL       = 'https://github.com/Shaikh-Majid/GitPractices.git'
        GIT_CREDENTIALS_CICD =  'Github-Jenkins'
        GIT_CREDENTIALS_DEVEL = 'Github-Jenkins'
        GIT_BRANCH            = "${env.BRANCH_NAME ?: 'master'}"

        // ---- Application identity -------------------------------------------
        APP_NAME            = 'technest'
        APP_VERSION         = sh(script: "node -p \"require('./package.json').version\"", returnStdout: true).trim()

        // ---- AWS / ECR -------------------------------------------------------
        //AWS_REGION          = 'ap-south-1'
        //AWS_ACCOUNT_ID      = credentials('aws-account-id')
        //ECR_REGISTRY        = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        //ECR_REPO            = "${ECR_REGISTRY}/${APP_NAME}"

        // ---- Immutable image tag --------------------------------------------
        // <semver>-<build>-<sha>. Immutable by construction: no 'latest', ever.
        // A mutable tag plus imagePullPolicy:IfNotPresent means nodes silently
        // serve stale images and you cannot reason about what is running.
        //GIT_SHA_SHORT       = sh(script: 'git rev-parse --short=8 HEAD', returnStdout: true).trim()
        IMAGE_TAG           = "${APP_VERSION}-${BUILD_NUMBER}-${GIT_SHA_SHORT}"
        IMAGE_FULL          = "${ECR_REPO}:${IMAGE_TAG}"

        // ---- Nexus -----------------------------------------------------------
        NEXUS_URL           = 'http://13.201.241.166:8081'
        NEXUS_NPM_REPO      = ''
        NEXUS_RAW_REPO      = 'technest-artifacts'

        // ---- SonarQube -------------------------------------------------------
        SONAR_HOST_URL      = 'https://sonarqube.technest.internal'
        SONAR_PROJECT_KEY   = 'technest-auth-app'

        // ---- Kubernetes / Helm ----------------------------------------------
        HELM_CHART_DIR      = 'helm/technest'
        K8S_NAMESPACE_DEV   = 'technest-dev'
        K8S_NAMESPACE_PROD  = 'technest-prod'
        EKS_CLUSTER_DEV     = 'technest-eks-dev'
        EKS_CLUSTER_PROD    = 'technest-eks-prod'

        // ---- Endpoints -------------------------------------------------------
        DEV_URL             = 'https://dev.technest.example.com'
        PROD_URL            = 'https://technest.example.com'

        // ---- Notifications ---------------------------------------------------
        EMAIL_RECIPIENTS    = 'devops@technest.example.com, engineering@technest.example.com'
        SLACK_CHANNEL       = '#technest-deploys'

        // ---- Build behaviour -------------------------------------------------
        NODE_ENV            = 'production'
        // npm writes to $HOME by default; on a shared agent that collides
        // between concurrent jobs. Pin the cache into the workspace.
        NPM_CONFIG_CACHE    = "${WORKSPACE}/.npm-cache"
        TRIVY_CACHE_DIR     = "${WORKSPACE}/.trivy-cache"
        DOCKER_BUILDKIT     = '1'
    }
    parameters {
        string(name: 'GIT_BRANCH',    defaultValue: 'master', description: 'Application repo branch')
        string(name: 'DEVEL_BRANCH',  defaultValue: 'main',   description: 'Infrastructure repo branch')
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
        stage('Clean Workspace & Checkout') {
            agent any
            steps {
                cleanWs(
                    deleteDirs: true,
                    disableDeferredWipeout: true,
                    notFailBuild: true
                )

                dir('src/cicd') {
                    git branch: "${params.GIT_BRANCH ?: 'master'}",
                        credentialsId: "${GIT_CREDENTIALS_CICD}",
                        url: "${GIT_REPO_CICD}"
                }
                dir('src/app') {
                    git branch: "${params.DEVEL_BRANCH ?: 'main'}",
                        credentialsId: "${GIT_CREDENTIALS_DEVEL}",
                        url: "${GIT_REPO_DEVEL}"
                }
            }
            post {
                success {
                    script { sendNotification("Git Successfully Checkout the Repo", "success") }
                }
                failure {
                    script { sendNotification("Git Checkout failed", "failure") }
                }
            }
        }

        stage('Install Dependencies') {
            agent any
            steps {
                script {
                    withCredentials([string(credentialsId: 'nexus-npm-token', variable: 'NPM_TOKEN')]) {
                        // Heredoc is quoted ('EOF') so Groovy never interpolates
                        // NPM_TOKEN — it stays a shell variable and out of logs.
                        sh '''
                            set -eu
                            cat > .npmrc <<'EOF'
              registry=${NEXUS_URL}/repository/${NEXUS_NPM_REPO}/
              always-auth=true
              EOF
                            echo "//nexus.technest.internal/repository/${NEXUS_NPM_REPO}/:_authToken=${NPM_TOKEN}" >> .npmrc
                        '''
                        retry(2) {
                            timeout(time: 10, unit: 'MINUTES') {
                                sh 'npm ci --prefer-offline --no-audit --no-fund'
                            }
                        }
                    }
                }
            }
            post {
                always {
                    // The token lives in this file. Remove it the moment we are
                    // done, so it cannot leak via archiveArtifacts or a shell.
                    sh 'rm -f .npmrc'
                }
            }
        }
    }

/*def sendNotification(String message, String status) {
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
def sendNotification(String message, String status) {
emailext(
subject: "${status}: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
body: """
<html>
<body>
<h1>${message}<h1>
/*<h2>${env.JOB_NAME} #${env.BUILD_NUMBER} </h2>

<p><b>Job Name:</b>${env.JOB_NAME}</p>
<p><b>Build Number:</b>${env.BUILD_NUMBER}</p>
<p><b>Build URL:</b> <a href="${env.BUILD_URL}">${env.BUILD_URL}</a></p>
<p><b>Console Output:</b> <a href="${env.BUILD_URL}/console">View Console</a></p>

<h3>Changes:</h3>
<p>\${CHANGES}</p>
<h3>Console Output (last 100 lines):</h3>
<pre>\${BUILD_LOG, maxLines=100}</pre>

</body>
</html>
""",
        to: "ms5038248@gmail.com",
        mimeType: 'text/html',
        attachLog: true
    )
}