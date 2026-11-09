#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
AVAILABLE_KB="$(df -Pk "$ROOT" | awk 'NR == 2 {print $4}')"
if (( AVAILABLE_KB < 1048576 )); then
  printf 'Falta espacio para construir imágenes. Libera al menos 1 GiB en la partición del proyecto.\n' >&2
  exit 1
fi
npm --prefix backend run lint
npm --prefix frontend run lint
npm --prefix backend test
npm --prefix frontend test
npm --prefix frontend run build
bash scripts/test-integration.sh
docker compose config --quiet
docker build -t unsa-matricula-backend:check ./backend
docker build -t unsa-matricula-frontend:check ./frontend
printf 'Calidad, integración y construcción de imágenes: OK\n'
