output "repository_urls" {
  description = "URLs de los repositorios ECR"
  value       = { for name, repo in aws_ecr_repository.main : name => repo.repository_url }
}

output "repository_arns" {
  description = "ARNs de los repositorios ECR"
  value       = { for name, repo in aws_ecr_repository.main : name => repo.arn }
}
