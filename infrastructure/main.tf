# ==========================================
# Módulo de Red (VPC, Subredes, NAT)
# ==========================================
module "network" {
  source = "./modules/network"

  project_name = var.project_name
  environment  = var.environment
}

# ==========================================
# Módulo de Registro de Imágenes (ECR)
# ==========================================
module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
  environment  = var.environment
}

# ==========================================
# Módulo de Cómputo (EKS)
# ==========================================
module "eks" {
  source = "./modules/eks"

  project_name        = var.project_name
  environment         = var.environment
  cluster_role_arn    = var.eks_cluster_role_arn
  node_role_arn       = var.eks_node_role_arn
  private_subnet_ids  = module.network.private_subnet_ids
}
