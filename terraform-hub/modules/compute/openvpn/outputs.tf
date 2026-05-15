output "eni_id" {
  value = aws_instance.this.primary_network_interface_id
}

output "private_ip" {
  value = aws_instance.this.private_ip
}

output "public_ip" {
  value = aws_instance.this.public_ip
}
