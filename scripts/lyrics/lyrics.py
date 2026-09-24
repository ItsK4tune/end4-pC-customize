#!/usr/bin/env python3
import sys
import os
import re
import json
import hashlib
import urllib.parse
import subprocess

CACHE_DIR = os.path.expanduser("~/.cache/quickshell/lyrics")

def clean_song_info(raw_title: str, raw_artist: str):
    artist = re.sub(r"\s*-\s*Topic$", "", raw_artist, flags=re.IGNORECASE).strip()
    title = raw_title.strip()

    # Extract Japanese / quote brackets 「...」 or 『...』 if present
    jp_match = re.search(r"[「『]([^」』]+)[」』]", title)
    jp_title = jp_match.group(1).strip() if jp_match else None

    # Strip standard tags & video junk
    junk_patterns = [
        r"[\(\[](official\s*)?(music\s*)?(video|audio|lyrics?|hd|4k|mv|visualizer|clip|audio\s*video|lyric\s*video)[^\)\]]*[\)\]]",
        r"[\(\[](feat\.?|ft\.?)[^\)\]]*[\)\]]",
        r"【[^】]*】",
        r"［[^］]*］",
        r"\[[^\]]*\]"
    ]
    for pat in junk_patterns:
        title = re.sub(pat, " ", title, flags=re.IGNORECASE)

    title = re.sub(r"\s+", " ", title).strip()

    # Split "Artist - Song" or "Song - Artist"
    sep_match = re.search(r"\s+[-–—:|]\s+", title)
    if sep_match:
        parts = re.split(r"\s+[-–—:|]\s+", title, maxsplit=1)
        part0, part1 = parts[0].strip(), parts[1].strip()
        if artist:
            if artist.lower() in part0.lower() or part0.lower() in artist.lower():
                title = part1
            elif artist.lower() in part1.lower() or part1.lower() in artist.lower():
                title = part0
        else:
            artist = part0
            title = part1
    elif jp_title:
        title = jp_title

    title = title.strip("\"' \u201c\u201d\u300c\u300d")
    return title.strip(), artist.strip()

def parse_lrc(lrc_text: str) -> list:
    lines = []
    for raw in lrc_text.splitlines():
        raw = raw.strip()
        if not raw:
            continue
        try:
            tag_end = raw.index("]")
            time_str = raw[1:tag_end]
            text = raw[tag_end + 1:].strip()
            mins, secs = time_str.split(":")
            timestamp = int(mins) * 60 + float(secs)
            lines.append({"time": timestamp, "text": text})
        except Exception:
            continue
    return sorted(lines, key=lambda x: x["time"])

def parse_plain(plain_text: str, duration: float) -> list:
    raw_lines = [l.strip() for l in plain_text.splitlines() if l.strip()]
    if not raw_lines:
        return []
    if duration <= 0:
        duration = max(len(raw_lines) * 4.0, 180.0)
    step = duration / len(raw_lines)
    lines = []
    for i, line in enumerate(raw_lines):
        lines.append({"time": round(i * step, 2), "text": line})
    return lines

def fetch_json(url: str):
    try:
        res = subprocess.run([
            "curl", "-s", "--http1.1", "--connect-timeout", "2", "--max-time", "4",
            "-A", "Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0",
            url
        ], capture_output=True, text=True)
        if res.returncode == 0 and res.stdout:
            data = json.loads(res.stdout)
            if isinstance(data, dict) and data.get("statusCode") in (429, 503):
                return None
            return data
    except Exception:
        pass
    return None

def get_cache_path(title: str, artist: str) -> str:
    os.makedirs(CACHE_DIR, exist_ok=True)
    key = f"{title.lower()}___{artist.lower()}"
    h = hashlib.sha256(key.encode("utf-8")).hexdigest()
    return os.path.join(CACHE_DIR, f"{h}.json")

def load_from_cache(title: str, artist: str):
    path = get_cache_path(title, artist)
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return None

def save_to_cache(title: str, artist: str, lines: list):
    path = get_cache_path(title, artist)
    try:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(lines, f, ensure_ascii=False)
    except Exception:
        pass

def fetch_lyrics(raw_title: str, raw_artist: str, duration: float) -> list:
    c_title, c_artist = clean_song_info(raw_title, raw_artist)
    if not c_title:
        return []

    # Check local cache first
    cached = load_from_cache(c_title, c_artist)
    if cached is not None:
        return cached

    plain_fallback = None

    # 1. Exact get
    if c_title and c_artist:
        url = f"https://lrclib.net/api/get?track_name={urllib.parse.quote(c_title)}&artist_name={urllib.parse.quote(c_artist)}"
        data = fetch_json(url)
        if isinstance(data, dict):
            if data.get("syncedLyrics"):
                lines = parse_lrc(data["syncedLyrics"])
                if lines:
                    save_to_cache(c_title, c_artist, lines)
                    return lines
            elif data.get("plainLyrics") and not plain_fallback:
                plain_fallback = data["plainLyrics"]

    # 2. Search by track_name & artist_name
    if c_title and c_artist:
        url = f"https://lrclib.net/api/search?track_name={urllib.parse.quote(c_title)}&artist_name={urllib.parse.quote(c_artist)}"
        data = fetch_json(url)
        if isinstance(data, list):
            for item in data:
                if item.get("syncedLyrics"):
                    lines = parse_lrc(item["syncedLyrics"])
                    if lines:
                        save_to_cache(c_title, c_artist, lines)
                        return lines
                elif item.get("plainLyrics") and not plain_fallback:
                    plain_fallback = item["plainLyrics"]

    # 3. Search by query string
    q = f"{c_title} {c_artist}".strip()
    if q:
        url = f"https://lrclib.net/api/search?q={urllib.parse.quote(q)}"
        data = fetch_json(url)
        if isinstance(data, list):
            for item in data:
                if item.get("syncedLyrics"):
                    lines = parse_lrc(item["syncedLyrics"])
                    if lines:
                        save_to_cache(c_title, c_artist, lines)
                        return lines
                elif item.get("plainLyrics") and not plain_fallback:
                    plain_fallback = item["plainLyrics"]

    # 4. Search by title only
    if c_title:
        url = f"https://lrclib.net/api/search?q={urllib.parse.quote(c_title)}"
        data = fetch_json(url)
        if isinstance(data, list):
            for item in data:
                if item.get("syncedLyrics"):
                    lines = parse_lrc(item["syncedLyrics"])
                    if lines:
                        save_to_cache(c_title, c_artist, lines)
                        return lines
                elif item.get("plainLyrics") and not plain_fallback:
                    plain_fallback = item["plainLyrics"]

    # If no synced lyrics, fallback to plain lyrics
    if plain_fallback:
        lines = parse_plain(plain_fallback, duration)
        if lines:
            save_to_cache(c_title, c_artist, lines)
            return lines

    return []

def main():
    if len(sys.argv) < 2:
        print("no_info", flush=True)
        sys.exit(0)

    raw_title = sys.argv[1].strip()
    raw_artist = sys.argv[2].strip() if len(sys.argv) > 2 else ""
    duration = 0.0
    if len(sys.argv) > 3:
        try:
            duration = float(sys.argv[3])
        except ValueError:
            duration = 0.0

    if not raw_title:
        print("no_info", flush=True)
        sys.exit(0)

    lines = fetch_lyrics(raw_title, raw_artist, duration)
    if not lines:
        print("not_found", flush=True)
        sys.exit(0)

    parts = []
    for line in lines:
        parts.append(str(line["time"]))
        parts.append(line["text"].replace("§", ""))
    parts.append("ok")
    print("§".join(parts), flush=True)

if __name__ == "__main__":
    main()