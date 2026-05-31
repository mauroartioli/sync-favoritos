/**
 * Sync Favoritos Gateway - Service Worker (v2)
 *
 * v2 changes:
 * - Optional token auth via header `X-SF-Token` (stored in chrome.storage.local as `sf_token`)
 */

let isSyncing = false;

const DEFAULTS = {
  endpoint: "http://127.0.0.1:5004/safari_bookmarks.json",
  token: ""
};

chrome.runtime.onInstalled.addListener(async () => {
  await ensureDefaults();
  chrome.alarms.create("sync_bookmarks", { periodInMinutes: 5 });
  syncBookmarks();
});

chrome.runtime.onStartup.addListener(() => {
  syncBookmarks();
});

chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === "sync_bookmarks") syncBookmarks();
});

chrome.action.onClicked.addListener(() => {
  syncBookmarks();
});

async function ensureDefaults() {
  const stored = await chrome.storage.local.get(["sf_endpoint", "sf_token"]);
  const toSet = {};
  if (typeof stored.sf_endpoint !== "string") toSet.sf_endpoint = DEFAULTS.endpoint;
  if (typeof stored.sf_token !== "string") toSet.sf_token = DEFAULTS.token;
  if (Object.keys(toSet).length > 0) await chrome.storage.local.set(toSet);
}

function chromiumToSimple(node) {
  if (node.url) {
    return { type: "url", name: node.title, url: node.url };
  }
  const children = (node.children || []).map(chromiumToSimple);
  return { type: "folder", name: node.title, children };
}

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

async function createNodes(simpleNodes, parentId) {
  for (const node of simpleNodes) {
    if (node.type === "url") {
      await chrome.bookmarks.create({ parentId, title: node.name, url: node.url });
      continue;
    }
    if (node.type === "folder") {
      const createdFolder = await chrome.bookmarks.create({ parentId, title: node.name });
      await createNodes(node.children || [], createdFolder.id);
    }
  }
}

function flashBadgeSuccess() {
  chrome.action.setBadgeText({ text: "✓" });
  chrome.action.setBadgeBackgroundColor({ color: "#2ECC71" });
  setTimeout(() => chrome.action.setBadgeText({ text: "" }), 4000);
}

function flashBadgeError() {
  chrome.action.setBadgeText({ text: "ERR" });
  chrome.action.setBadgeBackgroundColor({ color: "#E74C3C" });
  setTimeout(() => chrome.action.setBadgeText({ text: "" }), 5000);
}

async function syncBookmarks() {
  if (isSyncing) return;
  isSyncing = true;

  try {
    chrome.action.setBadgeText({ text: "..." });
    chrome.action.setBadgeBackgroundColor({ color: "#3498DB" });

    await ensureDefaults();
    const { sf_endpoint, sf_token } = await chrome.storage.local.get(["sf_endpoint", "sf_token"]);

    const headers = {};
    if (sf_token) headers["X-SF-Token"] = sf_token;

    const response = await fetch(sf_endpoint, { headers });
    if (!response.ok) throw new Error(`Gateway retornou HTTP ${response.status}`);
    const safariData = await response.json();

    const tree = await chrome.bookmarks.getTree();
    const rootNode = tree[0];
    if (!rootNode?.children || rootNode.children.length < 2) {
      throw new Error("Não foi possível encontrar as pastas raiz de favoritos padrão.");
    }

    const barId = rootNode.children[0].id;
    const otherId = rootNode.children[1].id;

    const barNodes = await chrome.bookmarks.getChildren(barId);
    const otherNodes = await chrome.bookmarks.getChildren(otherId);

    const currentEdgeState = {
      bookmark_bar: barNodes.map(chromiumToSimple),
      other: otherNodes.map(chromiumToSimple)
    };

    if (JSON.stringify(currentEdgeState) === JSON.stringify(safariData)) {
      chrome.action.setBadgeText({ text: "" });
      return;
    }

    await clearFolder(barId);
    await clearFolder(otherId);
    await createNodes(safariData.bookmark_bar || [], barId);
    await createNodes(safariData.other || [], otherId);

    flashBadgeSuccess();
  } catch (err) {
    console.error("Falha ao sincronizar favoritos:", err);
    flashBadgeError();
  } finally {
    isSyncing = false;
  }
}
