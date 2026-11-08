variable "aws_region" {
  description = "Región de AWS donde se desplegará la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Nombre del entorno (dev, prod)"
  type        = string
}

variable "project_name" {
  description = "Nombre del proyecto para prefijar recursos"
  type        = string
  default     = "unsa-matricula"
}

variable "eks_cluster_role_arn" {
  description = "ARN del rol LabEksClusterRole de AWS Academy"
  type        = string
}

variable "eks_node_role_arn" {
  description = "ARN del rol LabEksNodeRole de AWS Academy"
  type        = string
}
