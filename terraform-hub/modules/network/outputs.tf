output "vpc_id" {
  value = aws_vpc.this.id
}

output "private_subnet_ids" {
  value = local.use_grouped_private_subnets ? concat(
    local.k8s_private_subnet_ids,
    local.observability_private_subnet_ids
  ) : local.legacy_private_subnet_ids
}

output "public_subnet_ids" {
  value = [
    for name in local.public_subnet_order :
    aws_subnet.public[name].id
  ]
}

output "k8s_private_subnet_ids" {
  value = local.k8s_private_subnet_ids
}

output "observability_subnet_ids" {
  value = local.observability_private_subnet_ids
}

output "private_route_table_id" {
  value = aws_route_table.private.id
}
