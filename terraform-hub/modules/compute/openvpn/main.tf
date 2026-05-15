resource "aws_instance" "this" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  key_name               = var.key_name
  vpc_security_group_ids = [var.openvpn_sg_id]

  source_dest_check = false

  tags = {
    Name = "openvpn_server"
  }
}
