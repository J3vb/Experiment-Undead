// The launcher window: asks the Rust side for the state, installs updates on its own,
// and Play starts the newest installed game (docs/plans/separate-launcher.md, step 1).
"use strict";

const { invoke } = window.__TAURI__.core;
const { listen } = window.__TAURI__.event;

const playButton = document.getElementById("play");
const cancelButton = document.getElementById("cancel");
const channelSelect = document.getElementById("channel");
const statusLine = document.getElementById("status");
const headline = document.getElementById("headline");
const notes = document.getElementById("notes");
const progressBar = document.getElementById("progress");
const folderLine = document.getElementById("folder");

let online = true;
// Each version installs on its own once per run; after a failure Play turns into Retry.
let tried = "";
let retry = false;

function showStatus(text, isError) {
  statusLine.textContent = text;
  statusLine.classList.toggle("error", Boolean(isError));
}

async function show() {
  const state = await invoke("status");
  channelSelect.value = state.channel;
  folderLine.textContent = state.game_dir;
  const newest = state.newest;
  headline.textContent = newest ? `v${newest.version}` : online ? "No release on this channel yet" : "Offline";
  notes.textContent = newest ? newest.notes : "";
  progressBar.hidden = !state.busy;
  cancelButton.hidden = !state.busy;
  const installed = state.installed[0];
  retry = !state.busy && state.update_ready && tried === newest.version;
  playButton.disabled = state.busy || (!installed && !retry);
  playButton.textContent = state.busy ? "Installing" : retry && !installed ? "Retry" : "Play";
  if (state.busy || retry) return;
  if (state.update_ready) {
    tried = newest.version;
    showStatus(`Downloading v${newest.version}…`);
    progressBar.value = 0;
    try {
      await invoke("install");
    } catch (problem) {
      showStatus(String(problem), true);
    }
    return show();
  }
  if (installed) {
    showStatus(online ? `Up to date (v${installed})` : `Offline: playing v${installed}`);
  } else {
    showStatus(online ? "Nothing to install yet." : "Connect to the internet to install the game.", !online);
  }
}

async function refresh() {
  try {
    await invoke("refresh");
    online = true;
  } catch (problem) {
    online = false;
  }
  await show();
}

listen("progress", (event) => {
  const { done, total } = event.payload;
  progressBar.value = total > 0 ? Math.floor((done * 100) / total) : 0;
  playButton.textContent = `Installing ${progressBar.value}%`;
});

listen("finished", (event) => {
  const { ok, message } = event.payload;
  showStatus(message, !ok);
  show();
});

playButton.addEventListener("click", async () => {
  try {
    if (retry && playButton.textContent === "Retry") {
      tried = "";
      return show();
    }
    await invoke("play");
  } catch (problem) {
    showStatus(String(problem), true);
  }
});

cancelButton.addEventListener("click", () => invoke("cancel"));

channelSelect.addEventListener("change", async () => {
  await invoke("set_channel", { channel: channelSelect.value });
  tried = "";
  await show();
});

refresh();
