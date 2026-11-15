// Run from the repo root: node --test tools/assets/tests/validate_gltf.test.mjs
import { spawnSync } from "node:child_process";
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import assert from "node:assert/strict";

const SCRIPT = "tools/assets/validate_gltf.mjs";
const GOOD = "assets/models/kit/wall_panel.glb";

function run(dir) {
  return spawnSync(process.execPath, [SCRIPT, dir], { encoding: "utf8" });
}

function folderWith(name, bytes) {
  const dir = mkdtempSync(join(tmpdir(), "gltf-"));
  mkdirSync(join(dir, "kit"));
  writeFileSync(join(dir, "kit", name), bytes);
  return dir;
}

test("committed models pass", () => {
  const result = run("assets/models");
  assert.equal(result.status, 0, result.stdout);
});

test("a valid model passes", () => {
  const dir = folderWith("ok.glb", readFileSync(GOOD));
  assert.equal(run(dir).status, 0);
});

test("a truncated model fails", () => {
  const bytes = readFileSync(GOOD);
  const dir = folderWith("cut.glb", bytes.subarray(0, bytes.length / 2));
  const result = run(dir);
  assert.equal(result.status, 1);
  assert.match(result.stdout, /FAIL kit\/cut\.glb/);
});

test("a model with a broken JSON chunk fails", () => {
  const bytes = Buffer.from(readFileSync(GOOD));
  const at = bytes.indexOf('"accessors"');
  bytes.write('"accessorz"', at);
  const dir = folderWith("bad.glb", bytes);
  const result = run(dir);
  assert.equal(result.status, 1);
  assert.match(result.stdout, /error/);
});

test("an empty folder fails", () => {
  const dir = mkdtempSync(join(tmpdir(), "gltf-"));
  assert.equal(run(dir).status, 1);
});

test("a good copy next to a bad one still fails the run", () => {
  const dir = folderWith("cut.glb", Buffer.from("glTF"));
  copyFileSync(GOOD, join(dir, "kit", "ok.glb"));
  const result = run(dir);
  assert.equal(result.status, 1);
  assert.match(result.stdout, /1\/2 models pass/);
});
