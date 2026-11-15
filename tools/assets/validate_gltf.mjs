// Runs the Khronos glTF validator on every .glb under a folder.
// Usage: node tools/assets/validate_gltf.mjs [folder]   (default: assets/models)
// Fails on any validator error; warnings are printed but allowed.
import { readFileSync, readdirSync } from "node:fs";
import { join, relative } from "node:path";
import validator from "gltf-validator";

const root = process.argv[2] ?? "assets/models";

function findGlbs(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) return findGlbs(path);
    return entry.name.endsWith(".glb") ? [path] : [];
  });
}

const files = findGlbs(root).sort();
if (files.length === 0) {
  console.error(`no .glb files in ${root}`);
  process.exit(1);
}

let failed = 0;
for (const file of files) {
  const report = await validator.validateBytes(new Uint8Array(readFileSync(file)), {
    uri: file,
    maxIssues: 50,
  });
  const { numErrors, numWarnings, messages } = report.issues;
  console.log(`${numErrors ? "FAIL" : "ok  "} ${relative(root, file)} (${numErrors} errors, ${numWarnings} warnings)`);
  for (const m of messages.filter((m) => m.severity <= 1)) {
    console.log(`     - ${m.severity === 0 ? "error" : "warning"} ${m.code}: ${m.message} (${m.pointer ?? ""})`);
  }
  if (numErrors) failed += 1;
}
console.log(`${files.length - failed}/${files.length} models pass the glTF validator`);
process.exit(failed ? 1 : 0);
