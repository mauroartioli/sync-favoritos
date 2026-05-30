# Erro 403 no `git push` (como resolver)

Se ao tentar enviar para o GitHub aparecer algo como:

> `Permission to <usuario>/<repo>.git denied ... (403)`

significa que o Git está autenticando com uma conta errada (ou sem permissão).

## Opção A (recomendado): GitHub CLI (gh)

1. Instale o GitHub CLI (`gh`).
2. No Terminal:
   ```bash
   gh auth login
   ```
3. Depois disso, rode o `git push` normalmente.

## Opção B: Personal Access Token (PAT)

1. No GitHub: Settings → Developer settings → Personal access tokens.
2. Crie um token com permissão para **repo**.
3. Use o token no push (o GitHub não aceita mais senha):
   - quando o Git pedir “password”, cole o token

## Dica

Se você tiver mais de uma conta no GitHub, confira qual usuário está logado no `gh`:

```bash
gh auth status
```

