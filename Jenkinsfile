pipeline {
  agent any
  tools { nodejs 'node18' }
  environment {
    ECR_REPO  = "445160884854.dkr.ecr.us-east-2.amazonaws.com/netflix-clone"
    IMAGE_TAG = "${env.BUILD_NUMBER}"
  }
  stages {
    stage('Checkout') {
      steps {
        git branch: 'main', url: 'https://github.com/ao93/netflix-clone.git'
      }
    }
    stage('Install Dependencies') {
      steps { sh 'yarn install' }
    }
    stage('Docker Build') {
      steps {
        withCredentials([string(credentialsId: 'tmdb-api-key', variable: 'TMDB_KEY')]) {
          sh "docker build --build-arg TMDB_V3_API_KEY=\$TMDB_KEY -t $ECR_REPO:$IMAGE_TAG ."
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
        sh "aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin $ECR_REPO && docker push $ECR_REPO:$IMAGE_TAG"
      }
    }
    stage('Update Manifests') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'github-creds', usernameVariable: 'GIT_USER', passwordVariable: 'GIT_TOKEN')]) {
          sh "rm -rf netflix-clone-manifest && git clone https://\$GIT_USER:\$GIT_TOKEN@github.com/ao93/netflix-clone-manifest.git && cd netflix-clone-manifest && sed -i 's|image: .*|image: $ECR_REPO:$IMAGE_TAG|g' base/deployment.yaml && git config user.email ci@jenkins.local && git config user.name Jenkins && git add base/deployment.yaml && git commit -m 'ci: update image' && git push origin main"
        }
      }
    }
  }
  post {
    always { echo "Build ${BUILD_NUMBER}: ${currentBuild.result}" }
  }
}