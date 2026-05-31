# Sync Favoritos v2 (em construção)

Objetivo da v2: manter a mesma transparência da v1 (sem janela, sem ícone, sem UI), mas virar um **produto mais “encapsulado”**:

- Serviço local (gateway) iniciado automaticamente no login via **launchd/LaunchAgent**
- Binário/app **nativo macOS (Swift)**, sem dependência de Python instalado
- Extensão do Edge ainda existe, mas com instalação guiada (sideload) e comunicação autenticada (token)

## Status

- Base inicial implementada (daemon Swift + LaunchAgent + extensão v2).
- A versão funcionando hoje continua em `v1/`.

## Próximos componentes (planejados)

- `macos/` (Swift): serviço + instalador LaunchAgent (já existe um `install.sh`)
- `edge-extension/`: extensão com token (já existe); próximo passo é sync por diff (em vez de “apagar e recriar tudo”)
- `docs/`: instalação, permissões (TCC), troubleshooting, releases

## Instalar (macOS)

1. No Terminal:
   ```bash
   cd "/Users/mauroartioli/Documents/09.Projetos/Sync Favoritos/v2/macos"
   chmod +x install.sh uninstall.sh
   ./install.sh
   ```
2. Conceda **Acesso Total ao Disco** para o binário instalado em:
   `~/Library/Application Support/SyncFavoritos/SyncFavoritos.app`
3. No Edge do Mac: carregue a extensão da pasta `v2/edge-extension`.

Obs.: a v2 usa a porta `5004` por padrão (para evitar conflito com a v1, que usa `5003`).
