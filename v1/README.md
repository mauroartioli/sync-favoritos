# Sync Favoritos (Safari ➜ Microsoft Edge Cloud ➜ Todos os Dispositivos)

Este projeto oferece uma solução definitiva, automatizada, limpa e de **mão única (unidirecional)** para espelhar os seus favoritos do **Safari** (macOS/iOS) diretamente para o **Microsoft Edge** e mantê-los sincronizados perfeitamente em todas as suas máquinas (Windows Desktop, LegionGo e o Notebook Corporativo restrito) de forma nativa e sem duplicações!

A sincronização realiza um **espelhamento direto e completo** (sobrescrevendo os favoritos do Edge com os do Safari) para garantir que a sua experiência e hierarquia de favoritos sejam idênticas em qualquer dispositivo.

---

## 🚀 Como Funciona a Nova Arquitetura "Mac Edge Gateway"

Para resolver o problema das duplicações geradas pela sincronização de nuvem da Microsoft, esta nova arquitetura utiliza a **API oficial do Microsoft Edge** no Mac para atualizar os favoritos. Desta forma, a nuvem do Edge entende perfeitamente os comandos de exclusão e adição, mantendo o sincronismo limpo e propagando-o de forma nativa.

```
+----------------------------+
| Safari (Bookmarks.plist)   | <--- Fonte da Verdade
+----------------------------+
              |
              v (Análise em Tempo Real & Monitoramento)
+----------------------------+
| mac_exporter.py (Servidor)  | <--- Rodando localmente em http://localhost:5003
+----------------------------+
              |
              v (API Fetch local)
+----------------------------+
| Extensão Edge no Mac M4    | <--- API Nativa chrome.bookmarks
+----------------------------+
              |
              v (Sincronismo nativo da Microsoft)
+----------------------------+
| Microsoft Edge Cloud Sync  |
+----------------------------+
   /          |          \
  v           v           v
Windows    LegionGo    Notebook Corporativo (100% Nativo, sem scripts!)
```

### Principais Benefícios:
1. **Zero Scripts no Windows:** O notebook corporativo bloqueado e os PCs Windows pessoais **não precisam rodar mais nada!** Eles receberão seus favoritos limpos diretamente do sincronismo nativo da conta Microsoft.
2. **Zero Duplicações:** A extensão local no Mac usa a API oficial do navegador, o que garante que a nuvem saiba exatamente o que foi adicionado e deletado, acabando com as pastas duplicadas.
3. **Disponível na Nuvem:** Se você fizer login no Edge de qualquer computador público ou de terceiros, seus favoritos corretos estarão lá instantaneamente.

---

## 🛠️ Configuração no macOS (Macbook Pro M4)

Siga os **3 passos rápidos** abaixo para deixar tudo funcionando no seu Mac:

### Passo 1: Limpeza Inicial (Redefinir Sincronização)
Antes de ativarmos a nova sincronização nativa, faremos uma rápida limpeza na nuvem do Edge para garantir que qualquer "lixo" ou favoritos duplicados anteriores sejam excluídos dos servidores da Microsoft:
1. No Microsoft Edge do Mac, abra a página `edge://settings/profiles/sync`.
2. Vá até o final da página e clique em **"Redefinir sincronização" (Reset Sync)**.
3. Marque a opção para excluir os dados de sincronização dos servidores da Microsoft e clique em **Redefinir**.

---

### Passo 2: Configurar a Inicialização Automática e Silenciosa
Para uma experiência extremamente transparente, compilamos um aplicativo macOS dedicado (`v1/mac/SyncFavoritos.app`) configurado como um **Agente de Sistema Oculto**. Ele inicia automaticamente com o Mac de forma 100% invisível, sem abrir nenhuma janela e sem exibir ícone no Dock:
1. No Finder, navegue até a pasta do projeto em: `Documents/09.Projetos/Sync Favoritos/v1/mac/`.
2. Abra o Terminal nesta pasta e execute o script de instalação automática:
   ```bash
   chmod +x setup_mac.sh && ./setup_mac.sh
   ```
3. Pronto! O aplicativo silencioso está registrado nos seus **Itens de Inicialização** (*Ajustes do Sistema ➜ Geral ➜ Itens de Inicialização*).
4. *Dica:* Ele iniciará o servidor Python local em segundo plano na porta 5003 silenciosamente sempre que você logar no Mac. Para parar ou ver o status do servidor sob demanda, você pode usar o atalho `iniciar_servidor.command`.

---

### Passo 3: Carregar a Extensão no Microsoft Edge do Mac
Agora, vamos carregar a extensão exclusiva no Edge do seu Mac para fazer a ponte de sincronismo definitiva:
1. Abra o Microsoft Edge no seu Mac.
2. Acesse a página de extensões digitando `edge://extensions` na barra de endereços.
3. No canto inferior esquerdo, ative a opção **"Modo de desenvolvedor" (Developer mode)**.
4. Clique no botão **"Carregar descompactada" (Load unpacked)** que aparecerá no topo da página.
5. Selecione a pasta da extensão deste projeto localizada em:
   `/Users/mauroartioli/Documents/09.Projetos/Sync Favoritos/v1/mac/extension`
6. **Pronto!** A extensão será instalada e começará a rodar imediatamente.

---

## 💡 Como Funciona o Sincronismo no Dia a Dia

*   **Feedback Visual Premium:** Quando a extensão sincroniza com sucesso, ela exibe um badge verde com um **`✓`** no ícone da extensão na barra de ferramentas por 4 segundos para te manter informado.
*   **Inteligente e Leve:** A extensão se comunica com o servidor a cada 5 minutos. Ela compara a estrutura de pastas do Safari com as do Edge e **só executa alterações se detectar alguma mudança real**, protegendo o desempenho do seu computador e do navegador.
*   **Watcher de Favoritos automático:** Em segundo plano, a thread do script Python vigia o arquivo `Bookmarks.plist` do Safari a cada 5 segundos. Se você adicionar um favorito no Safari, ela atualiza o JSON de backup local imediatamente.
*   **Backup de Segurança:** O Edge do Mac e os scripts continuam criando um arquivo de backup de segurança (`Bookmarks.bak`) antes de realizar alterações estruturais, garantindo total segurança de dados.

---

## 🔄 Como Reinstalar do Zero (Se Formatar o Mac)

Se você formatar o Mac ou precisar configurar uma nova máquina do zero, a reinstalação é automática e leva menos de 2 minutos:

1. **Baixe/Copie a pasta do projeto** (`Sync Favoritos/`) para o seu Mac no mesmo caminho: `~/Documents/09.Projetos/Sync Favoritos/`.
2. **Execute o Instalador Automático:**
   * Abra o Terminal na pasta `v1/mac/` do projeto e execute:
     ```bash
     chmod +x setup_mac.sh && ./setup_mac.sh
     ```
   * Isso compilará automaticamente o `SyncFavoritos.app` nativo, aplicará o modo oculto invisível, assinará o aplicativo e o registrará nos seus Ajustes de Login do macOS.
3. **Autorize o Acesso ao Disco (TCC Bypass):**
   * Vá em *Ajustes do Sistema ➜ Privacidade e Segurança ➜ Acesso Total ao Disco*.
   * Arraste a pasta `SyncFavoritos.app` (gerada dentro de `v1/mac/`) para a lista e ative a chave ao lado dela.
4. **Carregue a Extensão no Edge:**
   * No Microsoft Edge, acesse `edge://extensions`.
   * Ative o "Modo de desenvolvedor", clique em "Carregar descompactada" e selecione a pasta `v1/mac/extension`.

*E pronto! Todo o ecossistema silencioso estará ativo e funcionando novamente!*
