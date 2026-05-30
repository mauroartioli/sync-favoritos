# GitHub (passo a passo bem básico)

Este guia é para você conseguir **subir este projeto para o GitHub** e depois compartilhar um link.

## 1) Criar uma conta

1. Acesse o site do GitHub e crie uma conta.
2. Confirme o e-mail.

## 2) Instalar o Git no Mac

1. Abra o Terminal.
2. Rode:
   ```bash
   git --version
   ```
3. Se não tiver, o macOS normalmente oferece instalar as “Command Line Tools”. Aceite.

## 3) Criar um repositório no GitHub (site)

1. No GitHub, clique em **New repository**.
2. Nome sugerido: `sync-favoritos`
3. Marque como **Public** (se você quer download livre) ou **Private** (se preferir).
4. Não precisa adicionar README (já temos um).

## 4) Subir o projeto (comandos no Terminal)

No Terminal, dentro da pasta do projeto:

```bash
cd "/Users/mauroartioli/Documents/09.Projetos/Sync Favoritos"
git init
git add .
git commit -m "chore: snapshot v1 e scaffold v2"
git branch -M main
git remote add origin <COLE_AQUI_A_URL_DO_SEU_REPO>
git push -u origin main
```

No GitHub, a URL do repo é algo como:
- HTTPS: `https://github.com/SEU_USUARIO/sync-favoritos.git`

## 5) Compartilhar

Depois do push, você pode compartilhar o link do repositório:
- `https://github.com/SEU_USUARIO/sync-favoritos`

## 6) (Opcional) Releases para download

Quando você tiver um instalador/dmg/zip, dá para publicar em **Releases** no GitHub:

1. Página do repositório → **Releases** → **Draft a new release**
2. Preenche tag (ex.: `v1.0.0`) e faz upload do arquivo.

