# resources/ — Official Resource Pack Metadata

The TV app (v2.2.0+) no longer bundles the 747 MB resource pack inside the APK — it
downloads the pack once, verifies SHA-256, and resumes interrupted parts.

## What lives here (in this git branch)

Only the **small** files that GitHub raw can serve (< 100 MB each) are tracked
in this folder:

| File | Size | Purpose |
|------|------|---------|
| `resources.json` | KB | Manifest published to the site (sizes + digests) |
| `shubidx` | 1.7 MB | Song database index |
| `bgphoto.jpg` | 0.7 MB | Default background photo |
| `bgv.mp4` | 8.9 MB | Default background video loop |
| `Roland SC-55.sf2` | 9.1 MB | Lightweight Sound Canvas soundfont (low-RAM friendly) |
| `WinLive Karaoke Mobile.sf2` | 15.4 MB | Optimized karaoke mobile soundfont |

The two large files are **never committed here** (exceeds the git 100 MB limit):

| File | Size | Where it goes |
|------|------|---------------|
| `SAM5504B.sf2` | 132 MB | Release asset only |
| `shubblob` | 606 MB | Release asset only |

## Where the app downloads from (in order)

1. `https://github.com/zoryvaxcinema-source/SING-HUB/releases/download/R2026-RES-v1/<file>` (release asset — all files)
2. `https://raw.githubusercontent.com/zoryvaxcinema-source/SING-HUB/main/resources/<file>` (small files only)
3. `https://singhub.zoryva.me/resources/<file>` (website mirror)
4. `https://karaoke.zoryva.me/resources/<file>` (legacy mirror)

## Publishing a pack

Run the publish script from the repo root (requires GitHub CLI auth):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/Publish-ResourcePack.ps1
```

It verifies the canonical files, refreshes `resources.json`, commits the small
trio into this folder, and uploads all files as assets of release `R2026-RES-v1`
on GitHub. `git push` of the updated branch is left to you on purpose.
