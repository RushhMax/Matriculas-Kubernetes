#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export PATH="$HOME/.local/bin:$PATH"
export AWS_PAGER=""
REGION=us-east-1
EXPECTED_ACCOUNT=455290382075
AWS_ARGS=(--region "$REGION" --profile "${AWS_PROFILE:-unsa-lab}")
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
command -v aws >/dev/null || { printf 'Falta AWS CLI v2.\n' >&2; exit 1; }
docker info >/dev/null
if [[ -n "$(git status --porcelain -- backend frontend database scripts .github compose.test.yml)" ]]; then
  printf 'Confirma tus cambios versionados en un commit antes de publicar.\n' >&2
  exit 1
fi
TAG="$(git rev-parse HEAD)"
ACCOUNT="$(aws "${AWS_ARGS[@]}" sts get-caller-identity --query Account --output text)"
[[ "$ACCOUNT" == "$EXPECTED_ACCOUNT" ]] || { printf 'Cuenta incorrecta: %s\n' "$ACCOUNT" >&2; exit 1; }
REGISTRY="${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"
for COMPONENT in backend frontend; do
  aws "${AWS_ARGS[@]}" ecr describe-repositories --repository-names "unsa-matricula-$COMPONENT" >/dev/null
done
# All checks must pass before either image is published.
bash scripts/check-persona2.sh
# ECR needs only a short-lived token. Keep it separate from the user's credential helper.
DOCKER_ENDPOINT="${DOCKER_HOST:-$(docker context inspect --format '{{.Endpoints.docker.Host}}')}"
AUTH_CONFIG_DIR="$(mktemp -d /tmp/unsa-ecr-auth.XXXXXX)"
chmod 700 "$AUTH_CONFIG_DIR"
printf '{"auths":{}}\n' > "$AUTH_CONFIG_DIR/config.json"
chmod 600 "$AUTH_CONFIG_DIR/config.json"
cleanup_auth() {
  python3 -c 'import shutil,sys; shutil.rmtree(sys.argv[1])' "$AUTH_CONFIG_DIR"
}
trap cleanup_auth EXIT
AUTH_DOCKER=(docker --config "$AUTH_CONFIG_DIR" --host "$DOCKER_ENDPOINT")
aws "${AWS_ARGS[@]}" ecr get-login-password |
  "${AUTH_DOCKER[@]}" login --username AWS --password-stdin "$REGISTRY"
for COMPONENT in backend frontend; do
  docker build --build-arg "APP_VERSION=$TAG" \
    -t "$REGISTRY/unsa-matricula-$COMPONENT:$TAG" "./$COMPONENT"
done
mkdir -p artifacts
: > artifacts/ecr-release.txt
for COMPONENT in backend frontend; do
  IMAGE="$REGISTRY/unsa-matricula-$COMPONENT:$TAG"
  "${AUTH_DOCKER[@]}" push "$IMAGE"
  DIGEST="$(aws "${AWS_ARGS[@]}" ecr describe-images --repository-name "unsa-matricula-$COMPONENT" --image-ids "imageTag=$TAG" --query 'imageDetails[0].imageDigest' --output text)"
  printf '%s\nDigest: %s\n' "$IMAGE" "$DIGEST" | tee -a artifacts/ecr-release.txt
done
printf 'Entrega artifacts/ecr-release.txt a la Persona 3.\n'
