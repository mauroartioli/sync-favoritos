const endpointInput = document.getElementById("endpoint");
const tokenInput = document.getElementById("token");
const saveBtn = document.getElementById("save");
const statusEl = document.getElementById("status");

async function load() {
  const { sf_endpoint, sf_token } = await chrome.storage.local.get(["sf_endpoint", "sf_token"]);
  endpointInput.value = sf_endpoint || "http://127.0.0.1:5003/safari_bookmarks.json";
  tokenInput.value = sf_token || "";
}

async function save() {
  const sf_endpoint = endpointInput.value.trim();
  const sf_token = tokenInput.value.trim();
  await chrome.storage.local.set({ sf_endpoint, sf_token });
  statusEl.textContent = "Salvo.";
  statusEl.className = "ok";
  setTimeout(() => {
    statusEl.textContent = "";
    statusEl.className = "muted";
  }, 1500);
}

saveBtn.addEventListener("click", () => save());
load();

