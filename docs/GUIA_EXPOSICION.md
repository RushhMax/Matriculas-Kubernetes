# Guía de exposición — UNSA Matrícula Kubernetes

## Preparación (10 minutos antes)

```powershell
kubectl get nodes
kubectl get pods -n unsa-matricula
kubectl top pods -n unsa-matricula
Invoke-RestMethod http://localhost/api/health
```

Abrir:

1. `http://localhost` en el navegador.
2. Una terminal con `powershell -File scripts/dashboard.ps1`.
3. Una terminal con `kubectl get pods -n unsa-matricula -w`.
4. Una terminal con `kubectl get hpa -n unsa-matricula -w`.

## Guion recomendado (12–15 minutos)

### 1. Problema y arquitectura — 2 minutos

> En matrícula existe una concentración extrema de tráfico. Diseñamos la aplicación para
> que los componentes web sean reemplazables y escalables, mientras PostgreSQL conserva el
> estado en un volumen persistente. Kubernetes, no la aplicación, es el protagonista.

Mostrar la opción **7 — Arquitectura** del dashboard.

### 2. Aplicación, balanceo y Redis — 2 minutos

- Ingresar como estudiante y mostrar cursos/vacantes.
- Abrir `http://localhost/cluster?demo=1`.
- Ejecutar las opciones **2** y **3** del dashboard.
- Explicar `served_by`, `db` y `cache`.

### 3. HPA — 3 minutos

```powershell
powershell -File scripts/run-hpa-experiment.ps1 -MaxVus 120 -CpuMs 30
```

Se debe observar `2 → 4 → 5` Pods. Resultados ya comprobados:

- 21 670 solicitudes HTTP.
- 154.69 solicitudes/s.
- p95 de 1.06 s.
- 0 % de errores.
- CPU máxima observada de 495 % respecto al request.

### 4. Self-healing y persistencia — 3 minutos

En el dashboard:

- Opción **4**: eliminar un backend.
- Opción **5**: registrar dato, eliminar PostgreSQL y verificarlo.

Resultados medidos: reemplazo del backend en 30.94 s y recuperación de PostgreSQL en 7 s,
con la matrícula conservada.

### 5. Liveness, rolling update y backup — 3 minutos

```powershell
powershell -File scripts/run-resilience-experiments.ps1
powershell -File scripts/run-rolling-experiment.ps1
```

Explicar la diferencia:

- Readiness retira temporalmente un Pod del Service.
- Liveness reinicia el contenedor cuando `/health` falla reiteradamente.
- Deployment reemplaza Pods durante rolling update con `maxUnavailable: 0`.
- StatefulSet mantiene identidad; PVC mantiene los datos.
- CronJob conserva los dumps en un PVC diferente.

### 6. Observabilidad y cierre — 2 minutos

```powershell
kubectl port-forward -n monitoring svc/monitoring-grafana 3001:80
```

Abrir `http://localhost:3001`. Usuario `admin`, contraseña `unsa-grafana-demo`.

> La evidencia muestra escalabilidad, tolerancia a fallos y persistencia como propiedades
> medibles. La aplicación puede cambiar; la arquitectura y los experimentos son reutilizables.

## Preguntas frecuentes del docente

**¿Por qué StatefulSet para PostgreSQL?**  Porque necesita identidad y almacenamiento
estable; las réplicas HTTP no.

**¿Por qué un Service?**  Los Pods cambian de IP. El Service entrega identidad y selección
estable mediante labels.

**¿Cómo calcula HPA 50 %?**  Compara el uso medido con el `request` de CPU, no con el límite.

**¿Secret cifra la contraseña?**  No por sí solo; desacopla configuración y acceso. En
producción se usaría cifrado en etcd y un gestor externo.

**¿Redis es fuente de verdad?**  No. Puede perderse; PostgreSQL sigue siendo la fuente
transaccional.

**¿Qué pasa si se cae el nodo único?**  El laboratorio demuestra fallas de Pod. Alta
disponibilidad ante falla de nodo requiere un clúster multinodo y almacenamiento replicado.
