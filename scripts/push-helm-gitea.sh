#!/usr/bin/env bash
# FILE_NAME: push-helm-gitea.sh
# DESCRIPTION: Package Backstage Helm chart and push to Gitea Helm package registry
# VERSION: 0.1.0
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHART_DIR="${ROOT}/charts/backstage"
DIST_DIR="${ROOT}/charts/dist"

GITEA_HOST="${GITEA_HOST:-gitea.devzero.local:8443}"
GITEA_OWNER="${GITEA_OWNER:-giteaAdmin}"
GITEA_USER="${GITEA_USER:-giteaAdmin}"
GITEA_PASS="${GITEA_PASS:-ChangeMeLabOnlyGitea}"
# Optional: resolve hostname to loopback when running outside cluster DNS
GITEA_RESOLVE="${GITEA_RESOLVE:-gitea.devzero.local:8443:127.0.0.1}"

mkdir -p "${DIST_DIR}"

echo "[T-01] helm lint ${CHART_DIR}"
helm lint "${CHART_DIR}"

echo "[T-02] helm package → ${DIST_DIR}"
# Remove prior packages for this chart name/version to avoid clutter
rm -f "${DIST_DIR}/backstage-"*.tgz
helm package "${CHART_DIR}" -d "${DIST_DIR}"

CHART_TGZ="$(ls -1t "${DIST_DIR}"/backstage-*.tgz | head -1)"
echo "[T-03] packaged ${CHART_TGZ}"

PUSH_URL="https://${GITEA_HOST}/api/packages/${GITEA_OWNER}/helm/api/charts"
echo "[T-04] POST ${PUSH_URL}"

CURL_ARGS=(
  -sk
  --user "${GITEA_USER}:${GITEA_PASS}"
  -X POST
  --upload-file "${CHART_TGZ}"
  "${PUSH_URL}"
)
if [[ -n "${GITEA_RESOLVE}" ]]; then
  CURL_ARGS+=(--resolve "${GITEA_RESOLVE}")
fi

HTTP_CODE="$(curl "${CURL_ARGS[@]}" -w '%{http_code}' -o /tmp/helm-push-body.txt)"
BODY="$(cat /tmp/helm-push-body.txt 2>/dev/null || true)"
echo "[T-05] HTTP ${HTTP_CODE} ${BODY}"

if [[ "${HTTP_CODE}" != "201" && "${HTTP_CODE}" != "200" ]]; then
  echo "[DBG-001] Helm chart push failed" >&2
  exit 1
fi

echo "[T-06] verify package listing"
curl -sk --resolve "${GITEA_RESOLVE}" --user "${GITEA_USER}:${GITEA_PASS}" \
  "https://${GITEA_HOST}/api/v1/packages/${GITEA_OWNER}?type=helm&q=backstage" \
  | tee /tmp/helm-packages.json
echo

echo "[T-07] helm repo add / search (optional smoke)"
REPO_URL="https://${GITEA_HOST}/api/packages/${GITEA_OWNER}/helm"
LAB_CA="${LAB_CA:-$(cd "${ROOT}/../.." && pwd)/clusters/lab/certs/ca.crt}"
# Prefer lab CA; fall back to skip-verify for kind/lab TLS
HELM_TLS_ARGS=()
if [[ -f "${LAB_CA}" ]]; then
  HELM_TLS_ARGS+=(--ca-file "${LAB_CA}")
else
  HELM_TLS_ARGS+=(--insecure-skip-tls-verify)
fi
if getent hosts gitea.devzero.local >/dev/null 2>&1 || grep -q 'gitea.devzero.local' /etc/hosts 2>/dev/null; then
  helm repo add --force-update \
    --username "${GITEA_USER}" --password "${GITEA_PASS}" \
    "${HELM_TLS_ARGS[@]}" \
    gitea-lab "${REPO_URL}"
  helm repo update gitea-lab >/dev/null
  helm search repo gitea-lab/backstage
else
  echo "[T-07] skip helm repo add (gitea.devzero.local not in hosts); package push OK"
fi

echo "[OK] Chart ${CHART_TGZ##*/} → ${REPO_URL}"
echo "[OK] UI: https://${GITEA_HOST}/${GITEA_OWNER}/-/packages/helm/backstage/$(helm show chart "${CHART_DIR}" | awk '/^version:/{print $2}')"
