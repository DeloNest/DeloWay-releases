#!/usr/bin/env python3
"""
DeloWay Theme Integrity Checker
================================
Validates that DeloWay codebase adheres strictly to the monochrome identity (OLED Dark & High-Contrast Light)
and prevents reintroduction of accent colors or arbitrary hardcoded hex codes.

Allowed:
- Pure monochrome: #000, #fff, #000000, #ffffff, "transparent", "white", "black"
- Neutral grays: where R, G, B channels are approximately equal or from official neutral tokens
- Semantic indicators: Danger/Urgent (red), Warning (amber/yellow), Success (green) in tiny indicators only
- Theme definition files (Theme.qml, theme.json, etc.) define official tokens.

Forbidden:
- Any accent color property definitions or UI selectors
- Hardcoded colored hex codes (purples, blues, magentas, cyans, oranges outside semantic contexts)
- Colored gradients
"""

import sys
import re
from pathlib import Path

# Base paths
PROJECT_ROOT = Path(__file__).resolve().parent.parent
SHELL_DIR = PROJECT_ROOT / "shell"

# Excluded files that are allowed to define tokens or provide backward compatibility
EXEMPT_FILES = {
    SHELL_DIR / "theme" / "Theme.qml",
    SHELL_DIR / "theme" / "theme.json",
    SHELL_DIR / "theme" / "themes" / "deloos-dark.json",
    SHELL_DIR / "theme" / "themes" / "deloos-light.json",
    SHELL_DIR / "services" / "ConfigManager.qml",
}

# Semantic hex colors allowed for status indicators (status dots, warning badges, danger actions)
SEMANTIC_HEX_ALLOWLIST = {
    # Danger / Urgent / Error (Red)
    "#ef4444", "#dc2626", "#b91c1c", "#f87171", "#e11d48",
    # Warning / Alert (Amber / Orange)
    "#f59e0b", "#d97706", "#b45309", "#fbbf24",
    # Success / Online (Green)
    "#10b981", "#059669", "#22c55e", "#16a34a", "#4ade80",
}

# Pure neutral grayscale hex codes allowed inline
MONOCHROME_HEX_ALLOWLIST = {
    "#000000", "#ffffff", "#000", "#fff",
    "#0a0a0a", "#111111", "#121212", "#141414", "#181818", "#1a1a1a",
    "#222222", "#2a2a2a", "#333333", "#444444", "#555555", "#666666",
    "#777777", "#888888", "#999999", "#aaaaaa", "#cccccc", "#dddddd", "#eeeeee",
    "#0f172a", "#101318", "#151922", "#1a202c", "#2a3142", "#202533", "#3d465c", # Dark neutrals
    "#f8fafc", "#f1f5f9", "#e2e8f0", "#cbd5e1", "#94a3b8", "#64748b", "#475569", "#334155", # Light neutrals
    "#111827", "#4b5563", "#9ca3af", "#d5dbe6", "#e5e9f0", "#b8c3d6", "#9da7be", "#626c82"
}

HEX_REGEX = re.compile(r'#(?:[0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\b')

# Patterns forbidden in component files
FORBIDDEN_PATTERNS = [
    (re.compile(r'setAccentColor\s*\('), "Explicit call or definition of setAccentColor()"),
    (re.compile(r'accentPaletteOptions'), "Accent color palette options UI"),
    (re.compile(r'Theme\.colors\.accent\b'), "Direct usage of Theme.colors.accent in UI (use Theme.notchText, Theme.colors.text, or Theme.notchBorderHighlight)"),
]

def is_neutral_hex(hex_str: str) -> bool:
    hex_clean = hex_str.lstrip('#').lower()
    if len(hex_clean) == 3:
        return hex_clean[0] == hex_clean[1] == hex_clean[2]
    if len(hex_clean) == 6:
        r = int(hex_clean[0:2], 16)
        g = int(hex_clean[2:4], 16)
        b = int(hex_clean[4:6], 16)
        # Check if R, G, B are very close (grayscale)
        return max(r, g, b) - min(r, g, b) <= 24
    if len(hex_clean) == 8:
        r = int(hex_clean[0:2], 16)
        g = int(hex_clean[2:4], 16)
        b = int(hex_clean[4:6], 16)
        return max(r, g, b) - min(r, g, b) <= 24
    return False

def check_file(file_path: Path):
    violations = []
    try:
        content = file_path.read_text(encoding="utf-8")
    except Exception as e:
        return [(0, f"Cannot read file: {e}")]

    lines = content.splitlines()
    for line_idx, line in enumerate(lines, start=1):
        stripped = line.strip()
        # Skip pure comments
        if stripped.startswith("//") or stripped.startswith("/*") or stripped.startswith("*"):
            continue

        # Check forbidden patterns
        for pattern, reason in FORBIDDEN_PATTERNS:
            if pattern.search(line):
                # Skip backward compatibility alias definition inside ConfigManager
                if file_path.name == "ConfigManager.qml" and "readonly property color accentColor" in line:
                    continue
                violations.append((line_idx, f"[Forbidden Pattern] {reason} | Line: {stripped}"))

        # Check hex colors
        for match in HEX_REGEX.finditer(line):
            hex_val = match.group(0).lower()
            if hex_val in MONOCHROME_HEX_ALLOWLIST or hex_val in SEMANTIC_HEX_ALLOWLIST:
                continue
            if is_neutral_hex(hex_val):
                continue

            violations.append((
                line_idx,
                f"[Disallowed Color] Non-monochrome hex '{hex_val}' found. Line: {stripped}"
            ))

    return violations

def main():
    print("=" * 65)
    print(" DeloWay Theme Integrity & Monochrome Identity Checker")
    print("=" * 65)
    
    total_files = 0
    total_violations = 0
    files_with_issues = 0

    qml_files = sorted(SHELL_DIR.glob("**/*.qml"))
    js_files = sorted(SHELL_DIR.glob("**/*.js"))
    target_files = qml_files + js_files

    for f in target_files:
        if f in EXEMPT_FILES:
            continue
        total_files += 1
        violations = check_file(f)
        if violations:
            files_with_issues += 1
            total_violations += len(violations)
            rel_path = f.relative_to(PROJECT_ROOT)
            print(f"\n❌ \033[1;31m{rel_path}\033[0m ({len(violations)} violation{'s' if len(violations)>1 else ''}):")
            for line_no, msg in violations:
                print(f"   Line {line_no:4d}: {msg}")

    print("\n" + "-" * 65)
    print(f"Scanned: {total_files} files")
    if total_violations == 0:
        print("\033[1;32m✔ SUCCESS: 100% Monochrome compliance. Zero accent violations found.\033[0m")
        print("=" * 65)
        return 0
    else:
        print(f"\033[1;31m✘ FAILURE: Found {total_violations} violation(s) across {files_with_issues} file(s).\033[0m")
        print("=" * 65)
        return 1

if __name__ == "__main__":
    sys.exit(main())
