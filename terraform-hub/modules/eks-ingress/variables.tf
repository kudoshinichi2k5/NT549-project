variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where EKS is deployed"
  type        = string
}

variable "alb_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller (IRSA)"
  type        = string
}
