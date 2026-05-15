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
    echo "[cleanup-customers][ERROR] Missing command: $1" >&2
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
    [[ -n "${CUSTOMER_EMAIL}" ]] && printf '%s\n' "${CUSTOMER_EMAIL}"
    return
  fi

  if [[ -z "${CUSTOMER_EMAIL_PREFIX}" ]]; then
    return
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

delete_customer() {
  local user_id="$1"
  local token="$2"
  local output="$3"

  request DELETE "${USERS_ENDPOINT}/${user_id}" "${output}" \
    -H "Authorization: Bearer ${token}"
}

echo "[cleanup-customers] BASE_URL=${BASE_URL}"

deleted=0
skipped=0
index=0

while IFS= read -r email; do
  [[ -z "${email}" ]] && continue
  index=$((index + 1))
  login_out="${TMP_DIR}/login-${index}.json"
  code="$(login_customer "${email}" "${login_out}")"

  if [[ "${code}" != "200" ]]; then
    echo "[cleanup-customers] skip login-unavailable: ${email} (status=${code})"
    skipped=$((skipped + 1))
    continue
  fi

  user_id="$(jq -r '.user.id // .id // empty' "${login_out}")"
  token="$(jq -r '.access_token // empty' "${login_out}")"

  if [[ -z "${user_id}" || -z "${token}" ]]; then
    echo "[cleanup-customers] skip invalid-login-response: ${email}"
    skipped=$((skipped + 1))
    continue
  fi

  delete_out="${TMP_DIR}/delete-${index}.json"
  code="$(delete_customer "${user_id}" "${token}" "${delete_out}")"
  if [[ "${code}" == "204" || "${code}" == "404" ]]; then
    echo "[cleanup-customers] deleted: ${email} (${user_id})"
    deleted=$((deleted + 1))
  else
    echo "[cleanup-customers][WARN] cannot delete ${email}. status=${code}" >&2
    cat "${delete_out}" >&2 || true
    skipped=$((skipped + 1))
  fi
done < <(build_customer_emails)

echo "[cleanup-customers] done. deleted=${deleted}, skipped=${skipped}"
