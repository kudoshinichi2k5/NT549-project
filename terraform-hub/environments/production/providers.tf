terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.6"
    }
  }
}

provider "aws" {
  region = var.region
}

# =========================
# Kubernetes Provider (EKS)
# =========================
provider "kubernetes" {
  host = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(
    data.aws_eks_cluster.this.certificate_authority[0].data
  )
  token = data.aws_eks_cluster_auth.this.token
}

# =========================
# Helm Provider (EKS)
# =========================
provider "helm" {
  kubernetes = {
    host = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(
      data.aws_eks_cluster.this.certificate_authority[0].data
    )
    token = data.aws_eks_cluster_auth.this.token
  }
}

