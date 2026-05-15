variable "name" {
  type        = string
  description = "Application Load Balancer name"
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type        = list(string)
  description = "Public subnets for the ALB"
}

variable "alb_sg_id" {
  type = string
}

variable "listener_port" {
  type    = number
  default = 80
}

variable "listener_protocol" {
  type    = string
  default = "HTTP"
}

variable "target_port" {
  type        = number
  description = "Backend NodePort exposed by the Kubernetes ingress"
}

variable "target_protocol" {
  type    = string
  default = "HTTP"
}

variable "health_check_path" {
  type    = string
  default = "/"
}

variable "health_check_matcher" {
  type        = string
  description = "Expected HTTP codes for ALB health checks"
  default     = "200"
}

variable "instance_ids" {
  type        = list(string)
  description = "Kubernetes EC2 instance IDs attached behind the ALB"
}
