# Proyecto Final de Unidad — Cloud Computing

## Tema propuesto
**Sistema de matrícula universitario escalable y tolerante a fallos sobre Kubernetes**

> Escenario hipotético inspirado en la UNSA.

La idea principal es que la aplicación de matrícula sea el **caso de negocio**, pero que el protagonista de la entrega sea **Kubernetes** y los recursos cloud-native que se puedan demostrar de forma visible, medible y justificable.

---

# 1. Arquitectura objetivo

La aplicación tendrá cuatro componentes principales:

- Frontend
- Backend / API
- PostgreSQL
- Redis

Arquitectura general:

```text
                     ESTUDIANTES
                         │
                         ▼
                      INGRESS
                         │
              ┌──────────┴──────────┐
              │                     │
              ▼                     ▼
        frontend-service       backend-service
              │                     │
              ▼                     ▼
        Frontend Pods          Backend Pods
          [F1]                  [B1][B2]
                                    │
                          ┌─────────┴─────────┐
                          ▼                   ▼
                     PostgreSQL            Redis
                    StatefulSet           Deployment
                         │
                         ▼
                        PVC
```

El backend debe poder tener varias réplicas para demostrar escalabilidad horizontal.

---

# 2. Recursos Kubernetes que deben mostrarse

| Recurso | Aplicación en el proyecto |
|---|---|
| **Namespace** | Aísla todos los recursos del proyecto `unsa-matricula` |
| **Deployment Frontend** | Administra las réplicas del frontend |
| **Deployment Backend** | Administra y recupera los Pods del backend |
| **StatefulSet PostgreSQL** | Mantiene la base de datos con identidad y almacenamiento persistente |
| **Deployment Redis** | Ejecuta la caché |
| **Service Frontend** | Permite acceder a los Pods del frontend |
| **Service Backend** | Permite que frontend encuentre al backend |
| **Service PostgreSQL** | Permite al backend encontrar la base de datos sin depender de IPs |
| **Service Redis** | Permite al backend encontrar Redis |
| **Ingress** | Punto de entrada HTTP al sistema |
| **ConfigMap** | Configuración no sensible |
| **Secret** | Password de BD y credenciales |
| **PVC** | Persistencia de PostgreSQL |
| **HPA** | Escala automáticamente el backend |
| **Liveness Probe** | Detecta procesos que dejaron de funcionar |
| **Readiness Probe** | Evita enviar tráfico a Pods que todavía no están preparados |
| **Requests / Limits** | Controla CPU y memoria por contenedor |
| **CronJob** | Backup programado de PostgreSQL |

Comandos útiles para mostrar durante la exposición:

```bash
kubectl get all -n unsa-matricula
```

```bash
kubectl get ingress,pvc,hpa,configmap,secret -n unsa-matricula
```

---

# 3. Los cuatro contenedores

## Frontend
Puede implementarse con React, Astro o Vue.

Debe mostrar al menos:

- Cursos disponibles
- Vacantes
- Acción de matricular
- Cursos matriculados

## Backend
Puede implementarse con FastAPI o Node.js.

Endpoints mínimos sugeridos:

```text
GET  /courses
GET  /courses/:id
POST /enrollments
GET  /students/:id/enrollments
GET  /health
GET  /ready
```

## PostgreSQL

Almacena:

- Estudiantes
- Cursos
- Matrículas
- Vacantes

## Redis

Debe tener una razón demostrable.

Ejemplo:

```text
GET /courses

Primera consulta
Backend → PostgreSQL → Redis

Consultas siguientes
Backend → Redis
```

Así se demuestra reducción de carga sobre la base de datos.

---

# 4. Demostraciones principales

## Demo 1 — Distribución entre réplicas

Iniciar con:

```text
Backend replicas = 2
```

Hacer que cada respuesta del backend indique algo como:

```text
served_by: backend-7c68...
```

Resultado esperado:

```text
Solicitud 1 → backend-pod-A
Solicitud 2 → backend-pod-B
Solicitud 3 → backend-pod-A
```

Esto demuestra:

- Service
- Distribución entre réplicas
- Balanceo interno

---

# 5. Demo 2 — Escalamiento automático

Estado inicial:

```text
Backend

[B1] [B2]
```

Generar carga con k6:

```text
50 usuarios
↓
200
↓
500
```

Con el aumento de CPU, el HPA debería reaccionar:

```text
[B1][B2]

    ↓

[B1][B2][B3]

    ↓

[B1][B2][B3][B4][B5]
```

Comandos útiles:

```bash
kubectl get hpa -w
```

```bash
kubectl get pods -w
```

Registrar:

- Usuarios concurrentes
- Requests/segundo
- Latencia promedio
- Latencia p95
- Errores
- CPU
- Réplicas

---

# 6. Demo 3 — Tolerancia a fallos

Con tres réplicas:

```text
Backend

B1 ✅
B2 ✅
B3 ✅
```

Eliminar manualmente un Pod:

```bash
kubectl delete pod backend-xxxxx
```

Estado temporal:

```text
B1 ✅
B2 ❌
B3 ✅
```

Kubernetes detecta:

```text
Desired = 3
Current = 2
```

Luego crea automáticamente un nuevo Pod:

```text
B4 ✅
```

Resultado:

```text
B1 ✅
B3 ✅
B4 ✅
```

La aplicación debería seguir respondiendo durante la falla.

Esta demo demuestra:

- Deployment
- ReplicaSet
- Controller Manager
- Service
- Self-healing

---

# 7. Demo 4 — Readiness y Liveness

Backend:

```text
/health
/ready
```

Configuración sugerida:

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8000

readinessProbe:
  httpGet:
    path: /ready
    port: 8000
```

Interpretación:

- **Readiness:** ¿Este Pod ya puede recibir tráfico?
- **Liveness:** ¿Este Pod sigue funcionando correctamente?

Se puede provocar un fallo de `/health` para demostrar que Kubernetes reinicia el contenedor.

---

# 8. Demo 5 — Persistencia

Registrar una matrícula:

```text
Andrea → Cloud Computing → matriculada
```

Eliminar el Pod de PostgreSQL:

```bash
kubectl delete pod postgres-0
```

PostgreSQL se vuelve a levantar.

Luego se vuelve a consultar:

```text
Andrea → Cloud Computing → matriculada
```

Los datos deben seguir existiendo gracias al:

```text
PersistentVolumeClaim
```

Mensaje clave:

> Pod ≠ datos. El Pod puede morir; la información permanece.

---

# 9. Demo 6 — ConfigMaps y Secrets

No hardcodear datos sensibles.

## ConfigMap

```text
DB_HOST
DB_PORT
REDIS_HOST
ENVIRONMENT
```

## Secret

```text
DB_USER
DB_PASSWORD
```

Mensaje clave:

> Separamos configuración, código y secretos.

---

# 10. Demo 7 — Requests y Limits

Ejemplo para el backend:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

Comando útil:

```bash
kubectl top pods
```

Esto permite explicar:

- Cuánto recurso necesita cada Pod
- Cuánto puede consumir como máximo
- Relación con HPA
- Relación con cgroups

---

# 11. Plus fuerte — Rolling Update

Partir de:

```text
Backend v1
```

Actualizar a:

```text
Backend v2
```

Durante el despliegue deberían convivir temporalmente:

```text
v1
v1
v2
v1
v2
v2
v2
```

Comandos:

```bash
kubectl rollout status deployment/backend
```

Si algo falla:

```bash
kubectl rollout undo deployment/backend
```

Esto demuestra:

- Actualización progresiva
- Sin tumbar todo el servicio
- Rollback

---

# 12. Plus recomendado — Backup con CronJob

Flujo:

```text
CronJob
   ↓
cada X minutos / horas
   ↓
pg_dump
   ↓
backup
```

Para demo puede ejecutarse cada pocos minutos.

Comandos:

```bash
kubectl get cronjobs
```

```bash
kubectl get jobs
```

Esto demuestra que Kubernetes también puede manejar cargas batch.

---

# 13. Observabilidad

## Nivel obligatorio

```text
kubectl top pods
kubectl top nodes
kubectl get hpa
kubectl describe pod
kubectl logs
```

Requiere Metrics Server.

## Plus si hay tiempo

- Prometheus
- Grafana

Dashboard sugerido:

- CPU backend
- RAM backend
- Número de Pods
- Requests/segundo
- Latencia

Demo ideal:

```text
k6 genera carga
       ↓
CPU sube
       ↓
HPA escala
       ↓
Pods aparecen
```

Si Grafana muestra esto en tiempo real, la demostración gana mucho valor.

---

# 14. Distribución entre 4 integrantes

| Integrante | Área | Aplicación | Kubernetes | Demostración |
|---|---|---|---|---|
| **1. Frontend + entrada** | Experiencia usuario | Frontend | Deployment, Service, Ingress, ConfigMap | Acceso y distribución |
| **2. Backend + escalamiento** | Lógica | API matrícula | Deployment, requests/limits, probes, HPA | Estrés + autoscaling |
| **3. Datos + persistencia** | Datos | PostgreSQL + Redis | StatefulSet, PVC, Secret, Redis Service, CronJob | Persistencia + backup |
| **4. Plataforma + resiliencia** | DevOps / Cloud | Integración | Namespace, Metrics Server, rollout, scripts k6, observabilidad | Fallos + rolling update |

---

# 15. Integrante 1 — Frontend + Networking

Debe entregar:

```text
Frontend funcional
Dockerfile
frontend Deployment
frontend Service
Ingress
ConfigMap
```

Debe saber explicar:

```text
Usuario
↓
Ingress
↓
Service
↓
Frontend Pod
↓
Backend Service
```

Su demo:

> Acceso externo y comunicación entre servicios.

---

# 16. Integrante 2 — Backend + Autoscaling

Debe entregar:

```text
API
Dockerfile
Deployment
Service
health endpoint
ready endpoint
requests / limits
HPA
```

Su demo principal:

```text
k6
↓
CPU aumenta
↓
HPA
↓
2 → 5 réplicas
```

---

# 17. Integrante 3 — PostgreSQL + Redis + Persistencia

Debe encargarse de:

```text
PostgreSQL StatefulSet
PVC
Secret
Redis
schema
seed
backup CronJob
```

Su demo:

```text
crear matrícula
↓
eliminar PostgreSQL Pod
↓
Pod vuelve
↓
matrícula sigue existiendo
```

Luego mostrar el backup.

---

# 18. Integrante 4 — DevOps + Resiliencia + Métricas

Debe integrar:

```text
Namespace
Metrics Server
k6
scripts de prueba
kubectl top
rolling update
rollback
fallos
documentación de experimentos
```

Su demo:

```text
elimina Backend Pod
↓
Kubernetes lo reemplaza

Backend v1
↓ rolling update
Backend v2

↓ si falla
rollback
```

---

# 19. Todos deben entender la arquitectura

Aunque cada integrante tenga una responsabilidad principal, todos deben poder explicar:

```text
API Server
Scheduler
Controller Manager
etcd
kubelet
Container Runtime
kube-proxy
```

Y también:

```text
Usuario
↓
Ingress
↓
Frontend
↓
Backend
↓
PostgreSQL / Redis
```

---

# 20. Tabla de experimentos

| Prueba | Estado inicial | Acción | Qué observamos | Evidencia |
|---|---|---|---|---|
| Estrés | 2 Pods | 500 VUs k6 | CPU/latencia suben | k6 + métricas |
| Escalabilidad | min=2 | carga CPU | 2 → N Pods | HPA |
| Falla | 3 Pods | delete Pod | se crea reemplazo | `get pods -w` |
| Persistencia | PostgreSQL activo | delete Pod | datos permanecen | consulta |
| Health | Pod sano | provocar fallo | reinicio | events |
| Rolling Update | v1 | deploy v2 | reemplazo gradual | rollout |

---

# 21. Qué recursos deberían verse en la exposición

Comando principal:

```bash
kubectl get all -n unsa-matricula
```

El profesor debería poder ver algo parecido a:

```text
pod/frontend-...
pod/backend-...
pod/backend-...
pod/postgres-0
pod/redis-...

service/frontend
service/backend
service/postgres
service/redis

deployment/frontend
deployment/backend
deployment/redis

statefulset/postgres
```

Luego:

```bash
kubectl get ingress,hpa,pvc,configmap,secret,cronjob -n unsa-matricula
```

---

# 22. Objetivo técnico del proyecto

> **Implementar y evaluar una arquitectura cloud-native para un sistema de matrícula universitario utilizando Kubernetes, demostrando escalabilidad horizontal, tolerancia a fallos, persistencia, gestión de configuración y despliegues sin interrupción mediante experimentos controlados.**

---

# 23. Prioridades

## Nivel 1 — Obligatorio y debe funcionar perfecto

```text
Docker
Frontend
Backend
PostgreSQL
Redis
Deployments / StatefulSet
Services
Ingress
PVC
HPA
Stress test
Self-healing
```

## Nivel 2 — Para subir bastante la nota

```text
Readiness / Liveness
Requests / Limits
ConfigMaps / Secrets
Metrics Server
Rolling Update
Rollback
CronJob backup
```

## Nivel 3 — Solo si lo anterior ya está terminado

```text
Prometheus
Grafana
NetworkPolicy
CI/CD con GitHub Actions
```

---

# 24. Demo final ideal

La mejor demostración sería encadenar todo:

```text
1. Sistema estable con 2 Pods backend
                 ↓
2. Lanzamos k6
                 ↓
3. CPU aumenta
                 ↓
4. HPA escala 2 → 5
                 ↓
5. Seguimos enviando solicitudes
                 ↓
6. Eliminamos manualmente un Pod
                 ↓
7. Sistema continúa respondiendo
                 ↓
8. Kubernetes crea otro Pod
                 ↓
9. Detenemos k6
                 ↓
10. HPA reduce nuevamente réplicas
```

Mientras una terminal muestra:

```bash
kubectl get pods -w
```

y otra:

```bash
kubectl get hpa -w
```

Si además se puede visualizar CPU y latencia en una gráfica o Grafana, mejor.

---

# 25. Enfoque final

La prioridad no debe ser agregar muchas funcionalidades al sistema de matrícula.

La prioridad debe ser demostrar de manera visible, medible y justificable:

- Escalabilidad
- Tolerancia a fallos
- Self-healing
- Persistencia
- Configuración cloud-native
- Gestión de recursos
- Rolling updates
- Observabilidad
- Automatización

La aplicación es el escenario.

**Kubernetes es el verdadero protagonista del proyecto.**
