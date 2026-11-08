# Persona 2: calidad, imágenes y entrega en AWS

## Entorno del equipo

- Cuenta AWS: `455290382075`.
- Región: `us-east-1`.
- ECR: `unsa-matricula-backend` y `unsa-matricula-frontend`.
- EKS existente: `unsa-matricula-dev-cluster`.
- Node.js 22.14 o superior, npm, Python 3, AWS CLI v2 y Docker con el comando `docker compose`.

No necesitas crear infraestructura ni ejecutar Terraform apply/destroy para publicar imágenes.
La autenticación ECR usa credenciales de la API; no usa archivos SSH `.pem`.

## 1. Preparar el equipo

AWS CLI se instaló para el usuario actual en `~/.local/bin/aws`. En una terminal donde
`aws` no esté disponible:

```bash
export PATH="$HOME/.local/bin:$PATH"
aws --version
```

Comprueba `docker info`, `docker compose version` y `docker context ls`. Tener el cliente
`docker` instalado no garantiza que el motor esté activo. Si ya usas Docker Desktop,
inicia su servicio y selecciona su contexto:

```bash
systemctl --user start docker-desktop
docker context use desktop-linux
docker info
```

No mezcles paquetes de Ubuntu (`docker.io`, `docker-compose-v2`) con los paquetes ya
instalados de Docker (`docker-ce-cli`, `docker-compose-plugin`): pueden entrar en conflicto
y retirar Docker Desktop. Para una instalación nueva consulta las instrucciones oficiales
de [Docker Desktop](https://docs.docker.com/desktop/setup/install/linux/ubuntu/) o
[Docker Engine](https://docs.docker.com/engine/install/ubuntu/), según el entorno elegido.

Desde la raíz del repositorio:

```bash
npm ci --prefix backend
npm ci --prefix frontend
```

## 2. Conectar con AWS Academy

Activa Start Lab, espera el indicador verde y abre AWS Details → AWS CLI → Show.
En tu terminal local, ejecuta:

```bash
python3 scripts/configure-aws-lab.py
```

Introduce solo el valor de cada credencial, sin `export` ni comillas. La entrada permanece
oculta. El asistente guarda el perfil `unsa-lab` con permisos de archivo 600 en
`~/.aws/credentials`, conserva otros perfiles y valida la cuenta esperada. No escribe claves
en el proyecto. Repite el asistente cuando las credenciales temporales caduquen.

```bash
aws sts get-caller-identity --profile unsa-lab
aws ecr describe-repositories --region us-east-1 --profile unsa-lab \
  --query 'repositories[].{Nombre:repositoryName,URI:repositoryUri}' --output table
```

La caducidad de credenciales no borra los recursos. El tiempo de sesión, presupuesto y
fin del curso son límites diferentes. Coordina el cierre del entorno con Persona 1.

La consulta del entorno del 8 de noviembre de 2026 devolvió EKS `1.31`. Esa versión está
en [soporte extendido](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html):
la [tarifa publicada](https://aws.amazon.com/eks/pricing/) es USD 0,60/h por el control plane,
equivalente a USD 14,40 por 24 horas, antes de nodos y red. Persona 1 debe revisar el
presupuesto y la estrategia de versión/cierre. Esto no es una medición de facturación real.

## 3. Ejecutar la calidad local

```bash
npm --prefix backend run lint
npm --prefix frontend run lint
npm --prefix backend test
npm --prefix frontend test
npm --prefix frontend run build
bash scripts/test-integration.sh
```

La integración inicia un proyecto Compose separado, `unsa-persona2-tests`, con datos
temporales, PostgreSQL en `127.0.0.1:55432` y Redis en `127.0.0.1:56379`.
Al salir elimina solo esos contenedores de prueba. No usa los volúmenes de la aplicación.
Puedes cambiar los puertos con `TEST_DB_PORT` y `TEST_REDIS_PORT` si están ocupados.

Se comprueban salud, readiness, errores de conexión, caché, matrícula válida, matrícula
duplicada, curso lleno, estudiante/curso inexistente y dos solicitudes simultáneas por
la última vacante. El frontend prueba selección y cierre de sesión y llamadas de matrícula.

Para ejecutar toda la verificación, incluyendo ambas imágenes Docker:

```bash
bash scripts/check-persona2.sh
```

El comando comprueba que haya al menos 1 GiB libre en la partición del proyecto antes
de comenzar. Reserva más margen si Docker Desktop guarda su disco virtual en otra partición.

Reportes: `backend/reports`, `backend/coverage` y `frontend/reports`. Están ignorados por Git;
el workflow los conserva como artefactos incluso cuando una prueba falla.

## 4. Publicar manualmente la primera versión

Confirma en un commit los archivos de código, scripts y workflow que se van a publicar.
El publicador exige que esos archivos estén sin modificaciones y etiqueta con el SHA completo
de ese commit. Un archivo local de notas fuera de esas rutas no bloquea la publicación.

```bash
bash scripts/publish-ecr.sh
```

El script verifica la cuenta y los repositorios, ejecuta todas las comprobaciones, inicia sesión
en ECR y publica las dos imágenes. No crea repositorios ni despliega en EKS.
Utiliza el perfil `unsa-lab` (o el nombre indicado en `AWS_PROFILE`) para evitar mezclarlo
con credenciales exportadas de otras cuentas.
La autenticación de Docker se guarda solo durante la publicación en un directorio temporal
con permisos 700 y archivo 600. El directorio se elimina al finalizar, incluso si falla el push.
Esto permite publicar aunque el gestor `pass` de Docker Desktop no esté inicializado.
Si falla una comprobación, termina antes de publicar. Si una publicación falla después de
publicar la otra imagen, corrige la causa y vuelve a ejecutar el mismo commit.

El resultado está en `artifacts/ecr-release.txt`: URI, SHA y digest de ambas imágenes.
Entrega ese archivo a Persona 3. No uses `latest` para una entrega reproducible.

## 5. Activar GitHub Actions

El workflow `.github/workflows/ci.yml` implementa:

1. Lint, pruebas unitarias e integración con PostgreSQL/Redis y build del frontend.
2. `terraform fmt -check`, `init -backend=false` y `validate`, sin aplicar recursos.
3. Construcción de ambas imágenes. Estos jobs requieren los dos anteriores en verde.
4. Publicación a ECR únicamente para main/master, después de integrar los cambios.
5. CD opcional al EKS existente con comprobación de rollout y smoke test.

En Settings → Secrets and variables → Actions del repositorio, configura:

- Secret `AWS_ACCESS_KEY_ID`.
- Secret `AWS_SECRET_ACCESS_KEY`.
- Secret `AWS_SESSION_TOKEN`.

Son los valores vigentes de Academy. El perfil de tu computadora no se transfiere al runner.
Actualiza los tres secrets cuando caduquen. El workflow verifica también la cuenta AWS.
No se utilizan secrets en los jobs de publicación de pull requests.

Si tienes GitHub CLI instalado, ya ejecutaste `gh auth login` con tu cuenta y puedes
administrar los secrets de ese repositorio, puedes copiarlos desde el perfil local sin
mostrarlos ni pasarlos como argumentos de consola:

```bash
python3 scripts/configure-github-secrets.py
```

El asistente verifica primero la cuenta AWS y envía cada valor por la entrada estándar
de `gh secret set`. Si no tienes esos permisos, Persona 1 debe configurar los secrets.

El problema de facturación de Actions debe resolverlo el propietario del repositorio.
La publicación manual permite continuar con AWS mientras se resuelve, pero no constituye
evidencia de una ejecución de GitHub Actions.

Configura protección de main para exigir los checks del workflow antes de integrar.
Para demostrar que una prueba fallida bloquea la entrega, usa un PR temporal: cambia una
expectativa de salud para que falle, conserva el enlace al run fallido, restaura la prueba
y conserva el run verde. No integres la expectativa incorrecta.

## 6. Coordinar CD con Persona 3

El overlay AWS existente requiere correcciones de Persona 3 antes de habilitar CD:

- `resources: ../../` no constituye una base Kustomize válida actualmente. Organizar una base
  con su kustomization y una referencia sin el ciclo actual.
- El parche apunta a `unsa-matricula-ingress` y el recurso base se llama `unsa-ingress`.
- El Ingress base tiene clase `traefik`; alinear la clase con el controlador de AWS.
- Revisar la ruta `/api`: el Nginx frontend quita ese prefijo, el backend no lo quita.
- Verificar almacenamiento/PVC, secretos, controlador de ingreso, permisos y Metrics Server.

Después de corregirlo, Persona 3 puede renderizar la versión exacta sin aplicar nada:

```bash
python3 scripts/deploy-ecr.py --tag SHA_COMPLETO > /tmp/unsa-release.yaml
```

El script crea un overlay temporal, fija ambos tags ECR y conserva los manifiestos originales.
Para aplicar una versión publicada, con el contexto EKS correcto y la plataforma preparada:

```bash
aws eks update-kubeconfig --profile unsa-lab --region us-east-1 \
  --name unsa-matricula-dev-cluster
AWS_PROFILE=unsa-lab python3 scripts/deploy-ecr.py --tag SHA_COMPLETO --deploy
```

Se comprueba el contexto, se aplica la versión, se espera el rollout y se valida readiness
con el SHA esperado y la consulta de cursos a través del frontend. Este smoke test usa un
túnel temporal; Persona 3 debe comprobar también el acceso externo por Ingress.

Cuando ese procedimiento funcione, configura la variable de repositorio
`ENABLE_EKS_DEPLOY=true`. Hasta entonces el job deploy permanece deshabilitado para no
interferir con la preparación de plataforma. El runner necesita acceso de red y permisos
Kubernetes sobre el clúster. Para rollback puede aplicarse un SHA anterior que siga en ECR.

## 7. Evidencias que cierran la tarea

- PR y commits del cambio.
- Reportes unitarios e integración, incluido el caso concurrente de última vacante.
- Un CI verde y un CI bloqueado por prueba fallida.
- Imágenes ECR con tags SHA y sus digests.
- Cambio integrado → publicación → rollout → smoke test, una vez habilitado CD.
- Evidencia conjunta de rolling update/rollback con Persona 3.

No marcar como completado un paso externo solamente porque exista su script.
