# Despliegue del proyecto en AWS

## Resumen

Sí es posible desplegar el proyecto en AWS sin reescribir la aplicación. Existen dos rutas:

| Alternativa | Cuándo elegirla | Tiempo estimado | Complejidad |
|---|---|---:|---|
| **EC2 + k3s** | El docente pide AWS y Kubernetes, pero no exige EKS | 3–5 horas | Baja–media |
| **Amazon EKS Auto Mode** | El docente exige explícitamente EKS o Kubernetes administrado | 6–10 horas | Media–alta |

La alternativa más rápida es crear una instancia EC2, instalar k3s y desplegar los cuatro
componentes actuales. La alternativa académicamente más fuerte es EKS Auto Mode.

> Los tiempos presuponen que la cuenta AWS está habilitada, se poseen permisos IAM y no hay
> restricciones de AWS Academy. Si se necesita solicitar permisos, el tiempo puede aumentar.

---

## Alternativa A — Implementación simple: EC2 + k3s

### Qué demuestra

- El sistema se ejecuta realmente en AWS.
- Kubernetes administra frontend, backend, PostgreSQL y Redis.
- Se conservan Deployments, StatefulSet, Services, HPA, probes, PVC y CronJob.
- Se pueden repetir las pruebas de carga, self-healing y persistencia.
- Se obtiene una IP pública accesible durante la exposición.

### Qué no demuestra

- No utiliza el control plane administrado de EKS.
- Existe un solo nodo, por lo que demuestra fallas de Pods, no tolerancia a la pérdida del nodo.
- El almacenamiento se encuentra en el volumen EBS de la instancia, no en una arquitectura
  PostgreSQL altamente disponible.

### Infraestructura mínima

```text
Internet
   |
   v
IP publica EC2
   |
   v
Traefik incluido en k3s
   |
   v
Frontend -> Backend -> PostgreSQL / Redis
                         |
                         v
                    Volumen EBS
```

Para la aplicación base se recomienda una instancia con al menos 4 GiB de RAM. Si se desea
ejecutar simultáneamente Prometheus y Grafana, es preferible disponer de 8 GiB. Una instancia
micro suele ser insuficiente para todos los componentes y una prueba de carga.

### Reglas de seguridad

El Security Group debería permitir únicamente:

| Puerto | Origen | Uso |
|---:|---|---|
| 22 | Solo la IP del expositor | SSH |
| 80 | Internet o IPs autorizadas | Aplicación |
| 443 | Internet o IPs autorizadas | HTTPS opcional |

No se deben exponer directamente 3000, 5432 ni 6379.

### Procedimiento resumido

1. Crear una instancia Ubuntu o Amazon Linux en EC2.
2. Asociar un volumen EBS suficiente para imágenes, datos y backups.
3. Instalar k3s:

   ```bash
   curl -sfL https://get.k3s.io | sh -
   sudo kubectl get nodes
   ```

4. Publicar las imágenes en Amazon ECR o construirlas dentro de EC2.
5. Cambiar las imágenes de los Deployments para usar ECR.
6. Aplicar los manifiestos Kubernetes.
7. Instalar Metrics Server si la distribución no lo proporciona listo para el HPA.
8. Acceder mediante la IP pública y ejecutar las pruebas desde la computadora local.
9. Guardar capturas de EC2, ECR, Pods, HPA, PVC y resultados k6.
10. Terminar la instancia y eliminar recursos al finalizar la evaluación.

### Tiempo estimado

| Actividad | Tiempo |
|---|---:|
| Crear EC2, red y Security Group | 30–45 min |
| Instalar y comprobar k3s | 20–40 min |
| Crear ECR y publicar imágenes | 30–60 min |
| Adaptar y desplegar manifiestos | 45–90 min |
| Corregir acceso, almacenamiento y HPA | 30–60 min |
| Ejecutar pruebas y tomar evidencias | 45–90 min |
| **Total razonable** | **3–5 horas** |

Se recomienda reservar medio día para contar con margen de solución de problemas.

---

## Alternativa B — Implementación recomendada: Amazon EKS Auto Mode

### Arquitectura

```text
Usuarios
   |
   v
AWS Application Load Balancer
   |
   v
Amazon EKS Auto Mode
   |
   +-- Frontend Deployment
   +-- Backend Deployment + HPA
   +-- PostgreSQL StatefulSet + EBS
   +-- Redis Deployment
   +-- CronJob + EBS de backups
```

EKS Auto Mode administra elementos como capacidad de cómputo, networking, balanceo y
almacenamiento. La documentación oficial se encuentra en:

- [Amazon EKS Auto Mode](https://docs.aws.amazon.com/eks/latest/userguide/automode.html)
- [Creación rápida de un clúster Auto Mode](https://docs.aws.amazon.com/eks/latest/userguide/automode-get-started-console.html)

### Requisitos de cuenta e IAM

Se necesita una cuenta AWS, AWS Academy Learner Lab o perfil con permisos para:

- EKS.
- EC2 y Auto Scaling.
- VPC, subredes y Security Groups.
- IAM y creación/asociación de roles.
- ECR.
- EBS.
- Elastic Load Balancing.
- CloudFormation si se utiliza `eksctl`.

Comprobación local:

```powershell
aws --version
eksctl version
kubectl version --client
helm version
aws sts get-caller-identity
```

### Imágenes en Amazon ECR

Los nodos EKS no pueden utilizar las imágenes almacenadas únicamente en Docker Desktop.
Se necesitan dos repositorios:

```text
unsa-matricula-backend
unsa-matricula-frontend
```

Creación:

```powershell
aws ecr create-repository `
  --repository-name unsa-matricula-backend `
  --region <REGION>

aws ecr create-repository `
  --repository-name unsa-matricula-frontend `
  --region <REGION>
```

Autenticación:

```powershell
aws ecr get-login-password --region <REGION> |
docker login --username AWS --password-stdin `
  <ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com
```

Backend:

```powershell
docker build --provenance=false `
  --build-arg APP_VERSION=aws-v1 `
  -t unsa-matricula-backend:aws-v1 ./backend

docker tag unsa-matricula-backend:aws-v1 `
  <ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/unsa-matricula-backend:aws-v1

docker push `
  <ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/unsa-matricula-backend:aws-v1
```

Frontend:

```powershell
docker build --provenance=false `
  -t unsa-matricula-frontend:aws-v1 ./frontend

docker tag unsa-matricula-frontend:aws-v1 `
  <ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/unsa-matricula-frontend:aws-v1

docker push `
  <ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/unsa-matricula-frontend:aws-v1
```

Los Deployments deberán apuntar a esas direcciones y utilizar tags inmutables.

### Almacenamiento con Amazon EBS

En EKS Auto Mode se puede crear un StorageClass `gp3` cifrado:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: auto-ebs-sc
provisioner: ebs.csi.eks.amazonaws.com
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: gp3
  encrypted: "true"
```

Los PVC de PostgreSQL y backups deben declarar:

```yaml
storageClassName: auto-ebs-sc
```

Documentación oficial:

- [Almacenamiento EBS para Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html)
- [Quickstart de persistencia EBS en Auto Mode](https://docs.aws.amazon.com/eks/latest/userguide/quickstart.html)

### Acceso mediante Application Load Balancer

Para una demostración AWS completa se recomienda:

```text
Internet -> ALB -> Ingress -> frontend-service
```

Se puede emplear la integración de EKS Auto Mode o AWS Load Balancer Controller. El
Ingress producirá un nombre DNS similar a:

```text
k8s-unsa-xxxxxxxx.<REGION>.elb.amazonaws.com
```

La prueba de carga se ejecutaría así:

```powershell
k6 run `
  -e BASE_URL=http://<DNS-DEL-ALB>/api `
  load-tests/k6.js
```

Referencia oficial:

- [Application Load Balancers en Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html)

### Observabilidad

Se puede conservar el stack actual:

- Metrics Server para HPA y `kubectl top`.
- Prometheus para series temporales.
- Grafana para dashboards.

También se puede añadir CloudWatch Container Insights, aunque no es obligatorio para la
entrega y genera recursos adicionales.

### Tiempo estimado

| Actividad | Tiempo |
|---|---:|
| Revisar cuenta, cuotas y permisos IAM | 30–90 min |
| Crear EKS Auto Mode y configurar kubectl | 30–60 min |
| Crear ECR y publicar imágenes | 30–60 min |
| Crear overlay AWS y StorageClass EBS | 60–120 min |
| Configurar ALB/Ingress | 60–120 min |
| Desplegar y diagnosticar workloads | 60–150 min |
| Repetir HPA, fallas y persistencia | 60–120 min |
| Actualizar informe y evidencias | 45–90 min |
| **Total razonable** | **6–10 horas** |

Para alguien que despliega EKS por primera vez, se recomienda reservar un día completo.

---

## PostgreSQL y Redis: proyecto académico frente a producción

Para conservar el requisito de cuatro contenedores durante la evaluación:

- Frontend en EKS.
- Backend en EKS.
- PostgreSQL en StatefulSet con EBS.
- Redis en Deployment.

En un entorno productivo sería preferible:

- PostgreSQL en Amazon RDS.
- Redis en Amazon ElastiCache.
- Credenciales en AWS Secrets Manager.
- Backups mediante snapshots y políticas administradas.

Durante la presentación se puede explicar esta diferencia como una decisión académica:
PostgreSQL y Redis permanecen en Kubernetes para demostrar StatefulSet, PVC, Services y
persistencia.

---

## Organización recomendada de manifiestos

No se deberían sobrescribir los manifiestos locales. Se recomienda Kustomize:

```text
k8s/
├── base/
└── overlays/
    ├── local/
    └── aws/
```

El overlay AWS modificaría:

- Imágenes ECR.
- StorageClass EBS.
- Ingress/ALB.
- Host público.
- Requests y limits adecuados a los nodos.
- Secrets o integración con Secrets Manager.

Despliegue:

```powershell
kubectl apply -k k8s/overlays/aws
```

---

## Evidencias que deben recogerse en AWS

Para demostrar que no se trata de un despliegue local:

1. Clúster EKS o instancia EC2 en la consola AWS.
2. Repositorios e imágenes de ECR.
3. Nodos de Kubernetes con direcciones y zona AWS.
4. DNS del Load Balancer.
5. Volúmenes EBS creados por los PVC.
6. HPA escalando de 2 a 5 Pods.
7. Pods distribuidos y reemplazados.
8. Persistencia después de recrear PostgreSQL.
9. Resultados k6.
10. Dashboard Grafana o métricas de CloudWatch.

Comandos principales:

```powershell
kubectl get nodes -o wide
kubectl get all,ingress,hpa,pvc -n unsa-matricula
kubectl get storageclass
kubectl top nodes
kubectl top pods -n unsa-matricula
```

---

## Costos y eliminación de recursos

Amazon EKS cobra una tarifa por hora por cada clúster, además de EC2, EBS, Load Balancer,
IPv4 pública, transferencia y cargos adicionales de Auto Mode. La tarifa publicada para un
clúster bajo soporte estándar es USD 0.10 por hora; se debe consultar siempre la página
vigente de [precios de Amazon EKS](https://aws.amazon.com/eks/pricing/).

Después de la exposición se debe eliminar, en este orden:

1. Ingress y Services `LoadBalancer`.
2. Aplicación y PVC, si ya se respaldaron las evidencias.
3. Stack Prometheus/Grafana.
4. Clúster EKS o instancia EC2.
5. Load Balancers que pudieran quedar activos.
6. Volúmenes y snapshots EBS no requeridos.
7. Elastic IPs sin asociar.
8. Repositorios ECR si no se conservarán.
9. Verificar Cost Explorer y Resource Explorer.

> Eliminar únicamente el clúster sin revisar EBS y Load Balancers puede dejar recursos con
> cobro activo.

---

## Recomendación final

- Si el docente dice solamente **“debe estar en AWS”**, utilizar **EC2 + k3s**. Cumple AWS,
  Kubernetes, cuatro contenedores y las pruebas, con menos riesgo y tiempo.
- Si dice **“debe utilizar Amazon EKS”**, utilizar **EKS Auto Mode** y reservar un día.
- No migrar PostgreSQL a RDS antes de la evaluación si es obligatorio demostrar cuatro
  contenedores y StatefulSet.
- Crear la infraestructura uno o dos días antes, ejecutar las pruebas, guardar evidencia y
  apagar/eliminar recursos después de la presentación.

## Información necesaria antes de implementarlo

Para iniciar el despliegue se debe definir:

1. Cuenta AWS o AWS Academy disponible.
2. Si el requisito exige EKS o solo AWS.
3. Región autorizada.
4. Presupuesto o créditos disponibles.
5. Permisos IAM efectivos.
6. Tiempo durante el cual debe permanecer público.

