#!/usr/bin/env groovy

pipeline {
    agent {
        label 'master_node'
    }

    options {
        buildDiscarder(logRotator(
            numToKeepStr: '30',
            artifactNumToKeepStr: '10'
        ))

        timeout(time: 2, unit: 'HOURS')

        timestamps()

        disableConcurrentBuilds()

        skipDefaultCheckout(true)

        ansiColor('xterm')
    }

    environment {

        // ---------------- Git ----------------
        PROJECT_NAME          = 'enterprise-microservice'

        GIT_REPO_CICD         = 'https://github.com/Shaikh-Majid/TechNest-CICD-Pipeline.git'
        GIT_REPO_DEVEL        = 'https://github.com/Shaikh-Majid/TechNest-Ecom-RJ.git'

        GIT_CREDENTIALS_CICD  = 'GitHub'
        GIT_CREDENTIALS_DEVEL = 'GitHub'

        // ---------------- Application ----------------

        APP_NAME = 'technest'

        // ---------------- Nexus ----------------

        NEXUS_URL = 'http://13.201.241.166:8081'

        NEXUS_NPM_REPO = 'PRJ-technest-auth'

        NEXUS_RAW_REPO = 'PRJ-technest-auth'

        // ---------------- Sonar ----------------

        SONAR_PROJECT_KEY = 'shaikh-majid'

        SONAR_HOST_URL = 'https://sonarcloud.io'

        // ---------------- Workspace ----------------

        APP_DIR = 'src/app'

        CICD_DIR = 'src/cicd'

        NPM_CONFIG_CACHE = "${WORKSPACE}/.npm-cache"

        TRIVY_CACHE_DIR = "${WORKSPACE}/.trivy-cache"

        DOCKER_BUILDKIT = '1'
    }

    parameters {

        string(
            name: 'GIT_BRANCH',
            defaultValue: 'master',
            description: 'CI/CD Repository Branch'
        )

        string(
            name: 'DEVEL_BRANCH',
            defaultValue: 'main',
            description: 'Application Repository Branch'
        )

        booleanParam(
            name: 'RUN_TESTS',
            defaultValue: true,
            description: 'Run Unit Tests'
        )

        booleanParam(
            name: 'SKIP_SONARQUBE',
            defaultValue: false,
            description: 'Skip SonarQube Scan'
        )

        booleanParam(
            name: 'UPLOAD_TO_NEXUS',
            defaultValue: true,
            description: 'Upload Artifact'
        )
    }

    triggers {
        githubPush()
    }

    stages {

stage('Clean Workspace & Checkout') {

    steps {

        cleanWs(
            deleteDirs: true,
            disableDeferredWipeout: true,
            notFailBuild: true
        )

        script {

            echo "=============================="
            echo "Checking out CI/CD Repository"
            echo "=============================="

            dir(CICD_DIR) {

                checkout([
                    $class: 'GitSCM',
                    branches: [[name: "*/${params.GIT_BRANCH}"]],
                    userRemoteConfigs: [[
                        url: GIT_REPO_CICD,
                        credentialsId: GIT_CREDENTIALS_CICD
                    ]]
                ])
            }

            echo "=============================="
            echo "Checking out Application Repository"
            echo "=============================="

            dir(APP_DIR) {

                checkout([
                    $class: 'GitSCM',
                    branches: [[name: "*/${params.DEVEL_BRANCH}"]],
                    userRemoteConfigs: [[
                        url: GIT_REPO_DEVEL,
                        credentialsId: GIT_CREDENTIALS_DEVEL
                    ]]
                ])

            }

        }

        script {

            echo "======================================="
            echo "Verifying Application Repository"
            echo "======================================="

            dir(APP_DIR) {

                sh '''
                set -eux

                echo "Workspace:"
                pwd

                echo
                echo "Git Remote:"
                git remote -v

                echo
                echo "Branch:"
                git branch -a

                echo
                echo "Current Commit:"
                git log --oneline -1

                echo
                echo "Repository Contents:"
                ls -lah

                echo
                echo "Searching package.json"
                test -f package.json

                echo
                echo "Searching server.js"
                test -f server.js

                echo
                echo "Searching README"
                test -f README.md

                echo
                echo "Repository Tree"
                find . -maxdepth 2 | sort

                '''
            }

        }

    }

    post {

        success {

            echo "Application checkout completed successfully."

            script {
                sendNotification(
                    "Git checkout completed successfully.",
                    "success"
                )
            }

        }

        failure {

            script {
                sendNotification(
                    "Git checkout failed.",
                    "failure"
                )
            }

        }

    }

}

stage('Install Dependencies') {

    steps {

        dir(APP_DIR) {

            withCredentials([
                usernamePassword(
                    credentialsId: 'jenkins-cred',
                    usernameVariable: 'NEXUS_USER',
                    passwordVariable: 'NEXUS_PASS'
                )
            ]) {

                sh '''
                set -euxo pipefail

                echo "========================================="
                echo "Node & NPM Version"
                echo "========================================="

                node --version
                npm --version

                echo
                echo "========================================="
                echo "Creating .npmrc"
                echo "========================================="

                cat > .npmrc <<EOF
registry=${NEXUS_URL}/repository/${NEXUS_NPM_REPO}/
always-auth=true
//13.201.241.166:8081/repository/${NEXUS_NPM_REPO}/:username=${NEXUS_USER}
//13.201.241.166:8081/repository/${NEXUS_NPM_REPO}/:_password=$(printf "%s" "${NEXUS_PASS}" | base64 -w0)
//13.201.241.166:8081/repository/${NEXUS_NPM_REPO}/:email=jenkins@example.com
EOF

                echo
                echo "========================================="
                echo "Installing Dependencies"
                echo "========================================="

                npm ci --prefer-offline --no-audit --no-fund

                echo
                echo "========================================="
                echo "Installed Packages"
                echo "========================================="

                npm list --depth=0 || true

                '''
            }
        }
    }

    post {

        always {

            dir(APP_DIR) {

                sh '''
                rm -f .npmrc
                '''
            }

        }

        success {

            echo "Dependencies installed successfully."

        }

        failure {

            echo "Dependency installation failed."

        }

    }

}
stage('SonarQube Analysis') {

    when {
        expression {
            return !params.SKIP_SONARQUBE
        }
    }

    steps {

        dir(APP_DIR) {

            script {

                def scannerHome = tool 'sonar'

                withSonarQubeEnv('sonar') {

                    sh """
                    set -eux

                    ${scannerHome}/bin/sonar-scanner \
                      -Dsonar.organization=shaikh-majid \
                      -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                      -Dsonar.projectName=${APP_NAME} \
                      -Dsonar.projectVersion=${BUILD_NUMBER} \
                      -Dsonar.sources=. \
                      -Dsonar.sourceEncoding=UTF-8 \
                      -Dsonar.host.url=${SONAR_HOST_URL} \
                      -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info \
                      -Dsonar.exclusions=node_modules/**,coverage/**,dist/**,.git/**,.scannerwork/**,*.test.js
                    """

                }

            }

        }

    }

    post {

        success {

            echo "SonarQube scan completed successfully."

        }

        failure {

            echo "SonarQube scan failed."

        }

    }

}
stage('Quality Gate') {

    when {
        expression {
            return !params.SKIP_SONARQUBE
        }
    }

    steps {

        script {

            timeout(time: 10, unit: 'MINUTES') {

                def qualityGate = waitForQualityGate(abortPipeline: false)

                echo "===================================="
                echo "Quality Gate Status : ${qualityGate.status}"
                echo "===================================="

                switch (qualityGate.status) {

                    case 'OK':
                        echo "Quality Gate Passed."
                        break

                    case 'WARN':
                        unstable("Quality Gate returned WARN.")
                        break

                    case 'ERROR':
                        error("Quality Gate Failed.")
                        break

                    default:
                        unstable("Unexpected Quality Gate Status: ${qualityGate.status}")
                }

            }

        }

    }

}
stage('Build & Package') {

    steps {

        dir(APP_DIR) {

            script {

                env.APP_VERSION = sh(
                    script: "node -p \"require('./package.json').version\"",
                    returnStdout: true
                ).trim()

                env.IMAGE_TAG = "${env.APP_VERSION}-${env.BUILD_NUMBER}"

                sh '''
                set -euxo pipefail

                rm -rf dist
                mkdir -p dist

                test -f package.json
                test -f server.js

                ARTIFACT_NAME="${APP_NAME}-${IMAGE_TAG}.tar.gz"

                echo "Creating ${ARTIFACT_NAME}"

                tar \
                    --exclude=node_modules \
                    --exclude=.git \
                    --exclude=coverage \
                    --exclude=.scannerwork \
                    --exclude=dist \
                    -czf dist/${ARTIFACT_NAME} .

                sha256sum dist/${ARTIFACT_NAME} \
                    > dist/${ARTIFACT_NAME}.sha256

                ls -lh dist
                '''
            }

            archiveArtifacts(
                artifacts: 'dist/*',
                fingerprint: true
            )

        }

    }

}
stage('Upload to Nexus') {

    when {
        allOf {
            expression { return params.UPLOAD_TO_NEXUS }
            anyOf {
                branch 'main'
                branch 'develop'
            }
        }
        beforeAgent true
    }

    steps {

        dir(APP_DIR) {

            script {

                withCredentials([
                    usernamePassword(
                        credentialsId: 'nexus-jenkins',
                        usernameVariable: 'NEXUS_USER',
                        passwordVariable: 'NEXUS_PASS'
                    )
                ]) {

                    retry(3) {

                        sh '''
                        set -euxo pipefail

                        echo "======================================"
                        echo "Uploading Artifacts to Nexus"
                        echo "======================================"

                        ARTIFACT_NAME="${APP_NAME}-${IMAGE_TAG}.tar.gz"

                        echo
                        echo "Artifacts:"
                        ls -lh dist/

                        for f in \
                            "dist/${ARTIFACT_NAME}" \
                            "dist/${ARTIFACT_NAME}.sha256"
                        do

                            test -f "$f"

                            echo
                            echo "Uploading $(basename "$f")"

                            HTTP_CODE=$(
                                curl \
                                    --silent \
                                    --show-error \
                                    --write-out "%{http_code}" \
                                    --output /tmp/nexus_upload.log \
                                    --user "${NEXUS_USER}:${NEXUS_PASS}" \
                                    --upload-file "$f" \
                                    "${NEXUS_URL}/repository/${NEXUS_RAW_REPO}/${APP_NAME}/${IMAGE_TAG}/$(basename "$f")"
                            )

                            echo "HTTP Status : ${HTTP_CODE}"

                            if [ "${HTTP_CODE}" != "201" ]; then
                                echo
                                echo "Upload failed for $(basename "$f")"

                                echo
                                echo "Nexus Response:"
                                cat /tmp/nexus_upload.log || true

                                exit 1
                            fi

                            echo "Successfully uploaded $(basename "$f")"

                        done

                        echo
                        echo "======================================"
                        echo "All artifacts uploaded successfully."
                        echo "======================================"

                        '''

                    }

                    echo "Artifacts published successfully."

                    echo "${NEXUS_URL}/repository/${NEXUS_RAW_REPO}/${APP_NAME}/${IMAGE_TAG}/"

                }

            }

        }

    }

    post {

        success {

            echo "Nexus upload completed successfully."

        }

        failure {

            echo "Nexus upload failed."

        }

    }

}

}
post {

    success {
        sendNotification(
            "Pipeline completed successfully.",
            "success"
        )
    }

    failure {
        sendNotification(
            "Pipeline failed.",
            "failure"
        )
    }

    always {
        cleanWs(
            deleteDirs: true,
            notFailBuild: true
        )
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

def sendNotification(String message, String status) {
emailext(
subject: "${status}: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
body: """
<html>
<body>
<h1>${message}</h1>
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
