#!/bin/bash
set -euo pipefail

APP_SUPPORT_DIR="${HOME}/Library/Application Support/SyncFavoritos"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
PLIST_LABEL="com.mauroartioli.syncfavoritos"
PLIST_PATH="${LAUNCH_AGENTS_DIR}/${PLIST_LABEL}.plist"

echo "== Sync Favoritos v2 :: Remoção (macOS) =="
echo ""

UID_NUM="$(id -u)"
launchctl bootout "gui/${UID_NUM}" "${PLIST_PATH}" 2>/dev/null || true

rm -f "${PLIST_PATH}"
rm -f "${APP_SUPPORT_DIR}/bin/syncfavoritos" "${APP_SUPPORT_DIR}/bin/syncfavoritosd" 2>/dev/null || true
rm -f "${APP_SUPPORT_DIR}/syncfavoritos.log" "${APP_SUPPORT_DIR}/syncfavoritosd.log" 2>/dev/null || true

echo "✓ LaunchAgent removido."
echo ""
echo "Obs.: os dados em '${APP_SUPPORT_DIR}' não foram apagados automaticamente."
echo "Se quiser limpar tudo:"
echo "  rm -rf \"${APP_SUPPORT_DIR}\""
