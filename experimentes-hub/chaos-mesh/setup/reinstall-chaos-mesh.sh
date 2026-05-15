#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SETUP_DIR="${ROOT_DIR}/chaos-mesh/setup"
INSTALL_SCRIPT="${SETUP_DIR}/install-chaos-mesh.sh"
NAMESPACE="${NAMESPACE:-chaos-mesh}"
RELEASE="${RELEASE:-chaos-mesh}"
INGRESS_FILE="${INGRESS_FILE:-$ROOT_DIR/chaos-mesh/ingress.yaml}"
NAMESPACE_DELETE_TIMEOUT_SECONDS="${NAMESPACE_DELETE_TIMEOUT_SECONDS:-120}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[ERROR] Missing command: $1" >&2
    exit 1
  fi
}

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "[ERROR] Missing file: $1" >&2
    exit 1
  fi
}

wait_for_namespace_deletion() {
  local elapsed=0

  while kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; do
    if [[ "$elapsed" -ge "$NAMESPACE_DELETE_TIMEOUT_SECONDS" ]]; then
      echo "[ERROR] Timed out waiting for namespace $NAMESPACE to be deleted." >&2
      exit 1
    fi

    sleep 2
    elapsed=$((elapsed + 2))
  done
}

require_cmd kubectl
require_cmd helm
require_file "$INSTALL_SCRIPT"
require_file "$INGRESS_FILE"

echo "[INFO] Reinstalling Chaos Mesh..."

kubectl delete -f "$INGRESS_FILE" --ignore-not-found=true >/dev/null 2>&1 || true
helm uninstall "$RELEASE" --namespace "$NAMESPACE" --wait >/dev/null 2>&1 || true
kubectl delete namespace "$NAMESPACE" --ignore-not-found=true --wait=false >/dev/null 2>&1 || true

wait_for_namespace_deletion

bash "$INSTALL_SCRIPT"
