#!/usr/bin/env bash
set -euo pipefail

# Resolve paths once so the script can be run from any directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
EXPERIMENTS_DIR="${SCRIPT_DIR}/../experiments"
USAGE_FILE="${SCRIPT_DIR}/run-chaos.usage.txt"
CHAOS_ENV_FILE_DEFAULT="${REPO_DIR}/chaos-mesh/.env.chaos"
CHAOS_ENV_FILE="${CHAOS_ENV_FILE:-${CHAOS_ENV_FILE_DEFAULT}}"
BASELINE_DURATION="${BASELINE_DURATION:-30s}"
WARMUP_DURATION="${WARMUP_DURATION:-60s}"
RECOVERY_DURATION="${RECOVERY_DURATION:-60s}"
CHAOS_DURATION_OVERRIDE="${CHAOS_DURATION:-}"
RUN_LOAD="${RUN_LOAD:-false}"
LOAD_TEST_DIR="${LOAD_TEST_DIR:-${REPO_DIR}/load-testing}"
LOAD_RUN_SCRIPT="${LOAD_RUN_SCRIPT:-${LOAD_TEST_DIR}/scripts/run-user-journey.sh}"
LOAD_ENV_FILE="${LOAD_ENV_FILE:-${LOAD_TEST_DIR}/scripts-k6/.env.k6}"
MANIFEST=""
TARGET_SERVICE=""
FAULT_FAMILY=""
CLEANED_UP="false"
LOAD_PID=""
MANIFEST_CLEANED_UP="false"

load_env_file() {
  local env_file="$1"

  if [[ ! -f "${env_file}" ]]; then
    return 0
  fi

  set -a
  # shellcheck disable=SC1090
  source "${env_file}"
  set +a
}

log() {
  printf '[chaos][%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[chaos][ERROR] Missing command: $1" >&2
    exit 1
  fi
}

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "[chaos][ERROR] Missing file: $1" >&2
    exit 1
  fi
}

bool_is_true() {
  local value="${1:-false}"
  case "${value,,}" in
    1|true|yes|on)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

wait_phase() {
  local phase="$1"
  local duration="$2"

  if [[ "${duration}" == "0" || "${duration}" == "0s" ]]; then
    log "${phase}: skipped"
    return 0
  fi

  log "${phase}: waiting ${duration}"
  sleep "${duration}"
}

stop_load() {
  if [[ -z "${LOAD_PID}" ]]; then
    return 0
  fi

  if [[ -n "${LOAD_PID}" ]] && kill -0 "${LOAD_PID}" >/dev/null 2>&1; then
    log "stopping managed load pid=${LOAD_PID}"
    kill -INT "${LOAD_PID}" >/dev/null 2>&1 || true
    wait "${LOAD_PID}" >/dev/null 2>&1 || true
  fi

  LOAD_PID=""
}

cleanup_manifest() {
  if [[ "${MANIFEST_CLEANED_UP}" == "true" ]]; then
    return 0
  fi

  if [[ -n "${MANIFEST}" && -f "${MANIFEST}" ]]; then
    log "cleaning up manifest: ${MANIFEST}"
    kubectl delete -f "${MANIFEST}" --ignore-not-found=true >/dev/null 2>&1 || true
  fi

  MANIFEST_CLEANED_UP="true"
}

cleanup() {
  if [[ "${CLEANED_UP}" == "true" ]]; then
    return 0
  fi

  stop_load
  cleanup_manifest
  CLEANED_UP="true"
}

trap cleanup EXIT INT TERM

usage() {
  require_file "${USAGE_FILE}"
  sed -n '1,$p' "${USAGE_FILE}"
}

start_load() {
  if ! bool_is_true "${RUN_LOAD}"; then
    log "managed load: disabled"
    return 0
  fi

  require_cmd bash
  require_file "${LOAD_RUN_SCRIPT}"
  require_file "${LOAD_ENV_FILE}"

  log "managed load: starting"
  log "load_test_dir=${LOAD_TEST_DIR}"
  log "load_run_script=${LOAD_RUN_SCRIPT}"
  log "load_env_file=${LOAD_ENV_FILE}"

  (
    cd "${LOAD_TEST_DIR}"
    K6_ENV_FILE="${LOAD_ENV_FILE}" K6_WEB_DASHBOARD="${K6_WEB_DASHBOARD:-false}" bash "${LOAD_RUN_SCRIPT}"
  ) &
  LOAD_PID="$!"

  log "managed load pid=${LOAD_PID}"
}

wait_for_load() {
  local load_exit=0

  if [[ -z "${LOAD_PID}" ]]; then
    return 0
  fi

  log "waiting for managed load pid=${LOAD_PID}"

  wait "${LOAD_PID}" || load_exit=$?

  LOAD_PID=""
  return "${load_exit}"
}

reset_manifest() {
  log "resetting previous experiment state"
  kubectl delete -f "${MANIFEST}" --ignore-not-found=true >/dev/null 2>&1 || true
  sleep 2
  MANIFEST_CLEANED_UP="false"
}

EXPERIMENT_NAME="${1:-}"
if [[ -z "${EXPERIMENT_NAME}" ]]; then
  usage
  exit 1
fi

require_cmd kubectl
load_env_file "${CHAOS_ENV_FILE}"

BASELINE_DURATION="${BASELINE_DURATION:-30s}"
WARMUP_DURATION="${WARMUP_DURATION:-60s}"
RECOVERY_DURATION="${RECOVERY_DURATION:-60s}"
CHAOS_DURATION_OVERRIDE="${CHAOS_DURATION:-}"
RUN_LOAD="${RUN_LOAD:-false}"
LOAD_TEST_DIR="${LOAD_TEST_DIR:-${REPO_DIR}/load-testing}"
LOAD_RUN_SCRIPT="${LOAD_RUN_SCRIPT:-${LOAD_TEST_DIR}/scripts/run-user-journey.sh}"
LOAD_ENV_FILE="${LOAD_ENV_FILE:-${LOAD_TEST_DIR}/scripts-k6/.env.k6}"

# Map logical experiment names to manifests and default durations.
case "${EXPERIMENT_NAME}" in
  product-crash-loop)
    MANIFEST="${EXPERIMENTS_DIR}/pod-crash-loop/product-service-crash.yaml"
    DURATION="90s"
    TARGET_SERVICE="product-service"
    FAULT_FAMILY="crash-loop-like"
    ;;
  network-delay-api-gateway)
    MANIFEST="${EXPERIMENTS_DIR}/network-delay/api-gateway-delay.yaml"
    DURATION="90s"
    TARGET_SERVICE="product-service"
    FAULT_FAMILY="network-delay"
    ;;
  pod-kill-product)
    MANIFEST="${EXPERIMENTS_DIR}/pod-kill/product-service.yaml"
    DURATION="30s"
    TARGET_SERVICE="product-service"
    FAULT_FAMILY="pod-kill"
    ;;
  pod-kill-order)
    MANIFEST="${EXPERIMENTS_DIR}/pod-kill/order-service.yaml"
    DURATION="30s"
    TARGET_SERVICE="order-service"
    FAULT_FAMILY="pod-kill"
    ;;
  cpu-stress-product)
    MANIFEST="${EXPERIMENTS_DIR}/cpu-stress/product-service-cpu.yaml"
    DURATION="60s"
    TARGET_SERVICE="product-service"
    FAULT_FAMILY="cpu-stress"
    ;;
  *)
    echo "Unknown experiment: ${EXPERIMENT_NAME}" >&2
    usage
    exit 1
    ;;
esac

if [[ -n "${CHAOS_DURATION_OVERRIDE}" ]]; then
  DURATION="${CHAOS_DURATION_OVERRIDE}"
fi

require_file "${MANIFEST}"

log "experiment=${EXPERIMENT_NAME}"
log "fault_family=${FAULT_FAMILY}"
log "target_service=${TARGET_SERVICE}"
log "manifest=${MANIFEST}"
log "chaos_env_file=${CHAOS_ENV_FILE}"
if bool_is_true "${RUN_LOAD}"; then
  log "traffic_source=managed-load"
else
  log "traffic_source=external"
  log "recommended traffic source: ./load-testing/scripts/run-user-journey.sh"
fi

start_load

if bool_is_true "${RUN_LOAD}"; then
  wait_phase "baseline-under-load" "${BASELINE_DURATION}"
  wait_phase "warm-up-under-load" "${WARMUP_DURATION}"
else
  wait_phase "baseline" "${BASELINE_DURATION}"
  wait_phase "warm-up" "${WARMUP_DURATION}"
fi

reset_manifest

log "applying experiment"
kubectl apply -f "${MANIFEST}"

log "chaos-active: waiting ${DURATION}"
sleep "${DURATION}"

cleanup_manifest
log "cleanup complete"

wait_phase "recovery" "${RECOVERY_DURATION}"
wait_for_load
CLEANED_UP="true"
log "done"
