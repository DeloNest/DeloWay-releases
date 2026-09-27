#!/usr/bin/env python3
"""DeloWay's Dolphin: a modern, quiet file manager on top of the colours, fonts and icons
kdeglobals already gives every KDE app (deloway-theme-apply.py).

    deloway_dolphin.py apply [--dry-run]         layout, toolbar, sidebar, context menu, style

What it sets, and how often:
- Layout (dolphinrc): tabs are not restored, no selection "+" on hover, two-line names,
  22 px rows in the sidebar and details view, a context menu without what the toolbar
  already has (sort, view mode) or what Plasma alone uses. Written once per LAYOUT
  version: whatever the user changes afterwards in Dolphin's settings stays.
- Toolbar (kxmlgui5/dolphin/dolphinui.rc): back, forward, the path, search, view options,
  menu — no split-view buttons. Built from the ui file compiled into Dolphin (only the
  toolbar is replaced) with that file's version, so a Dolphin update is never shadowed;
  a toolbar the user edited (no DeloWay marker) is left alone.
- Sidebar (user-places.xbel): Remote, Recent, Search For and Tags hidden, once — Plasma
  features that are empty or meaningless here. Places and Devices stay.
- Style (breezerc): no toolbar separators, dotted focus rectangles or panel frames,
  animations at the shell's pace. Managed keys only, on every run.
Nothing is written while a Dolphin window is open: it writes its own settings back on
close, and the sidebar file is shared with every KDE file dialog.
"""

import configparser
import os
import re
import subprocess
import sys
from pathlib import Path

LAYOUT_VERSION = 1

DOLPHIN_LAYOUT = {
    "General": {
        # A new window opens where it is asked to, not on last session's tabs.
        "RememberOpenedTabs": "false",
        # The "+" on hovered items: selection already has click, Ctrl, Shift and rubber band.
        "ShowSelectionToggle": "false",
        "ShowZoomSlider": "false",
    },
    "IconsMode": {"MaximumTextLines": "2"},
    "DetailsMode": {"IconSize": "22", "PreviewSize": "22"},
    "CompactMode": {"IconSize": "22", "PreviewSize": "22"},
    "PlacesPanel": {"IconSize": "22"},
    "ContextMenu": {
        # In the toolbar (view options) or one click away in a window of its own.
        "ShowSortBy": "false",
        "ShowViewMode": "false",
        "ShowOpenInNewWindow": "false",
        "ShowOpenInSplitView": "false",
    },
}

# File item actions (plugins) hidden from the context menu: Plasma activities, tags
# (a Baloo feature with no view here) and a row of coloured folder icons.
HIDDEN_ITEM_ACTIONS = ("kactivitymanagerd_fileitem_linking_plugin", "tagsfileitemaction",
                       "setfoldericonitemaction", "forgetfileitemaction")

HIDDEN_PLACES_GROUPS = ("Remote", "RecentlySaved", "SearchFor", "Tags")

# Breeze reads these on every start; they are the style, not the user's layout.
BREEZE_STYLE = {
    "Style": {
        "ToolBarDrawItemSeparator": "false",
        "ViewDrawFocusIndicator": "false",
        "ViewDrawTreeBranchLines": "false",
        "SidePanelDrawFrame": "false",
        "DockWidgetDrawFrame": "false",
        "MenuOpacity": "100",
        "AnimationsEnabled": "true",
        "AnimationsDuration": "150",             # the shell's motion tokens: 120–200 ms
        "StackedWidgetTransitionsEnabled": "true",
        "ScrollBarAddLineButtons": "0",
        "ScrollBarSubLineButtons": "0",
    },
}

TOOLBAR_MARKER = "<!-- DeloWay toolbar (scripts/deloway_dolphin.py) -->"
TOOLBAR_ACTIONS = ("go_back", "go_forward", "url_navigators", "toggle_search",
                   "view_settings", "hamburger_menu")


def config_home() -> Path:
    return Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")


def data_home() -> Path:
    return Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share")


def log(msg: str):
    print(f"[deloway-dolphin] {msg}")


def write_if_changed(path: Path, content: str, dry_run: bool) -> bool:
    try:
        if path.read_text(encoding="utf-8") == content:
            return False
    except (OSError, UnicodeDecodeError):
        pass
    if dry_run:
        log(f"[dry-run] would update {path}")
        return True
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f"{path.name}.tmp.{os.getpid()}")
    tmp.write_text(content, encoding="utf-8")
    os.replace(tmp, path)
    log(f"updated {path}")
    return True


# ── KConfig files (case-sensitive keys, "[A][B]" nested groups kept as one name) ──

def read_kconfig(path: Path):
    cfg = configparser.RawConfigParser(strict=False, delimiters=("=",), comment_prefixes=("#",),
                                       interpolation=None)
    cfg.optionxform = str
    if path.exists():
        cfg.read(path, encoding="utf-8")
    return cfg


def kconfig_text(cfg) -> str:
    lines = []
    for group in cfg.sections():
        lines.append(f"[{group}]")
        lines.extend(f"{k}={v}" for k, v in cfg.items(group))
        lines.append("")
    return "\n".join(lines)


def merge(cfg, groups: dict):
    for group, keys in groups.items():
        if not cfg.has_section(group):
            cfg.add_section(group)
        for k, v in keys.items():
            cfg.set(group, k, v)


def dolphin_running() -> bool:
    try:
        return subprocess.run(["pgrep", "-x", "dolphin"], capture_output=True, timeout=3).returncode == 0
    except (OSError, subprocess.SubprocessError):
        return True   # cannot tell: leave everything for the next run


# ── Layout ──

def apply_layout(dry_run: bool) -> bool:
    path = config_home() / "dolphinrc"
    try:
        cfg = read_kconfig(path)
    except configparser.Error as e:
        log(f"dolphinrc unreadable, left alone: {e}")
        return False
    done = cfg.getint("DeloWay", "Layout", fallback=0) if cfg.has_section("DeloWay") else 0
    if done >= LAYOUT_VERSION:
        return False
    merge(cfg, DOLPHIN_LAYOUT)
    merge(cfg, {"DeloWay": {"Layout": str(LAYOUT_VERSION)}})
    return write_if_changed(path, kconfig_text(cfg), dry_run)


def apply_item_actions(dry_run: bool) -> bool:
    path = config_home() / "kservicemenurc"
    try:
        cfg = read_kconfig(path)
    except configparser.Error:
        return False
    merge(cfg, {"Show": {name: "false" for name in HIDDEN_ITEM_ACTIONS}})
    return write_if_changed(path, kconfig_text(cfg), dry_run)


def apply_style(dry_run: bool) -> bool:
    path = config_home() / "breezerc"
    try:
        cfg = read_kconfig(path)
    except configparser.Error:
        return False
    merge(cfg, BREEZE_STYLE)
    return write_if_changed(path, kconfig_text(cfg), dry_run)


# ── Toolbar ──

def builtin_ui_file() -> str:
    """Dolphin's own dolphinui.rc: compiled into the binary as a zstd-compressed Qt
    resource. The highest version found is the main window's (Dolphin also embeds its
    KPart's, version 6 or so)."""
    exe = next((Path(d) / "dolphin" for d in os.environ.get("PATH", "/usr/bin").split(":")
                if (Path(d) / "dolphin").is_file()), None)
    if exe is None:
        return ""
    try:
        from compression import zstd   # Python 3.14
    except ImportError:
        return ""
    blob = exe.read_bytes()
    best, best_version = "", -1
    for m in re.finditer(rb"\x28\xb5\x2f\xfd", blob):
        try:
            text = zstd.ZstdDecompressor().decompress(blob[m.start():m.start() + 262144])
        except Exception:
            continue
        head = text[:300]
        v = re.search(rb'<gui name="dolphin" version="(\d+)"', head)
        if v and b"<ToolBar" in text and int(v.group(1)) > best_version:
            best, best_version = text.decode("utf-8", "replace"), int(v.group(1))
    return best


def ui_version(text: str) -> int:
    m = re.search(r'<gui name="dolphin" version="(\d+)"', text)
    return int(m.group(1)) if m else -1


def build_toolbar_ui(builtin: str) -> str:
    actions = "".join(f'        <Action name="{a}" />\n' for a in TOOLBAR_ACTIONS)
    toolbar = ('<ToolBar noMerge="1" name="mainToolBar" >\n'
               '        <text context="@title:menu">Main Toolbar</text>\n'
               f"{actions}    </ToolBar>")
    ui, n = re.subn(r"<ToolBar noMerge=\"1\" name=\"mainToolBar\"\s*>.*?</ToolBar>", toolbar, builtin,
                    count=1, flags=re.S)
    if n != 1:
        return ""
    return ui.replace('<!DOCTYPE gui SYSTEM "kpartgui.dtd">',
                      '<!DOCTYPE gui SYSTEM "kpartgui.dtd">\n' + TOOLBAR_MARKER, 1)


def apply_toolbar(dry_run: bool) -> bool:
    path = data_home() / "kxmlgui5" / "dolphin" / "dolphinui.rc"
    current = ""
    if path.exists():
        current = path.read_text(encoding="utf-8", errors="replace")
        if TOOLBAR_MARKER not in current:
            return False                       # the user's own toolbar
    builtin = builtin_ui_file()
    if not builtin:
        return False                           # cannot read Dolphin's: its default stays
    if current and ui_version(current) == ui_version(builtin):
        return False
    ui = build_toolbar_ui(builtin)
    return bool(ui) and write_if_changed(path, ui, dry_run)


# ── Sidebar ──

def apply_places(dry_run: bool) -> bool:
    """Hide the Plasma-only groups once (marker in dolphinrc): unhidden later, they stay."""
    rc_path = config_home() / "dolphinrc"
    places = data_home() / "user-places.xbel"
    if not places.exists():
        return False                           # Dolphin creates it on first start: next run
    try:
        rc = read_kconfig(rc_path)
    except configparser.Error:
        return False
    if rc.has_section("DeloWay") and rc.getint("DeloWay", "PlacesGroups", fallback=0) >= LAYOUT_VERSION:
        return False
    xml = places.read_text(encoding="utf-8", errors="replace")
    for group in HIDDEN_PLACES_GROUPS:
        tag = f"GroupState-{group}-IsHidden"
        if f"<{tag}>" in xml:
            xml = re.sub(rf"<{tag}>\w*</{tag}>", f"<{tag}>true</{tag}>", xml)
        else:
            xml, n = re.subn(r'(<metadata owner="http://www.kde.org">)', rf"\1\n   <{tag}>true</{tag}>", xml, count=1)
            if n != 1:
                return False                   # unknown layout: leave it
    changed = write_if_changed(places, xml, dry_run)
    merge(rc, {"DeloWay": {"PlacesGroups": str(LAYOUT_VERSION)}})
    write_if_changed(rc_path, kconfig_text(rc), dry_run)
    return changed


def apply(dry_run: bool = False) -> bool:
    apply_style(dry_run)
    apply_item_actions(dry_run)
    if dolphin_running():
        return False
    apply_layout(dry_run)
    apply_toolbar(dry_run)
    apply_places(dry_run)
    return True


def main(argv):
    dry = "--dry-run" in argv
    if len(argv) >= 2 and argv[1] == "apply":
        apply(dry)
        return 0
    print(__doc__.split("\n\n")[1], file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
