// Bumps the desktop app version everywhere a release needs it (Tauri v2's
// tauri.conf.json only accepts a literal semver or a package.json path, so
// this script — not a config pointer — keeps the copies in sync) and
// prepends a Flathub release entry.
//
// Usage: npm run bump -- 0.2.0
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const here = p => fileURLToPath(new URL(p, import.meta.url));
const v = process.argv[2];
if (!/^\d+\.\d+\.\d+$/.test(v || '')) {
  console.error('usage: npm run bump -- X.Y.Z');
  process.exit(1);
}

let changed = 0;
function edit(rel, subs) {
  const path = here(rel);
  const raw = readFileSync(path, 'utf8');
  const crlf = raw.includes('\r\n'); // git autocrlf can hand us CRLF files
  let s = raw.replace(/\r\n/g, '\n');
  for (const [re, rep, required] of subs) {
    if (!re.test(s)) {
      if (required) throw new Error(`${rel}: pattern not found: ${re}`);
      continue; // optional pattern legitimately absent from this file
    }
    s = s.replace(re, rep);
  }
  writeFileSync(path, crlf ? s.replace(/\n/g, '\r\n') : s);
  changed++;
  console.log('updated', rel);
}

const REQUIRED = true;

// The app + bundle version (installers read it from here).
edit('../src-tauri/tauri.conf.json', [
  [/^  "version": "\d+\.\d+\.\d+",$/m, `  "version": "${v}",`, REQUIRED],
]);
// Rust crate metadata.
edit('../src-tauri/Cargo.toml', [
  [/^version = "\d+\.\d+\.\d+"/m, `version = "${v}"`, REQUIRED],
]);
// Cargo.lock: only the civics-desktop package entry.
edit('../src-tauri/Cargo.lock', [
  [/(\[\[package\]\]\nname = "civics-desktop"\nversion = ")\d+\.\d+\.\d+(")/, `$1${v}$2`, REQUIRED],
]);
// MSIX requires a 4-part version.
edit('../packaging/msix/AppxManifest.xml', [
  [/Version="\d+\.\d+\.\d+\.\d+"/, `Version="${v}.0"`, REQUIRED],
]);
// winget: PackageVersion plus the release-asset URLs (only the installer file
// has URLs). ManifestVersion stays untouched (schema version, not ours).
for (const f of [
  '../packaging/winget/Yilab.CivicsAudioPrep.yaml',
  '../packaging/winget/Yilab.CivicsAudioPrep.installer.yaml',
  '../packaging/winget/Yilab.CivicsAudioPrep.locale.en-US.yaml',
]) {
  edit(f, [
    [/^PackageVersion: \d+\.\d+\.\d+$/m, `PackageVersion: ${v}`, REQUIRED],
    [/desktop-v\d+\.\d+\.\d+/g, `desktop-v${v}`],
    [/Civics%20Audio%20Prep_\d+\.\d+\.\d+_/g, `Civics%20Audio%20Prep_${v}_`],
  ]);
}

// Flathub metainfo: prepend a release entry (skip if this version is listed).
const metaPath = here('../packaging/flatpak/com.yilab.civics.desktop.metainfo.xml');
const metaRaw = readFileSync(metaPath, 'utf8');
const metaCrlf = metaRaw.includes('\r\n');
let meta = metaRaw.replace(/\r\n/g, '\n');
if (!meta.includes(`<release version="${v}"`)) {
  const date = new Date().toISOString().slice(0, 10);
  meta = meta.replace(
    /<releases>\s*\n/,
    `<releases>\n    <release version="${v}" date="${date}">\n      <description>\n        <p>TODO: release notes.</p>\n      </description>\n    </release>\n`,
  );
  writeFileSync(metaPath, metaCrlf ? meta.replace(/\n/g, '\r\n') : meta);
  console.log('updated ../packaging/flatpak/com.yilab.civics.desktop.metainfo.xml');
  changed++;
}

console.log(`
done (${changed} files). Next:
  git add -A && git commit -m "chore: bump desktop to ${v}"
  git tag desktop-v${v} && git push --tags
  # then write real release notes into the new metainfo <release> entry
  # and, after the release is published, fill winget sha256/ProductCode.`);
