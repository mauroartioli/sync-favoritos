#!/bin/bash

# Sync Favoritos - macOS Automated Silent Installation Script
# Author: Antigravity AI
# Description: Installs and registers the quiet SyncFavoritos.app Login Item from scratch.
#              Compiles the launcher app from AppleScript source, configures it as a hidden agent,
#              handles codesigning/TCC bypass, and registers it as the official startup Login Item.

GREEN='\033[0;32m'
NC='\033[0m' # No Color
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'

echo -e "${BLUE}=================================================================${NC}"
echo -e "${YELLOW}     Sync Favoritos - Instalação de Inicialização Automática     ${NC}"
echo -e "${BLUE}=================================================================${NC}"
echo ""

# 1. Definições de caminhos
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LAUNCHER_APP="${SCRIPT_DIR}/SyncFavoritos.app"
APPLESCRIPT_SOURCE="${SCRIPT_DIR}/launcher.applescript"
EXPORTER_PATH="${SCRIPT_DIR}/mac_exporter.py"

# Garante permissões básicas de execução no Python
chmod +x "$EXPORTER_PATH"

# 2. Compilação do aplicativo silencioso a partir do código-fonte AppleScript
echo "1. Compilando o aplicativo de segundo plano silencioso..."
if [ ! -f "$APPLESCRIPT_SOURCE" ]; then
    echo -e "${RED}Erro: Arquivo fonte '$APPLESCRIPT_SOURCE' não encontrado.${NC}"
    exit 1
fi

# Remove versão antiga se existir
rm -rf "$LAUNCHER_APP"

# Compila o app usando a ferramenta nativa do macOS osacompile
osacompile -o "$LAUNCHER_APP" "$APPLESCRIPT_SOURCE"

if [ $? -ne 0 ] || [ ! -d "$LAUNCHER_APP" ]; then
    echo -e "${RED}Erro ao compilar o aplicativo usando osacompile.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Aplicativo compilado com sucesso em: ${LAUNCHER_APP}${NC}"

# 3. Configuração do aplicativo para rodar como Agente Oculto (sem ícone no Dock)
echo "2. Configurando o aplicativo para rodar em modo oculto (headless)..."
PLIST_FILE="${LAUNCHER_APP}/Contents/Info.plist"

if [ -f "$PLIST_FILE" ]; then
    python3 -c "
import plistlib
with open('$PLIST_FILE', 'rb') as f:
    pl = plistlib.load(f)
pl['LSUIElement'] = True
with open('$PLIST_FILE', 'wb') as f:
    plistlib.dump(pl, f)
"
    echo -e "${GREEN}✓ Info.plist atualizado (LSUIElement ativado).${NC}"
else
    echo -e "${RED}Erro: Info.plist não encontrado em ${PLIST_FILE}.${NC}"
    exit 1
fi

# 4. Limpeza de atributos estendidos e Assinatura Digital do App
echo "3. Limpando atributos Finder e assinando digitalmente o aplicativo..."
xattr -cr "$LAUNCHER_APP"
codesign --force --sign - "$LAUNCHER_APP" 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Assinatura digital do aplicativo aplicada com sucesso.${NC}"
else
    echo -e "${YELLOW}Aviso: Falha ao aplicar códigosign, mas o app ainda deve rodar localmente.${NC}"
fi

# 5. Limpeza de logins anteriores
echo "4. Removendo registros antigos de inicialização..."
osascript -e 'tell application "System Events" to delete (every login item whose name is "Sync Favoritos")' 2>/dev/null
osascript -e 'tell application "System Events" to delete (every login item whose name is "SyncFavoritos")' 2>/dev/null
osascript -e 'tell application "System Events" to delete (every login item whose name is "iniciar_servidor.command")' 2>/dev/null

# 6. Registra o aplicativo nos Itens de Inicialização (Login Items)
echo "5. Registrando o inicializador silencioso no seu perfil do macOS..."
osascript -e "tell application \"System Events\" to make new login item at end with properties {path:\"${LAUNCHER_APP}\", name:\"Sync Favoritos\", hidden:true}"

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}=================================================================${NC}"
    echo -e "${GREEN}✓ INSTALAÇÃO CONCLUÍDA COM SUCESSO!                              ${NC}"
    echo -e "${GREEN}=================================================================${NC}"
    echo ""
    echo -e "${YELLOW}⚠️ PASSO CRÍTICO EXIGIDO (Apenas na primeira instalação):${NC}"
    echo -e "Você precisa autorizar o novo aplicativo a ler os favoritos do Safari."
    echo -e "Siga estes passos rápidos:"
    echo -e "1. Abra os ${BLUE}Ajustes do Sistema ➜ Privacidade e Segurança ➜ Acesso Total ao Disco${NC}."
    echo -e "2. Arraste e solte o aplicativo compilado:"
    echo -e "   ${YELLOW}${LAUNCHER_APP}${NC}"
    echo -e "   para dentro da lista de permissões."
    echo -e "3. Certifique-se de que a chave ao lado de ${BLUE}SyncFavoritos${NC} está ativada."
    echo ""
    echo -e "Iniciando o servidor silencioso agora..."
    open "$LAUNCHER_APP"
    echo -e "${GREEN}✓ Servidor iniciado em segundo plano na porta 5003!${NC}"
    echo -e "${GREEN}=================================================================${NC}"
else
    echo -e "${RED}✗ ERRO: Falha ao registrar nos Ajustes de Login do macOS.${NC}"
    exit 1
fi

exit 0
