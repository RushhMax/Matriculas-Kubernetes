# ==========================================
# REPOSITORIOS ECR
# ==========================================
resource "aws_ecr_repository" "main" {
  for_each = toset(var.repository_names)

  name                 = "${var.project_name}-${each.value}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-${each.value}"
  }
}

# ==========================================
# POLÍTICA DE CICLO DE VIDA (limpiar imágenes viejas)
# ==========================================
resource "aws_ecr_lifecycle_policy" "main" {
  for_each   = toset(var.repository_names)
  repository = aws_ecr_repository.main[each.value].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Mantener solo las últimas 10 imágenes"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
