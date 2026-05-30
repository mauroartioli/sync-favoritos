#!/bin/bash

# Sync Favoritos - Inicializador do Gateway macOS (TCC Bypass)
# Author: Antigravity AI
# Description: Inicializa o servidor local em segundo plano usando a permissão do Terminal,
#              garantindo acesso ao Bookmarks.plist sem bloqueios do Sandbox do macOS.

# Definições de cores
GREEN='\033[0;32m'
NC='\033[0m' # Sem Cor
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'

# Limpa a tela do Terminal
clear

echo -e "${BLUE}=====================================================${NC}"
echo -e "${YELLOW}     Sync Favoritos - Inicializador do Gateway       ${NC}"
echo -e "${BLUE}=====================================================${NC}"
echo ""

# Identifica o diretório do script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
EXPORTER_PATH="${SCRIPT_DIR}/mac_exporter.py"

# 1. Limpa instâncias anteriores rodando na porta 5003
echo "Verificando e limpando portas..."
PID=$(lsof -t -i:5003)
if [ ! -z "$PID" ]; then
    echo "Encerrando processo anterior (PID: $PID)..."
    kill -9 $PID 2>/dev/null
    sleep 1
fi

# 2. Inicializa o servidor Python em segundo plano com nohup (herda as permissões do Terminal)
echo "Iniciando servidor local de sincronismo em segundo plano..."
nohup python3 "$EXPORTER_PATH" --server > "${SCRIPT_DIR}/server.log" 2>&1 &

# Aguarda a inicialização do processo
sleep 2

# 3. Verifica a integridade da conexão local
echo "Verificando integridade da conexão..."
STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5003/safari_bookmarks.json)

if [ "$STATUS_CODE" -eq 200 ]; then
    echo ""
    echo -e "${GREEN}✓ SUCESSO: O Gateway de Sincronismo está ativo e operando!${NC}"
    echo -e "Servidor local ativo em: ${YELLOW}http://localhost:5003${NC}"
    echo -e "• iCloud Drive / OneDrive será atualizado automaticamente ao alterar favoritos no Safari."
    echo -e "• O Microsoft Edge local fará o sincronismo nativo a cada 5 minutos."
    echo -e "• Todos os outros dispositivos receberão os favoritos limpos pela nuvem Microsoft."
else
    echo ""
    echo -e "${RED}✗ ERRO: Falha ao inicializar o servidor de sincronismo.${NC}"
    echo -e "Por favor, examine os logs de erro em: ${YELLOW}${SCRIPT_DIR}/server.log${NC}"
fi

echo ""
echo -e "${BLUE}=====================================================${NC}"
echo "Esta janela do Terminal será fechada automaticamente em 4 segundos..."
sleep 4

# Fecha a janela do Terminal ativa silenciosamente
osascript -e 'tell application "Terminal" to close first window' &
exit 0
