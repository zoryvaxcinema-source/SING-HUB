<#
.SYNOPSIS
Publishes the built Karaoke Studio APKs as the V2.2.0 GitHub release and
patches version.json apkSize fields with the real file sizes.

.DESCRIPTION
Steps:
  1. Locates the built APKs (defaults to application/app/build/outputs/apk/...).
  2. Rewrites version.json (root) with correct apkSize values.
  3. Creates/updates the release tag V2.2.0 on zoryvaxcinema-source/SING-HUB
     and uploads both APKs as assets (--clobber makes it idempotent).
  4. Stages version.json + README.md for the next commit; git push is left to you.

Requirements: GitHub CLI (gh) authenticated.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File scripts/Publish-ApkRelease.ps1

.EXAMPLE
Re-run for a different version:
powershell -ExecutionPolicy Bypass -File scripts/Publish-ApkRelease.ps1 -VersionName 2.2.1 -VersionCode 20
#>

param(
    [string]$RepoRoot = "$PSScriptRoot\..",
    [string]$BuildDir = "$RepoRoot\..\application\app\build\outputs\apk",
    [string]$VersionName = "2.2.1",
    [int]$VersionCode = 21,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$ReleaseTag = "V$VersionName"

$tvApk     = Join-Path $BuildDir "host\release\KaraokeStudio-TV-v$VersionName.apk"
$remoteApk = Join-Path $BuildDir "remote\release\KaraokeStudio-Remote-v$VersionName.apk"
foreach ($p in @($tvApk, $remoteApk)) {
    if (-not (Test-Path $p)) { throw "APK not found: $p (build it first: .\gradlew.bat assembleHostRelease assembleRemoteRelease)" }
}
$tvSize     = (Get-Item $tvApk).Length
$remoteSize = (Get-Item $remoteApk).Length
Write-Host ("==> TV:     {0} ({1:N1} MB)" -f $tvApk, ($tvSize / 1MB))
Write-Host ("==> Remote: {0} ({1:N1} MB)" -f $remoteApk, ($remoteSize / 1MB))

$ghBase = "https://github.com/zoryvaxcinema-source/SING-HUB/releases/download/$ReleaseTag/"

if (-not ($DryRun)) {
    # --- Patch version.json with real sizes ---------------------------------
    $versionJsonPath = Join-Path $RepoRoot 'version.json'
    $v = Get-Content $versionJsonPath -Raw | ConvertFrom-Json
    if (-not $v.targets) { throw "version.json has no 'targets' object" }
    $v.targets.tv.versionCode = $VersionCode;      $v.targets.tv.versionName = $VersionName
    $v.targets.tv.apkName = "KaraokeStudio-TV-v$VersionName.apk"; $v.targets.tv.apkSize = $tvSize
    $v.targets.tv.apkUrl = ($ghBase + "KaraokeStudio-TV-v$VersionName.apk")
    $v.targets.tv.fallbackUrl = "https://singhub.zoryva.me/downloads/KaraokeStudio-TV-v$VersionName.apk"
    $v.targets.host.versionCode = $VersionCode;    $v.targets.host.versionName = $VersionName
    $v.targets.host.apkName = "KaraokeStudio-TV-v$VersionName.apk"; $v.targets.host.apkSize = $tvSize
    $v.targets.host.apkUrl = ($ghBase + "KaraokeStudio-TV-v$VersionName.apk")
    $v.targets.host.fallbackUrl = "https://singhub.zoryva.me/downloads/KaraokeStudio-TV-v$VersionName.apk"
    $v.targets.remote.versionCode = $VersionCode;  $v.targets.remote.versionName = $VersionName
    $v.targets.remote.apkName = "KaraokeStudio-Remote-v$VersionName.apk"; $v.targets.remote.apkSize = $remoteSize
    $v.targets.remote.apkUrl = ($ghBase + "KaraokeStudio-Remote-v$VersionName.apk")
    $v.targets.remote.fallbackUrl = "https://singhub.zoryva.me/downloads/KaraokeStudio-Remote-v$VersionName.apk"
    # Also refresh the top-level identity block used by standalone checks
    if ($null -ne $v.versionCode) { $v.versionCode = $VersionCode; $v.versionName = $VersionName }
    $v | ConvertTo-Json -Depth 5 | Set-Content $versionJsonPath -Encoding UTF8
    Write-Host "==> version.json patched with real apkSize values."

    # --- Upload release ------------------------------------------------------
    cmd /c "gh --version >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { throw "GitHub CLI (gh) is required. Install: winget install GitHub.cli" }

    $exists = cmd /c "gh release view $ReleaseTag --repo zoryvaxcinema-source/SING-HUB --json name -q .name 2>nul"
    if ([string]::IsNullOrWhiteSpace($exists)) {
        & gh release create $ReleaseTag `
            --repo zoryvaxcinema-source/SING-HUB `
            --title ("Karaoke Studio v{0} - Ultra-Slim APK and Downloadable Resource Pack" -f $VersionName) `
            --latest
        if ($LASTEXITCODE -ne 0) { throw "Failed creating release $ReleaseTag" }
    } else {
        & gh release edit $ReleaseTag --repo zoryvaxcinema-source/SING-HUB --latest
    }

    Write-Host "  uploading TV APK..."
    & gh release upload $ReleaseTag $tvApk --repo zoryvaxcinema-source/SING-HUB --clobber
    if ($LASTEXITCODE -ne 0) { throw "TV APK upload failed" }
    Write-Host "  uploading Remote APK..."
    & gh release upload $ReleaseTag $remoteApk --repo zoryvaxcinema-source/SING-HUB --clobber
    if ($LASTEXITCODE -ne 0) { throw "Remote APK upload failed" }
    Write-Host "==> Release $ReleaseTag uploaded."

    cmd /c "git -C `"$RepoRoot`" add version.json README.md"
    Write-Host ""
    Write-Host "DONE. Commit and push the updated version.json:" -ForegroundColor Green
    Write-Host "    git -C `"$RepoRoot`" commit -m `"v$VersionName release`""
    Write-Host "    git -C `"$RepoRoot`" push origin main"
} else {
    Write-Host "DryRun: would patch version.json and upload release $ReleaseTag with:" -ForegroundColor Yellow
    Write-Host ("  {0} -> {1} ({2} bytes)" -f "KaraokeStudio-TV-v$VersionName.apk", ($ghBase + "KaraokeStudio-TV-v$VersionName.apk"), $tvSize)
    Write-Host ("  {0} -> {1} ({2} bytes)" -f "KaraokeStudio-Remote-v$VersionName.apk", ($ghBase + "KaraokeStudio-Remote-v$VersionName.apk"), $remoteSize)
}
