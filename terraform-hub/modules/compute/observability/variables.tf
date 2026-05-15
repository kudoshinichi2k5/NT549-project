variable "ami" {}
variable "instance_type" {}

variable "key_name" {
  description = "SSH key name (from keypair module)"
}

variable "subnet_ids" {}
variable "observability_sg_id" {}

variable "nodes" {
  description = "Static placement plan for observability and storage instances"
  type = map(object({
    subnet_index = number
    private_ip   = string
  }))
}
