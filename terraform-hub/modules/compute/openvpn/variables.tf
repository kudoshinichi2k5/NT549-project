variable "ami" {}
variable "instance_type" {}

variable "key_name" {
  description = "SSH key name (from keypair module)"
}

variable "public_subnet_id" {}
variable "openvpn_sg_id" {}
