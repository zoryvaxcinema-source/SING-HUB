# SING-HUB

Official **Karaoke Studio** APK downloads.

## Downloads (v2.1.4)

- [Karaoke Studio TV (Host)](https://github.com/zoryvaxcinema-source/SING-HUB/releases/download/V2.1.4/KaraokeStudio-TV-v2.1.4.apk) *(764 MB, Android 7.0+)*
- [Karaoke Studio Remote](https://github.com/zoryvaxcinema-source/SING-HUB/releases/download/V2.1.4/KaraokeStudio-Remote-v2.1.4.apk) *(4.7 MB, Android 6.0+)*

### v2.1.4 — Black Screen Fix & Low-End TV Reliability

- 🛡️ Black screen fix: fully backgrounded boot with watchdog recovery — no more frozen black stage on low-end TV boxes
- 🖥️ WebView renderer-crash auto-recovery (stage rebuilds instead of staying blank)
- 🔁 Capped reload backoff — no more infinite reload loops on flaky Wi-Fi
- 🎬 Background-video retry limit with photo-mode fallback when the BGV pack is missing
- ✨ Low-Spec TV Mode (≤2GB RAM): decorative animations freeze, heavy GPU filters drop
- 🧠 Memory & fd leak fixes (LRU MIDI cache, blob I/O locking, atomic queue updates)
- 🎵 RFC-correct range streaming (reliable seek/resume); lyric timings follow tempo/key shift

Older releases are available under [Releases](https://github.com/zoryvaxcinema-source/SING-HUB/releases).

Website: https://singhub.zoryva.me
