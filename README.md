# UNSA Matrícula — Kubernetes

Sistema de matrícula universitario escalable desplegado sobre Kubernetes.
Escenario hipotético inspirado en la UNSA — Cloud Computing S10.

## Componentes

| Servicio   | Tecnología        | Puerto |
|------------|-------------------|--------|
| Frontend   | Vue 3 + Nginx     | 80     |
| Backend    | Node + Express    | 3000   |
| PostgreSQL | postgres:15       | 5432   |
| Redis      | redis:7           | 6379   |

---

## 1. Requisitos previos

Instalar las siguientes herramientas antes de continuar:

| Herramienta | Link de descarga | Versión usada |
|-------------|-----------------|---------------|
| Docker Desktop (con Kubernetes) | https://www.docker.com/products/docker-desktop/ | 29.x |
| kubectl | Viene incluido con Docker Desktop | v1.36+ |
| Helm | https://helm.sh/docs/intro/install/ | v3/v4 |
| k6 (pruebas de carga) | https://grafana.com/docs/k6/latest/set-up/install-k6/ | latest |

### Habilitar Kubernetes en Docker Desktop

1. Abrir Docker Desktop
2. Ir a **Settings → Kubernetes**
3. Marcar **Enable Kubernetes**
4. Click **Apply & Restart**
5. Esperar a que el ícono de Kubernetes en la barra inferior quede en verde

Verificar que todo está activo:
```powershell
docker --version
kubectl get nodes
# Debe mostrar: desktop-control-plane   Ready
```

---

## 2. Ejecutar con Docker Compose (desarrollo local rápido)

```powershell
# Desde la raíz del proyecto
docker compose up --build

# Acceder en: http://localhost
# API en:     http://localhost:3000
```

Para detener y limpiar volúmenes:
```powershell
docker compose down -v
```

---

## 3. Desplegar en Kubernetes (Docker Desktop)

### 3.1 Instalar Traefik Ingress Controller (una sola vez)

```powershell
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm upgrade --install traefik traefik/traefik `
  --namespace traefik --create-namespace --wait
```

### 3.2 Instalar Metrics Server (una sola vez, necesario para HPA)

```powershell
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

> **Importante — Docker Desktop requiere un paso extra:**
> El metrics-server necesita el flag `--kubelet-insecure-tls` porque el certificado del kubelet es autofirmado.
> Exportar, editar y re-aplicar:

```powershell
# Exportar el deployment
kubectl get deployment metrics-server -n kube-system -o yaml > metrics-server-patch.yaml
```

Abrir `metrics-server-patch.yaml` y en la sección `args:` agregar la línea `- --kubelet-insecure-tls` al final de los argumentos:

```yaml
      containers:
      - args:
        - --cert-dir=/tmp
        - --secure-port=10250
        - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
        - --kubelet-use-node-status-port
        - --metric-resolution=15s
        - --kubelet-insecure-tls    # <-- agregar esta línea
```

```powershell
kubectl apply -f metrics-server-patch.yaml

# Verificar que funciona (esperar ~30 segundos)
kubectl top nodes
# Debe mostrar CPU y memoria del nodo
```

### 3.3 Instalar K9s — dashboard visual del cluster (recomendado)

K9s es una UI en terminal que permite ver pods, logs, métricas y eventos en tiempo real. Muy útil para la presentación.

**Windows (opción 1 — winget):**
```powershell
winget install derailed.k9s
```

**Windows (opción 2 — descarga directa):**
1. Ir a https://github.com/derailed/k9s/releases/latest
2. Descargar `k9s_Windows_amd64.zip`
3. Extraer `k9s.exe` a una carpeta en el PATH (ej. `C:\Windows\System32`)

**Verificar instalación:**
```powershell
k9s version
```

**Uso básico:**
```powershell
# Abrir K9s apuntando al namespace del proyecto
k9s --namespace unsa-matricula
```

Comandos dentro de K9s:
- `:pods` — ver pods
- `:hpa` — ver HPA y réplicas actuales
- `:events` — ver eventos del cluster
- `l` sobre un pod — ver logs en vivo
- `d` sobre un pod — describir pod
- `ctrl+d` sobre un pod — eliminarlo (para demo de self-healing)

### 3.4 Construir imágenes locales

> **Importante:** usar `--provenance=false` para evitar que Docker cree un manifest list
> (índice multi-arquitectura) que Kubernetes no puede resolver con imágenes locales.

```powershell
docker build --provenance=false --build-arg APP_VERSION=demo-v1.2.0 -t unsa-matricula-backend:demo-v1.2.0 ./backend
docker build --provenance=false -t unsa-matricula-frontend:demo-v1.2.1 ./frontend
```

### 3.4 Aplicar todos los manifests

```powershell
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/
```

### 3.5 Acceso local

La configuración incluye una regla local y funciona directamente en:

```text
http://localhost
```

Opcionalmente, abrir **PowerShell como Administrador** y ejecutar:

```powershell
Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value "127.0.0.1 unsa.local"
```

En Linux/Mac:
```bash
echo "127.0.0.1 unsa.local" | sudo tee -a /etc/hosts
```

### 3.6 Verificar que todo está corriendo

```powershell
kubectl get all -n unsa-matricula
```

Resultado esperado:
- `pod/backend-xxx` → `1/1 Running` (2 réplicas)
- `pod/frontend-xxx` → `1/1 Running`
- `pod/postgres-0` → `1/1 Running`
- `pod/redis-xxx` → `1/1 Running`

```powershell
kubectl get hpa -n unsa-matricula
# Debe mostrar: cpu: X%/50%  (no <unknown>)

kubectl get ingress -n unsa-matricula
# Debe mostrar ADDRESS asignado
```

Acceder en: **http://localhost** o **http://unsa.local** si se configuró `hosts`.

---

## 4. Solución de problemas comunes

### Al reconstruir la imagen, el pod sigue con la versión vieja

Kubernetes cachea el tag `latest` en containerd y no lo actualiza aunque Docker lo reconstruya.
Solución: usar un tag nuevo en cada rebuild:

```powershell
docker build --provenance=false -t unsa-matricula-frontend:demo-v1.2.2 ./frontend
kubectl set image deployment/frontend frontend=unsa-matricula-frontend:demo-v1.2.2 -n unsa-matricula
# Actualizar también k8s/frontend-deployment.yaml con el nuevo tag
```

---

### `ErrImageNeverPull` en pods de backend/frontend

Docker Desktop a veces almacena imágenes como manifest lists que Kubernetes no puede resolver.
Solución: reconstruir con `--provenance=false`:

```powershell
docker build --provenance=false --build-arg APP_VERSION=demo-v1.2.0 -t unsa-matricula-backend:demo-v1.2.0 ./backend
docker build --provenance=false -t unsa-matricula-frontend:demo-v1.2.1 ./frontend
kubectl rollout restart deployment/backend deployment/frontend -n unsa-matricula
```

### HPA muestra `cpu: <unknown>/50%`

El metrics-server no está instalado o no tiene el flag `--kubelet-insecure-tls`.
Seguir el paso 3.2 completo.

### El Ingress no responde en http://unsa.local

Verificar que:
1. El Ingress Controller está corriendo: `kubectl get pods -n traefik`
2. La entrada en hosts está guardada: `cat C:\Windows\System32\drivers\etc\hosts`
3. El Ingress tiene ADDRESS asignado: `kubectl get ingress -n unsa-matricula`

---

## 5. Demos Kubernetes para la presentación

### Demo 1 — Distribución entre réplicas

La navbar muestra el pod que respondió cada request. Recargar varias veces y observar que cambia entre `backend-xxx-yyy` y `backend-xxx-zzz`.

```powershell
kubectl get pods -n unsa-matricula -w
```

---

### Demo 2 — Escalamiento automático (HPA)

Abrir 3 terminales en paralelo:

```powershell
# Terminal 1: observar HPA
kubectl get hpa -n unsa-matricula -w

# Terminal 2: observar pods
kubectl get pods -n unsa-matricula -w

# Terminal 3: lanzar carga
k6 run load-tests/k6.js
```

El HPA escalará el backend de 2 a 5 réplicas cuando la CPU supere 50%.

---

### Demo 3 — Tolerancia a fallos (Self-healing)

```powershell
# Ver pods del backend
kubectl get pods -n unsa-matricula -l app=backend

# Eliminar uno mientras el sistema recibe tráfico
kubectl delete pod <nombre-del-pod> -n unsa-matricula

# Observar cómo Kubernetes crea uno nuevo automáticamente
kubectl get pods -n unsa-matricula -w
```

---

### Demo 4 — Persistencia de datos

```powershell
# 1. Registrar una matrícula en el frontend
# 2. Eliminar el pod de PostgreSQL
kubectl delete pod postgres-0 -n unsa-matricula

# 3. Esperar a que vuelva (StatefulSet lo recrea automáticamente)
kubectl get pods -n unsa-matricula -w

# 4. Verificar que los datos siguen en el frontend
```

---

### Demo 5 — CronJob Backup

```powershell
kubectl get cronjobs -n unsa-matricula
kubectl get jobs -n unsa-matricula
```

---

### Demo 6 — Rolling Update sin downtime

```powershell
# Hacer un cambio en el backend y reconstruir
docker build --provenance=false --build-arg APP_VERSION=demo-v2.0.0 -t unsa-matricula-backend:demo-v2.0.0 ./backend
kubectl set image deployment/backend backend=unsa-matricula-backend:demo-v2.0.0 -n unsa-matricula
kubectl rollout status deployment/backend -n unsa-matricula

# Si algo falla, rollback en un comando:
kubectl rollout undo deployment/backend -n unsa-matricula
```

---

## 6. Pruebas de carga con k6

```powershell
# Contra docker-compose (desarrollo)
k6 run load-tests/k6.js

# Contra Kubernetes
k6 run -e BASE_URL=http://localhost/api load-tests/k6.js
```

Métricas que registra:
- `request_success_rate` — disponibilidad de la API durante la carga
- `api_latency_ms` — latencia de `/load` y `/courses`
- `errors` — contador de errores

La prueba funcional de matrícula se ejecuta por separado:

```powershell
k6 run -e BASE_URL=http://localhost/api load-tests/enrollment-smoke.js
```

---

## 7. Comandos útiles

```powershell
# Ver logs del backend
kubectl logs -l app=backend -n unsa-matricula --tail=50

# Ver consumo de recursos en tiempo real
kubectl top pods -n unsa-matricula

# Conectar a PostgreSQL directamente
kubectl exec -it postgres-0 -n unsa-matricula -- psql -U matricula -d matricula

# Ver eventos del namespace (útil para debug)
kubectl get events -n unsa-matricula --sort-by='.lastTimestamp'

# Ver todo el estado del cluster de un vistazo
kubectl get all,ingress,hpa,pvc,configmap,secret,cronjob -n unsa-matricula
```

---

## 8. Estructura del repositorio

```
proyecto1/
├── frontend/          # Vue 3 + Nginx
├── backend/           # Node + Express
├── database/          # schema.sql + seed.sql
├── k8s/               # Manifests de Kubernetes
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── backend-deployment.yaml
│   ├── backend-service.yaml
│   ├── frontend-deployment.yaml
│   ├── frontend-service.yaml
│   ├── postgres-statefulset.yaml
│   ├── postgres-service.yaml
│   ├── postgres-pvc.yaml
│   ├── postgres-initdb-configmap.yaml
│   ├── redis-deployment.yaml
│   ├── redis-service.yaml
│   ├── hpa.yaml
│   ├── ingress.yaml
│   └── cronjob-backup.yaml
├── load-tests/        # Scripts k6
├── scripts/           # Despliegue, dashboard y experimentos reproducibles
├── observability/     # Valores Helm de Prometheus/Grafana
├── docs/report/       # Informe LaTeX, capturas y evidencias
├── .github/workflows/ # CI y publicación de imágenes en GHCR
└── docker-compose.yml
```

---

## 9. Centro de demostración e informe

El dashboard de consola presenta arquitectura, Pods, HPA, métricas, eventos, diagnóstico y
acciones guiadas:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/dashboard.ps1
```

Para instalar Prometheus y Grafana:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/install-observability.ps1
kubectl port-forward -n monitoring svc/monitoring-grafana 3001:80
```

Grafana queda en `http://localhost:3001` con usuario `admin` y contraseña
`unsa-grafana-demo`.
