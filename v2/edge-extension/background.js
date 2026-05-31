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
  await ensureOriginsPermission();
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

async function ensureOriginsPermission() {
  const origins = [
    "http://127.0.0.1:5004/*",
    "http://localhost:5004/*",
    "http://127.0.0.1:5003/*",
    "http://localhost:5003/*"
  ];

  try {
    const granted = await chrome.permissions.contains({ origins });
    if (granted) return;
    await chrome.permissions.request({ origins });
  } catch (err) {
    console.warn("Não foi possível solicitar permissões de origem automaticamente:", err);
  }
}

function chromiumToSimple(node) {
  if (node.url) {
    return { type: "url", name: node.title, url: node.url };
  }
  const children = (node.children || []).map(chromiumToSimple);
  return { type: "folder", name: node.title, children };
}

function normTitle(title) {
  return String(title || "").trim();
}

function desiredKey(node) {
  if (node.type === "url") return `u:${node.url || ""}`;
  return `f:${normTitle(node.name)}`;
}

function existingKey(node) {
  if (node.url) return `u:${node.url}`;
  return `f:${normTitle(node.title)}`;
}

function findBestMatch(desired, existingList, usedIds) {
  const wantKey = desiredKey(desired);
  for (const ex of existingList) {
    if (usedIds.has(ex.id)) continue;
    if (existingKey(ex) === wantKey) return ex;
  }
  // Fallback for URLs: also try title match when URL duplicates exist.
  if (desired.type === "url") {
    const wantTitle = normTitle(desired.name);
    for (const ex of existingList) {
      if (usedIds.has(ex.id)) continue;
      if (ex.url && normTitle(ex.title) === wantTitle) return ex;
    }
  }
  return null;
}

async function safeRemoveTree(id) {
  try {
    await chrome.bookmarks.removeTree(id);
  } catch (err) {
    console.warn(`Aviso ao remover nó ${id}:`, err);
  }
}

async function ensureUpdated(existing, desired) {
  const updates = {};
  const wantTitle = normTitle(desired.name);
  if (normTitle(existing.title) !== wantTitle) updates.title = wantTitle;
  if (desired.type === "url" && existing.url !== desired.url) updates.url = desired.url;
  if (Object.keys(updates).length === 0) return;
  await chrome.bookmarks.update(existing.id, updates);
}

async function reorderChildren(parentId, orderedIds) {
  for (let i = 0; i < orderedIds.length; i++) {
    try {
      await chrome.bookmarks.move(orderedIds[i], { parentId, index: i });
    } catch (err) {
      console.warn(`Aviso ao reordenar nó ${orderedIds[i]}:`, err);
    }
  }
}

async function syncFolderStrict(parentId, desiredNodes) {
  const existingChildren = await chrome.bookmarks.getChildren(parentId);
  const usedIds = new Set();
  const finalOrder = [];

  for (const desired of desiredNodes) {
    const match = findBestMatch(desired, existingChildren, usedIds);
    if (match) {
      usedIds.add(match.id);
      await ensureUpdated(match, desired);
      finalOrder.push(match.id);

      if (desired.type === "folder") {
        await syncFolderStrict(match.id, desired.children || []);
      }
      continue;
    }

    if (desired.type === "url") {
      const created = await chrome.bookmarks.create({
        parentId,
        title: normTitle(desired.name),
        url: desired.url
      });
      finalOrder.push(created.id);
      continue;
    }

    if (desired.type === "folder") {
      const createdFolder = await chrome.bookmarks.create({
        parentId,
        title: normTitle(desired.name)
      });
      finalOrder.push(createdFolder.id);
      await syncFolderStrict(createdFolder.id, desired.children || []);
    }
  }

  // Remove anything not present in Safari.
  for (const ex of existingChildren) {
    if (!usedIds.has(ex.id)) await safeRemoveTree(ex.id);
  }

  await reorderChildren(parentId, finalOrder);
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
    await ensureOriginsPermission();
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

    // Strict mirror (Safari is source of truth), but apply changes via diff instead of wipe+rebuild.
    await syncFolderStrict(barId, safariData.bookmark_bar || []);
    await syncFolderStrict(otherId, safariData.other || []);

    flashBadgeSuccess();
  } catch (err) {
    console.error("Falha ao sincronizar favoritos:", err);
    flashBadgeError();
  } finally {
    isSyncing = false;
  }
}
