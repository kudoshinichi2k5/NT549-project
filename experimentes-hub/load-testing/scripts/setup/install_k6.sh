#!/usr/bin/env bash
set -euo pipefail

echo "[install_k6] Starting k6 installation..."

if ! command -v apt-get >/dev/null 2>&1; then
  echo "[install_k6] Error: apt-get not found. This script supports Debian/Ubuntu only." >&2
  exit 1
fi

SUDO=""
if [[ "${EUID}" -ne 0 ]]; then
  if ! command -v sudo >/dev/null 2>&1; then
    echo "[install_k6] Error: run as root or install sudo." >&2
    exit 1
  fi
  SUDO="sudo"
fi

echo "[install_k6] Installing prerequisites..."
${SUDO} apt-get update -y
${SUDO} apt-get install -y ca-certificates gnupg apt-transport-https

echo "[install_k6] Adding Grafana k6 GPG key..."
${SUDO} mkdir -p /etc/apt/keyrings
curl -fsSL https://dl.k6.io/key.gpg | ${SUDO} gpg --dearmor -o /etc/apt/keyrings/k6-archive-keyring.gpg
${SUDO} chmod 0644 /etc/apt/keyrings/k6-archive-keyring.gpg

echo "[install_k6] Adding k6 apt repository..."
echo "deb [signed-by=/etc/apt/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" \
  | ${SUDO} tee /etc/apt/sources.list.d/k6.list >/dev/null

echo "[install_k6] Updating package index..."
${SUDO} apt-get update -y

echo "[install_k6] Installing k6..."
${SUDO} apt-get install -y k6

echo "[install_k6] k6 installed successfully:"
k6 version
