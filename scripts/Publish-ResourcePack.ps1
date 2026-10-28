<#
.SYNOPSIS
Publishes the Singhub resource pack (song library, soundfont, media) to the
SING-HUB GitHub repository and refreshes resources/resources.json.

.DESCRIPTION
Steps:
  1. Validates the canonical pack files (sizes + SHA-256) against the known digests.
  2. Copies the small files into resources/ (tracked in git, served by raw.githubusercontent).
  3. Rewrites resources/resources.json (sizes, digests, order, distribution hints).
  4. Creates/updates the GitHub release R2026-RES-v1 and uploads ALL 5 files as assets.
  5. DOES NOT push git commits — review the staged changes and push yourself.

Requirements: GitHub CLI (gh) authenticated with push/release rights on
zoryvaxcinema-source/SING-HUB, ~25 GB free scratch not needed (streams assets).

.EXAMPLE
powershell -ExecutionPolicy Bypass -File scripts/Publish-ResourcePack.ps1

.EXAMPLE
Use a custom pack directory:
powershell -ExecutionPolicy Bypass -File scripts/Publish-ResourcePack.ps1 -PackDir "D:\packs\resource-pack-master"
#>

param(
    [string]$RepoRoot = "$PSScriptRoot\..",
    [string]$PackDir  = "$RepoRoot\..\application\resource-pack-master",
    [string]$ReleaseTag = "R2026-RES-v1",
    [switch]$SkipReleaseUpload,
    [switch]$SkipJsonRefresh
)

$ErrorActionPreference = 'Stop'

# Canonical pack definition — MUST stay in sync with
# application/app/src/main/java/com/singhub/karaoke/ResourceDownloadManager.java
$Expected = [ordered]@{
    'shubidx'     = @{ size = 1797052;    sha256 = 'D748DF7F5982BABA2FA99D7B178272033812775F3638B297CAA45661C435CB06'; small = $true }
    'bgphoto.jpg' = @{ size = 650727;     sha256 = '45FEEB258316B3BCBE6394CCD44A783B3F24AF5AABA03A483187D4CE7F36E2B9'; small = $true }
    'bgv.mp4'     = @{ size = 8951088;    sha256 = '3D1462474CC7D7E3D9B8D3C8CD8C780106F60E2862C733447D72E09E4CD93C74'; small = $true }
    'SAM5504B.sf2'= @{ size = 132047676;  sha256 = '63B14CAA66A19FE4EDB7FC661CB1C0F46DD979B615246A69F9AD150AF56E856F'; small = $false }
    'shubblob'    = @{ size = 606828544;  sha256 = '4E71F9D3B520832B59B6B0B94766FF059018C85A920A0F2D0A592A2BD54845EF'; small = $false }
}
$Descriptions = [ordered]@{
    'shubidx'      = 'Song database index (40,000+ songs)'
    'bgphoto.jpg'  = 'Default background photo'
    'bgv.mp4'      = 'Default background video loop'
    'SAM5504B.sf2' = 'Dream SAM5504B Studio soundfont (MIDI synthesizer voices)'
    'shubblob'     = 'Encrypted song library blob (40,000+ karaoke MIDI/lrc tracks)'
}
$PackVersion = (Get-Date -Format 'yyyy-MM-dd')

Write-Host "==> RepoRoot: $RepoRoot"
Write-Host "==> PackDir:  $PackDir"

if (-not (Test-Path $PackDir)) { throw "Pack directory not found: $PackDir" }

# --- 1. Validate pack files -------------------------------------------------
$validated = @()
foreach ($name in $Expected.Keys) {
    $path = Join-Path $PackDir $name
    if (-not (Test-Path $path)) { throw "Missing pack file: $path" }
    $file = Get-Item $path
    if ($file.Length -ne $Expected[$name].size) {
        throw "$name size mismatch: got $($file.Length), expected $($Expected[$name].size)"
    }
    Write-Host "  hashing $name ..." -NoNewline
    $sha = (Get-FileHash -Algorithm SHA256 -Path $path).Hash
    if (-not $sha.Equals($Expected[$name].sha256, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "$name SHA-256 mismatch!`n  got:      $sha`n  expected: $($Expected[$name].sha256)"
    }
    Write-Host " OK"
    $validated += [pscustomobject]@{
        name          = $name
        size          = $file.Length
        sha256        = $sha.ToUpperInvariant()
        description   = $Descriptions[$name]
        distribution  = @('release-asset') + $(if ($Expected[$name].small) { 'github-raw' })
    }
}
Write-Host "==> Pack validation passed (5/5 files)."

# --- 2. Copy small files into resources/ (tracked in git) -------------------
$orderedNames = @('shubidx','bgphoto.jpg','bgv.mp4','SAM5504B.sf2','shubblob')
$validated = $orderedNames | ForEach-Object { $found = $validated | Where-Object name -eq $_; $found }

$stagedPaths = @()
foreach ($o in $validated) {
    if (-not $o.distribution.Contains('github-raw')) { continue }
    $src = Join-Path $PackDir $o.name
    $dst = Join-Path $RepoRoot "resources\$($o.name)"
    Copy-Item -Force -Path $src -Destination $dst
    $stagedPaths += $dst
}
Write-Host "==> Small files staged into resources/ ($($stagedPaths.Count) files)."

# --- 3. Refresh resources.json ----------------------------------------------
if (-not $SkipJsonRefresh) {
    $manifest = [ordered]@{
        packVersion     = $PackVersion
        releaseTag      = $ReleaseTag
        repository      = 'zoryvaxcinema-source/SING-HUB'
        saveDir         = '/sdcard/Singhub'
        encryptionNote  = "Legacy all-in-one singhub_resources.zip uses ZipCrypto password 'Singhub@2026#SecureVault'"
        files           = $validated
    }
    $jsonPath = Join-Path $RepoRoot 'resources\resources.json'
    $manifest | ConvertTo-Json -Depth 4 | Set-Content -Path $jsonPath -Encoding UTF8
    Write-Host "==> resources/resources.json refreshed."
}

# --- 4. Upload release assets ------------------------------------------------
if (-not $SkipReleaseUpload) {
    cmd /c "gh --version >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { throw "GitHub CLI (gh) is required to upload release assets. Install: winget install GitHub.cli" }

    Write-Host "==> Ensuring release $ReleaseTag exists..."
    $exists = cmd /c "gh release view $ReleaseTag --repo zoryvaxcinema-source/SING-HUB --json name -q .name 2>nul"
    if ([string]::IsNullOrWhiteSpace($exists)) {
        & gh release create $ReleaseTag `
            --repo zoryvaxcinema-source/SING-HUB `
            --title "Singhub Resource Pack ($PackVersion)" `
            --notes ("Official offline resource pack consumed by Karaoke Studio v2.2.0+. " +
                     "Files are downloaded in-order with resume + SHA-256 verification by the in-app installer. " +
                     "Keep this release public and unmodified when a newer pack ships.")
        if ($LASTEXITCODE -ne 0) { throw "Failed creating release $ReleaseTag" }
    }

    foreach ($o in $validated) {
        $path = Join-Path $PackDir $o.name
        Write-Host ("  uploading {0} ({1:N1} MB) ..." -f $o.name, ($o.size / 1MB))
        & gh release upload $ReleaseTag $path `
            --repo zoryvaxcinema-source/SING-HUB `
            --clobber
        if ($LASTEXITCODE -ne 0) { throw "Upload failed for $($o.name)" }
    }
    Write-Host "==> Release assets uploaded."
} else {
    Write-Host "==> SKIPPED release upload (-SkipReleaseUpload)."
}

cmd /c "git -C `"$RepoRoot`" add resources"
Write-Host ""
Write-Host "DONE. Review staged changes (git status) and push yourself:" -ForegroundColor Green
Write-Host "    git -C `"$RepoRoot`" commit -m `"Publish resource pack manifest ($PackVersion)`""
Write-Host "    git -C `"$RepoRoot`" push origin main"
