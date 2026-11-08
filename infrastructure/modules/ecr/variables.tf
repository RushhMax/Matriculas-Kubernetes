variable "project_name" {
  description = "Nombre del proyecto para prefijar recursos"
  type        = string
}

variable "environment" {
  description = "Nombre del entorno (dev, prod)"
  type        = string
}

variable "repository_names" {
  description = "Lista de nombres de repositorios ECR a crear"
  type        = list(string)
  default     = ["backend", "frontend"]
}
