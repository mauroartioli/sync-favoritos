#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${ROOT_DIR}/../.." && pwd)"

APP_SUPPORT_DIR="${HOME}/Library/Application Support/SyncFavoritos"
BIN_DIR="${APP_SUPPORT_DIR}/bin"
BIN_PATH="${BIN_DIR}/syncfavoritosd"
LOG_PATH="${APP_SUPPORT_DIR}/syncfavoritosd.log"
CFG_PATH="${APP_SUPPORT_DIR}/config.json"

LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
PLIST_LABEL="com.mauroartioli.syncfavoritos"
PLIST_PATH="${LAUNCH_AGENTS_DIR}/${PLIST_LABEL}.plist"
PLIST_TEMPLATE="${ROOT_DIR}/LaunchAgent.com.mauroartioli.syncfavoritos.plist"

echo "== Sync Favoritos v2 :: Instalação (macOS) =="
echo ""

mkdir -p "${BIN_DIR}"
mkdir -p "${LAUNCH_AGENTS_DIR}"

echo "1) Compilando daemon (SwiftPM, release)..."
cd "${ROOT_DIR}"
SCRATCH_PATH="${APP_SUPPORT_DIR}/swiftpm-scratch"
CACHE_PATH="${APP_SUPPORT_DIR}/swiftpm-cache"
MODULE_CACHE_PATH="${APP_SUPPORT_DIR}/clang-module-cache"
mkdir -p "${SCRATCH_PATH}" "${CACHE_PATH}" "${MODULE_CACHE_PATH}"
BUILD_BIN_DIR="$(swift build -c release \
  --scratch-path "${SCRATCH_PATH}" \
  --cache-path "${CACHE_PATH}" \
  -Xswiftc -module-cache-path -Xswiftc "${MODULE_CACHE_PATH}" \
  --show-bin-path)"

echo "2) Instalando binário em Application Support..."
cp -f "${BUILD_BIN_DIR}/syncfavoritosd" "${BIN_PATH}"
chmod +x "${BIN_PATH}"

echo "3) Preparando LaunchAgent..."
sed \
  -e "s|__BIN_PATH__|${BIN_PATH}|g" \
  -e "s|__LOG_PATH__|${LOG_PATH}|g" \
  "${PLIST_TEMPLATE}" > "${PLIST_PATH}"

echo "4) Recarregando LaunchAgent..."
UID_NUM="$(id -u)"
launchctl bootout "gui/${UID_NUM}" "${PLIST_PATH}" 2>/dev/null || true
launchctl bootstrap "gui/${UID_NUM}" "${PLIST_PATH}"
launchctl kickstart -k "gui/${UID_NUM}/${PLIST_LABEL}"

echo ""
echo "✓ Instalado."
echo ""
echo "Arquivos:"
echo "- Binário: ${BIN_PATH}"
echo "- Config:  ${CFG_PATH}"
echo "- Logs:    ${LOG_PATH}"
echo ""
echo "Próximos passos:"
echo "1) Conceda Acesso Total ao Disco ao binário acima (Ajustes do Sistema → Privacidade e Segurança → Acesso Total ao Disco)."
echo "2) Carregue a extensão do Edge em: ${REPO_DIR}/v2/edge-extension"
echo "3) (Opcional) Se o gateway exigir token, copie o token do config.json para a extensão (sf_token)."
