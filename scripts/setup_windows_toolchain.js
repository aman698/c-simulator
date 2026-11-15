#!/usr/bin/env node
/**
 * Windows-native fallback toolchain installer (no admin rights needed).
 *
 * Downloads the official MSYS2 UCRT64 `gcc` package and all of its runtime
 * dependencies from repo.msys2.org, verifies every package against the
 * SHA-256 recorded in the signed repo database, and unpacks them into
 * `.toolchain/msys64/` inside this project. The judge auto-detects
 * `.toolchain/msys64/ucrt64/bin/gcc.exe` when no `gcc` is on PATH.
 *
 * The RECOMMENDED setup is still WSL2/Linux (real ASan + UBSan + LeakSanitizer).
 * MinGW gcc has no AddressSanitizer/LeakSanitizer; the judge then uses its
 * portable heap checker (judge-runtime/heapcheck.h) instead. See README.md.
 *
 * Usage:  node scripts/setup_windows_toolchain.js
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const DEST = path.join(ROOT, '.toolchain', 'msys64');
// --clang additionally installs the CLANG64 environment (clang + compiler-rt with a
// Windows AddressSanitizer/UBSan runtime). The validator uses it for an extra
// memory-safety pass: `npm run validate -- --cc clang`.
const WANT_CLANG = process.argv.includes('--clang');
const ENV = WANT_CLANG ? 'clang64' : 'ucrt64';
const REPO = `https://repo.msys2.org/mingw/${ENV}/`;
const PREFIX = WANT_CLANG ? 'mingw-w64-clang-x86_64-' : 'mingw-w64-ucrt-x86_64-';
const ROOT_PACKAGES = WANT_CLANG ? [`${PREFIX}clang`, `${PREFIX}compiler-rt`, `${PREFIX}lld`] : [`${PREFIX}gcc`];

function decompress(buf) {
  if (buf[0] === 0x28 && buf[1] === 0xb5 && buf[2] === 0x2f && buf[3] === 0xfd) {
    if (typeof zlib.zstdDecompressSync !== 'function') {
      throw new Error('This Node.js lacks zstd support; use Node >= 22.15 / 23.8.');
    }
    return zlib.zstdDecompressSync(buf);
  }
  if (buf[0] === 0x1f && buf[1] === 0x8b) return zlib.gunzipSync(buf);
  if (buf[0] === 0xfd && buf[1] === 0x37) throw new Error('xz archives are not supported');
  return buf; // plain tar
}

/** Minimal tar reader (ustar + pax + GNU long names). Yields {name, type, data, linkname}. */
function* readTar(buf) {
  let off = 0;
  let paxPath = null;
  let paxLink = null;
  let gnuLong = null;
  while (off + 512 <= buf.length) {
    const hdr = buf.subarray(off, off + 512);
    if (hdr.every((b) => b === 0)) break;
    const str = (a, b) => hdr.subarray(a, b).toString('utf8').replace(/\0.*$/s, '');
    let name = str(0, 100);
    const sizeField = str(124, 136).trim();
    const size = sizeField ? parseInt(sizeField, 8) : 0;
    const type = String.fromCharCode(hdr[156] || 48);
    let linkname = str(157, 257);
    const magic = str(257, 263);
    if (magic.startsWith('ustar')) {
      const prefix = str(345, 500);
      if (prefix) name = `${prefix}/${name}`;
    }
    const dataStart = off + 512;
    const data = buf.subarray(dataStart, dataStart + size);
    off = dataStart + Math.ceil(size / 512) * 512;
    if (type === 'x' || type === 'g') {
      const text = data.toString('utf8');
      let i = 0;
      while (i < text.length) {
        const sp = text.indexOf(' ', i);
        if (sp < 0) break;
        const len = parseInt(text.slice(i, sp), 10);
        const rec = text.slice(sp + 1, i + len - 1);
        const eq = rec.indexOf('=');
        const k = rec.slice(0, eq);
        const v = rec.slice(eq + 1);
        if (type === 'x' && k === 'path') paxPath = v;
        if (type === 'x' && k === 'linkpath') paxLink = v;
        i += len;
      }
      continue;
    }
    if (type === 'L') {
      gnuLong = data.toString('utf8').replace(/\0.*$/s, '');
      continue;
    }
    if (paxPath) name = paxPath;
    if (gnuLong) name = gnuLong;
    if (paxLink) linkname = paxLink;
    paxPath = paxLink = gnuLong = null;
    yield { name, type, data, linkname };
  }
}

function parseDesc(text) {
  const out = {};
  const blocks = text.split(/\n\n+/);
  for (const b of blocks) {
    const lines = b.trim().split('\n');
    const m = /^%([A-Z0-9]+)%$/.exec(lines[0] || '');
    if (m) out[m[1]] = lines.slice(1).filter(Boolean);
  }
  return out;
}

async function fetchBuf(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`GET ${url} -> HTTP ${res.status}`);
  return Buffer.from(await res.arrayBuffer());
}

function stripConstraint(dep) {
  return dep.split(/[<>=:]/)[0].trim();
}

async function main() {
  if (process.platform !== 'win32') {
    console.log('This installer is only for native Windows. On Linux/WSL install gcc with your package manager.');
    return;
  }
  fs.mkdirSync(DEST, { recursive: true });
  console.log(`Fetching package database ${REPO}${ENV}.db ...`);
  const dbTar = decompress(await fetchBuf(`${REPO}${ENV}.db`));
  const pkgs = new Map();
  const provides = new Map();
  for (const entry of readTar(dbTar)) {
    if (!entry.name.endsWith('/desc')) continue;
    const d = parseDesc(entry.data.toString('utf8'));
    const name = d.NAME?.[0];
    if (!name) continue;
    const info = {
      name,
      version: d.VERSION?.[0],
      filename: d.FILENAME?.[0],
      sha256: d.SHA256SUM?.[0],
      depends: (d.DEPENDS || []).map(stripConstraint),
    };
    pkgs.set(name, info);
    for (const p of d.PROVIDES || []) provides.set(stripConstraint(p), name);
  }
  console.log(`  ${pkgs.size} packages in database.`);

  const needed = new Map();
  const queue = [...ROOT_PACKAGES];
  while (queue.length) {
    const want = queue.shift();
    const real = pkgs.has(want) ? want : provides.get(want);
    if (!real) throw new Error(`Cannot resolve dependency ${want}`);
    if (needed.has(real)) continue;
    const info = pkgs.get(real);
    needed.set(real, info);
    queue.push(...info.depends);
  }
  console.log(`Resolved ${needed.size} packages.`);

  const markerDir = path.join(DEST, '.installed');
  fs.mkdirSync(markerDir, { recursive: true });
  for (const info of needed.values()) {
    const marker = path.join(markerDir, `${info.name}-${info.version}`);
    if (fs.existsSync(marker)) {
      console.log(`  = ${info.name} ${info.version} (already installed)`);
      continue;
    }
    process.stdout.write(`  + ${info.name} ${info.version} ... `);
    const raw = await fetchBuf(REPO + info.filename);
    const sha = crypto.createHash('sha256').update(raw).digest('hex');
    if (sha !== info.sha256) throw new Error(`SHA-256 mismatch for ${info.filename}`);
    const tar = decompress(raw);
    const deferredLinks = [];
    let files = 0;
    for (const e of readTar(tar)) {
      if (e.name.startsWith('.')) continue; // .PKGINFO, .MTREE, .BUILDINFO
      const target = path.join(DEST, e.name);
      if (!target.startsWith(DEST)) throw new Error(`Unsafe path in archive: ${e.name}`);
      if (e.type === '5') {
        fs.mkdirSync(target, { recursive: true });
      } else if (e.type === '0' || e.type === '\0' || e.type === '7') {
        fs.mkdirSync(path.dirname(target), { recursive: true });
        fs.writeFileSync(target, e.data);
        files++;
      } else if (e.type === '1' || e.type === '2') {
        deferredLinks.push(e);
      }
    }
    for (const e of deferredLinks) {
      const target = path.join(DEST, e.name);
      const src = e.type === '1' ? path.join(DEST, e.linkname) : path.resolve(path.dirname(target), e.linkname);
      if (fs.existsSync(src) && fs.statSync(src).isFile()) {
        fs.mkdirSync(path.dirname(target), { recursive: true });
        fs.copyFileSync(src, target);
      }
    }
    fs.writeFileSync(marker, sha);
    console.log(`ok (${(raw.length / 1048576).toFixed(1)} MB, ${files} files)`);
  }
  const exe = path.join(DEST, ENV, 'bin', WANT_CLANG ? 'clang.exe' : 'gcc.exe');
  console.log(fs.existsSync(exe) ? `\nDone. Installed ${exe}` : `\nWARNING: ${exe} not found after install`);
}

main().catch((err) => {
  console.error(`\nERROR: ${err.message}`);
  process.exit(1);
});
