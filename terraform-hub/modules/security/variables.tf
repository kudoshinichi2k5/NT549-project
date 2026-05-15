variable "vpc_id" {}
variable "vpc_cidr" {}
variable "my_ip_cidr" {}

variable "eks_cluster_security_group_id" {
  description = "EKS cluster control plane security group ID"
  type        = string
  default     = null
}

variable "vpn_cidr" {
  description = "OpenVPN subnet CIDR"
  type        = string
  default     = null
}
