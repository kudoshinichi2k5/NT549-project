# ==================================================
# Network Module
# ==================================================
# This module provisions the base VPC networking:
# - VPC, subnets (public/private)
# - Internet Gateway and NAT Gateway
# - Route tables for internet and VPN connectivity
#
# Static network resources are provisioned via Terraform.
# Runtime-dependent VPN routing is intentionally separated
# to avoid Terraform late-binding dependency issues.
# ==================================================


# =================
# Subnet Strategy
# =================
locals {
  use_grouped_private_subnets = length(var.k8s_private_subnets) > 0 || length(var.observability_subnets) > 0

  public_subnet_order = [
    for idx, _ in var.public_subnets :
    format("public-subnet-%d", idx + 1)
  ]
  public_subnet_map = {
    for idx, cidr in var.public_subnets :
    local.public_subnet_order[idx] => {
      cidr = cidr
      az   = var.azs[idx % length(var.azs)]
    }
  }

  legacy_private_subnet_order = [
    for idx, _ in var.private_subnets :
    format("private-subnet-%d", idx + 1)
  ]
  legacy_private_subnet_map = {
    for idx, cidr in var.private_subnets :
    local.legacy_private_subnet_order[idx] => {
      cidr = cidr
      az   = var.azs[idx % length(var.azs)]
    }
  }

  k8s_private_subnet_order = [
    for idx, _ in var.k8s_private_subnets :
    format("private-k8s-%d", idx + 1)
  ]
  k8s_private_subnet_map = {
    for idx, cidr in var.k8s_private_subnets :
    local.k8s_private_subnet_order[idx] => {
      cidr = cidr
      az   = var.azs[idx % length(var.azs)]
    }
  }

  default_observability_subnet_names = [
    "private-observability",
    "private-logs-tracing",
    "private-storage",
  ]
  observability_subnet_order = [
    for idx, _ in var.observability_subnets :
    idx < length(local.default_observability_subnet_names)
    ? local.default_observability_subnet_names[idx]
    : format("private-observability-%d", idx + 1)
  ]
  observability_subnet_map = {
    for idx, cidr in var.observability_subnets :
    local.observability_subnet_order[idx] => {
      cidr = cidr
      az   = var.azs[idx % length(var.azs)]
    }
  }

  k8s_private_subnet_ids = [
    for name in local.k8s_private_subnet_order :
    aws_subnet.k8s_private[name].id
  ]
  observability_private_subnet_ids = [
    for name in local.observability_subnet_order :
    aws_subnet.observability_private[name].id
  ]
  legacy_private_subnet_ids = [
    for name in local.legacy_private_subnet_order :
    aws_subnet.private[name].id
  ]

  private_subnet_association_map = local.use_grouped_private_subnets ? merge(
    { for name, subnet in aws_subnet.k8s_private : name => subnet.id },
    { for name, subnet in aws_subnet.observability_private : name => subnet.id },
    ) : {
    for name, subnet in aws_subnet.private :
    name => subnet.id
  }
}

# =================
# Virtual Private Cloud
# =================
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "k0s-vpc"
  }
}

# =================
# Internet Gateway
# =================

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
}

# =================
# Private Subnets
# =================
resource "aws_subnet" "private" {
  for_each = local.use_grouped_private_subnets ? {} : local.legacy_private_subnet_map

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(
    {
      Name = each.key

      # Required for internal LB
      "kubernetes.io/role/internal-elb" = "1"
    },
    var.cluster_name != null ? {
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    } : {}
  )
}

resource "aws_subnet" "k8s_private" {
  for_each = local.use_grouped_private_subnets ? local.k8s_private_subnet_map : {}

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(
    {
      Name = each.key

      # Required for internal LB
      "kubernetes.io/role/internal-elb" = "1"
    },
    var.cluster_name != null ? {
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    } : {}
  )
}

resource "aws_subnet" "observability_private" {
  for_each = local.use_grouped_private_subnets ? local.observability_subnet_map : {}

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(
    {
      Name = each.key

      # Required for internal LB
      "kubernetes.io/role/internal-elb" = "1"
    },
    var.cluster_name != null ? {
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    } : {}
  )
}

# =================
# Public Subnets
# =================
resource "aws_subnet" "public" {
  for_each = local.public_subnet_map

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = merge(
    {
      Name = each.key

      # Required for public LB
      "kubernetes.io/role/elb" = "1"
    },
    var.cluster_name != null ? {
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    } : {}
  )
}

# ==================================
# Elastic IP - Fixed IP for NAT
# ==================================
resource "aws_eip" "nat" {
  domain = "vpc"
}

# ==================================
# NAT Gateway
# ==================================
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[local.public_subnet_order[0]].id

  depends_on = [aws_internet_gateway.this]
}

# ==================================================
# Public Route Table - 0.0.0.0 to Internet Gateway
# ==================================================
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}


# ==================================================
# Private Route Table
# ==================================================
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
}

# Default outbound route for private subnets (Internet access via NAT)
resource "aws_route" "private_to_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

#
resource "aws_route_table_association" "private" {
  for_each       = local.private_subnet_association_map
  subnet_id      = each.value
  route_table_id = aws_route_table.private.id
}
