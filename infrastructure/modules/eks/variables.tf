variable "project_name" {
  description = "Nombre del proyecto para prefijar recursos"
  type        = string
}

variable "environment" {
  description = "Nombre del entorno (dev, prod)"
  type        = string
}

variable "cluster_role_arn" {
  description = "ARN del rol de IAM para el Control Plane de EKS (LabEksClusterRole)"
  type        = string
}

variable "node_role_arn" {
  description = "ARN del rol de IAM para los nodos de EKS (LabEksNodeRole)"
  type        = string
}

variable "kubernetes_version" {
  description = "Versión de Kubernetes para el clúster"
  type        = string
  default     = "1.31"
}

variable "node_instance_type" {
  description = "Tipo de instancia EC2 para los nodos"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Número deseado de nodos"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Número mínimo de nodos"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Número máximo de nodos"
  type        = number
  default     = 3
}

variable "private_subnet_ids" {
  description = "IDs de las subredes privadas donde se desplegarán los nodos"
  type        = list(string)
}
