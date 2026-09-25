#!/usr/bin/env python3
import sys
import os
import re
import json
import hashlib
import urllib.parse
import urllib.request
import subprocess
import unicodedata

CACHE_DIR = os.path.expanduser("~/.cache/quickshell/lyrics")

def get_mpris_url(dbus_name: str = None) -> str:
    """Attempt to retrieve xesam:url from playerctl."""
    cmd = ["playerctl"]
    if dbus_name and dbus_name.strip():
        cmd.extend(["-p", dbus_name.strip()])
    cmd.extend(["metadata", "xesam:url"])
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=1.5)
        if res.returncode == 0 and res.stdout.strip():
            url = res.stdout.strip()
            if url.startswith("http"):
                return url
    except Exception:
        pass

    # Fallback: check any running playerctl player
    if dbus_name:
        try:
            res = subprocess.run(["playerctl", "metadata", "xesam:url"], capture_output=True, text=True, timeout=1.5)
            if res.returncode == 0 and res.stdout.strip():
                url = res.stdout.strip()
                if url.startswith("http"):
                    return url
        except Exception:
            pass
    return None

def fetch_youtube_oembed(url: str):
    """Retrieve original untranslated video title and channel name via YouTube oEmbed."""
    if not url or ("youtube.com" not in url and "youtu.be" not in url):
        return None, None
    try:
        oembed_url = f"https://www.youtube.com/oembed?url={urllib.parse.quote(url)}&format=json"
        req = urllib.request.Request(oembed_url, headers={
            "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0"
        })
        with urllib.request.urlopen(req, timeout=2.5) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data.get("title"), data.get("author_name")
    except Exception:
        return None, None

def get_romanized_and_english(text: str) -> list:
    """Convert CJK titles (Japanese/Korean/Chinese) to Romaji/English via Google Translate dt=rm."""
    if not text:
        return []
    has_cjk = bool(re.search(r"[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uac00-\ud7af]", text))
    if not has_cjk:
        return []
    try:
        url = f"https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=en&dt=t&dt=rm&q={urllib.parse.quote(text)}"
        req = urllib.request.Request(url, headers={
            "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0"
        })
        with urllib.request.urlopen(req, timeout=2.5) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            results = []
            if isinstance(data, list) and len(data) > 0 and isinstance(data[0], list):
                for part in data[0]:
                    if isinstance(part, list):
                        for item in part:
                            if isinstance(item, str) and item.strip() and item != text:
                                norm = "".join(c for c in unicodedata.normalize("NFD", item) if unicodedata.category(c) != "Mn")
                                norm = norm.strip()
                                if norm and norm not in results:
                                    results.append(norm)
            return results
    except Exception:
        return []

def clean_artist(raw_artist: str) -> str:
    if not raw_artist:
        return ""
    artist = raw_artist.strip()
    junk_artist_patterns = [
        r"\s*-\s*Topic$",
        r"\s+(Official(\s*(Channel|Music|Audio|Video))?|VEVO|Records?|Entertainment|Music|Studio|Media)$",
        r"^\s*Channel:\s*"
    ]
    for pat in junk_artist_patterns:
        artist = re.sub(pat, "", artist, flags=re.IGNORECASE).strip()
    # Strip parenthesized foreign names if main name exists, e.g. NewJeans (뉴진스) -> NewJeans
    m = re.match(r"^([^(]+)\s*\([^)]+\)$", artist)
    if m and m.group(1).strip():
        artist = m.group(1).strip()
    return artist

def clean_song_info(raw_title: str, raw_artist: str = ""):
    artist = clean_artist(raw_artist)
    title = raw_title.strip()

    # Strip unread notification badges: (1), (784)
    title = re.sub(r"^\(\d+\)\s*", "", title).strip()
    # Strip trailing - YouTube / | YouTube
    title = re.sub(r"\s*[-–—:|]?\s*YouTube$", "", title, flags=re.IGNORECASE).strip()

    # Japanese bracket tags: 【MV】, ［Audio］, etc.
    title = re.sub(r"【[^】]*】", " ", title)
    title = re.sub(r"［[^］]*］", " ", title)
    title = re.sub(r"〔[^〕]*〕", " ", title)
    title = re.sub(r"〈[^〉]*〉", " ", title)
    title = re.sub(r"《[^》]*》", " ", title)

    # Strip video junk tags
    junk_patterns = [
        r"[\(\[](official\s*)?(music\s*)?(video|audio|lyrics?|hd|4k|mv|pv|visualizer|clip|audio\s*video|lyric\s*video)[^\)\]]*[\)\]]",
        r"[\(\[](full\s*album|remastered|extended\s*mix|original\s*mix|acoustic|live\s*version|performance)[^\)\]]*[\)\]]",
        r"[\(\[](vietsub|engsub|kara|thuyết\s*minh)[^\)\]]*[\)\]]",
        r"[\(\[]the\s*first\s*take[\)\]]",
        r"\|\s*(official\s*)?(music\s*)?(video|audio|lyrics?|mv|pv|visualizer).*$",
        r"/\s*the\s*first\s*take.*$",
    ]
    for pat in junk_patterns:
        title = re.sub(pat, " ", title, flags=re.IGNORECASE)

    title = re.sub(r"\s+", " ", title).strip()

    # Extract Japanese brackets 「...」 or 『...』
    jp_match = re.search(r"[「『]([^」』]+)[」』]", title)
    jp_title = jp_match.group(1).strip() if jp_match else None

    # Extract single/double quoted title: 'Ditto', "Song"
    quote_match = re.search(r"['\"‘“]([^'\"’”]{2,})['\"’”]", title)
    quoted_title = quote_match.group(1).strip() if quote_match else None

    if jp_title:
        title = jp_title
    elif quoted_title:
        title = quoted_title
    else:
        # Split separators: ' - ', ' / ', ' | ', ' ~ '
        sep_match = re.search(r"\s+[-–—:|/~]\s*|\s*[/~|]\s+", title)
        if sep_match:
            parts = re.split(r"\s+[-–—:|/~]\s*|\s*[/~|]\s+", title)
            parts = [p.strip() for p in parts if p.strip()]
            if len(parts) >= 2:
                part0, part1 = parts[0], parts[1]
                p0_low, p1_low = part0.lower(), part1.lower()
                a_low = artist.lower() if artist else ""

                is_feat_p1 = bool(re.match(r"^(feat\.?|ft\.?|vocal\.?)", p1_low))
                is_feat_p0 = bool(re.match(r"^(feat\.?|ft\.?|vocal\.?)", p0_low))

                if is_feat_p1:
                    title = part0
                elif is_feat_p0:
                    title = part1
                elif artist and (a_low in p0_low or p0_low in a_low):
                    title = part1
                elif artist and (a_low in p1_low or p1_low in a_low):
                    title = part0
                elif not artist:
                    artist = clean_artist(part0)
                    title = part1
                else:
                    title = part0

    # Clean leftover feat/ft/vocal from title itself
    title = re.sub(r"\s*[\(\[]?(feat\.?|ft\.?|vocal\.?)\s+[^()\[\]]+[\)\]]?", "", title, flags=re.IGNORECASE).strip()
    title = re.sub(r"\s*[/／]\s*(feat\.?|ft\.?|vocal\.?).*$", "", title, flags=re.IGNORECASE).strip()

    title = title.strip("\"' \u201c\u201d\u300c\u300d\u300e\u300f\u3010\u3011\u3014\u3015")
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

def similarity(s1: str, s2: str) -> float:
    if not s1 or not s2:
        return 0.0
    w1 = set(re.findall(r"\w+", s1.lower()))
    w2 = set(re.findall(r"\w+", s2.lower()))
    if not w1 or not w2:
        return 1.0 if s1.lower().strip() == s2.lower().strip() else 0.0
    if w1 == w2:
        return 1.0
    s1_clean = re.sub(r"\W+", "", s1.lower())
    s2_clean = re.sub(r"\W+", "", s2.lower())
    if s1_clean == s2_clean:
        return 1.0
    if s1_clean in s2_clean or s2_clean in s1_clean:
        return 0.85
    overlap = len(w1 & w2) / len(w1 | w2)
    return overlap

def score_item(item: dict, target_title: str, target_artist: str, target_dur: float) -> float:
    track_name = item.get("trackName", "")
    artist_name = item.get("artistName", "")
    duration = float(item.get("duration") or 0.0)
    has_synced = bool(item.get("syncedLyrics"))
    has_plain = bool(item.get("plainLyrics"))

    sim_artist = similarity(target_artist, artist_name) if target_artist else 0.5
    sim_title = similarity(target_title, track_name)

    # Disqualify completely mismatching artist if target artist was provided
    if target_artist and len(target_artist) >= 3 and sim_artist < 0.2:
        return -999.0

    # Disqualify completely mismatching title
    if sim_title < 0.2:
        return -999.0

    score = (sim_artist * 40.0) + (sim_title * 40.0)

    # Proximity of duration: prefer master/radio cut that matches player length
    if target_dur > 0 and duration > 0:
        diff = abs(target_dur - duration)
        if diff <= 2.0:
            score += 25.0
        elif diff <= 5.0:
            score += 18.0
        elif diff <= 15.0:
            score += 10.0
        elif diff <= 30.0:
            score += 0.0
        else:
            score -= min(35.0, diff * 0.5)

    if has_synced:
        score += 30.0
    elif has_plain:
        score += 10.0

    return score

def fetch_lyrics(raw_title: str, raw_artist: str, duration: float, dbus_name: str = "") -> list:
    # 0. Check YouTube oEmbed for original title and author
    oembed_title, oembed_author = None, None
    mpris_url = get_mpris_url(dbus_name)
    if mpris_url:
        oe_t, oe_a = fetch_youtube_oembed(mpris_url)
        if oe_t:
            sim_a = similarity(raw_artist, oe_a) if (raw_artist and oe_a) else 0.0
            sim_t = similarity(raw_title, oe_t) if (raw_title and oe_t) else 0.0
            # Only use oembed if artist matches or title is similar, or if raw fields are sparse
            if sim_a >= 0.3 or sim_t >= 0.25 or (not raw_artist and sim_t > 0):
                oembed_title, oembed_author = oe_t, oe_a

    # Prepare search candidates: list of (title, artist)
    candidates = []

    if oembed_title:
        ot, oa = clean_song_info(oembed_title, oembed_author or raw_artist)
        if ot:
            candidates.append((ot, oa))
            # Also romanize CJK if present
            for alt_title in get_romanized_and_english(ot):
                candidates.append((alt_title, oa))

    # Clean raw title & artist
    ct, ca = clean_song_info(raw_title, raw_artist)
    if ct and (ct, ca) not in candidates:
        candidates.append((ct, ca))
        for alt_title in get_romanized_and_english(ct):
            if (alt_title, ca) not in candidates:
                candidates.append((alt_title, ca))

    # Add inverted (artist as title, title as artist) if artist is not empty
    if ct and ca and (ca, ct) not in candidates:
        candidates.append((ca, ct))

    if not candidates:
        return []

    primary_title, primary_artist = candidates[0]

    # Check local cache first
    cached = load_from_cache(primary_title, primary_artist)
    if cached is not None:
        return cached
    if ct and ca:
        cached_raw = load_from_cache(ct, ca)
        if cached_raw is not None:
            return cached_raw

    # Collect and score results from LRCLIB
    pool = []

    for t_cand, a_cand in candidates:
        # 1. Exact get
        if t_cand and a_cand:
            url = f"https://lrclib.net/api/get?track_name={urllib.parse.quote(t_cand)}&artist_name={urllib.parse.quote(a_cand)}"
            data = fetch_json(url)
            if isinstance(data, dict) and data.get("id"):
                score = score_item(data, t_cand, a_cand, duration)
                if score > 0:
                    pool.append((score, data))

        # 2. Search track_name & artist_name
        if t_cand and a_cand:
            url = f"https://lrclib.net/api/search?track_name={urllib.parse.quote(t_cand)}&artist_name={urllib.parse.quote(a_cand)}"
            data = fetch_json(url)
            if isinstance(data, list):
                for item in data:
                    score = score_item(item, t_cand, a_cand, duration)
                    if score > 0:
                        pool.append((score, item))

        # 3. Search query string
        q = f"{t_cand} {a_cand}".strip()
        if q:
            url = f"https://lrclib.net/api/search?q={urllib.parse.quote(q)}"
            data = fetch_json(url)
            if isinstance(data, list):
                for item in data:
                    score = score_item(item, t_cand, a_cand, duration)
                    if score > 0:
                        pool.append((score, item))

        # If we already have high scoring candidates (> 90 with syncedLyrics), we can stop
        if any(sc >= 90 and item.get("syncedLyrics") for sc, item in pool):
            break

    # 4. Search by title only as last resort with strict artist verification
    if not pool and primary_title:
        url = f"https://lrclib.net/api/search?q={urllib.parse.quote(primary_title)}"
        data = fetch_json(url)
        if isinstance(data, list):
            for item in data:
                score = score_item(item, primary_title, primary_artist, duration)
                if score > 0:
                    pool.append((score, item))

    if not pool:
        return []

    # Sort candidates by score descending
    pool.sort(key=lambda x: x[0], reverse=True)
    best_score, best_item = pool[0]

    # Parse and save best item
    if best_item.get("syncedLyrics"):
        lines = parse_lrc(best_item["syncedLyrics"])
        if lines:
            save_to_cache(primary_title, primary_artist, lines)
            if ct and ca:
                save_to_cache(ct, ca, lines)
            return lines

    if best_item.get("plainLyrics"):
        lines = parse_plain(best_item["plainLyrics"], duration)
        if lines:
            save_to_cache(primary_title, primary_artist, lines)
            if ct and ca:
                save_to_cache(ct, ca, lines)
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

    dbus_name = sys.argv[4].strip() if len(sys.argv) > 4 else ""

    if not raw_title:
        print("no_info", flush=True)
        sys.exit(0)

    lines = fetch_lyrics(raw_title, raw_artist, duration, dbus_name)
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