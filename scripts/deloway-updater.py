#!/usr/bin/env python3
"""DeloWay System Updater Backend.

Handles checking for updates from GitHub/Git remote, fetching changelogs,
applying updates, syncing themes/fonts, and safely reloading the shell.
Outputs JSON for direct consumption by Quickshell QML Process.
"""

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys


def get_project_dir() -> Path:
    script_path = Path(__file__).resolve()
    return script_path.parent.parent


def run_git(cmd: list[str], cwd: Path, timeout: int = 15) -> tuple[int, str, str]:
    env = os.environ.copy()
    env["GIT_TERMINAL_PROMPT"] = "0"
    try:
        proc = subprocess.run(
            ["git"] + cmd,
            cwd=str(cwd),
            capture_output=True,
            text=True,
            timeout=timeout,
            env=env,
        )
        return proc.returncode, proc.stdout.strip(), proc.stderr.strip()
    except subprocess.TimeoutExpired:
        return -1, "", "Operation timed out"
    except Exception as e:
        return -2, "", str(e)


def get_current_info(project_dir: Path) -> dict:
    _, commit_hash, _ = run_git(["rev-parse", "--short", "HEAD"], project_dir)
    _, commit_full, _ = run_git(["rev-parse", "HEAD"], project_dir)
    _, commit_date, _ = run_git(["log", "-1", "--format=%cd", "--date=relative"], project_dir)
    _, commit_msg, _ = run_git(["log", "-1", "--format=%s"], project_dir)
    _, branch, _ = run_git(["rev-parse", "--abbrev-ref", "HEAD"], project_dir)
    _, count, _ = run_git(["rev-list", "--count", "HEAD"], project_dir)
    _, origin_url, _ = run_git(["remote", "get-url", "origin"], project_dir)

    return {
        "commit": commit_hash or "unknown",
        "full_commit": commit_full or "unknown",
        "date": commit_date or "",
        "message": commit_msg or "",
        "branch": branch or "master",
        "total_commits": int(count) if count.isdigit() else 0,
        "version": "v2.0 OLED",
        "repository_url": origin_url or "https://github.com/DeloNest/DeloWay-releases.git",
    }


def check_updates(project_dir: Path, channel: str = "dev") -> dict:
    info = get_current_info(project_dir)
    branch = info["branch"] or "master"

    # Attempt to fetch from origin
    code, _, err = run_git(["fetch", "origin", branch], project_dir, timeout=12)

    # If fetch failed (e.g. offline or auth required)
    if code != 0:
        # Check if we have remote tracking
        rev_code, remote_rev, _ = run_git(["rev-parse", f"origin/{branch}"], project_dir)
        if rev_code != 0:
            return {
                "status": "error",
                "error": err or "Failed to connect to update server",
                "channel": channel,
                "current": info,
                "commits_behind": 0,
                "changelog": [],
            }

    # Compare local HEAD with origin/branch
    code, diff_count, _ = run_git(["rev-list", "--count", f"HEAD..origin/{branch}"], project_dir)
    behind = int(diff_count) if diff_count.isdigit() else 0

    changelog = []
    if behind > 0:
        _, log_out, _ = run_git(
            ["log", f"-n{min(behind, 15)}", "--pretty=format:%h|%an|%s|%cr", f"HEAD..origin/{branch}"],
            project_dir
        )
        for line in log_out.splitlines():
            parts = line.split("|")
            if len(parts) >= 4:
                changelog.append({
                    "hash": parts[0],
                    "author": parts[1],
                    "subject": parts[2],
                    "date": parts[3]
                })

        return {
            "status": "update_available",
            "commits_behind": behind,
            "channel": channel,
            "current": info,
            "changelog": changelog,
            "error": "",
        }
    else:
        # Already up to date; fetch last 5 local commits for recent history
        _, log_out, _ = run_git(
            ["log", "-n5", "--pretty=format:%h|%an|%s|%cr", "HEAD"],
            project_dir
        )
        for line in log_out.splitlines():
            parts = line.split("|")
            if len(parts) >= 4:
                changelog.append({
                    "hash": parts[0],
                    "author": parts[1],
                    "subject": parts[2],
                    "date": parts[3]
                })

        return {
            "status": "up_to_date",
            "commits_behind": 0,
            "channel": channel,
            "current": info,
            "changelog": changelog,
            "error": "",
        }


def apply_update(project_dir: Path) -> dict:
    info = get_current_info(project_dir)
    branch = info["branch"] or "master"

    # Pull latest changes
    code, out, err = run_git(["pull", "--ff-only", "origin", branch], project_dir, timeout=30)
    if code != 0:
        # If fast-forward failed, try rebase or return detailed error
        code, out, err = run_git(["pull", "--rebase", "origin", branch], project_dir, timeout=30)
        if code != 0:
            return {
                "success": False,
                "error": err or out or "Git pull failed (local changes might conflict)",
            }

    # Run theme applier to ensure all generated files are synchronized
    theme_apply = project_dir / "scripts" / "deloway-theme-apply.py"
    if theme_apply.exists():
        subprocess.run([sys.executable, str(theme_apply)], cwd=str(project_dir), check=False)

    # Refresh font caches if any new fonts were added
    subprocess.run(["fc-cache", "-f"], check=False, timeout=30)

    # Perform clean restart of Quickshell
    restart_cmd = 'killall quickshell; sleep 1.5; hyprctl dispatch exec "quickshell -p ' + str(project_dir / "shell") + '"'
    subprocess.Popen(["bash", "-c", restart_cmd])

    return {
        "success": True,
        "message": "Update applied successfully. Reloading interface...",
        "new_info": get_current_info(project_dir),
    }


def main():
    parser = argparse.ArgumentParser(description="DeloWay System Updater")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # info
    subparsers.add_parser("info", help="Get current repository info")

    # check
    check_parser = subparsers.add_parser("check", help="Check for updates")
    check_parser.add_argument("--channel", default="dev", choices=["dev", "stable"])

    # apply
    subparsers.add_parser("apply", help="Apply updates and restart shell")

    args = parser.parse_args()
    project_dir = get_project_dir()

    if args.command == "info":
        res = get_current_info(project_dir)
    elif args.command == "check":
        res = check_updates(project_dir, channel=args.channel)
    elif args.command == "apply":
        res = apply_update(project_dir)
    else:
        res = {"error": "Unknown command"}

    print(json.dumps(res, ensure_ascii=False))


if __name__ == "__main__":
    main()
