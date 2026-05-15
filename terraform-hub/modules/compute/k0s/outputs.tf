locals {
  worker_keys = sort([
    for name in keys(aws_instance.k0s_node) :
    name if name != "master"
  ])
}

output "nodes" {
  value = aws_instance.k0s_node
}

output "controller" {
  value = aws_instance.k0s_node["master"]
}

output "workers" {
  value = [for name in local.worker_keys : aws_instance.k0s_node[name]]
}

output "worker_instance_ids" {
  description = "k0s worker EC2 instance IDs only"
  value       = [for name in local.worker_keys : aws_instance.k0s_node[name].id]
}

output "instance_ids" {
  description = "All k0s EC2 instance IDs (controller + workers)"
  value = concat(
    [aws_instance.k0s_node["master"].id],
    [for name in local.worker_keys : aws_instance.k0s_node[name].id]
  )
}
