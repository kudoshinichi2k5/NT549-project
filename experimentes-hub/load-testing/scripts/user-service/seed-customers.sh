#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${K6_ENV_FILE:-${REPO_DIR}/scripts-k6/.env.k6}"

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  set -a; source "${ENV_FILE}"; set +a
fi

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[seed-customers][ERROR] Missing command: $1" >&2
    exit 1
  fi
}

require_cmd curl
require_cmd jq

BASE_URL="${BASE_URL:-http://mini-ecommerce.tienphatng237.com}"
USERS_ENDPOINT="${USERS_ENDPOINT:-/api/v1/users}"
LOGIN_ENDPOINT="${LOGIN_ENDPOINT:-/api/v1/users/login}"
CUSTOMER_PASSWORD="${CUSTOMER_PASSWORD:-${SEED_USER_PASSWORD:-K6Read@12345}}"
CUSTOMER_COUNT="${CUSTOMER_COUNT:-1}"
CUSTOMER_EMAIL="${CUSTOMER_EMAIL:-}"
CUSTOMER_EMAILS="${CUSTOMER_EMAILS:-}"
CUSTOMER_EMAIL_PREFIX="${K6_CUSTOMER_EMAIL_PREFIX_OVERRIDE:-${CUSTOMER_EMAIL_PREFIX:-}}"
CUSTOMER_EMAIL_DOMAIN="${CUSTOMER_EMAIL_DOMAIN:-example.test}"
SEED_CUSTOMER_NAME_PREFIX="${SEED_CUSTOMER_NAME_PREFIX:-K6 Load Customer}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

api_url() {
  local path="$1"
  printf '%s%s' "${BASE_URL%/}" "${path}"
}

request() {
  local method="$1"
  local path="$2"
  local output="$3"
  shift 3

  curl -sS -o "${output}" -w '%{http_code}' -X "${method}" "$(api_url "${path}")" "$@"
}

trim() {
  printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

build_customer_emails() {
  if [[ -n "${CUSTOMER_EMAILS}" ]]; then
    printf '%s\n' "${CUSTOMER_EMAILS}" | tr ',' '\n' | while IFS= read -r item; do
      item="$(trim "${item}")"
      [[ -n "${item}" ]] && printf '%s\n' "${item}"
    done
    return
  fi

  if [[ "${CUSTOMER_COUNT}" -eq 1 ]]; then
    if [[ -z "${CUSTOMER_EMAIL}" ]]; then
      echo "[seed-customers][ERROR] Missing CUSTOMER_EMAIL when CUSTOMER_COUNT=1" >&2
      exit 1
    fi

    printf '%s\n' "${CUSTOMER_EMAIL}"
    return
  fi

  if [[ -z "${CUSTOMER_EMAIL_PREFIX}" ]]; then
    echo "[seed-customers][ERROR] Missing CUSTOMER_EMAIL_PREFIX when CUSTOMER_COUNT>1" >&2
    exit 1
  fi

  local index
  for ((index = 1; index <= CUSTOMER_COUNT; index += 1)); do
    printf '%s.%s@%s\n' "${CUSTOMER_EMAIL_PREFIX}" "${index}" "${CUSTOMER_EMAIL_DOMAIN}"
  done
}

login_customer() {
  local email="$1"
  local output="$2"

  request POST "${LOGIN_ENDPOINT}" "${output}" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"${email}\",\"password\":\"${CUSTOMER_PASSWORD}\"}"
}

create_customer() {
  local email="$1"
  local index="$2"
  local output="$3"
  local name

  name="${SEED_CUSTOMER_NAME_PREFIX} ${index}"
  request POST "${USERS_ENDPOINT}" "${output}" \
    -H 'Content-Type: application/json' \
    -d "{\"name\":\"${name}\",\"email\":\"${email}\",\"password\":\"${CUSTOMER_PASSWORD}\",\"role\":\"CUSTOMER\"}"
}

ensure_customer() {
  local email="$1"
  local index="$2"
  local create_out="${TMP_DIR}/create-${index}.json"
  local login_out="${TMP_DIR}/login-${index}.json"
  local code

  code="$(login_customer "${email}" "${login_out}")"
  if [[ "${code}" != "200" ]]; then
    code="$(create_customer "${email}" "${index}" "${create_out}")"
    if [[ "${code}" != "201" && "${code}" != "400" && "${code}" != "409" ]]; then
      echo "[seed-customers][ERROR] Cannot create customer ${email}. status=${code}" >&2
      cat "${create_out}" >&2 || true
      exit 1
    fi

    code="$(login_customer "${email}" "${login_out}")"
    if [[ "${code}" != "200" ]]; then
      echo "[seed-customers][ERROR] Cannot login customer ${email}. status=${code}" >&2
      cat "${login_out}" >&2 || true
      exit 1
    fi
  fi

  local user_id
  user_id="$(jq -r '.user.id // .id // empty' "${login_out}")"
  if [[ -z "${user_id}" ]]; then
    echo "[seed-customers][ERROR] Invalid login response for ${email}" >&2
    cat "${login_out}" >&2 || true
    exit 1
  fi

  printf '%s\t%s\n' "${email}" "${user_id}"
}

echo "[seed-customers] BASE_URL=${BASE_URL}"
echo "[seed-customers] customer_count=${CUSTOMER_COUNT}"

created_or_ready=0
index=0
while IFS= read -r email; do
  [[ -z "${email}" ]] && continue
  index=$((index + 1))
  IFS=$'\t' read -r ready_email user_id < <(ensure_customer "${email}" "${index}")
  echo "[seed-customers] ready: ${ready_email} (${user_id})"
  created_or_ready=$((created_or_ready + 1))
done < <(build_customer_emails)

echo "[seed-customers] done. ready=${created_or_ready}"
