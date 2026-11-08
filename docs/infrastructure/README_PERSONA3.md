# Guía para la Persona 3 (Kubernetes)

## Estado actual

La infraestructura está lista:
- ✅ VPC creada
- ✅ Subredes públicas y privadas
- ✅ NAT Gateway
- ✅ Clúster EKS con 2 nodos `Ready`
- ✅ Repositorios ECR vacíos

## Lo que debes hacer

### 1. Conectarte al clúster

```bash
aws eks update-kubeconfig --region us-east-1 --name unsa-matricula-dev-cluster
kubectl get nodes
```

### 2. Verificar que el namespace existe

```bash
kubectl get namespace unsa-matricula
```

### 3. Desplegar la aplicación

```bash
cd k8s
kubectl apply -k overlays/aws/
```

### 4. Verificar el despliegue

```bash
kubectl get pods -n unsa-matricula
kubectl get svc -n unsa-matricula
kubectl get ingress -n unsa-matricula
```

### 5. Obtener la URL del Load Balancer

```bash
kubectl get ingress -n unsa-matricula
```

## Notas importantes

- Las imágenes deben estar en ECR antes de desplegar.
- La Persona 2 (CI/CD) se encargará de publicar las imágenes.
- Si el Ingress no funciona, verificar el AWS Load Balancer Controller.
