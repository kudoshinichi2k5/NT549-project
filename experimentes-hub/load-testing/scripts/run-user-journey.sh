#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${K6_ENV_FILE:-${REPO_DIR}/scripts-k6/.env.k6}"

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  set -a; source "${ENV_FILE}"; set +a
fi

SEED_CUSTOMERS_BEFORE_RUN="${SEED_CUSTOMERS_BEFORE_RUN:-true}"
CLEANUP_CUSTOMERS_AFTER_RUN="${CLEANUP_CUSTOMERS_AFTER_RUN:-true}"
SEED_PRODUCTS_BEFORE_RUN="${SEED_PRODUCTS_BEFORE_RUN:-false}"
CLEANUP_PRODUCTS_AFTER_RUN="${CLEANUP_PRODUCTS_AFTER_RUN:-${SEED_PRODUCTS_BEFORE_RUN}}"
RUN_ID="${RUN_ID:-$(date +%s)}"
BASE_CUSTOMER_EMAIL_PREFIX="${CUSTOMER_EMAIL_PREFIX:-k6.customer}"
BASE_SEED_NAMESPACE="${SEED_NAMESPACE:-rl-seed}"

cleanup() {
  local exit_code="$1"

  printf '\n[run-user-journey] starting cleanup...\n'

  if [[ "${CLEANUP_PRODUCTS_AFTER_RUN}" == "true" ]]; then
    bash "${SCRIPT_DIR}/product-service/cleanup-seed-users.sh" || true
  fi

  if [[ "${CLEANUP_CUSTOMERS_AFTER_RUN}" == "true" ]]; then
    bash "${SCRIPT_DIR}/user-service/cleanup-seed-customers.sh" || true
  fi

  printf '[run-user-journey] cleanup finished.\n'
  trap - EXIT
  exit "${exit_code}"
}

if [[ -n "${CUSTOMER_EMAILS:-}" ]]; then
  :
elif [[ "${CUSTOMER_COUNT:-1}" -gt 1 ]]; then
  export K6_CUSTOMER_EMAIL_PREFIX_OVERRIDE="${BASE_CUSTOMER_EMAIL_PREFIX}.${RUN_ID}"
fi

if [[ "${SEED_PRODUCTS_BEFORE_RUN}" == "true" || "${CLEANUP_PRODUCTS_AFTER_RUN}" == "true" ]]; then
  export K6_SEED_NAMESPACE_OVERRIDE="${BASE_SEED_NAMESPACE}.${RUN_ID}"
fi

trap 'cleanup $?' EXIT

if [[ "${SEED_CUSTOMERS_BEFORE_RUN}" == "true" ]]; then
  printf '[run-user-journey] seeding customers...\n'
  bash "${SCRIPT_DIR}/user-service/seed-customers.sh"
fi

if [[ "${SEED_PRODUCTS_BEFORE_RUN}" == "true" ]]; then
  printf '[run-user-journey] seeding products...\n'
  bash "${SCRIPT_DIR}/product-service/seed-products.sh"
fi

cd "${REPO_DIR}"
cd "${REPO_DIR}/scripts-k6"
printf '[run-user-journey] running k6 load...\n'
k6 run user-journey.js
