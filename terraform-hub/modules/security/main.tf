locals {
  vpn_cidrs = var.vpn_cidr == null ? [] : [var.vpn_cidr]
}

resource "aws_security_group" "k0s" {
  name   = "k0s-staging-sg"
  vpc_id = var.vpc_id

  dynamic "ingress" {
    for_each = local.vpn_cidrs
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "SSH from VPN clients"
    }
  }

  dynamic "ingress" {
    for_each = local.vpn_cidrs
    content {
      from_port   = 6443
      to_port     = 6443
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "Kubernetes API from VPN clients"
    }
  }

  dynamic "ingress" {
    for_each = local.vpn_cidrs
    content {
      from_port   = -1
      to_port     = -1
      protocol    = "icmp"
      cidr_blocks = [ingress.value]
      description = "ICMP from VPN clients"
    }
  }

  # Internal cluster traffic
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "openvpn" {
  name   = "openvpn-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "alb" {
  name   = "alb-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from the internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "observability" {
  name   = "observability-staging-sg"
  vpc_id = var.vpc_id

  dynamic "ingress" {
    for_each = local.vpn_cidrs
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "SSH from VPN clients"
    }
  }

  dynamic "ingress" {
    for_each = local.vpn_cidrs
    content {
      from_port   = -1
      to_port     = -1
      protocol    = "icmp"
      cidr_blocks = [ingress.value]
      description = "ICMP from VPN clients"
    }
  }

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Grafana from the ALB"
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Prometheus from VPC workloads"
  }

  ingress {
    from_port   = 3100
    to_port     = 3100
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Loki from VPC workloads"
  }

  ingress {
    from_port   = 3200
    to_port     = 3200
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Tempo query API from VPC workloads"
  }

  ingress {
    from_port   = 4317
    to_port     = 4318
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Tempo OTLP from VPC workloads"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "eks_control_plane" {
  count  = var.eks_cluster_security_group_id == null ? 0 : 1
  name   = "eks-control-plane-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "eks_nodes" {
  count  = var.eks_cluster_security_group_id == null ? 0 : 1
  name   = "eks-nodes-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "eks_api_from_vpn" {
  count = (
    var.vpn_cidr != null && var.eks_cluster_security_group_id != null
  ) ? 1 : 0

  type      = "ingress"
  protocol  = "tcp"
  from_port = 443
  to_port   = 443

  cidr_blocks       = [var.vpn_cidr]
  security_group_id = var.eks_cluster_security_group_id

  description = "Allow kubectl access to EKS private endpoint from VPN"
}
