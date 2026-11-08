# ==========================================
# CLÚSTER DE EKS
# ==========================================
resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-${var.environment}-cluster"
  version  = var.kubernetes_version
  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids = var.private_subnet_ids
  }

  # Habilitar logs del control plane (opcional, ayuda a depurar)
  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  tags = {
    Name = "${var.project_name}-${var.environment}-cluster"
  }
}

# ==========================================
# NODE GROUP
# ==========================================
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-${var.environment}-nodes"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  instance_types = [var.node_instance_type]

  # Configuración de disco
  disk_size = 20

  # Actualización sin downtime
  update_config {
    max_unavailable = 1
  }

  # Etiquetas para los nodos
  labels = {
    role = "worker"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-nodes"
  }

  depends_on = [aws_eks_cluster.main]
}
