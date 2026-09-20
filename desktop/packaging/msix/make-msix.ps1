# Builds CivicsAudioPrep.msix from the release exe + AppxManifest.xml.
#
# Prereqs:
#   1. Partner Center identity filled into AppxManifest.xml (see its header).
#   2. Windows SDK on PATH (makeappx.exe, signtool.exe) — or the script finds
#      them under the installed SDK.
#
# For STORE submission: upload the unsigned .msix to Partner Center — Microsoft
# signs it after certification. Signing is only needed for LOCAL sideload
# testing; run with -Sign to generate + trust a self-signed dev cert (admin).
#
# Usage (from desktop/packaging/msix/):
#   powershell -ExecutionPolicy Bypass -File make-msix.ps1          # unsigned
#   powershell -ExecutionPolicy Bypass -File make-msix.ps1 -Sign    # sideload test
param(
  [switch]$Sign
)
$ErrorActionPreference = 'Stop'

$msixDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$desktop  = Resolve-Path "$msixDir\..\.."
$layout   = "$msixDir\layout"
$out      = "$msixDir\CivicsAudioPrep.msix"

# --- sanity: placeholders replaced? ---
$manifest = Get-Content "$msixDir\AppxManifest.xml" -Raw
if ($manifest -match 'PARTNER-CENTER') {
  throw 'AppxManifest.xml still has PARTNER-CENTER placeholders — fill in the identity from Partner Center first.'
}

# --- build the release exe (frontend bundle + cargo release) ---
Push-Location $desktop
npm install --no-audit --no-fund | Out-Null
npm run build | Out-Null
cargo build --release --manifest-path src-tauri\Cargo.toml
Pop-Location
$exe = "$desktop\src-tauri\target\release\civics-desktop.exe"
if (-not (Test-Path $exe)) { throw "release exe missing: $exe" }

# --- stage the package layout ---
if (Test-Path $layout) { Remove-Item -Recurse -Force $layout }
New-Item -ItemType Directory -Force "$layout\Assets" | Out-Null
Copy-Item $exe "$layout\civics-desktop.exe"
Copy-Item "$msixDir\AppxManifest.xml" "$layout\AppxManifest.xml"
# Tauri's icon set already uses the MSIX asset names.
foreach ($icon in 'StoreLogo.png','Square44x44Logo.png','Square71x71Logo.png','Square150x150Logo.png','Square310x310Logo.png') {
  Copy-Item "$desktop\src-tauri\icons\$icon" "$layout\Assets\$icon"
}

# --- pack ---
$makeappx = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\makeappx.exe" |
  Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
if (-not $makeappx) { throw 'makeappx.exe not found — install the Windows SDK.' }
& $makeappx pack /d $layout /p $out /nv /o | Out-Null
Write-Host "wrote $out"

# --- optional: self-signed cert for sideload testing (needs admin to trust) ---
if ($Sign) {
  $signtool = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\signtool.exe" |
    Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
  $subject = ($manifest | Select-String 'Publisher="([^"]+)"').Matches.Groups[1].Value
  $cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object Subject -eq $subject | Select-Object -First 1
  if (-not $cert) {
    $cert = New-SelfSignedCertificate -Type Custom -Subject $subject `
      -KeyUsage DigitalSignature -CertStoreLocation 'Cert:\CurrentUser\My' `
      -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3', '2.5.29.19={text}')
  }
  & $signtool sign /fd SHA256 /a /sha1 $cert.Thumbprint $out | Out-Null
  Write-Host 'signed. To sideload-test, first trust the cert (admin):'
  Write-Host "  Import-Certificate -FilePath <exported.cer> -CertStoreLocation Cert:\LocalMachine\TrustedPeople"
}
