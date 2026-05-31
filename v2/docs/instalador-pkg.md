# Sync Favoritos v2 — Instalador `.pkg` (mais profissional)

Este instalador é o formato mais próximo de “app baixado da internet com instalador nativo do macOS”.

## O que ele instala

- App: `/Applications/SyncFavoritos.app` (sem ícone no Dock)
- LaunchAgent: `/Library/LaunchAgents/com.mauroartioli.syncfavoritos.plist`
  - Inicia automaticamente no login do usuário (rodando como o próprio usuário)

## Como gerar o `.pkg` (para publicar no GitHub Releases)

No Terminal:

```bash
cd "/Users/mauroartioli/Documents/09.Projetos/Sync Favoritos/v2/macos"
chmod +x build_pkg.sh
./build_pkg.sh
```

O arquivo sai em:

`/Users/mauroartioli/Documents/09.Projetos/Sync Favoritos/v2/dist/SyncFavoritos-2.0.0-unsigned.pkg`

## Como instalar

1. Dê 2 cliques no `.pkg`
2. Siga o instalador
3. Conceda **Acesso Total ao Disco** para:
   `/Applications/SyncFavoritos.app`
4. Faça logout/login (ou reinicie), para o LaunchAgent começar a rodar automaticamente
5. No Edge, carregue a extensão v2 (sideload) em `v2/edge-extension`

## Observação importante (assinatura/notarização)

Este `.pkg` é **unsigned** (não assinado). Para eliminar avisos do Gatekeeper ao distribuir para outras pessoas,
o próximo passo é assinar e notarizar (exige conta Apple Developer).

