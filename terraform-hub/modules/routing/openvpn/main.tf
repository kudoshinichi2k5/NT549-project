resource "aws_route" "private_to_openvpn" {
  route_table_id         = var.private_route_table_id
  destination_cidr_block = var.vpn_cidr
  network_interface_id   = var.openvpn_eni_id
}
