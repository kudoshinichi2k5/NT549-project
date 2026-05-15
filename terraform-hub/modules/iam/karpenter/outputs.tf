output "karpenter_role_arn" {
  description = "IAM Role ARN used by Karpenter controller (IRSA)"
  value       = aws_iam_role.this.arn
}

output "karpenter_role_name" {
  description = "IAM Role name used by Karpenter controller"
  value       = aws_iam_role.this.name
}

output "instance_profile_name" {
  description = "Instance profile name attached to Karpenter-managed EC2 nodes"
  value       = aws_iam_instance_profile.this.name
}

output "instance_profile_arn" {
  description = "Instance profile ARN attached to Karpenter-managed EC2 nodes"
  value       = aws_iam_instance_profile.this.arn
}
