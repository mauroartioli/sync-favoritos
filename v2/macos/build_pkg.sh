#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${ROOT_DIR}/../.." && pwd)"
DIST_DIR="${REPO_DIR}/v2/dist"

VERSION="2.0.0"
IDENTIFIER="com.mauroartioli.syncfavoritos"
PKG_NAME="SyncFavoritos-${VERSION}-unsigned.pkg"

INFO_PLIST_TEMPLATE="${ROOT_DIR}/Info.plist.template"
LAUNCH_AGENT_PLIST="${ROOT_DIR}/LaunchAgent.system.plist"

echo "== Sync Favoritos v2 :: Build PKG =="
mkdir -p "${DIST_DIR}"

WORK_DIR="$(mktemp -d)"
PAYLOAD_DIR="${WORK_DIR}/payload"
SCRIPTS_DIR="${WORK_DIR}/scripts"

mkdir -p "${PAYLOAD_DIR}/Applications"
mkdir -p "${PAYLOAD_DIR}/Library/LaunchAgents"
mkdir -p "${SCRIPTS_DIR}"

echo "1) Build Swift (release)..."
cd "${ROOT_DIR}"
SCRATCH_PATH="${WORK_DIR}/swiftpm-scratch"
CACHE_PATH="${WORK_DIR}/swiftpm-cache"
MODULE_CACHE_PATH="${WORK_DIR}/clang-module-cache"
mkdir -p "${SCRATCH_PATH}" "${CACHE_PATH}" "${MODULE_CACHE_PATH}"

swift build -c release \
  --scratch-path "${SCRATCH_PATH}" \
  --cache-path "${CACHE_PATH}" \
  -Xswiftc -module-cache-path -Xswiftc "${MODULE_CACHE_PATH}"

BIN_DIR="$(swift build -c release \
  --scratch-path "${SCRATCH_PATH}" \
  --cache-path "${CACHE_PATH}" \
  -Xswiftc -module-cache-path -Xswiftc "${MODULE_CACHE_PATH}" \
  --show-bin-path)"

BIN_SRC="${BIN_DIR}/syncfavoritos"
if [ ! -f "${BIN_SRC}" ]; then
  echo "ERRO: binário não encontrado em ${BIN_SRC}"
  exit 1
fi

echo "2) Montando SyncFavoritos.app..."
APP_BUNDLE="${PAYLOAD_DIR}/Applications/SyncFavoritos.app"
APP_CONTENTS="${APP_BUNDLE}/Contents"
APP_MACOS="${APP_CONTENTS}/MacOS"
APP_RESOURCES="${APP_CONTENTS}/Resources"
mkdir -p "${APP_MACOS}" "${APP_RESOURCES}"
cp -f "${BIN_SRC}" "${APP_MACOS}/SyncFavoritos"
chmod +x "${APP_MACOS}/SyncFavoritos"
cp -f "${INFO_PLIST_TEMPLATE}" "${APP_CONTENTS}/Info.plist"

echo "3) Instalando LaunchAgent (system-wide)..."
cp -f "${LAUNCH_AGENT_PLIST}" "${PAYLOAD_DIR}/Library/LaunchAgents/com.mauroartioli.syncfavoritos.plist"

echo "4) Copiando scripts..."
cp -f "${ROOT_DIR}/pkg/scripts/postinstall" "${SCRIPTS_DIR}/postinstall"
chmod +x "${SCRIPTS_DIR}/postinstall"

echo "5) Gerando pkg (unsigned)..."
pkgbuild \
  --root "${PAYLOAD_DIR}" \
  --scripts "${SCRIPTS_DIR}" \
  --identifier "${IDENTIFIER}" \
  --version "${VERSION}" \
  --install-location "/" \
  "${DIST_DIR}/${PKG_NAME}"

echo "✓ Gerado: ${DIST_DIR}/${PKG_NAME}"
