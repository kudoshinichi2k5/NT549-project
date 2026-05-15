resource "aws_instance" "observability_node" {
  for_each               = var.nodes
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[each.value.subnet_index]
  private_ip             = each.value.private_ip
  key_name               = var.key_name
  vpc_security_group_ids = [var.observability_sg_id]

  tags = {
    Name = each.key
  }
}

moved {
  from = aws_instance.observability_node["prometheus"]
  to   = aws_instance.observability_node["obser_01"]
}
