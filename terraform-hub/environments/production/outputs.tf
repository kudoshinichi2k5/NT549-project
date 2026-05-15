# =========================
# EKS Core Outputs
# =========================
output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_cluster_ca" {
  value = module.eks.cluster_ca
}

# =========================
# IAM Outputs (for future IRSA / Karpenter)
# =========================
output "eks_node_role_arn" {
  value = module.iam_eks.node_role_arn
}

output "alb_controller_role_arn" {
  description = "IAM Role ARN for AWS Load Balancer Controller"
  value       = module.iam_alb.alb_controller_role_arn
}

output "karpenter_role_arn" {
  description = "IAM Role ARN for Karpenter (IRSA)"
  value       = module.iam_karpenter.karpenter_role_arn
}

output "karpenter_instance_profile_name" {
  description = "Instance profile name used by Karpenter EC2 nodes"
  value       = module.iam_karpenter.instance_profile_name
}

output "karpenter_instance_profile_arn" {
  description = "Instance profile ARN used by Karpenter EC2 nodes"
  value       = module.iam_karpenter.instance_profile_arn
}
# =========================
# Observability
# =========================
output "observability_private_ips" {
  value = [for i in module.observability.instances : i.private_ip]
}

# =========================
# OpenVPN
# =========================
output "openvpn_public_ip" {
  value = module.openvpn.public_ip
}