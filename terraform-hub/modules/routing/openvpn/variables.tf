variable "private_route_table_id" {
  description = "Private route table ID that should return traffic to VPN clients"
  type        = string
}

variable "vpn_cidr" {
  description = "CIDR assigned to VPN clients"
  type        = string
}

variable "openvpn_eni_id" {
  description = "Primary ENI ID of the OpenVPN instance"
  type        = string
}
