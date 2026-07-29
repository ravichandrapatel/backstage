#!/usr/bin/env bash
# FILE_NAME: build-push-gitea.sh
# DESCRIPTION: Build separate FE/BE images and push ONLY to lab Gitea registry
# VERSION: 0.1.1
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
# shellcheck disable=SC1091
[ -s "${NVM_DIR}/nvm.sh" ] && . "${NVM_DIR}/nvm.sh"
nvm use 22 >/dev/null 2>&1 || nvm use 22.23.1 >/dev/null 2>&1 || true
export PATH="$(dirname "$(command -v node)"):/usr/local/bin:/usr/bin:/bin"

# OCI registry paths must be lowercase (Gitea owner folder ≠ login username)
REGISTRY="${REGISTRY:-gitea.devzero.local:8443}"
OWNER="${OWNER:-giteaadmin}"
TAG="${TAG:-$(git rev-parse --short HEAD 2>/dev/null || echo latest)}"
FRONTEND_IMAGE="${REGISTRY}/${OWNER}/backstage-frontend:${TAG}"
BACKEND_IMAGE="${REGISTRY}/${OWNER}/backstage-backend:${TAG}"
FRONTEND_LATEST="${REGISTRY}/${OWNER}/backstage-frontend:latest"
BACKEND_LATEST="${REGISTRY}/${OWNER}/backstage-backend:latest"

GITEA_USER="${GITEA_USER:-giteaAdmin}"
GITEA_PASS="${GITEA_PASS:-ChangeMeLabOnlyGitea}"

# Avoid broken DOCKER_HOST from WSL/desktop leftovers
unset DOCKER_HOST || true

echo "[T-01] Yarn install + TypeScript + package builds"
YARN_ENABLE_IMMUTABLE_INSTALLS=false node .yarn/releases/yarn-4.13.0.cjs install
node .yarn/releases/yarn-4.13.0.cjs tsc
node .yarn/releases/yarn-4.13.0.cjs build:backend
node .yarn/releases/yarn-4.13.0.cjs workspace app build

echo "[T-02] Build backend image (local) ${BACKEND_IMAGE}"
DOCKER_BUILDKIT=1 docker build \
  -f packages/backend/Dockerfile \
  -t "${BACKEND_IMAGE}" \
  -t "${BACKEND_LATEST}" \
  .

echo "[T-03] Build frontend image (local) ${FRONTEND_IMAGE}"
DOCKER_BUILDKIT=1 docker build \
  -f packages/app/Dockerfile \
  -t "${FRONTEND_IMAGE}" \
  -t "${FRONTEND_LATEST}" \
  .

echo "[T-04] Auth + push ONLY to Gitea registry via crane (lab CA)"
CA_FILE="${CA_FILE:-${ROOT}/../clusters/lab/certs/ca.crt}"
if [ ! -f "${CA_FILE}" ]; then
  CA_FILE="${ROOT}/clusters/lab/certs/ca.crt"
fi
BUNDLE="$(mktemp)"
cat /etc/ssl/certs/ca-certificates.crt "${CA_FILE}" > "${BUNDLE}"
export SSL_CERT_FILE="${BUNDLE}"
export CURL_CA_BUNDLE="${BUNDLE}"
trap 'rm -f "${BUNDLE}"' EXIT

if ! command -v crane >/dev/null 2>&1; then
  echo "crane is required to push past the self-signed lab cert (install google/go-containerregistry crane)" >&2
  exit 1
fi
crane auth login "${REGISTRY}" -u "${GITEA_USER}" -p "${GITEA_PASS}"

# crane 0.20.x has no docker-daemon transport — save tar then push
TMPDIR_PUSH="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_PUSH}" "${BUNDLE}"' EXIT

push_one() {
  local local_ref="$1"
  local remote_ref="$2"
  echo "[T-05] Push ${remote_ref}"
  docker save "${local_ref}" -o "${TMPDIR_PUSH}/img.tar"
  crane push "${TMPDIR_PUSH}/img.tar" "${remote_ref}"
  rm -f "${TMPDIR_PUSH}/img.tar"
}

push_one "${BACKEND_IMAGE}" "${BACKEND_IMAGE}"
push_one "${BACKEND_LATEST}" "${BACKEND_LATEST}"
push_one "${FRONTEND_IMAGE}" "${FRONTEND_IMAGE}"
push_one "${FRONTEND_LATEST}" "${FRONTEND_LATEST}"

echo
echo "Pushed (Gitea only):"
echo "  ${BACKEND_IMAGE}"
echo "  ${BACKEND_LATEST}"
echo "  ${FRONTEND_IMAGE}"
echo "  ${FRONTEND_LATEST}"
