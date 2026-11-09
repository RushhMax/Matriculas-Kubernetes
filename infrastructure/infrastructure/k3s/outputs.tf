output "instance_id" {
  value = aws_instance.k3s.id
}

output "public_ip" {
  value = aws_instance.k3s.public_ip
}

output "private_ip" {
  value = aws_instance.k3s.private_ip
}

output "security_group_id" {
  value = aws_security_group.k3s.id
}
