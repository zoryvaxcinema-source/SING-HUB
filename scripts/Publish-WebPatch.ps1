<#
.SYNOPSIS
Builds the next Singhub web hot-patch (full www overlay zip) from the
current app assets and refreshes patch.json.

.DESCRIPTION
Use this when the bundled www/ UI changes and you want devices to hot-patch
without reinstalling the APK.

Steps:
  1. Reads the current patch.json to find the next patchVersion.
  2. Zips the ENTIRE content of application/app/src/main/assets/www into
     patches/singhub_web_patch_vN.zip (paths WITHOUT a www/ prefix are also
     accepted by the app, which strips that folder automatically).
  3. Rewrites patch.json: patchVersion=N, minAppVersionCode=<first code that
     carries the new UI> (default 19), maxAppVersionCode=999999, size + SHA-256.
  4. Stages patch.json + the new zip; commit + push to main so
     raw.githubusercontent serves it (the app's primary patch source).

.EXAMPLE
powershell -ExecutionPolicy Bypass -File scripts/Publish-WebPatch.ps1

.EXAMPLE
Rebuild after more UI tweaks, still as v16:
powershell -ExecutionPolicy Bypass -File scripts/Publish-WebPatch.ps1 -ForceVersion 16
#>

param(
    [string]$RepoRoot = "$PSScriptRoot\..",
    [string]$WwwDir   = "$RepoRoot\..\application\app\src\main\assets\www",
    [int]$MinAppVersionCode = 19,
    [string]$Changelog = "v2.2.0 UI: slim APK downloader, resource status card, cloud soundfont fallback, debounced dial previews, LAN-IP cleanup",
    [int]$ForceVersion = 0,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $WwwDir)) { throw "www directory not found: $WwwDir" }

$patchJsonPath = Join-Path $RepoRoot 'patch.json'
$p = Get-Content $patchJsonPath -Raw | ConvertFrom-Json
$next = if ($ForceVersion -gt 0) { $ForceVersion } else { [int]$p.patchVersion + 1 }

$zipPath = Join-Path $RepoRoot ("patches\singhub_web_patch_v{0}.zip" -f $next)
if (Test-Path $zipPath) { throw "Patch file already exists: $zipPath (delete it to rebuild)" }

if ($DryRun) {
    Write-Host "DryRun: would create $zipPath from $WwwDir as patchVersion $next (min app code $MinAppVersionCode)" -ForegroundColor Yellow
    return
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    # Keep the www root contents *at* the zip root and ALSO inside a www/ wrapper
    # for maximum compatibility with old receivers (they strip "www/").
    $files = Get-ChildItem $WwwDir -Recurse -File
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($WwwDir.Length).TrimStart('\','/').Replace('\','/')
        if ([string]::IsNullOrWhiteSpace($rel)) { continue }
        [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $f.FullName, $rel, [System.IO.Compression.CompressionLevel]::Optimal)
    }
} finally {
    $zip.Dispose()
}

$size = (Get-Item $zipPath).Length
$sha  = (Get-FileHash -Algorithm SHA256 -Path $zipPath).Hash

$p.patchVersion      = $next
$p.patchName         = "v$next"
$p.releaseDate       = (Get-Date -Format 'yyyy-MM-dd')
$p.minAppVersionCode = $MinAppVersionCode
$p.maxAppVersionCode = 999999
$p.title             = "Singhub Web Hot-Patch v$next"
$p.changelog         = $Changelog
$p.patchUrl          = "https://singhub.zoryva.me/downloads/patches/singhub_web_patch_v$next.zip"
$p.fallbackUrl       = "https://raw.githubusercontent.com/zoryvaxcinema-source/SING-HUB/main/patches/singhub_web_patch_v$next.zip"
$p.patchSize         = $size
$p.sha256            = $sha

$p | ConvertTo-Json -Depth 3 | Set-Content $patchJsonPath -Encoding UTF8

git -C $RepoRoot add patch.json $zipPath 2>$null | Out-Null

Write-Host ("==> Patch v{0} built: {1} bytes" -f $next, $size)
Write-Host ("    SHA-256 {0}" -f $sha)
Write-Host ""
Write-Host "DONE. Commit & push so raw.githubusercontent serves it:" -ForegroundColor Green
Write-Host "    git -C `"$RepoRoot`" commit -m `"Web patch v$next`""
Write-Host "    git -C `"$RepoRoot`" push origin main"
Write-Host "Also copy the zip to your website host if you keep the singhub.zoryva.me mirror alive."
