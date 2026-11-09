#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
COMPOSE=(docker compose -p unsa-persona2-tests -f compose.test.yml)
docker info >/dev/null
# This project contains only disposable test services; it never uses application volumes.
trap '"${COMPOSE[@]}" down --volumes' EXIT
"${COMPOSE[@]}" up -d --wait --wait-timeout 90
DB_HOST=127.0.0.1 DB_PORT="${TEST_DB_PORT:-55432}" \
DB_USER=matricula DB_PASSWORD=test-only-password DB_NAME=matricula_test \
REDIS_HOST=127.0.0.1 REDIS_PORT="${TEST_REDIS_PORT:-56379}" REDIS_DB=15 \
ALLOW_TEST_DB_RESET=yes npm --prefix backend run test:integration
