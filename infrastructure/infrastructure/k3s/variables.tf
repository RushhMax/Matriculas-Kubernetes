variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "subnet_id" {
  type        = string
  description = "Subred publica existente"
}

variable "instance_profile_name" {
  type        = string
  description = "Instance Profile autorizado para EC2 y SSM"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "allowed_http_cidr" {
  type        = string
  description = "IP publica autorizada en formato /32"
}
