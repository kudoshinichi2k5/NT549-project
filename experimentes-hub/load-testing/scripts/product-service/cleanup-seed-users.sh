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
    echo "[cleanup][ERROR] Missing command: $1" >&2
    exit 1
  fi
}

require_cmd curl
require_cmd jq

BASE_URL="${BASE_URL:-http://mini-ecommerce.tienphatng237.com}"
LOGIN_ENDPOINT="${LOGIN_ENDPOINT:-/api/v1/users/login}"
USERS_ENDPOINT="${USERS_ENDPOINT:-/api/v1/users}"
PRODUCTS_ENDPOINT="${PRODUCTS_ENDPOINT:-/api/v1/products}"

SEED_NAMESPACE="${K6_SEED_NAMESPACE_OVERRIDE:-${SEED_NAMESPACE:-rl-seed}}"
SEED_SELLER_COUNT="${SEED_SELLER_COUNT:-2}"
SEED_PRODUCTS_PER_SELLER="${SEED_PRODUCTS_PER_SELLER:-5}"
SEED_USER_PASSWORD="${SEED_USER_PASSWORD:-${TEST_USER_PASSWORD:-K6Read@12345}}"

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

uri_encode() {
  jq -rn --arg v "$1" '$v|@uri'
}

seller_email() {
  local index="$1"
  printf 'k6.%s.seller.%s@example.test' "${SEED_NAMESPACE}" "${index}"
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

find_product_ids() {
  local name="$1"
  local output="$2"
  local encoded_name
  local code

  encoded_name="$(uri_encode "${name}")"
  code="$(request GET "${PRODUCTS_ENDPOINT}?page=0&size=100&name=${encoded_name}" "${output}")"
  if [[ "${code}" != "200" ]]; then
    echo "[cleanup][WARN] cannot search product '${name}'. status=${code}" >&2
    return 1
  fi

  jq -r --arg name "${name}" '
    (.items // [])
    | map(select(.name == $name))
    | .[]
    | .id // empty
  ' "${output}"
}

delete_product() {
  local product_id="$1"
  local seller_token="$2"
  local output="$3"
  local code

  code="$(request DELETE "${PRODUCTS_ENDPOINT}/${product_id}" "${output}" \
    -H "Authorization: Bearer ${seller_token}")"

  if [[ "${code}" != "200" && "${code}" != "204" && "${code}" != "404" ]]; then
    echo "[cleanup][WARN] cannot delete product ${product_id}. status=${code}" >&2
    cat "${output}" >&2 || true
    return 1
  fi

  return 0
}

echo "[cleanup] BASE_URL=${BASE_URL}"
echo "[cleanup] namespace=${SEED_NAMESPACE}"

deleted_count=0
skipped_count=0
deleted_products=0

for ((seller_index = 1; seller_index <= SEED_SELLER_COUNT; seller_index += 1)); do
  email="$(seller_email "${seller_index}")"
  login_out="${TMP_DIR}/seller-login-${seller_index}.json"
  code="$(login_seller "${email}" "${login_out}")"

  if [[ "${code}" != "200" ]]; then
    echo "[cleanup] skip seller (cannot login or already deleted): ${email}"
    skipped_count=$((skipped_count + 1))
    continue
  fi

  seller_id="$(jq -r '.user.id // .id // empty' "${login_out}")"
  seller_token="$(jq -r '.access_token // empty' "${login_out}")"

  if [[ -z "${seller_id}" || -z "${seller_token}" ]]; then
    echo "[cleanup][WARN] invalid login payload for ${email}, skipping"
    skipped_count=$((skipped_count + 1))
    continue
  fi

  for ((product_index = 1; product_index <= SEED_PRODUCTS_PER_SELLER; product_index += 1)); do
    name="$(product_name "${seller_index}" "${product_index}")"
    search_out="${TMP_DIR}/product-search-${seller_index}-${product_index}.json"

    while IFS= read -r product_id; do
      [[ -z "${product_id}" ]] && continue
      delete_product_out="${TMP_DIR}/product-delete-${seller_index}-${product_index}-${product_id}.json"
      if delete_product "${product_id}" "${seller_token}" "${delete_product_out}"; then
        echo "[cleanup] deleted product: ${name} (${product_id})"
        deleted_products=$((deleted_products + 1))
      fi
    done < <(find_product_ids "${name}" "${search_out}" || true)
  done

  delete_out="${TMP_DIR}/seller-delete-${seller_index}.json"
  code="$(request DELETE "${USERS_ENDPOINT}/${seller_id}" "${delete_out}" \
    -H "Authorization: Bearer ${seller_token}")"

  if [[ "${code}" == "200" || "${code}" == "204" || "${code}" == "404" ]]; then
    echo "[cleanup] soft-deleted seller: ${email} (${seller_id})"
    deleted_count=$((deleted_count + 1))
  else
    echo "[cleanup][WARN] cannot delete seller ${email}. status=${code}" >&2
    cat "${delete_out}" >&2 || true
    skipped_count=$((skipped_count + 1))
  fi
done

echo "[cleanup] done. deleted=${deleted_count}, skipped=${skipped_count}"
echo "[cleanup] products_deleted=${deleted_products}"
