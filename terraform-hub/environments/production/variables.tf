# =========================
# Global
# =========================
variable "region" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
}

variable "public_subnet" {
  type = string
}

variable "my_ip_cidr" {
  type = string
}

# =========================
# SSH
# =========================
variable "key_name" {
  type = string
}

variable "public_key_path" {
  type = string
}

# =========================
# AMI (for EC2-based services)
# =========================
variable "ami" {
  type = string
}

# =========================
# EKS
# =========================
variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = "1.29"
}

variable "node_instance_type" {
  type = string
}

variable "node_desired_size" {
  type = number
}

variable "node_min_size" {
  type = number
}

variable "node_max_size" {
  type = number
}

# =========================
# Observability
# =========================
variable "observability_instance_type" {
  type = string
}

# =========================
# OpenVPN
# =========================
variable "openvpn_instance_type" {
  type = string
}

variable "vpn_cidr" {
  description = "CIDR of OpenVPN subnet"
  type        = string
}
