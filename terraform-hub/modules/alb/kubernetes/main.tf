# =========================
# Kubernetes Application Load Balancer
# =========================
resource "aws_lb" "this" {
  name               = var.name
  load_balancer_type = "application"
  internal           = false

  subnets         = var.subnet_ids
  security_groups = [var.alb_sg_id]
}

resource "aws_lb_target_group" "this" {
  name_prefix = "k0s-"
  port        = var.target_port
  protocol    = var.target_protocol
  vpc_id      = var.vpc_id
  target_type = "instance"

  lifecycle {
    create_before_destroy = true
  }

  health_check {
    path    = var.health_check_path
    matcher = var.health_check_matcher
  }
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.listener_port
  protocol          = var.listener_protocol

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

resource "aws_lb_target_group_attachment" "instance" {
  count = length(var.instance_ids)

  target_group_arn = aws_lb_target_group.this.arn
  target_id        = var.instance_ids[count.index]
  port             = var.target_port
}
