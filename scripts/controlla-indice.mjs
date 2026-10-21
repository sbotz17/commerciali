#!/usr/bin/env node
// Controlla che la memoria ad albero sia allineata al repository.
// Uso: node scripts/controlla-indice.mjs
import fs from "node:fs";
import path from "node:path";
import { execSync } from "node:child_process";

const root = process.cwd();
const indexFile = path.join(root, "docs/progetto/indice.md");
const memDir = path.join(root, "docs/progetto/memoria");

function walk(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap(e => {
    const p = path.join(dir, e.name);
    return e.isDirectory() ? walk(p) : [p];
  });
}

let errori = 0;
const segnala = (msg) => { console.log("PROBLEMA:", msg); errori++; };

if (!fs.existsSync(indexFile)) { segnala("manca docs/progetto/indice.md"); process.exit(1); }
if (!fs.existsSync(memDir)) { segnala("manca docs/progetto/memoria/"); process.exit(1); }

const indice = fs.readFileSync(indexFile, "utf8");
const nodi = walk(memDir).filter(f => f.endsWith(".md") && path.basename(f) !== "README.md");

for (const nodo of nodi) {
  const rel = path.relative(memDir, nodo);
  const testo = fs.readFileSync(nodo, "utf8");
  if (!testo.includes("**Ultima revisione**")) segnala(`${rel}: manca "Ultima revisione"`);
  if (!indice.includes(path.basename(rel))) segnala(`${rel}: non compare nell'indice`);
}

const fileChiave = execSync("git ls-files", { encoding: "utf8" })
  .split("\n")
  .filter(Boolean)
  .filter(f => /^(index\.html|firestore\.rules|firebase\.json)$/.test(f) ||
               /^js\/[^/]+\.js$/.test(f) ||
               /^worker\/src\/[^/]+\.js$/.test(f))
  .filter(f => f !== "js/supabase.js"); // legacy, non caricato

const tuttaLaMemoria = nodi.map(n => fs.readFileSync(n, "utf8")).join("\n");
for (const f of fileChiave) {
  if (!tuttaLaMemoria.includes(f)) segnala(`file chiave non mappato: ${f}`);
}

console.log(`Nodi di memoria: ${nodi.length}`);
console.log(`File chiave controllati: ${fileChiave.length}`);
console.log(errori === 0 ? "INDICE OK" : `INDICE CON ${errori} PROBLEMI`);
process.exit(errori === 0 ? 0 : 1);
