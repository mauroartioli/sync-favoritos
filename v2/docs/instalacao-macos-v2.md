# Sync Favoritos v2 — Instalação (macOS)

## 1) Instalar o gateway (daemon + LaunchAgent)

No Terminal:

```bash
cd "/Users/mauroartioli/Documents/09.Projetos/Sync Favoritos/v2/macos"
chmod +x install.sh uninstall.sh
./install.sh
```

Isso instala:

- Binário: `~/Library/Application Support/SyncFavoritos/bin/syncfavoritosd`
- Config: `~/Library/Application Support/SyncFavoritos/config.json`
- Logs: `~/Library/Application Support/SyncFavoritos/syncfavoritosd.log`
- LaunchAgent: `~/Library/LaunchAgents/com.mauroartioli.syncfavoritos.plist`

## 2) Permissões (obrigatório)

Para o daemon conseguir ler `~/Library/Safari/Bookmarks.plist`, conceda **Acesso Total ao Disco** para:

`~/Library/Application Support/SyncFavoritos/bin/syncfavoritosd`

Caminho: Ajustes do Sistema → Privacidade e Segurança → Acesso Total ao Disco.

## 3) Instalar a extensão no Edge (sideload)

1. No Edge, abra: `edge://extensions`
2. Ative **Modo do desenvolvedor**
3. Clique em **Carregar descompactada**
4. Selecione a pasta:
   `.../Sync Favoritos/v2/edge-extension`

## 4) (Opcional) Configurar token/endpoint na extensão

Se você quiser habilitar token no gateway (ou mudar endpoint), abra:

- `edge://extensions` → Sync Favoritos (v2) → **Detalhes** → **Opções da extensão**

## Verificar se está rodando

Abra no navegador:

- `http://127.0.0.1:5003/health`

Se estiver ok, deve retornar JSON com `ok: true`.

