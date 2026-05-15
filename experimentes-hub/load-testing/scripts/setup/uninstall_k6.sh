#!/usr/bin/env bash
set -euo pipefail

echo "[uninstall_k6] Starting k6 cleanup..."

if ! command -v apt-get >/dev/null 2>&1; then
  echo "[uninstall_k6] Error: apt-get not found. This script supports Debian/Ubuntu only." >&2
  exit 1
fi

SUDO=""
if [[ "${EUID}" -ne 0 ]]; then
  if ! command -v sudo >/dev/null 2>&1; then
    echo "[uninstall_k6] Error: run as root or install sudo." >&2
    exit 1
  fi
  SUDO="sudo"
fi

echo "[uninstall_k6] Removing k6 package..."
${SUDO} apt-get remove --purge -y k6 || true

echo "[uninstall_k6] Removing k6 repository and keyring..."
${SUDO} rm -f /etc/apt/sources.list.d/k6.list
${SUDO} rm -f /etc/apt/keyrings/k6-archive-keyring.gpg

echo "[uninstall_k6] Cleaning apt cache..."
${SUDO} apt-get autoremove -y
${SUDO} apt-get clean
${SUDO} apt-get update -y || true

echo "[uninstall_k6] k6 removed."
