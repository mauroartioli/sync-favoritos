#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${ROOT_DIR}/../.." && pwd)"

APP_SUPPORT_DIR="${HOME}/Library/Application Support/SyncFavoritos"
BIN_DIR="${APP_SUPPORT_DIR}/bin"
BIN_PATH="${BIN_DIR}/syncfavoritos"
LOG_PATH="${APP_SUPPORT_DIR}/syncfavoritos.log"
CFG_PATH="${APP_SUPPORT_DIR}/config.json"

APP_BUNDLE_PATH="${APP_SUPPORT_DIR}/SyncFavoritos.app"
APP_CONTENTS_PATH="${APP_BUNDLE_PATH}/Contents"
APP_MACOS_PATH="${APP_CONTENTS_PATH}/MacOS"
APP_RESOURCES_PATH="${APP_CONTENTS_PATH}/Resources"
APP_EXE_PATH="${APP_MACOS_PATH}/SyncFavoritos"
APP_INFO_PLIST="${APP_CONTENTS_PATH}/Info.plist"

LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
PLIST_LABEL="com.mauroartioli.syncfavoritos"
PLIST_PATH="${LAUNCH_AGENTS_DIR}/${PLIST_LABEL}.plist"
PLIST_TEMPLATE="${ROOT_DIR}/LaunchAgent.com.mauroartioli.syncfavoritos.plist"
INFO_PLIST_TEMPLATE="${ROOT_DIR}/Info.plist.template"

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
SRC_BIN=""
if [ -f "${BUILD_BIN_DIR}/syncfavoritos" ]; then
  SRC_BIN="${BUILD_BIN_DIR}/syncfavoritos"
elif [ -f "${BUILD_BIN_DIR}/syncfavoritosd" ]; then
  # Back-compat if user has an older SwiftPM build cache.
  SRC_BIN="${BUILD_BIN_DIR}/syncfavoritosd"
else
  echo "ERRO: binário não encontrado em '${BUILD_BIN_DIR}'."
  echo "Esperado: syncfavoritos (ou syncfavoritosd)."
  exit 1
fi

cp -f "${SRC_BIN}" "${BIN_PATH}"
chmod +x "${BIN_PATH}"

echo "2a) Empacotando como app (sem Dock)..."
mkdir -p "${APP_MACOS_PATH}" "${APP_RESOURCES_PATH}"
cp -f "${BIN_PATH}" "${APP_EXE_PATH}"
chmod +x "${APP_EXE_PATH}"
cp -f "${INFO_PLIST_TEMPLATE}" "${APP_INFO_PLIST}"

echo "2b) Aplicando config default (sem token)..."
CFG_PATH="${CFG_PATH}" python3 - <<'PY'
import json, os
cfg_path = os.path.expanduser(os.environ["CFG_PATH"])
cfg = {}
if os.path.exists(cfg_path):
  try:
    with open(cfg_path, "r", encoding="utf-8") as f:
      cfg = json.load(f) or {}
  except Exception:
    cfg = {}

cfg["safari_bookmarks_path"] = cfg.get("safari_bookmarks_path") or "~/Library/Safari/Bookmarks.plist"
cfg["port"] = 5004
cfg["token"] = ""

os.makedirs(os.path.dirname(cfg_path), exist_ok=True)
with open(cfg_path, "w", encoding="utf-8") as f:
  json.dump(cfg, f)
print("Config aplicada em:", cfg_path)
PY

echo "3) Preparando LaunchAgent..."
sed \
  -e "s|__APP_EXE_PATH__|${APP_EXE_PATH}|g" \
  -e "s|__LOG_PATH__|${LOG_PATH}|g" \
  "${PLIST_TEMPLATE}" > "${PLIST_PATH}"

echo "4) Recarregando LaunchAgent..."
UID_NUM="$(id -u)"
launchctl bootout "gui/${UID_NUM}" "${PLIST_PATH}" 2>/dev/null || true
launchctl bootstrap "gui/${UID_NUM}" "${PLIST_PATH}"
launchctl kickstart -k "gui/${UID_NUM}/${PLIST_LABEL}"

echo "5) Ajustando porta automaticamente (se necessário)..."
if [ -f "${CFG_PATH}" ]; then
  CFG_PATH="${CFG_PATH}" python3 - <<'PY'
import json, os, subprocess, sys
cfg_path = os.path.expanduser(os.environ["CFG_PATH"])
with open(cfg_path, "r", encoding="utf-8") as f:
    cfg = json.load(f)
port = int(cfg.get("port", 5004))
def port_in_use(p: int) -> bool:
    try:
        r = subprocess.run(["lsof", "-n", f"-iTCP:{p}", "-sTCP:LISTEN"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return r.returncode == 0
    except Exception:
        return False
if port == 5003 and port_in_use(5003):
    cfg["port"] = 5004
    with open(cfg_path, "w", encoding="utf-8") as f:
        json.dump(cfg, f)
    print("Porta 5003 estava em uso; config atualizada para 5004.")
PY
fi

echo ""
echo "✓ Instalado."
echo ""
echo "Arquivos:"
echo "- Binário: ${BIN_PATH}"
echo "- App:     ${APP_BUNDLE_PATH}"
echo "- Config:  ${CFG_PATH}"
echo "- Logs:    ${LOG_PATH}"
echo ""
echo "Próximos passos:"
echo "1) Conceda Acesso Total ao Disco ao app acima (Ajustes do Sistema → Privacidade e Segurança → Acesso Total ao Disco)."
echo "2) Carregue a extensão do Edge em: ${REPO_DIR}/v2/edge-extension"
echo "3) (Opcional) Se você quiser habilitar token, edite o config.json e preencha o campo 'token'."
