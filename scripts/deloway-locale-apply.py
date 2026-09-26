#!/usr/bin/env python3
"""
DeloWay Locale Apply Script
Applies system-wide language configuration to user files, environment.d, browsers, and desktop apps.
Supports --dry-run and --revert.
# managed by deloway
"""

import os
import sys
import argparse
import shutil
import subprocess
import configparser
from datetime import datetime
from pathlib import Path

MANAGED_HEADER = "# managed by deloway\n"

def log(msg):
    print(f"[deloway-locale] {msg}")

def backup_file(path: Path, dry_run: bool = False) -> None:
    if not path.exists():
        return
    # Only make backup once per timestamp session if not already backed up
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = path.with_suffix(f"{path.suffix}.bak_{timestamp}")
    log(f"Backing up {path} -> {backup_path}")
    if not dry_run:
        shutil.copy2(path, backup_path)

def write_managed_file(path: Path, content: str, dry_run: bool = False) -> None:
    path = path.expanduser().resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        # Check if already managed or needs backup
        backup_file(path, dry_run)
    
    log(f"Writing to {path}:\n{content.strip()}")
    if not dry_run:
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)


def available_arabic_locale():
    """Return an installed Arabic UTF-8 locale name (e.g. ar_SA.UTF-8) or None.

    Setting LANG to a locale that is NOT generated makes glibc fall back to "C",
    and in the C locale gettext ignores LANGUAGE — apps then lose their Arabic
    translations and, with them, their RTL layout. So only use one that exists.
    """
    try:
        out = subprocess.run(["locale", "-a"], capture_output=True, text=True, timeout=3).stdout.split()
    except Exception:
        return None
    norm = {l.lower().replace("utf8", "utf-8"): l for l in out}
    for cand in ("ar_sa.utf-8", "ar_ae.utf-8", "ar_eg.utf-8"):
        if cand in norm:
            return cand.split(".")[0][:3] + cand.split(".")[0][3:].upper() + ".UTF-8"
    for k in norm:
        if k.startswith("ar_") and k.endswith(".utf-8"):
            base = k.split(".")[0]
            return base[:3] + base[3:].upper() + ".UTF-8"
    return None


def main_locale_for(lang: str) -> str:
    """LANG for the requested UI language. Arabic UI works through LANGUAGE=ar:en
    (translations → RTL) even when LANG stays en_US.UTF-8."""
    if lang == "ar":
        return available_arabic_locale() or "en_US.UTF-8"
    return "en_US.UTF-8"

def numeric_locale(numbers: str) -> str:
    """LC_NUMERIC for Settings → Apps → Number Format (Qt/KDE apps take their digits
    from it): Eastern digits from the Arabic locale, Western from en_US."""
    if numbers == "eastern":
        return available_arabic_locale() or "en_US.UTF-8"
    return "en_US.UTF-8"


def apply_environment_d(lang: str, numbers: str = "western", dry_run: bool = False) -> None:
    env_dir = Path.home() / ".config" / "environment.d"
    target_file = env_dir / "90-deloway-locale.conf"

    if lang == "ar":
        content = (
            MANAGED_HEADER
            + f"LANG={main_locale_for('ar')}\n"
            + "LANGUAGE=ar:en\n"
            + f"LC_NUMERIC={numeric_locale(numbers)}\n"
            + "LC_TIME=en_US.UTF-8\n"
            + "LC_COLLATE=C\n"
        )
    else:
        content = (
            MANAGED_HEADER
            + "LANG=en_US.UTF-8\n"
            + "LANGUAGE=en_US:en\n"
            + f"LC_NUMERIC={numeric_locale(numbers)}\n"
            + "LC_TIME=en_US.UTF-8\n"
            + "LC_COLLATE=C\n"
        )

    write_managed_file(target_file, content, dry_run)

def apply_firefox_user_js(lang: str, dry_run: bool = False) -> None:
    mozilla_dir = Path.home() / ".mozilla" / "firefox"
    profiles_ini = mozilla_dir / "profiles.ini"
    if not profiles_ini.exists():
        log("Firefox profiles.ini not found, skipping Firefox.")
        return

    try:
        config = configparser.ConfigParser()
        config.read(profiles_ini)
        profiles = []
        for section in config.sections():
            if section.startswith("Profile") or section.startswith("Install"):
                if config.has_option(section, "Path"):
                    p_path = config.get(section, "Path")
                    is_rel = config.get(section, "IsRelative", fallback="1") == "1"
                    full_path = (mozilla_dir / p_path) if is_rel else Path(p_path)
                    if full_path.exists() and full_path not in profiles:
                        profiles.append(full_path)

        for profile in profiles:
            user_js = profile / "user.js"
            if lang == "ar":
                prefs = (
                    MANAGED_HEADER
                    + 'user_pref("intl.locale.requested", "ar,en-US");\n'
                    + 'user_pref("intl.accept_languages", "ar,en-US,en");\n'
                )
            else:
                prefs = (
                    MANAGED_HEADER
                    + 'user_pref("intl.locale.requested", "en-US");\n'
                    + 'user_pref("intl.accept_languages", "en-US,en");\n'
                )
            write_managed_file(user_js, prefs, dry_run)
    except Exception as e:
        log(f"Error configuring Firefox: {e}")

def apply_chromium_flags(lang: str, dry_run: bool = False) -> None:
    # Supported chromium family flag files on Arch / Linux
    flag_files = [
        Path.home() / ".config" / "brave-flags.conf",
        Path.home() / ".config" / "chrome-flags.conf",
        Path.home() / ".config" / "chromium-flags.conf",
        Path.home() / ".config" / "thorium-flags.conf",
    ]

    target_lang = "ar" if lang == "ar" else "en-US"
    flag_line = f"--lang={target_lang}"

    for flag_file in flag_files:
        # Check if browser is installed or flag file already exists
        browser_name = flag_file.stem.replace("-flags", "")
        is_installed = shutil.which(browser_name) is not None or flag_file.exists()
        if not is_installed:
            continue

        existing_lines = []
        if flag_file.exists():
            backup_file(flag_file, dry_run)
            with open(flag_file, "r", encoding="utf-8") as f:
                for line in f:
                    stripped = line.strip()
                    if not stripped.startswith("--lang="):
                        existing_lines.append(stripped)

        new_lines = [flag_line]
        for line in existing_lines:
            if line and line != MANAGED_HEADER.strip() and not line.startswith("--lang="):
                new_lines.append(line)

        content = MANAGED_HEADER + "\n".join(new_lines) + "\n"
        write_managed_file(flag_file, content, dry_run)

def apply_flatpak(lang: str, dry_run: bool = False) -> None:
    flatpak_bin = shutil.which("flatpak")
    if not flatpak_bin:
        return

    flatpak_langs = "ar;en" if lang == "ar" else "en"
    log(f"Running flatpak config --user --set languages {flatpak_langs}")
    if not dry_run:
        try:
            subprocess.run([flatpak_bin, "config", "--user", "--set", "languages", flatpak_langs], check=True, timeout=5)
        except Exception as e:
            log(f"Flatpak config failed: {e}")

def update_running_session(lang: str, dry_run: bool = False) -> None:
    lang_val = "ar:en" if lang == "ar" else "en_US:en"
    main_lang = main_locale_for(lang)

    log(f"Updating running session: LANG={main_lang}, LANGUAGE={lang_val}")
    if not dry_run:
        # 1. Hyprland runtime environment
        try:
            subprocess.run(["hyprctl", "keyword", "env", f"LANGUAGE,{lang_val}"], capture_output=True, timeout=2)
            subprocess.run(["hyprctl", "keyword", "env", f"LANG,{main_lang}"], capture_output=True, timeout=2)
        except Exception:
            pass

        # 2. systemd / D-Bus activation environment
        try:
            subprocess.run(["dbus-update-activation-environment", "--systemd", f"LANG={main_lang}", f"LANGUAGE={lang_val}"], capture_output=True, timeout=2)
        except Exception:
            pass

def revert(dry_run: bool = False) -> None:
    log("Reverting managed DeloWay locale configurations...")
    # Revert to English
    apply_environment_d("en", dry_run=dry_run)
    apply_firefox_user_js("en", dry_run)
    apply_chromium_flags("en", dry_run)
    apply_flatpak("en", dry_run)
    update_running_session("en", dry_run)
    log("Revert complete.")

def main():
    parser = argparse.ArgumentParser(description="DeloWay System-wide Locale Applier")
    parser.add_argument("--lang", choices=["ar", "en"], default="ar", help="Target language (ar or en)")
    parser.add_argument("--dry-run", action="store_true", help="Simulate changes without modifying files")
    parser.add_argument("--revert", action="store_true", help="Revert settings to English")
    parser.add_argument("--numbers", choices=["western", "eastern"], default="western",
                        help="Digits for Qt/KDE apps (LC_NUMERIC)")
    parser.add_argument("--env-only", action="store_true",
                        help="Only the session environment files (number format changes)")

    args = parser.parse_args()

    if args.revert:
        revert(dry_run=args.dry_run)
        return

    log(f"Applying system-wide language: {args.lang} (dry-run={args.dry_run})")
    apply_environment_d(args.lang, args.numbers, dry_run=args.dry_run)
    if args.env_only:
        return
    apply_firefox_user_js(args.lang, dry_run=args.dry_run)
    apply_chromium_flags(args.lang, dry_run=args.dry_run)
    apply_flatpak(args.lang, dry_run=args.dry_run)
    update_running_session(args.lang, dry_run=args.dry_run)
    log("Locale apply complete.")

if __name__ == "__main__":
    main()
