#!/usr/bin/env python3
import os
import sys
import json
import subprocess
from datetime import datetime, timedelta
from collections import Counter

def find_git_repos():
    home = os.path.expanduser("~")
    search_dirs = [
        os.path.join(home, ".config/quickshell/end4-pC"),
        os.path.join(home, "Projects"),
        os.path.join(home, "Workspace"),
        os.path.join(home, "workspace"),
        os.path.join(home, "dev"),
        os.path.join(home, "code"),
        os.path.join(home, "git"),
        os.path.join(home, "Documents")
    ]
    repos = []
    seen = set()

    for base in search_dirs:
        if not os.path.isdir(base):
            continue
        # Check if base itself is a git repo
        if os.path.isdir(os.path.join(base, ".git")):
            real = os.path.realpath(base)
            if real not in seen:
                repos.append(real)
                seen.add(real)
            continue
        # Scan 1-2 levels
        try:
            entries = os.listdir(base)
        except Exception:
            continue
        for entry in entries:
            if entry.startswith('.'):
                continue
            sub = os.path.join(base, entry)
            if os.path.isdir(os.path.join(sub, ".git")):
                real = os.path.realpath(sub)
                if real not in seen:
                    repos.append(real)
                    seen.add(real)
            elif os.path.isdir(sub):
                try:
                    for sub2 in os.listdir(sub):
                        subsub = os.path.join(sub, sub2)
                        if os.path.isdir(os.path.join(subsub, ".git")):
                            real = os.path.realpath(subsub)
                            if real not in seen:
                                repos.append(real)
                                seen.add(real)
                except Exception:
                    pass
    return repos

def get_repo_details(repo_path):
    try:
        # Status with branch & ahead/behind
        res = subprocess.run(
            ["git", "-C", repo_path, "status", "--porcelain=v1", "-b"],
            capture_output=True, text=True, timeout=2
        )
        lines = res.stdout.strip().splitlines()
        branch = "unknown"
        ahead = 0
        behind = 0
        modified = 0
        untracked = 0

        if lines:
            first = lines[0]
            # e.g. ## custom-features...fork/custom-features [ahead 2]
            if first.startswith("## "):
                b_info = first[3:]
                if "..." in b_info:
                    branch = b_info.split("...")[0].strip()
                    if "[ahead " in b_info:
                        try:
                            ahead = int(b_info.split("[ahead ")[1].split("]")[0].split(",")[0].strip())
                        except Exception:
                            pass
                    if "behind " in b_info:
                        try:
                            behind = int(b_info.split("behind ")[1].split("]")[0].strip())
                        except Exception:
                            pass
                else:
                    branch = b_info.strip()

            for line in lines[1:]:
                st = line[:2]
                if "??" in st:
                    untracked += 1
                else:
                    modified += 1

        # Last commit
        log_res = subprocess.run(
            ["git", "-C", repo_path, "log", "-1", "--pretty=format:%s|%cr|%at"],
            capture_output=True, text=True, timeout=2
        )
        parts = log_res.stdout.split("|") if log_res.stdout else []
        last_msg = parts[0] if len(parts) > 0 else "No commits"
        last_time = parts[1] if len(parts) > 1 else ""
        last_epoch = int(parts[2]) if len(parts) > 2 and parts[2].isdigit() else 0

        return {
            "name": os.path.basename(repo_path),
            "path": repo_path,
            "branch": branch,
            "ahead": ahead,
            "behind": behind,
            "modified": modified,
            "untracked": untracked,
            "last_commit": last_msg,
            "last_time": last_time,
            "last_epoch": last_epoch
        }
    except Exception as e:
        return None

def main():
    repos = find_git_repos()
    
    # 70 days window
    today = datetime.now().date()
    start_date = today - timedelta(days=69)
    days_list = [start_date + timedelta(days=i) for i in range(70)]
    date_strs = [d.strftime("%Y-%m-%d") for d in days_list]
    
    commit_counts = Counter()
    repo_infos = []

    for r in repos:
        # Get commit dates in window
        try:
            res = subprocess.run(
                ["git", "-C", r, "log", f"--since={start_date.strftime('%Y-%m-%d')}", "--date=short", "--pretty=format:%ad"],
                capture_output=True, text=True, timeout=2
            )
            for d in res.stdout.strip().splitlines():
                d = d.strip()
                if d in date_strs:
                    commit_counts[d] += 1
        except Exception:
            pass

        info = get_repo_details(r)
        if info:
            repo_infos.append(info)

    # Sort repos by most recent commit
    repo_infos.sort(key=lambda x: x["last_epoch"], reverse=True)
    top_repos = repo_infos[:4]

    # Build heatmap array
    heatmap = []
    max_count = max(commit_counts.values()) if commit_counts else 1
    total_commits = sum(commit_counts.values())

    for d, s in zip(days_list, date_strs):
        cnt = commit_counts.get(s, 0)
        if cnt == 0:
            lvl = 0
        elif cnt <= 2:
            lvl = 1
        elif cnt <= 5:
            lvl = 2
        elif cnt <= 8:
            lvl = 3
        else:
            lvl = 4
        heatmap.append({
            "date": s,
            "day": d.strftime("%a"),
            "weekday": d.weekday(), # 0 = Monday, 6 = Sunday
            "count": cnt,
            "level": lvl
        })

    # Calculate streak
    streak = 0
    cur_date = today
    # If today has 0 commits, check if yesterday had commits
    if commit_counts.get(cur_date.strftime("%Y-%m-%d"), 0) == 0:
        cur_date = today - timedelta(days=1)
    
    while True:
        s = cur_date.strftime("%Y-%m-%d")
        if commit_counts.get(s, 0) > 0:
            streak += 1
            cur_date -= timedelta(days=1)
        else:
            break

    result = {
        "streak": streak,
        "total_commits": total_commits,
        "repo_count": len(repos),
        "heatmap": heatmap,
        "repos": top_repos
    }

    print(json.dumps(result))

if __name__ == "__main__":
    main()
