/**
 * Sync Favoritos Gateway - Service Worker
 * Author: Antigravity AI
 * Description: Native sync engine that bridges Safari's bookmarks served locally on port 5003
 *              with Microsoft Edge using the native chrome.bookmarks API.
 */

let isSyncing = false;

// Inicializa a extensão
chrome.runtime.onInstalled.addListener(() => {
  console.log("Sync Favoritos Gateway instalado.");
  // Agenda a sincronização a cada 5 minutos
  chrome.alarms.create("sync_bookmarks", { periodInMinutes: 5 });
  // Sincroniza imediatamente após a instalação
  syncBookmarks();
});

// Sincroniza imediatamente ao abrir o navegador
chrome.runtime.onStartup.addListener(() => {
  console.log("Edge iniciado. Disparando sincronismo imediato...");
  syncBookmarks();
});

// Escuta os alarmes periódicos
chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === "sync_bookmarks") {
    syncBookmarks();
  }
});

// Clique no ícone da extensão força a sincronização sob demanda
chrome.action.onClicked.addListener(() => {
  console.log("Sincronização manual solicitada pelo usuário.");
  syncBookmarks();
});

/**
 * Converte recursivamente um nó do Chromium para o formato simplificado
 */
function chromiumToSimple(node) {
  if (node.url) {
    return {
      type: "url",
      name: node.title,
      url: node.url
    };
  } else {
    const children = (node.children || []).map(chromiumToSimple);
    return {
      type: "folder",
      name: node.title,
      children: children
    };
  }
}

/**
 * Limpa todos os favoritos de uma pasta raiz do Edge sem deletar a pasta em si
 */
async function clearFolder(folderId) {
  const children = await chrome.bookmarks.getChildren(folderId);
  for (const child of children) {
    try {
      await chrome.bookmarks.removeTree(child.id);
    } catch (err) {
      console.warn(`Aviso ao remover nó ${child.id}:`, err);
    }
  }
}

/**
 * Cria recursivamente a árvore de favoritos
 */
async function createNodes(simpleNodes, parentId) {
  for (const node of simpleNodes) {
    if (node.type === "url") {
      await chrome.bookmarks.create({
        parentId: parentId,
        title: node.name,
        url: node.url
      });
    } else if (node.type === "folder") {
      const createdFolder = await chrome.bookmarks.create({
        parentId: parentId,
        title: node.name
      });
      await createNodes(node.children || [], createdFolder.id);
    }
  }
}

/**
 * Sinaliza visualmente o sucesso da sincronização na barra de ferramentas do Edge
 */
function flashBadgeSuccess() {
  chrome.action.setBadgeText({ text: "✓" });
  chrome.action.setBadgeBackgroundColor({ color: "#2ECC71" }); // Verde esmeralda elegante
  
  setTimeout(() => {
    chrome.action.setBadgeText({ text: "" });
  }, 4000);
}

/**
 * Executa o fluxo de sincronismo nativo
 */
async function syncBookmarks() {
  if (isSyncing) {
    console.log("Sincronização já em andamento. Ignorando...");
    return;
  }
  isSyncing = true;
  
  try {
    // Altera o badge para indicar processamento
    chrome.action.setBadgeText({ text: "..." });
    chrome.action.setBadgeBackgroundColor({ color: "#3498DB" }); // Azul
    
    // Busca dados do servidor local Python
    const response = await fetch("http://localhost:5003/safari_bookmarks.json");
    if (!response.ok) {
      throw new Error(`Servidor local retornou status HTTP ${response.status}`);
    }
    const safariData = await response.json();
    
    // Captura os favoritos atuais do Edge nas duas raízes principais de forma dinâmica.
    // Em alguns perfis (devido à sincronização em nuvem ou redefinição), os IDs das pastas
    // raiz podem mudar de "1"/"2" para outros valores (como "133"/"134").
    const tree = await chrome.bookmarks.getTree();
    const rootNode = tree[0];
    if (!rootNode || !rootNode.children || rootNode.children.length < 2) {
      throw new Error("Não foi possível encontrar as pastas raiz de favoritos padrão (Barra e Outros).");
    }
    
    const barId = rootNode.children[0].id;
    const otherId = rootNode.children[1].id;
    
    console.log(`IDs das pastas raiz identificados dinamicamente: Barra = ${barId}, Outros = ${otherId}`);
    
    const barNodes = await chrome.bookmarks.getChildren(barId);
    const otherNodes = await chrome.bookmarks.getChildren(otherId);
    
    const currentBarSimplified = barNodes.map(chromiumToSimple);
    const currentOtherSimplified = otherNodes.map(chromiumToSimple);
    
    const currentEdgeState = {
      bookmark_bar: currentBarSimplified,
      other: currentOtherSimplified
    };
    
    // Compara o estado atual do Edge com os favoritos mais recentes do Safari
    const edgeStr = JSON.stringify(currentEdgeState);
    const safariStr = JSON.stringify(safariData);
    
    if (edgeStr === safariStr) {
      console.log("✓ Os favoritos do Edge já estão perfeitamente idênticos ao Safari.");
      chrome.action.setBadgeText({ text: "" });
      return;
    }
    
    console.log("Alteração detectada nos favoritos! Iniciando sincronização nativa...");
    
    // Passo 1: Limpar as pastas sem deletar as raízes de sistema
    await clearFolder(barId);
    await clearFolder(otherId);
    
    // Passo 2: Reconstruir usando a API nativa
    await createNodes(safariData.bookmark_bar || [], barId);
    await createNodes(safariData.other || [], otherId);
    
    console.log("✓ Sincronização de favoritos realizada com sucesso!");
    flashBadgeSuccess();
  } catch (error) {
    console.error("Falha ao sincronizar favoritos do Safari:", error);
    // Sinaliza erro com um badge vermelho por alguns segundos
    chrome.action.setBadgeText({ text: "ERR" });
    chrome.action.setBadgeBackgroundColor({ color: "#E74C3C" }); // Vermelho
    setTimeout(() => {
      chrome.action.setBadgeText({ text: "" });
    }, 5000);
  } finally {
    isSyncing = false;
  }
}
