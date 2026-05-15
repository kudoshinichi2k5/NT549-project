locals {
  ordered_instance_keys = sort(keys(aws_instance.observability_node))
}

output "nodes" {
  value = aws_instance.observability_node
}

output "instances" {
  value = [for name in local.ordered_instance_keys : aws_instance.observability_node[name]]
}
