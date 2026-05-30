# Sync Favoritos v2 (em construção)

Objetivo da v2: manter a mesma transparência da v1 (sem janela, sem ícone, sem UI), mas virar um **produto mais “encapsulado”**:

- Serviço local (gateway) iniciado automaticamente no login via **launchd/LaunchAgent**
- Binário/app **nativo macOS (Swift)**, sem dependência de Python instalado
- Extensão do Edge ainda existe, mas com instalação guiada (sideload) e comunicação autenticada (token)

## Status

- Ainda não implementado: aqui é a pasta reservada para a evolução.
- A versão funcionando hoje está em `v1/`.

## Próximos componentes (planejados)

- `macos/` (Swift): serviço + utilitário de instalação do LaunchAgent
- `edge-extension/`: extensão com token + sync por diff (em vez de “apagar e recriar tudo”)
- `docs/`: instalação, permissões (TCC), troubleshooting, releases

