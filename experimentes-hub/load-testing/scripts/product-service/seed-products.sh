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
    echo "[seed][ERROR] Missing command: $1" >&2
    exit 1
  fi
}

require_cmd curl
require_cmd jq

BASE_URL="${BASE_URL:-http://mini-ecommerce.tienphatng237.com}"
USERS_ENDPOINT="${USERS_ENDPOINT:-/api/v1/users}"
LOGIN_ENDPOINT="${LOGIN_ENDPOINT:-/api/v1/users/login}"
PRODUCTS_ENDPOINT="${PRODUCTS_ENDPOINT:-/api/v1/products}"

SEED_NAMESPACE="${K6_SEED_NAMESPACE_OVERRIDE:-${SEED_NAMESPACE:-rl-seed}}"
SEED_SELLER_COUNT="${SEED_SELLER_COUNT:-2}"
SEED_PRODUCTS_PER_SELLER="${SEED_PRODUCTS_PER_SELLER:-5}"
SEED_PRODUCT_STOCK="${SEED_PRODUCT_STOCK:-500}"
SEED_PRODUCT_PRICE="${SEED_PRODUCT_PRICE:-109.9}"
SEED_USER_PASSWORD="${SEED_USER_PASSWORD:-${TEST_USER_PASSWORD:-K6Read@12345}}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

api_url() {
  local path="$1"
  printf '%s%s' "${BASE_URL%/}" "${path}"
}

uri_encode() {
  jq -rn --arg v "$1" '$v|@uri'
}

request() {
  local method="$1"
  local path="$2"
  local output="$3"
  shift 3

  curl -sS -o "${output}" -w '%{http_code}' -X "${method}" "$(api_url "${path}")" "$@"
}

seller_email() {
  local index="$1"
  printf 'k6.%s.seller.%s@example.test' "${SEED_NAMESPACE}" "${index}"
}

seller_name() {
  local index="$1"
  printf 'K6 Seed Seller %s %s' "${SEED_NAMESPACE}" "${index}"
}

product_name() {
  local seller_index="$1"
  local product_index="$2"
  printf 'K6 Seed %s S%s P%s' "${SEED_NAMESPACE}" "${seller_index}" "${product_index}"
}

login_seller() {
  local email="$1"
  local output="$2"

  request POST "${LOGIN_ENDPOINT}" "${output}" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"${email}\",\"password\":\"${SEED_USER_PASSWORD}\"}"
}

ensure_seller_session() {
  local index="$1"
  local email
  local name
  local create_out
  local login_out
  local code

  email="$(seller_email "${index}")"
  name="$(seller_name "${index}")"
  create_out="${TMP_DIR}/seller-create-${index}.json"
  login_out="${TMP_DIR}/seller-login-${index}.json"

  code="$(login_seller "${email}" "${login_out}")"
  if [[ "${code}" != "200" ]]; then
    code="$(request POST "${USERS_ENDPOINT}" "${create_out}" \
      -H 'Content-Type: application/json' \
      -d "{\"name\":\"${name}\",\"email\":\"${email}\",\"password\":\"${SEED_USER_PASSWORD}\",\"role\":\"SELLER\"}")"

    if [[ "${code}" != "201" && "${code}" != "400" && "${code}" != "409" ]]; then
      echo "[seed][ERROR] Cannot create seller ${email}. status=${code}" >&2
      cat "${create_out}" >&2 || true
      exit 1
    fi

    code="$(login_seller "${email}" "${login_out}")"
    if [[ "${code}" != "200" ]]; then
      echo "[seed][ERROR] Cannot login seller ${email}. status=${code}" >&2
      cat "${login_out}" >&2 || true
      exit 1
    fi
  fi

  local seller_id
  local seller_token
  seller_id="$(jq -r '.user.id // .id // empty' "${login_out}")"
  seller_token="$(jq -r '.access_token // empty' "${login_out}")"

  if [[ -z "${seller_id}" || -z "${seller_token}" ]]; then
    echo "[seed][ERROR] Invalid seller login response for ${email}" >&2
    cat "${login_out}" >&2 || true
    exit 1
  fi

  printf '%s\t%s\t%s\n' "${email}" "${seller_id}" "${seller_token}"
}

product_exists() {
  local name="$1"
  local output="$2"
  local encoded_name
  local code

  encoded_name="$(uri_encode "${name}")"
  code="$(request GET "${PRODUCTS_ENDPOINT}?page=0&size=100&name=${encoded_name}" "${output}")"
  if [[ "${code}" != "200" ]]; then
    echo "[seed][WARN] Cannot search product '${name}'. status=${code}" >&2
    return 1
  fi

  jq -e --arg name "${name}" '
    (.items // [])
    | map(select(.name == $name))
    | length > 0
  ' "${output}" >/dev/null 2>&1
}

create_product() {
  local seller_token="$1"
  local name="$2"
  local stock="$3"
  local price="$4"
  local output="$5"
  local code

  code="$(request POST "${PRODUCTS_ENDPOINT}" "${output}" \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer ${seller_token}" \
    -d "{\"name\":\"${name}\",\"price\":${price},\"stock\":${stock}}")"

  if [[ "${code}" != "201" ]]; then
    echo "[seed][ERROR] Cannot create product '${name}'. status=${code}" >&2
    cat "${output}" >&2 || true
    exit 1
  fi
}

echo "[seed] BASE_URL=${BASE_URL}"
echo "[seed] namespace=${SEED_NAMESPACE}"
echo "[seed] sellers=${SEED_SELLER_COUNT}, products_per_seller=${SEED_PRODUCTS_PER_SELLER}, stock=${SEED_PRODUCT_STOCK}"

created_count=0
skipped_count=0

for ((seller_index = 1; seller_index <= SEED_SELLER_COUNT; seller_index += 1)); do
  IFS=$'\t' read -r email seller_id seller_token < <(ensure_seller_session "${seller_index}")
  echo "[seed] seller ready: ${email} (${seller_id})"

  for ((product_index = 1; product_index <= SEED_PRODUCTS_PER_SELLER; product_index += 1)); do
    name="$(product_name "${seller_index}" "${product_index}")"
    search_out="${TMP_DIR}/product-search-${seller_index}-${product_index}.json"

    if product_exists "${name}" "${search_out}"; then
      echo "[seed] skip existing product: ${name}"
      skipped_count=$((skipped_count + 1))
      continue
    fi

    create_out="${TMP_DIR}/product-create-${seller_index}-${product_index}.json"
    create_product "${seller_token}" "${name}" "${SEED_PRODUCT_STOCK}" "${SEED_PRODUCT_PRICE}" "${create_out}"
    product_id="$(jq -r '.id // empty' "${create_out}")"
    echo "[seed] created product: ${name} (${product_id:-unknown-id})"
    created_count=$((created_count + 1))
  done
done

echo "[seed] done. created=${created_count}, skipped=${skipped_count}"
