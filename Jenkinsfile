pipeline {
  agent any
  tools { nodejs 'node18' }
  environment {
    ECR_REPO  = 445160884854.dkr.ecr.us-east-2.amazonaws.com/netflix-clone
    IMAGE_TAG = "${env.BUILD_NUMBER}"
    MANIFESTS = "https://github.com/ao93/netflix-clone-manifest.git"
  }
  stages {
    stage('Checkout') {
      steps {
        git branch: 'main',
            url: 'https://github.com/ao93/netflix-clone.git'
      }
    }
    stage('Install Dependencies') {
      steps { sh 'npm ci' }
    }
    stage('OWASP Dep-Check') {
      steps {
        dependencyCheck additionalArguments: '--scan ./',
                        odcInstallation: 'DP-Check'
      }
    }
    stage('SonarQube') {
      steps {
        withSonarQubeEnv('SonarQube-Server') {
          sh "$SCANNER_HOME/bin/sonar-scanner -Dsonar.projectKey=netflix-clone"
        }
      }
    }
    stage('Docker Build') {
      steps {
        withCredentials([string(credentialsId: 'tmdb-api-key', variable: 'TMDB_KEY')]) {
          sh "docker build --build-arg TMDB_V3_API_KEY=$TMDB_KEY -t $ECR_REPO:$IMAGE_TAG ."
        }
      }
    }
    stage('Trivy Scan') {
      steps {
        sh "trivy image --exit-code 0 --severity HIGH,CRITICAL $ECR_REPO:$IMAGE_TAG"
      }
    }
    stage('Push to ECR') {
      steps {
        sh """
          aws ecr get-login-password --region us-east-1 | \
            docker login --username AWS --password-stdin $ECR_REPO
          docker push $ECR_REPO:$IMAGE_TAG
        """
      }
    }
    stage('Update Manifests Repo') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'github-creds',
            usernameVariable: 'GIT_USER', passwordVariable: 'GIT_TOKEN')]) {
          sh """
            git clone https://$GIT_USER:$GIT_TOKEN@github.com/ao93/netflix-clone-manifest.git
            cd netflix-clone-manifest
            sed -i "s|image: .*|image: $ECR_REPO:$IMAGE_TAG|g" base/deployment.yaml
            git config user.email "ci@jenkins.local"
            git config user.name "Jenkins CI"
            git add base/deployment.yaml
            git commit -m "ci: update image to build $IMAGE_TAG [skip ci]"
            git push origin main
          """
        }
      }
    }
  }
  post {
    always {
      emailext attachLog: true,
               subject: "Netflix Clone Build: ${currentBuild.result}",
               body: "Build ${BUILD_NUMBER} — ${currentBuild.result}",
               to: 'your-email@gmail.com'
    }
  }
}