pipeline {
  agent any

  parameters {
    choice(
      name: 'ENV',
      choices: ['staging', 'production'],
      description: 'Terraform environment to validate'
    )
  }

  environment {
    TF_IN_AUTOMATION = "true"
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Terraform Format') {
        steps {
            sh '''
            echo "▶ Running terraform fmt..."
            terraform fmt -recursive

            echo "▶ Checking if terraform fmt introduced changes..."
            if ! git diff --quiet; then
                echo "❌ Terraform files were not formatted."
                echo "👉 Jenkins has auto-formatted them."
                echo "👉 Please run 'terraform fmt -recursive', commit, and push."
                git --no-pager diff
                exit 1
            else
                echo "✅ Terraform files already formatted."
            fi
            '''
      }
    }


    stage('Terraform Init') {
      steps {
        dir("environments/${params.ENV}") {
          sh 'terraform init -backend=false'
        }
      }
    }

    stage('Terraform Validate') {
      steps {
        dir("environments/${params.ENV}") {
          sh 'terraform validate'
        }
      }
    }

    stage('TFLint') {
      steps {
        sh '''
        tflint --init
        tflint
        '''
      }
    }

    // stage('Checkov Security Scan') {
    //     steps {
    //         sh '''
    //         checkov -d . \
    //         --framework terraform \
    //         --skip-path environments/staging/terraform.tfstate \
    //         --quiet
    //         '''
    //     }
    // }


    // stage('Terraform Plan (dry-run)') {
    //   steps {
    //     dir("environments/${params.ENV}") {
    //       sh '''
    //       terraform plan \
    //         -input=false \
    //         -lock=false \
    //         -no-color
    //       '''
    //     }
    //   }
    // }
  }

  post {
    success {
      echo "✅ CI passed for ${params.ENV}. Safe to apply manually."
    }
    failure {
      echo "❌ CI failed for ${params.ENV}. Fix before apply."
    }
  }
}
