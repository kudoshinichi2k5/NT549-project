locals {
  node_name_overrides = {
    master  = "k0s_master"
    worker1 = "k0s_worker1"
    worker2 = "k0s_worker2"
    worker3 = "k0s_worker3"
  }
}

resource "aws_instance" "k0s_node" {
  for_each               = var.nodes
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[each.value.subnet_index]
  private_ip             = each.value.private_ip
  key_name               = var.key_name
  vpc_security_group_ids = [var.k0s_sg_id]

  tags = {
    Name = lookup(local.node_name_overrides, each.key, each.key)
  }
}

moved {
  from = aws_instance.controller
  to   = aws_instance.k0s_node["master"]
}

moved {
  from = aws_instance.workers[0]
  to   = aws_instance.k0s_node["worker1"]
}

moved {
  from = aws_instance.workers[1]
  to   = aws_instance.k0s_node["worker2"]
}

moved {
  from = aws_instance.workers[2]
  to   = aws_instance.k0s_node["worker3"]
}
