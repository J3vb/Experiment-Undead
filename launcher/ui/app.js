// The bottom bar: asks the Rust side for the state, installs updates on its own, and Play
// starts the newest installed game (docs/plans/separate-launcher.md, steps 1 and 5).
"use strict";

const { invoke } = window.__TAURI__.core;
const { listen } = window.__TAURI__.event;

const playButton = document.getElementById("play");
const playText = document.getElementById("play-text");
const cancelButton = document.getElementById("cancel");
const channelSelects = document.querySelectorAll("select.channel");
const statusLine = document.getElementById("status");
const progressBar = document.getElementById("progress");
const diskUsed = document.getElementById("disk-used");
const diskFree = document.getElementById("disk-free");

let online = true;
// Each version installs on its own once per run; after a failure Play turns into Retry.
let tried = "";
let retry = false;

function showStatus(text, kind) {
  statusLine.textContent = text;
  statusLine.className = kind || "";
}

function gigabytes(bytes) {
  return bytes >= 1e9 ? `${(bytes / 1e9).toFixed(1)} GB` : `${Math.round(bytes / 1e6)} MB`;
}

async function showDisk(busy) {
  const disk = await invoke("disk");
  diskUsed.textContent = disk.installed ? gigabytes(disk.installed) : "Not installed";
  diskFree.textContent = `${gigabytes(disk.free)} free`;
  if (!busy) {
    const total = disk.installed + disk.free;
    progressBar.value = total > 0 ? Math.max(1, Math.round((disk.installed * 100) / total)) : 0;
  }
}

function showChannels(state) {
  for (const select of channelSelects) {
    select.value = state.channel;
    select.options[0].textContent = state.stable ? `Stable v${state.stable}` : "Stable";
    select.options[1].textContent = state.test ? `Test v${state.test}` : "Test builds";
  }
}

async function show() {
  const state = await invoke("status");
  showChannels(state);
  document.dispatchEvent(new CustomEvent("launcher-state", { detail: state }));
  showDisk(state.busy);
  const newest = state.newest;
  cancelButton.hidden = !state.busy;
  const installed = state.installed[0];
  retry = !state.busy && state.update_ready && tried === newest.version;
  playButton.disabled = state.busy || (!installed && !retry);
  playText.textContent = state.busy ? "Installing" : retry && !installed ? "Retry" : "Play";
  if (state.busy || retry) return;
  if (state.update_ready) {
    tried = newest.version;
    playText.textContent = installed ? "Update" : "Install";
    showStatus(`Downloading v${newest.version}…`);
    progressBar.value = 0;
    try {
      await invoke("install");
    } catch (problem) {
      showStatus(String(problem), "error");
    }
    return show();
  }
  if (installed) {
    showStatus(online ? "Up to date" : `Offline: playing v${installed}`, online ? "ok" : "");
  } else {
    showStatus(online ? "Nothing to install yet." : "Connect to the internet to install the game.", online ? "" : "error");
  }
}

async function refresh() {
  try {
    await invoke("refresh");
    online = true;
  } catch (problem) {
    online = false;
  }
  if (online) {
    showStatus("Checking for a launcher update…");
    try {
      await invoke("self_update");
    } catch (problem) {
      // A failed launcher update keeps this launcher; the game still installs and plays.
    }
  }
  await show();
}

listen("progress", (event) => {
  const { done, total } = event.payload;
  progressBar.value = total > 0 ? Math.floor((done * 100) / total) : 0;
  playText.textContent = `Installing ${progressBar.value}%`;
});

listen("finished", (event) => {
  const { ok, message } = event.payload;
  showStatus(message, ok ? "ok" : "error");
  show();
});

playButton.addEventListener("click", async () => {
  try {
    if (retry && playText.textContent === "Retry") {
      tried = "";
      return show();
    }
    await invoke("play");
  } catch (problem) {
    showStatus(String(problem), "error");
  }
});

cancelButton.addEventListener("click", () => invoke("cancel"));

for (const select of channelSelects) {
  select.addEventListener("change", async () => {
    await invoke("set_channel", { channel: select.value });
    tried = "";
    await show();
  });
}

// After pages.js and host.js have added their listeners.
window.addEventListener("DOMContentLoaded", refresh);
