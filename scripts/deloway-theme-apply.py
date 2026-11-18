#!/usr/bin/env python3
"""
DeloWay Desktop - Dynamic System Theme Application Engine
Reads theme.json and deloway.json, generating consistent, atomic GTK 3.0, GTK 4.0 (libadwaita),
Thunar, Qt (qt6ct), and gsettings desktop themes matching DeloWay's strict monochrome identity.
"""

import sys
import os
import json
import re
import subprocess
import argparse
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import deloway_dolphin  # noqa: E402


def get_gsettings_value(key: str) -> str:
    """Read an org.gnome.desktop.interface gsettings key cleanly."""
    try:
        res = subprocess.run(
            ["gsettings", "get", "org.gnome.desktop.interface", key],
            capture_output=True,
            text=True,
            check=True
        )
        val = res.stdout.strip()
        if (val.startswith("'") and val.endswith("'")) or (val.startswith('"') and val.endswith('"')):
            val = val[1:-1]
        return val
    except Exception as e:
        print(f"[deloway-theme] Warning: Failed to get gsettings {key}: {e}", file=sys.stderr)
        return ""


def icon_theme_dirs() -> list:
    """Icon theme search path, in XDG order (~/.local/share/icons, ~/.icons, $XDG_DATA_DIRS)."""
    home = Path.home()
    data_home = Path(os.environ.get("XDG_DATA_HOME") or home / ".local" / "share")
    data_dirs = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
    return [data_home / "icons", home / ".icons"] + [Path(d) / "icons" for d in data_dirs.split(":") if d]


def icon_theme_installed(name: str) -> bool:
    return bool(name) and any((d / name / "index.theme").is_file() for d in icon_theme_dirs())


def resolve_icon_theme(is_dark: bool) -> str:
    """The DeloWay icon theme for the mode, or the closest installed fallback.

    Reversal-black(-dark) comes from packaging/deloway-icon-theme (install.sh). If it is
    missing, fall back to another Reversal variant, then Breeze, then Adwaita, and say so.
    """
    if is_dark:
        chain = ["Reversal-black-dark", "Reversal-dark", "breeze-dark", "Adwaita"]
    else:
        chain = ["Reversal-black", "Reversal", "breeze", "Adwaita"]
    for name in chain:
        if icon_theme_installed(name):
            if name != chain[0]:
                print(f"[deloway-theme] Icon theme '{chain[0]}' is not installed; using '{name}'. "
                      "Run install.sh to install deloway-icon-theme.", file=sys.stderr)
            return name
    return chain[0]


def set_gsettings_value(key: str, val: str, dry_run: bool = False):
    """Set an org.gnome.desktop.interface gsettings key only if different."""
    current = get_gsettings_value(key)
    if current == str(val):
        return
    if dry_run:
        print(f"[dry-run] gsettings set org.gnome.desktop.interface {key} '{val}' (current: '{current}')")
    else:
        try:
            subprocess.run(
                ["gsettings", "set", "org.gnome.desktop.interface", key, str(val)],
                check=True
            )
            print(f"[deloway-theme] gsettings set {key} -> {val}")
        except Exception as e:
            print(f"[deloway-theme] Error setting gsettings {key}: {e}", file=sys.stderr)


def atomic_write_if_changed(target_path: Path, content: str, dry_run: bool = False) -> bool:
    """Write content to target_path atomically only if content has changed."""
    target_path.parent.mkdir(parents=True, exist_ok=True)

    if target_path.exists():
        try:
            existing = target_path.read_text(encoding="utf-8")
            if existing == content:
                return False
        except Exception:
            pass

    if dry_run:
        print(f"[dry-run] Would update: {target_path} ({len(content)} bytes)")
        return True

    temp_path = target_path.with_name(f"{target_path.name}.tmp.{os.getpid()}")
    try:
        temp_path.write_text(content, encoding="utf-8")
        os.replace(temp_path, target_path)
        print(f"[deloway-theme] Updated: {target_path}")
        return True
    except Exception as e:
        if temp_path.exists():
            temp_path.unlink()
        print(f"[deloway-theme] Error writing {target_path}: {e}", file=sys.stderr)
        return False


def build_gtk_css(mode: str) -> str:
    """Generate dynamic GTK CSS with libadwaita named colors and component styles (Monochrome OLED / High Contrast / Glass)."""
    is_dark = (mode == "dark" or mode == "glass")
    project_dir = Path(__file__).resolve().parent.parent
    theme_file = project_dir / "shell" / "theme" / "themes" / f"deloos-{mode}.json"
    if not theme_file.exists():
        theme_file = project_dir / "shell" / "theme" / "themes" / "deloos-dark.json"

    with open(theme_file, "r", encoding="utf-8") as f:
        theme_data = json.load(f)
    colors = theme_data.get("colors", {})

    # Strict Monochrome Tokens derived from single source of truth
    if mode == "glass":
        # OLED Glass Translucent Mode (85% Black + Compositor Dual-pass Blur)
        bg_alpha = colors.get("backgroundAlpha", 0.85)
        window_bg = f"rgba(0, 0, 0, {bg_alpha})"
        window_fg = colors.get("text", "#ffffff")
        view_bg = f"rgba(0, 0, 0, {bg_alpha})"
        view_fg = colors.get("text", "#ffffff")
        sidebar_bg = f"rgba(10, 10, 10, {bg_alpha * 0.76:.2f})"
        sidebar_fg = colors.get("text", "#ffffff")
        headerbar_bg = f"rgba(10, 10, 10, {bg_alpha * 0.88:.2f})"
        headerbar_fg = colors.get("text", "#ffffff")
        headerbar_border = "rgba(255, 255, 255, 0.12)"
        card_bg = "rgba(20, 20, 20, 0.65)"
        popover_bg = colors.get("surfaceElevated", "#141414")
        dialog_bg = colors.get("surfaceElevated", "#141414")
        border = "rgba(255, 255, 255, 0.12)"
        text_muted = colors.get("textMuted", "#8e8e8e")
    elif is_dark:
        # OLED Pure Black & Neutral Elevated Surfaces
        window_bg = colors.get("background", "#000000")
        window_fg = colors.get("text", "#ffffff")
        view_bg = colors.get("background", "#000000")
        view_fg = colors.get("text", "#ffffff")
        sidebar_bg = colors.get("backgroundAlt", "#0a0a0a")
        sidebar_fg = colors.get("text", "#ffffff")
        headerbar_bg = colors.get("backgroundAlt", "#0a0a0a")
        headerbar_fg = colors.get("text", "#ffffff")
        headerbar_border = colors.get("border", "#222222")
        card_bg = colors.get("surfaceCard", "#111111")
        popover_bg = colors.get("surfaceElevated", "#111111")
        dialog_bg = colors.get("surfaceElevated", "#111111")
        border = colors.get("border", "#222222")
        text_muted = colors.get("textMuted", "#888888")
    else:
        # Crisp High-Contrast Light Mode
        window_bg = colors.get("surface", "#ffffff")
        window_fg = colors.get("text", "#0f172a")
        view_bg = colors.get("surface", "#ffffff")
        view_fg = colors.get("text", "#0f172a")
        sidebar_bg = colors.get("background", "#f8fafc")
        sidebar_fg = colors.get("text", "#0f172a")
        headerbar_bg = colors.get("background", "#f8fafc")
        headerbar_fg = colors.get("text", "#0f172a")
        headerbar_border = colors.get("borderSubtle", "#e2e8f0")
        card_bg = colors.get("surface", "#ffffff")
        popover_bg = colors.get("surface", "#ffffff")
        dialog_bg = colors.get("surface", "#ffffff")
        border = colors.get("border", "#d5dbe6")
        text_muted = colors.get("textMuted", "#64748b")

    # Neutral Contrast Active/Selection
    sel_bg = colors.get("accent", "#ffffff" if is_dark else "#0f172a")
    sel_fg = colors.get("accentText", "#000000" if is_dark else "#ffffff")

    # Translucent row selection matching Notch/Capsule cards
    sel_fill = colors.get("selectionFill", "#ffffff" if is_dark else "#0f172a")
    sel_alpha = colors.get("selectionAlpha", 0.16 if is_dark else 0.12)
    sel_border = colors.get("selectionBorder", "#ffffff" if is_dark else "#0f172a")
    sel_border_alpha = colors.get("selectionBorderAlpha", 0.35 if is_dark else 0.25)
    hover_fill = colors.get("hoverFill", "#ffffff" if is_dark else "#0f172a")
    hover_alpha = colors.get("hoverAlpha", 0.08 if is_dark else 0.06)

    thunar_row_sel_bg = f"alpha({sel_fill}, {sel_alpha})"
    thunar_row_sel_fg = colors.get("textPrimary", "#ffffff" if is_dark else "#0f172a")
    thunar_row_sel_border = f"alpha({sel_border}, {sel_border_alpha})"
    thunar_row_hover_bg = f"alpha({hover_fill}, {hover_alpha})"

    # Semantic Status Indicators (strictly constrained)
    destructive = colors.get("urgent", "#ef4444")
    warning = colors.get("warning", "#f59e0b" if is_dark else "#d97706")
    success = colors.get("success", "#10b981")

    return f"""/* ========================================================================== */
/* DeloWay Dynamic GTK Stylesheet (Generated by deloway-theme-apply.py)        */
/* Mode: {mode:<10}  Identity: Strict Monochrome (OLED / Light)           */
/* ========================================================================== */

/* --- Libadwaita & Standard GTK Named Colors --- */
@define-color theme_bg_color {window_bg};
@define-color theme_fg_color {window_fg};
@define-color theme_base_color {sidebar_bg};
@define-color theme_selected_bg_color {thunar_row_sel_bg};
@define-color theme_selected_fg_color {thunar_row_sel_fg};
@define-color accent_color {sel_bg};
@define-color accent_bg_color {sel_bg};
@define-color accent_fg_color {sel_fg};
@define-color window_bg_color {window_bg};
@define-color window_fg_color {window_fg};
@define-color view_bg_color {view_bg};
@define-color view_fg_color {view_fg};
@define-color headerbar_bg_color {headerbar_bg};
@define-color headerbar_fg_color {headerbar_fg};
@define-color headerbar_border_color {headerbar_border};
@define-color sidebar_bg_color {sidebar_bg};
@define-color sidebar_fg_color {sidebar_fg};
@define-color card_bg_color {card_bg};
@define-color card_fg_color {window_fg};
@define-color popover_bg_color {popover_bg};
@define-color popover_fg_color {window_fg};
@define-color dialog_bg_color {dialog_bg};
@define-color borders {border};
@define-color border_color {border};
@define-color text_muted {text_muted};

/* Unfocused / Backdrop Theme Named Colors (prevent white fallback in Thunar) */
@define-color theme_unfocused_selected_bg_color {thunar_row_sel_bg};
@define-color theme_unfocused_selected_fg_color {thunar_row_sel_fg};
@define-color theme_unfocused_bg_color {window_bg};
@define-color theme_unfocused_fg_color {window_fg};
@define-color theme_unfocused_base_color {sidebar_bg};
@define-color theme_unfocused_view_bg_color {view_bg};
@define-color theme_unfocused_text_color {view_fg};

/* Semantic status indicators */
@define-color destructive_color {destructive};
@define-color destructive_bg_color {destructive};
@define-color destructive_fg_color #ffffff;
@define-color warning_color {warning};
@define-color warning_bg_color {warning};
@define-color warning_fg_color #000000;
@define-color success_color {success};
@define-color success_bg_color {success};
@define-color success_fg_color #ffffff;

/* --- Global Window & Container Styling --- */
window, dialog {{
    background-color: @window_bg_color;
    color: @window_fg_color;
}}

headerbar {{
    background-color: @headerbar_bg_color;
    border-bottom: 1px solid @headerbar_border_color;
    color: @headerbar_fg_color;
}}

menubar, .menubar {{
    background-color: @headerbar_bg_color;
    color: @headerbar_fg_color;
    border-bottom: 1px solid @headerbar_border_color;
}}

menu, .menu, .context-menu, .csd menu, .csd .menu, .csd .context-menu, popover, popover.menu, window.popup {{
    background-color: @popover_bg_color;
    color: @popover_fg_color;
    border: 1px solid @border_color;
    border-radius: 8px;
    padding: 4px;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.60);
}}

menuitem, .menuitem {{
    border-radius: 6px;
    padding: 4px 8px;
    color: @popover_fg_color;
}}

menuitem:hover, menuitem:selected, .menuitem:hover, .menuitem:selected {{
    background-color: @theme_selected_bg_color;
    color: @theme_selected_fg_color;
}}

tooltip {{
    background-color: @popover_bg_color;
    border: 1px solid @border_color;
    border-radius: 6px;
    color: @popover_fg_color;
    padding: 4px 8px;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.45);
}}

/* Global Selection */
:selected {{
    background-color: @theme_selected_bg_color;
    color: @theme_selected_fg_color;
}}

/* High-contrast text input selection */
entry selection,
entry selection:focus,
entry:focus selection,
textview text selection {{
    background-color: {sel_bg};
    color: {sel_fg};
}}

/* ========================================================================== */
/* Thunar File Manager — Deep Monochrome OLED Styling                         */
/* ========================================================================== */

window.thunar, window#thunar-window, .thunar window {{
    background-color: @theme_bg_color;
    color: @theme_fg_color;
}}

/* Sidebar (Shortcuts & Treeview) */
window.thunar .sidebar,
window#thunar-window .sidebar,
.thunar scrolledwindow.sidebar,
.thunar .shortcuts-pane,
window.thunar .shortcuts-pane,
window.thunar .sidebar treeview,
.thunar .sidebar treeview {{
    background-color: @sidebar_bg_color;
    color: @sidebar_fg_color;
}}

/* Direction-aware sidebar borders for RTL and LTR */
window.thunar:dir(rtl) .sidebar,
window#thunar-window:dir(rtl) .sidebar,
.thunar:dir(rtl) scrolledwindow.sidebar,
.thunar:dir(rtl) .shortcuts-pane {{
    border-left: 1px solid @border_color;
    border-right: none;
}}

window.thunar:dir(ltr) .sidebar,
window#thunar-window:dir(ltr) .sidebar,
.thunar:dir(ltr) scrolledwindow.sidebar,
.thunar:dir(ltr) .shortcuts-pane {{
    border-right: 1px solid @border_color;
    border-left: none;
}}

window.thunar .sidebar treeview.view row,
window.thunar .sidebar row,
.thunar .sidebar treeview.view row,
.thunar .sidebar row {{
    min-height: 32px;
    margin: 1px 6px;
    padding: 4px 10px;
    border-radius: 8px;
    border: 1px solid transparent;
}}

window.thunar .sidebar treeview.view row image,
window.thunar .sidebar row image,
.thunar .sidebar image {{
    min-width: 16px;
    min-height: 16px;
}}

window.thunar .sidebar treeview.view row:hover,
window.thunar .sidebar row:hover,
.thunar .sidebar row:hover {{
    background-color: {thunar_row_hover_bg};
    border-color: transparent;
}}

window.thunar .sidebar treeview.view row:selected,
window.thunar .sidebar treeview.view row:selected:backdrop,
window.thunar .sidebar treeview.view row:backdrop:selected,
window.thunar .sidebar row:selected,
window.thunar .sidebar row:selected:backdrop,
window.thunar .sidebar row:backdrop:selected,
window.thunar .sidebar treeview:selected,
window.thunar .sidebar treeview:selected:backdrop,
.thunar .sidebar treeview.view row:selected,
.thunar .sidebar treeview.view row:selected:backdrop,
.thunar .sidebar row:selected,
.thunar .sidebar row:selected:backdrop {{
    background-color: {thunar_row_sel_bg};
    color: {thunar_row_sel_fg};
    border: 1px solid {thunar_row_sel_border};
    border-radius: 8px;
}}

/* Main File View (Grid, Compact & Detailed List) */
window.thunar .standard-view,
window.thunar .view,
window.thunar ExoIconView,
window.thunar ExoIconView.view,
window.thunar XfceIconView,
window.thunar XfceIconView.view,
window.thunar iconview,
window.thunar iconview.view,
window.thunar exo-icon-view,
window.thunar treeview.view,
.thunar .standard-view,
.thunar ExoIconView,
.thunar ExoIconView.view,
.thunar XfceIconView,
.thunar XfceIconView.view,
.thunar iconview,
.thunar exo-icon-view,
.thunar treeview.view {{
    background-color: {"transparent" if mode == "glass" else "@view_bg_color"};
    color: @view_fg_color;
}}

/* Cells and Rows Base */
window.thunar .view.cell,
window.thunar .standard-view .cell,
window.thunar ExoIconView .cell,
window.thunar XfceIconView .cell,
window.thunar treeview.view row {{
    border-radius: 8px;
    border: 1px solid transparent;
}}

/* Hover State */
window.thunar .standard-view:hover,
window.thunar .standard-view .cell:hover,
window.thunar .view:hover,
window.thunar .view.cell:hover,
window.thunar ExoIconView:hover,
window.thunar ExoIconView .cell:hover,
window.thunar XfceIconView:hover,
window.thunar XfceIconView .cell:hover,
window.thunar iconview:hover,
window.thunar exo-icon-view:hover,
window.thunar treeview.view:hover,
window.thunar treeview.view row:hover,
.thunar .standard-view:hover,
.thunar .standard-view .cell:hover,
.thunar ExoIconView:hover,
.thunar XfceIconView:hover,
.thunar treeview.view row:hover {{
    background-color: {thunar_row_hover_bg};
    border-color: transparent;
}}

/* Selected State - Icon View & List View (Active & Backdrop) */
.standard-view:selected,
.standard-view:selected:focus,
.standard-view:selected:backdrop,
.standard-view:backdrop:selected,
.standard-view .view:selected,
.standard-view .view:selected:focus,
.standard-view .view:selected:backdrop,
.standard-view .view:backdrop:selected,
.standard-view .cell:selected,
.standard-view .cell:selected:backdrop,
.standard-view treeview.view:selected,
.standard-view treeview.view:selected:backdrop,
ExoIconView:selected,
ExoIconView:selected:focus,
ExoIconView:selected:backdrop,
ExoIconView:backdrop:selected,
ExoIconView.view:selected,
ExoIconView.view:selected:focus,
ExoIconView.view:selected:backdrop,
ExoIconView.view:backdrop:selected,
ExoIconView .cell:selected,
ExoIconView .cell:selected:backdrop,
XfceIconView:selected,
XfceIconView:selected:focus,
XfceIconView:selected:backdrop,
XfceIconView:backdrop:selected,
XfceIconView.view:selected,
XfceIconView.view:selected:focus,
XfceIconView.view:selected:backdrop,
XfceIconView.view:backdrop:selected,
XfceIconView .cell:selected,
XfceIconView .cell:selected:backdrop,
iconview:selected,
iconview:selected:backdrop,
exo-icon-view:selected,
exo-icon-view:selected:backdrop,
window.thunar .standard-view:selected,
window.thunar .standard-view:selected:focus,
window.thunar .standard-view:selected:backdrop,
window.thunar .standard-view:backdrop:selected,
.thunar .standard-view:selected,
.thunar .standard-view:selected:focus,
.thunar .standard-view:selected:backdrop,
.thunar .standard-view:backdrop:selected,
window.thunar .standard-view .view:selected,
window.thunar .standard-view .view:selected:backdrop,
window.thunar .standard-view .cell:selected,
window.thunar .standard-view .cell:selected:backdrop,
window.thunar .standard-view treeview.view:selected,
window.thunar .standard-view treeview.view:selected:backdrop,
window.thunar .view:selected,
window.thunar .view:selected:backdrop,
window.thunar .view.cell:selected,
window.thunar .view.cell:selected:backdrop,
window.thunar ExoIconView:selected,
window.thunar ExoIconView:selected:backdrop,
window.thunar ExoIconView.view:selected,
window.thunar ExoIconView.view:selected:backdrop,
window.thunar ExoIconView .cell:selected,
window.thunar ExoIconView .cell:selected:backdrop,
window.thunar XfceIconView:selected,
window.thunar XfceIconView:selected:backdrop,
window.thunar XfceIconView.view:selected,
window.thunar XfceIconView.view:selected:backdrop,
window.thunar XfceIconView .cell:selected,
window.thunar XfceIconView .cell:selected:backdrop,
window.thunar iconview:selected,
window.thunar iconview:selected:backdrop,
window.thunar exo-icon-view:selected,
window.thunar exo-icon-view:selected:backdrop,
window.thunar treeview.view:selected,
window.thunar treeview.view:selected:backdrop,
window.thunar treeview.view row:selected,
window.thunar treeview.view row:selected:backdrop,
.thunar .standard-view .view:selected,
.thunar .standard-view .cell:selected,
.thunar .standard-view .cell:selected:backdrop,
.thunar .view.cell:selected,
.thunar .view.cell:selected:backdrop,
.thunar ExoIconView:selected,
.thunar ExoIconView:selected:backdrop,
.thunar XfceIconView:selected,
.thunar XfceIconView:selected:backdrop,
.thunar exo-icon-view:selected,
.thunar exo-icon-view:selected:backdrop,
.thunar treeview.view:selected,
.thunar treeview.view:selected:backdrop,
.thunar treeview.view row:selected,
.thunar treeview.view row:selected:backdrop {{
    background-color: {thunar_row_sel_bg};
    color: {thunar_row_sel_fg};
    border: 1px solid {thunar_row_sel_border};
    border-radius: 8px;
    outline: none;
}}

/* Text Selection Contrast Rules (Ensures filename text is 100% visible on selection) */
.standard-view text,
.standard-view .cell text,
ExoIconView text,
ExoIconView.view text,
ExoIconView .cell text,
XfceIconView text,
XfceIconView.view text,
XfceIconView .cell text,
iconview text,
exo-icon-view text,
window.thunar .standard-view text,
window.thunar .view text,
window.thunar ExoIconView text,
window.thunar XfceIconView text,
window.thunar treeview.view text,
.thunar .standard-view text,
.thunar ExoIconView text,
.thunar XfceIconView text,
.thunar treeview.view text {{
    color: @view_fg_color;
    background-color: transparent;
}}

.standard-view text:selected,
.standard-view text:selected:backdrop,
.standard-view text:backdrop:selected,
.standard-view .cell text:selected,
.standard-view .cell text:selected:backdrop,
.standard-view .view text:selected,
.standard-view .view text:selected:backdrop,
.standard-view .view.cell text:selected,
.standard-view .view.cell text:selected:backdrop,
ExoIconView text:selected,
ExoIconView text:selected:backdrop,
ExoIconView:backdrop text:selected,
ExoIconView.view text:selected,
ExoIconView.view text:selected:backdrop,
ExoIconView .cell text:selected,
ExoIconView .cell text:selected:backdrop,
XfceIconView text:selected,
XfceIconView text:selected:backdrop,
XfceIconView:backdrop text:selected,
XfceIconView.view text:selected,
XfceIconView.view text:selected:backdrop,
XfceIconView .cell text:selected,
XfceIconView .cell text:selected:backdrop,
iconview text:selected,
iconview text:selected:backdrop,
exo-icon-view text:selected,
exo-icon-view text:selected:backdrop,
window.thunar .standard-view text:selected,
window.thunar .standard-view text:selected:backdrop,
window.thunar .standard-view text:backdrop:selected,
window.thunar .standard-view .cell text:selected,
window.thunar .standard-view .cell text:selected:backdrop,
window.thunar .view text:selected,
window.thunar .view text:selected:backdrop,
window.thunar .view.cell text:selected,
window.thunar .view.cell text:selected:backdrop,
window.thunar .cell text:selected,
window.thunar .cell text:selected:backdrop,
window.thunar ExoIconView text:selected,
window.thunar ExoIconView text:selected:backdrop,
window.thunar ExoIconView.view text:selected,
window.thunar ExoIconView.view text:selected:backdrop,
window.thunar ExoIconView .cell text:selected,
window.thunar ExoIconView .cell text:selected:backdrop,
window.thunar XfceIconView text:selected,
window.thunar XfceIconView text:selected:backdrop,
window.thunar XfceIconView.view text:selected,
window.thunar XfceIconView.view text:selected:backdrop,
window.thunar iconview text:selected,
window.thunar iconview text:selected:backdrop,
window.thunar exo-icon-view text:selected,
window.thunar exo-icon-view text:selected:backdrop,
window.thunar treeview.view text:selected,
window.thunar treeview.view text:selected:backdrop,
window.thunar treeview.view row:selected text,
window.thunar treeview.view row:selected:backdrop text,
.thunar .standard-view text:selected,
.thunar .standard-view text:selected:backdrop,
.thunar ExoIconView text:selected,
.thunar ExoIconView text:selected:backdrop,
.thunar XfceIconView text:selected,
.thunar XfceIconView text:selected:backdrop,
.thunar treeview.view text:selected,
.thunar treeview.view text:selected:backdrop,
.thunar treeview.view row:selected text,
.thunar treeview.view row:selected:backdrop text {{
    color: {thunar_row_sel_fg};
    background-color: transparent;
}}

/* Fallback override for any selected widget inside Thunar */
window.thunar :selected,
window.thunar :selected:backdrop,
.thunar :selected,
.thunar :selected:backdrop {{
    color: {thunar_row_sel_fg};
}}

/* Inline File Rename Entry */
window.thunar .standard-view entry,
window.thunar ExoIconView entry,
window.thunar XfceIconView entry,
window.thunar treeview.view entry,
.thunar .standard-view entry,
.thunar ExoIconView entry,
.thunar XfceIconView entry {{
    background-color: @card_bg_color;
    color: @theme_fg_color;
    border: 1px solid {thunar_row_sel_border};
    border-radius: 6px;
    padding: 2px 6px;
}}

window.thunar .standard-view entry selection,
window.thunar ExoIconView entry selection,
window.thunar XfceIconView entry selection,
.thunar .standard-view entry selection {{
    background-color: {sel_bg};
    color: {sel_fg};
}}

/* Detailed List View Column Headers */
window.thunar treeview.view header button,
.thunar treeview.view header button {{
    background-color: @headerbar_bg_color;
    color: @text_muted;
    font-weight: 600;
    padding: 4px 8px;
    border: none;
    border-bottom: 1px solid @border_color;
}}

window.thunar treeview.view header button:hover,
.thunar treeview.view header button:hover {{
    color: @theme_fg_color;
    background-color: alpha(@theme_selected_bg_color, 0.08);
}}

/* Rubberband Selection */
window.thunar rubberband,
window.thunar .rubberband,
.thunar rubberband,
.thunar .rubberband,
window.thunar ExoIconView rubberband,
window.thunar ExoIconView .rubberband,
window.thunar XfceIconView rubberband,
window.thunar XfceIconView .rubberband {{
    background-color: {thunar_row_sel_bg};
    border: 1px solid {thunar_row_sel_border};
    border-radius: 4px;
}}

/* Transparent intermediate containers so window background shows through */
window.thunar notebook,
window.thunar notebook stack,
window.thunar paned,
window.thunar grid,
window.thunar box {{
    background-color: transparent;
}}

/* Location Bar & Pathbar */
window.thunar .location-bar,
window.thunar .path-bar,
window.thunar toolbar.location-bar,
.thunar .location-bar {{
    background-color: @headerbar_bg_color;
    border-bottom: 1px solid @border_color;
    padding: 4px 8px;
}}

window.thunar .path-bar button,
.thunar .path-bar button {{
    background-color: transparent;
    border: 1px solid transparent;
    border-radius: 8px;
    padding: 4px 10px;
    color: @headerbar_fg_color;
    font-weight: 500;
}}

window.thunar .path-bar button:hover,
.thunar .path-bar button:hover {{
    background-color: alpha(@theme_selected_bg_color, 0.08);
    border-color: @border_color;
}}

window.thunar .path-bar button:checked,
window.thunar .path-bar button:active,
.thunar .path-bar button:checked {{
    background-color: @theme_selected_bg_color;
    color: @theme_selected_fg_color;
    border-color: @theme_selected_bg_color;
}}

window.thunar .path-bar button:dir(rtl),
.thunar .path-bar button:dir(rtl) {{
    margin-left: 2px;
    margin-right: 0;
}}

window.thunar .path-bar button:dir(ltr),
.thunar .path-bar button:dir(ltr) {{
    margin-right: 2px;
    margin-left: 0;
}}

/* Toolbar */
window.thunar toolbar,
.thunar toolbar {{
    background-color: @headerbar_bg_color;
    border-bottom: 1px solid @border_color;
    padding: 3px 6px;
}}

window.thunar toolbar button,
.thunar toolbar button {{
    background-color: transparent;
    border: 1px solid transparent;
    border-radius: 8px;
    padding: 4px 8px;
    color: @headerbar_fg_color;
}}

window.thunar toolbar:dir(rtl) button,
.thunar toolbar:dir(rtl) button {{
    margin-left: 2px;
    margin-right: 0;
}}

window.thunar toolbar:dir(ltr) button,
.thunar toolbar:dir(ltr) button {{
    margin-right: 2px;
    margin-left: 0;
}}

window.thunar toolbar button:hover,
.thunar toolbar button:hover {{
    background-color: alpha(@theme_selected_bg_color, 0.08);
    border-color: @border_color;
}}

window.thunar toolbar button:checked,
window.thunar toolbar button:active,
.thunar toolbar button:checked {{
    background-color: alpha(@theme_selected_bg_color, 0.16);
    color: @headerbar_fg_color;
}}

/* Entries (Search & Path Input) */
window.thunar entry,
.thunar entry,
window.thunar .location-bar entry {{
    background-color: @view_bg_color;
    border: 1px solid @border_color;
    border-radius: 8px;
    color: @theme_fg_color;
    padding: 5px 10px;
}}

window.thunar entry:focus,
.thunar entry:focus {{
    border-color: @theme_selected_bg_color;
    outline: none;
}}

/* Paned Separator */
window.thunar paned > separator,
.thunar paned > separator,
.thunar .sidebar separator {{
    background-color: @border_color;
    min-width: 1px;
    min-height: 1px;
}}

/* Notebook Tabs (Split View & Multi-tab) */
window.thunar notebook,
.thunar notebook {{
    background-color: {"transparent" if mode == "glass" else "@theme_bg_color"};
}}

window.thunar notebook tab,
.thunar notebook tab {{
    background-color: @headerbar_bg_color;
    color: @headerbar_fg_color;
    padding: 5px 14px;
    border-radius: 8px 8px 0 0;
    border: none;
}}

window.thunar notebook tab:checked,
.thunar notebook tab:checked {{
    background-color: @view_bg_color;
    color: @theme_fg_color;
    border-bottom: 2px solid @theme_selected_bg_color;
}}

/* Statusbar */
window.thunar statusbar,
.thunar statusbar {{
    background-color: {"transparent" if mode == "glass" else "@sidebar_bg_color"};
    border-top: 1px solid @border_color;
    color: @text_muted;
    padding: 4px 12px;
    font-size: 11px;
}}

/* ========================================================================== */
/* Thunar File Manager — Menus, Context Menus, Submenus & Popovers           */
/* ========================================================================== */

/* Top-level Menu containers, Context Menus, Toolbar menus & Popovers */
window.thunar menu,
window#thunar-window menu,
.thunar menu,
window.thunar .menu,
.thunar .menu,
window.thunar .context-menu,
.thunar .context-menu,
window.thunar popover,
.thunar popover,
window.thunar popover.menu,
.thunar popover.menu,
window.thunar .location-bar menu,
.thunar .location-bar menu,
window.thunar .path-bar menu,
.thunar .path-bar menu,
window.thunar toolbar menu,
.thunar toolbar menu,
window.thunar combobox menu,
.thunar combobox menu,
window.thunar treeview.view header button menu,
.thunar treeview.view header button menu {{
    background-color: @popover_bg_color;
    color: @popover_fg_color;
    border: 1px solid @border_color;
    border-radius: 10px;
    padding: 6px;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.65);
}}

/* Submenus (Nested menus e.g. File/Edit submenus in hamburger menu) */
window.thunar menu menu,
.thunar menu menu,
window.thunar .menu .menu,
.thunar .menu .menu {{
    background-color: @popover_bg_color;
    color: @popover_fg_color;
    border: 1px solid @border_color;
    border-radius: 10px;
    padding: 6px;
    box-shadow: 0 12px 34px rgba(0, 0, 0, 0.70);
}}

/* Menu Items inside Thunar */
window.thunar menuitem,
.thunar menuitem,
window.thunar menu menuitem,
.thunar menu menuitem,
window.thunar .context-menu menuitem,
.thunar .context-menu menuitem {{
    min-height: 26px;
    padding: 5px 12px;
    margin: 1px 2px;
    border-radius: 6px;
    border: 1px solid transparent;
    color: @popover_fg_color;
    font-weight: normal;
}}

/* Menu item hover and selected state */
window.thunar menuitem:hover,
window.thunar menuitem:selected,
.thunar menuitem:hover,
.thunar menuitem:selected,
window.thunar menu menuitem:hover,
window.thunar menu menuitem:selected,
.thunar menu menuitem:hover,
.thunar menu menuitem:selected {{
    background-color: {thunar_row_sel_bg};
    color: {thunar_row_sel_fg};
    border: 1px solid {thunar_row_sel_border};
}}

/* Disabled menu items */
window.thunar menuitem:disabled,
.thunar menuitem:disabled {{
    color: @text_muted;
    background-color: transparent;
    border-color: transparent;
}}

/* Menu Separators */
window.thunar menu separator,
.thunar menu separator,
window.thunar .context-menu separator,
.thunar .context-menu separator {{
    background-color: @border_color;
    min-height: 1px;
    margin: 4px 6px;
}}

/* Shortcuts / Accelerators (e.g. Ctrl+T, Ctrl+N, Ctrl+Q) */
window.thunar menuitem accelerator,
.thunar menuitem accelerator,
window.thunar menuitem .accelerator,
.thunar menuitem .accelerator {{
    color: @text_muted;
    font-size: 11px;
}}

window.thunar menuitem:hover accelerator,
window.thunar menuitem:selected accelerator,
.thunar menuitem:hover accelerator,
.thunar menuitem:selected accelerator {{
    color: {thunar_row_sel_fg};
}}

window.thunar menuitem:dir(rtl) accelerator,
.thunar menuitem:dir(rtl) accelerator {{
    margin-right: 22px;
    margin-left: 0;
}}

window.thunar menuitem:dir(ltr) accelerator,
.thunar menuitem:dir(ltr) accelerator {{
    margin-left: 22px;
    margin-right: 0;
}}

/* Submenu Arrow Indicators */
window.thunar menu menuitem arrow,
.thunar menu menuitem arrow {{
    min-width: 14px;
    min-height: 14px;
    color: @text_muted;
}}

window.thunar menu menuitem:hover arrow,
window.thunar menu menuitem:selected arrow,
.thunar menu menuitem:hover arrow,
.thunar menu menuitem:selected arrow {{
    color: {thunar_row_sel_fg};
}}

/* Tooltips */
window.thunar tooltip,
.thunar tooltip,
window.thunar tooltip.background,
.thunar tooltip.background {{
    background-color: @popover_bg_color;
    border: 1px solid @border_color;
    border-radius: 8px;
    color: @popover_fg_color;
    padding: 5px 10px;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.50);
}}

/* Scrollbars */
window.thunar scrollbar,
.thunar scrollbar {{
    background-color: transparent;
}}

window.thunar scrollbar slider,
.thunar scrollbar slider {{
    min-width: 5px;
    min-height: 5px;
    border-radius: 8px;
    background-color: alpha(@border_color, 0.45);
}}

window.thunar scrollbar slider:hover,
.thunar scrollbar slider:hover {{
    min-width: 8px;
    min-height: 8px;
    background-color: alpha(@theme_selected_bg_color, 0.35);
}}

window.thunar scrollbar slider:hover,
.thunar scrollbar slider:hover {{
    background-color: @theme_selected_bg_color;
}}

/* Dialogs & Preferences */
window.thunar dialog,
dialog.thunar,
.thunar-dialog,
window.thunar .dialog-action-area,
window.thunar dialog.background,
window.thunar messagedialog {{
    background-color: @dialog_bg_color;
    color: @window_fg_color;
}}

window.thunar dialog notebook,
window.thunar dialog notebook stack {{
    background-color: @dialog_bg_color;
}}

window.thunar dialog notebook tab {{
    background-color: @sidebar_bg_color;
    border: 1px solid @border_color;
    border-radius: 6px 6px 0 0;
    padding: 4px 12px;
    color: @text_muted;
}}

window.thunar dialog notebook tab:checked {{
    background-color: @window_bg_color;
    border-bottom: 1px solid @window_bg_color;
    color: @window_fg_color;
    font-weight: bold;
}}

window.thunar dialog button,
.thunar-dialog button {{
    border-radius: 6px;
    border: 1px solid @border_color;
    background-color: @sidebar_bg_color;
    color: @window_fg_color;
    padding: 4px 12px;
}}

window.thunar dialog button:hover,
.thunar-dialog button:hover {{
    background-color: alpha(@theme_selected_bg_color, 0.12);
}}

window.thunar dialog button.suggested-action {{
    background-color: @accent_bg_color;
    color: @accent_fg_color;
    border-color: @accent_bg_color;
}}

window.thunar dialog button.destructive-action {{
    background-color: @destructive_color;
    color: #ffffff;
    border-color: @destructive_color;
}}
"""


def build_settings_ini(gtk_theme: str, icon_theme: str, cursor_theme: str, font_name: str, is_dark: bool) -> str:
    """Generate clean, unified settings.ini for GTK 3 and GTK 4."""
    prefer_dark_val = "1" if is_dark else "0"
    return f"""[Settings]
gtk-theme-name={gtk_theme}
gtk-icon-theme-name={icon_theme}
gtk-font-name={font_name}
gtk-cursor-theme-name={cursor_theme}
gtk-cursor-theme-size=24
gtk-application-prefer-dark-theme={prefer_dark_val}
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
"""


def generate_qt6ct_palette(mode: str, config_home: Path, dry_run: bool = False):
    """Generate deloway.conf color scheme for qt6ct / qt5ct."""
    qt6ct_dir = config_home / "qt6ct" / "colors"
    qt6ct_dir.mkdir(parents=True, exist_ok=True)
    target_conf = qt6ct_dir / "deloway.conf"

    is_dark = (mode == "dark")
    if is_dark:
        win_bg = "#000000"
        win_fg = "#ffffff"
        base_bg = "#0a0a0a"
        base_fg = "#ffffff"
        btn_bg = "#141414"
        btn_fg = "#ffffff"
        hl_bg = "#ffffff"
        hl_fg = "#000000"
        tip_bg = "#111111"
        tip_fg = "#ffffff"
        border = "#222222"
    else:
        win_bg = "#ffffff"
        win_fg = "#0f172a"
        base_bg = "#ffffff"
        base_fg = "#0f172a"
        btn_bg = "#f1f5f9"
        btn_fg = "#0f172a"
        hl_bg = "#0f172a"
        hl_fg = "#ffffff"
        tip_bg = "#ffffff"
        tip_fg = "#0f172a"
        border = "#d5dbe6"

    conf_content = f"""[ColorScheme]
# DeloWay Strict Monochrome Qt Color Scheme
# Mode: {mode}
window_bg={win_bg}
window_fg={win_fg}
base_bg={base_bg}
base_fg={base_fg}
button_bg={btn_bg}
button_fg={btn_fg}
highlight_bg={hl_bg}
highlight_fg={hl_fg}
tooltip_bg={tip_bg}
tooltip_fg={tip_fg}
border={border}
active_colors={win_fg}, {btn_bg}, {win_bg}, {base_bg}, {border}, {border}, {base_fg}, {win_fg}, {btn_fg}, {base_bg}, {win_bg}, #000000, {hl_bg}, {hl_fg}, {hl_bg}, {hl_bg}, {base_bg}, #000000, {tip_bg}, {tip_fg}, {border}
inactive_colors={win_fg}, {btn_bg}, {win_bg}, {base_bg}, {border}, {border}, {base_fg}, {win_fg}, {btn_fg}, {base_bg}, {win_bg}, #000000, {hl_bg}, {hl_fg}, {hl_bg}, {hl_bg}, {base_bg}, #000000, {tip_bg}, {tip_fg}, {border}
disabled_colors={border}, {btn_bg}, {win_bg}, {base_bg}, {border}, {border}, {border}, {win_fg}, {border}, {base_bg}, {win_bg}, #000000, {border}, {win_bg}, {border}, {border}, {base_bg}, #000000, {tip_bg}, {tip_fg}, {border}
"""
    atomic_write_if_changed(target_conf, conf_content, dry_run=dry_run)


def reload_thunar_safely():
    """Reload Thunar daemon if running, without closing active user windows."""
    try:
        # Check if thunar process is running
        proc = subprocess.run(["pgrep", "-x", "thunar"], capture_output=True, text=True)
        if proc.returncode != 0:
            return  # Not running

        # Check if any Thunar window is currently open in Hyprland
        hypr_proc = subprocess.run(["hyprctl", "clients", "-j"], capture_output=True, text=True)
        has_open_window = False
        if hypr_proc.returncode == 0:
            try:
                clients = json.loads(hypr_proc.stdout)
                for client in clients:
                    c_class = client.get("class", "").lower()
                    c_init = client.get("initialClass", "").lower()
                    if "thunar" in c_class or "thunar" in c_init:
                        has_open_window = True
                        break
            except Exception:
                pass

        if not has_open_window:
            subprocess.run(["thunar", "-q"], check=False)
            print("[deloway-theme] Reloaded Thunar daemon (no open windows).")
        else:
            print("[deloway-theme] Thunar windows are open: CSS reloaded live via GTK.")
    except Exception as e:
        print(f"[deloway-theme] Note on Thunar reload: {e}", file=sys.stderr)


def configure_thunar_defaults(dry_run: bool = False):
    """Ensure Thunar menubar is hidden permanently and toolbar hamburger menu is enabled."""
    try:
        # 1. Hide menubar permanently
        if dry_run:
            print("[dry-run] xfconf-query -c thunar -p /last-menubar-visible -t bool -s false --create")
        else:
            subprocess.run(
                ["xfconf-query", "-c", "thunar", "-p", "/last-menubar-visible", "-t", "bool", "-s", "false", "--create"],
                capture_output=True,
                check=False
            )

        # 2. Enable hamburger menu button in toolbar (menu:0 -> menu:1)
        proc = subprocess.run(
            ["xfconf-query", "-c", "thunar", "-p", "/last-toolbar-items"],
            capture_output=True,
            text=True,
            check=False
        )
        if proc.returncode == 0:
            current_items = proc.stdout.strip()
            if "menu:0" in current_items:
                new_items = current_items.replace("menu:0", "menu:1", 1)
                if dry_run:
                    print(f"[dry-run] xfconf-query -c thunar -p /last-toolbar-items -s '{new_items}'")
                else:
                    subprocess.run(
                        ["xfconf-query", "-c", "thunar", "-p", "/last-toolbar-items", "-s", new_items],
                        capture_output=True,
                        check=False
                    )
                    print("[deloway-theme] Enabled Thunar toolbar hamburger menu.")
            elif "menu:1" not in current_items:
                new_items = f"menu:1,{current_items}"
                if dry_run:
                    print(f"[dry-run] xfconf-query -c thunar -p /last-toolbar-items -s '{new_items}'")
                else:
                    subprocess.run(
                        ["xfconf-query", "-c", "thunar", "-p", "/last-toolbar-items", "-s", new_items],
                        capture_output=True,
                        check=False
                    )
                    print("[deloway-theme] Prepended Thunar toolbar hamburger menu.")
    except Exception as e:
        print(f"[deloway-theme] Note configuring Thunar defaults: {e}", file=sys.stderr)


def sync_default_file_manager(dry_run: bool = False):
    """Ensure Thunar is configured as the default file manager and handles org.freedesktop.FileManager1."""
    # 1. xdg-mime defaults
    for mime in ("inode/directory", "x-scheme-handler/trash"):
        if dry_run:
            print(f"[dry-run] xdg-mime default thunar.desktop {mime}")
        else:
            try:
                subprocess.run(["xdg-mime", "default", "thunar.desktop", mime], capture_output=True, check=False)
            except Exception:
                pass

    # 2. D-Bus activation override
    dbus_service_dir = Path.home() / ".local" / "share" / "dbus-1" / "services"
    dbus_service_file = dbus_service_dir / "org.freedesktop.FileManager1.service"
    dbus_service_content = (
        "[D-BUS Service]\n"
        "Name=org.freedesktop.FileManager1\n"
        "Exec=/usr/bin/Thunar --gapplication-service\n"
        "SystemdService=thunar.service\n"
    )
    if not dry_run:
        dbus_service_dir.mkdir(parents=True, exist_ok=True)
    atomic_write_if_changed(dbus_service_file, dbus_service_content, dry_run=dry_run)

    # 3. Systemd user service override for plasma-dolphin.service (which D-Bus delegates to on Arch)
    systemd_user_dir = Path.home() / ".config" / "systemd" / "user"
    dolphin_override = systemd_user_dir / "plasma-dolphin.service"
    dolphin_override_content = (
        "[Unit]\n"
        "Description=Thunar file manager (FileManager1 implementation)\n\n"
        "[Service]\n"
        "ExecStart=\n"
        "ExecStart=/usr/bin/Thunar --gapplication-service\n"
        "BusName=org.freedesktop.FileManager1\n"
    )
    if not dry_run:
        systemd_user_dir.mkdir(parents=True, exist_ok=True)
    changed = atomic_write_if_changed(dolphin_override, dolphin_override_content, dry_run=dry_run)
    if changed and not dry_run:
        try:
            subprocess.run(["systemctl", "--user", "daemon-reload"], capture_output=True, check=False)
        except Exception:
            pass


def get_font_name_with_scale(scale: float, base_font_descriptor: str) -> str:
    """Compute font string reflecting scale factor (0.85, 1.0, 1.15)."""
    base_size = 11
    calc_size = max(8, min(20, round(base_size * scale)))

    if "@opsz" in base_font_descriptor:
        # Match 'Family Style Size @opsz=Size,wght=Weight'
        m = re.match(r'^(.*?)\s+\d+\s+(@.*)$', base_font_descriptor)
        if m:
            family_style = m.group(1)
            # update opsz if present
            extra = re.sub(r'opsz=\d+', f'opsz={calc_size}', m.group(2))
            return f"{family_style} {calc_size} {extra}"

    # Simple fallback: replace or append size
    m = re.match(r'^(.*?)\s+\d+$', base_font_descriptor)
    if m:
        return f"{m.group(1)} {calc_size}"

    return f"{base_font_descriptor} {calc_size}"


def sync_system_language(ui_lang: str, dry_run: bool = False):
    """Sync session language environment (Hyprland, D-Bus, systemd) with DeloWay UI language."""
    # Same value as deloway-locale-apply.py (keeps an English fallback for untranslated strings)
    lang_val = "ar:en" if ui_lang == "ar" else "en_US:en"
    if dry_run:
        print(f"[deloway-theme] [DRY RUN] Would set LANGUAGE={lang_val}")
        return

    # 1. Update Hyprland environment keyword for all future dispatched execs
    try:
        subprocess.run(["hyprctl", "keyword", "env", f"LANGUAGE,{lang_val}"], check=False, capture_output=True)
    except Exception as e:
        print(f"[deloway-theme] Note setting Hyprland env: {e}", file=sys.stderr)

    # 2. Update D-Bus & systemd user session activation environment
    try:
        subprocess.run(["dbus-update-activation-environment", "--systemd", f"LANGUAGE={lang_val}"], check=False, capture_output=True)
    except Exception as e:
        print(f"[deloway-theme] Note setting dbus activation env: {e}", file=sys.stderr)

    # 3. Write persistent environment.d config for user session
    try:
        env_d = Path.home() / ".config" / "environment.d"
        env_d.mkdir(parents=True, exist_ok=True)
        conf_file = env_d / "10-deloway-lang.conf"
        content = f"# Generated by DeloWay Theme & System Engine\nLANGUAGE={lang_val}\n"
        if not conf_file.exists() or conf_file.read_text(encoding="utf-8") != content:
            conf_file.write_text(content, encoding="utf-8")
    except Exception as e:
        print(f"[deloway-theme] Note writing environment.d: {e}", file=sys.stderr)


# =============================================================================
# DeloWay unified toolkit theming (live dark/light switching)
# =============================================================================
#  GTK4 / libadwaita : ONE ~/.config/gtk-4.0/gtk.css holding BOTH palettes; dark lives
#                      under @media (prefers-color-scheme: dark), so running apps flip
#                      the instant the portal announces the new colour scheme.
#  GTK3              : two real themes (DeloWay-Dark / DeloWay-Light) = adw-gtk3 + our
#                      overrides. Switching gsettings gtk-theme reloads running apps.
#  Qt5 / Qt6         : QT_QPA_PLATFORMTHEME=gtk3 → Qt takes palette + fonts from the
#                      active DeloWay GTK theme (Qt6 follows changes live).
#  Fonts             : gsettings (interface/document/monospace) + a managed fontconfig
#                      file (rendering quality, Cairo for Arabic text).
# Strict monochrome: every "accent" slot is the neutral high-contrast colour.

DELOWAY_THEME_NAMES = {"dark": "DeloWay-Dark", "light": "DeloWay-Light", "glass": "DeloWay-Glass"}

PALETTES = {
    "glass": {
        "window_bg": "rgba(0, 0, 0, 0.85)", "window_fg": "#ffffff",
        "view_bg": "rgba(0, 0, 0, 0.85)", "view_fg": "#ffffff",
        "headerbar_bg": "rgba(10, 10, 10, 0.75)", "headerbar_fg": "#ffffff", "headerbar_border": "rgba(255, 255, 255, 0.12)",
        "sidebar_bg": "rgba(10, 10, 10, 0.65)", "sidebar_fg": "#ffffff", "sidebar_border": "rgba(255, 255, 255, 0.10)",
        "card_bg": "rgba(20, 20, 20, 0.65)", "card_fg": "#ffffff",
        "dialog_bg": "#141414", "popover_bg": "#141414",
        "border": "rgba(255, 255, 255, 0.12)", "shade": "rgba(0, 0, 0, 0.36)",
        "accent_bg": "#ffffff", "accent_fg": "#000000", "accent": "#ffffff",
        "destructive": "#ef4444", "warning": "#f59e0b", "success": "#10b981",
    },
    "dark": {
        "window_bg": "#000000", "window_fg": "#ffffff",
        "view_bg": "#000000", "view_fg": "#ffffff",
        "headerbar_bg": "#0a0a0a", "headerbar_fg": "#ffffff", "headerbar_border": "#222222",
        "sidebar_bg": "#0a0a0a", "sidebar_fg": "#ffffff", "sidebar_border": "#1a1a1a",
        "card_bg": "#111111", "card_fg": "#ffffff",
        "dialog_bg": "#0a0a0a", "popover_bg": "#111111",
        "border": "#222222", "shade": "rgba(0, 0, 0, 0.36)",
        "accent_bg": "#ffffff", "accent_fg": "#000000", "accent": "#ffffff",
        "destructive": "#ef4444", "warning": "#f59e0b", "success": "#10b981",
    },
    "light": {
        "window_bg": "#ffffff", "window_fg": "#0f172a",
        "view_bg": "#ffffff", "view_fg": "#0f172a",
        "headerbar_bg": "#f8fafc", "headerbar_fg": "#0f172a", "headerbar_border": "#e2e8f0",
        "sidebar_bg": "#f8fafc", "sidebar_fg": "#0f172a", "sidebar_border": "#e2e8f0",
        "card_bg": "#ffffff", "card_fg": "#0f172a",
        "dialog_bg": "#ffffff", "popover_bg": "#ffffff",
        "border": "#d5dbe6", "shade": "rgba(0, 0, 0, 0.07)",
        "accent_bg": "#0f172a", "accent_fg": "#ffffff", "accent": "#0f172a",
        "destructive": "#dc2626", "warning": "#d97706", "success": "#059669",
    },
}


def radius_tokens(element_radius: float) -> dict:
    """Mirror Theme.qml: 8px setting = 1.0; 4px ≈ sharp; 14px = rounded."""
    f = max(0.5, min(1.6, 1 + (element_radius - 8) / 12))
    return {"small": round(6 * f), "medium": round(10 * f), "large": round(14 * f)}


def _adw_vars(pal: dict) -> str:
    v = {
        "window-bg-color": pal["window_bg"], "window-fg-color": pal["window_fg"],
        "view-bg-color": pal["view_bg"], "view-fg-color": pal["view_fg"],
        "headerbar-bg-color": pal["headerbar_bg"], "headerbar-fg-color": pal["headerbar_fg"],
        "headerbar-border-color": pal["headerbar_border"], "headerbar-backdrop-color": pal["window_bg"],
        "headerbar-shade-color": pal["shade"],
        "sidebar-bg-color": pal["sidebar_bg"], "sidebar-fg-color": pal["sidebar_fg"],
        "sidebar-backdrop-color": pal["sidebar_bg"], "sidebar-border-color": pal["sidebar_border"],
        "sidebar-shade-color": pal["shade"],
        "secondary-sidebar-bg-color": pal["sidebar_bg"], "secondary-sidebar-fg-color": pal["sidebar_fg"],
        "secondary-sidebar-backdrop-color": pal["sidebar_bg"], "secondary-sidebar-border-color": pal["sidebar_border"],
        "card-bg-color": pal["card_bg"], "card-fg-color": pal["card_fg"], "card-shade-color": pal["shade"],
        "dialog-bg-color": pal["dialog_bg"], "dialog-fg-color": pal["window_fg"],
        "popover-bg-color": pal["popover_bg"], "popover-fg-color": pal["window_fg"], "popover-shade-color": pal["shade"],
        "thumbnail-bg-color": pal["card_bg"], "thumbnail-fg-color": pal["window_fg"],
        "shade-color": pal["shade"], "border-color": pal["border"],
        "accent-bg-color": pal["accent_bg"], "accent-fg-color": pal["accent_fg"], "accent-color": pal["accent"],
        "destructive-bg-color": pal["destructive"], "destructive-fg-color": "#ffffff", "destructive-color": pal["destructive"],
        "error-bg-color": pal["destructive"], "error-fg-color": "#ffffff", "error-color": pal["destructive"],
        "warning-bg-color": pal["warning"], "warning-fg-color": "rgba(0, 0, 0, 0.8)", "warning-color": pal["warning"],
        "success-bg-color": pal["success"], "success-fg-color": "#ffffff", "success-color": pal["success"],
    }
    return "\n".join(f"    --{k}: {val};" for k, val in v.items())


def build_gtk4_modular_theme(theme_name: str) -> str:
    """Build modular GTK4 stylesheet for a specific theme (dark, glass, or light).
    Defines both standard @define-color tokens and CSS custom properties (--var)."""
    pal = PALETTES.get(theme_name, PALETTES["dark"])

    defines = [
        f"@define-color window_bg_color {pal['window_bg']};",
        f"@define-color window_fg_color {pal['window_fg']};",
        f"@define-color view_bg_color {pal['view_bg']};",
        f"@define-color view_fg_color {pal['view_fg']};",
        f"@define-color headerbar_bg_color {pal['headerbar_bg']};",
        f"@define-color headerbar_fg_color {pal['headerbar_fg']};",
        f"@define-color headerbar_border_color {pal['headerbar_border']};",
        f"@define-color headerbar_backdrop_color {pal['window_bg']};",
        f"@define-color headerbar_shade_color {pal['shade']};",
        f"@define-color sidebar_bg_color {pal['sidebar_bg']};",
        f"@define-color sidebar_fg_color {pal['sidebar_fg']};",
        f"@define-color sidebar_border_color {pal['sidebar_border']};",
        f"@define-color sidebar_shade_color {pal['shade']};",
        f"@define-color secondary_sidebar_bg_color {pal['sidebar_bg']};",
        f"@define-color secondary_sidebar_fg_color {pal['sidebar_fg']};",
        f"@define-color secondary_sidebar_border_color {pal['sidebar_border']};",
        f"@define-color card_bg_color {pal['card_bg']};",
        f"@define-color card_fg_color {pal['card_fg']};",
        f"@define-color dialog_bg_color {pal['dialog_bg']};",
        f"@define-color popover_bg_color {pal['popover_bg']};",
        f"@define-color popover_fg_color {pal['window_fg']};",
        f"@define-color border_color {pal['border']};",
        f"@define-color accent_bg_color {pal['accent_bg']};",
        f"@define-color accent_fg_color {pal['accent_fg']};",
        f"@define-color accent_color {pal['accent']};",
        f"@define-color destructive_bg_color {pal['destructive']};",
        f"@define-color destructive_fg_color #ffffff;",
        f"@define-color destructive_color {pal['destructive']};",
        f"@define-color error_bg_color {pal['destructive']};",
        f"@define-color error_fg_color #ffffff;",
        f"@define-color error_color {pal['destructive']};",
        f"@define-color warning_bg_color {pal['warning']};",
        f"@define-color warning_fg_color {'#000000' if theme_name == 'light' else 'rgba(0, 0, 0, 0.8)'};",
        f"@define-color warning_color {pal['warning']};",
        f"@define-color success_bg_color {pal['success']};",
        f"@define-color success_fg_color #ffffff;",
        f"@define-color success_color {pal['success']};",
    ]

    root_vars = _adw_vars(pal)

    return f"""/* ========================================================================== */
/* DeloWay GTK4 Theme Palette: {theme_name.upper():<10}                           */
/* Strict Monochrome — Generated by deloway-theme-apply.py                      */
/* ========================================================================== */

/* --- Standard GTK @define-color definitions --- */
{chr(10).join(defines)}

/* --- Libadwaita CSS custom properties --- */
:root {{
{root_vars}
}}
"""


def build_nautilus_css(radius: dict) -> str:
    """Build dedicated, comprehensive Nautilus (GNOME Files) stylesheet.
    Customizes window, sidebar, pathbar breadcrumbs, navigation, file views,
    floating status pill, search bar, popovers, and scrollbars matching DeloWay."""
    r_small = radius["small"]
    r_med = radius["medium"]

    return f"""/* ========================================================================== */
/* DeloWay Nautilus (GNOME Files) Deep Theming                                */
/* Scoped to Nautilus to ensure 100% monochrome consistency & GTK safety.     */
/* ========================================================================== */

/* --- Main Window & Container --- */
window.nautilus-window,
.nautilus-window {{
    background-color: @window_bg_color;
    color: @window_fg_color;
}}

/* Transparent intermediate containers so window / glass background shows through */
.nautilus-window notebook,
.nautilus-window notebook stack,
.nautilus-window paned,
.nautilus-window .view,
.nautilus-window gridview,
.nautilus-window columnview,
.nautilus-window listview {{
    background-color: transparent;
    color: @view_fg_color;
}}

/* Paned Separator */
.nautilus-window paned > separator,
.nautilus-window separator {{
    background-color: @sidebar_border_color;
    min-width: 1px;
    min-height: 1px;
}}

/* --- Sidebar Styling --- */
.nautilus-window .navigation-sidebar,
.nautilus-window scrolledwindow.sidebar,
.nautilus-window .places-view {{
    background-color: @sidebar_bg_color;
    color: @sidebar_fg_color;
}}

/* Directional sidebar borders (RTL and LTR) */
.nautilus-window:dir(ltr) .navigation-sidebar {{
    border-right: 1px solid @sidebar_border_color;
    border-left: none;
}}
.nautilus-window:dir(rtl) .navigation-sidebar {{
    border-left: 1px solid @sidebar_border_color;
    border-right: none;
}}

/* Sidebar rows */
.nautilus-window .navigation-sidebar > row,
.nautilus-window .navigation-sidebar listview row,
.nautilus-window .places-view row,
.nautilus-window .navigation-sidebar row {{
    min-height: 34px;
    margin: 2px 6px;
    padding: 4px 10px;
    border-radius: {r_small}px;
    border: 1px solid transparent;
    transition: background-color 150ms ease, color 150ms ease;
}}

.nautilus-window .navigation-sidebar > row:hover,
.nautilus-window .navigation-sidebar listview row:hover,
.nautilus-window .places-view row:hover,
.nautilus-window .navigation-sidebar row:hover {{
    background-color: alpha(currentColor, 0.08);
    border-color: transparent;
}}

.nautilus-window .navigation-sidebar > row:selected,
.nautilus-window .navigation-sidebar listview row:selected,
.nautilus-window .places-view row:selected,
.nautilus-window .navigation-sidebar row:selected {{
    background-color: alpha(currentColor, 0.16);
    color: @window_fg_color;
    border: 1px solid alpha(currentColor, 0.30);
    border-radius: {r_small}px;
    font-weight: 600;
}}

/* --- Headerbar & Navigation Buttons --- */
.nautilus-window headerbar {{
    background-color: @headerbar_bg_color;
    border-bottom: 1px solid @headerbar_border_color;
    color: @headerbar_fg_color;
    min-height: 48px;
    padding: 0 8px;
}}

.nautilus-window headerbar button {{
    border-radius: {r_small}px;
    min-width: 32px;
    min-height: 32px;
    padding: 4px 8px;
    color: @headerbar_fg_color;
    background-color: transparent;
    border: 1px solid transparent;
    transition: background-color 150ms ease, border-color 150ms ease;
}}

.nautilus-window headerbar button:hover {{
    background-color: alpha(currentColor, 0.08);
    border-color: alpha(currentColor, 0.12);
}}

.nautilus-window headerbar button:checked,
.nautilus-window headerbar button:active {{
    background-color: alpha(currentColor, 0.16);
    border-color: alpha(currentColor, 0.25);
    color: @headerbar_fg_color;
}}

/* --- Path Bar / Breadcrumbs --- */
.nautilus-window .path-bar,
.nautilus-window nautilus-path-bar,
.nautilus-window .path-buttons-box {{
    margin: 0 4px;
}}

.nautilus-window .path-bar button,
.nautilus-window button.path-button,
.nautilus-window .path-buttons-box button {{
    border-radius: {r_small}px;
    padding: 4px 10px;
    font-weight: 500;
    color: @headerbar_fg_color;
    background-color: transparent;
    border: 1px solid transparent;
    margin: 0 1px;
    transition: background-color 150ms ease;
}}

.nautilus-window .path-bar button:hover,
.nautilus-window button.path-button:hover,
.nautilus-window .path-buttons-box button:hover {{
    background-color: alpha(currentColor, 0.08);
    border-color: alpha(currentColor, 0.12);
}}

.nautilus-window .path-bar button:checked,
.nautilus-window button.path-button:checked,
.nautilus-window button.path-button.current-dir,
.nautilus-window .path-buttons-box button:checked {{
    background-color: alpha(currentColor, 0.16);
    color: @headerbar_fg_color;
    font-weight: 700;
    border-color: alpha(currentColor, 0.25);
}}

.nautilus-window .location-bar entry,
.nautilus-window .path-bar entry {{
    background-color: @card_bg_color;
    border: 1px solid @border_color;
    border-radius: {r_small}px;
    color: @window_fg_color;
    padding: 5px 10px;
}}

/* --- Search Bar --- */
.nautilus-window searchbar,
.nautilus-window searchbar > revealer > box {{
    background-color: @headerbar_bg_color;
    border-bottom: 1px solid @headerbar_border_color;
    padding: 6px 10px;
}}

.nautilus-window searchbar entry {{
    background-color: @card_bg_color;
    border: 1px solid @border_color;
    border-radius: {r_small}px;
    color: @window_fg_color;
    padding: 6px 12px;
}}

.nautilus-window searchbar entry:focus-within {{
    border-color: @accent_bg_color;
    outline: none;
}}

/* --- File Views (Grid View / Card Style & Column/List View) --- */
.nautilus-window gridview > child,
.nautilus-window gridview item,
.nautilus-window .view.grid-view item {{
    border-radius: {r_small}px;
    padding: 8px;
    margin: 4px;
    border: 1px solid transparent;
    transition: background-color 150ms ease, border-color 150ms ease;
}}

.nautilus-window gridview > child:hover,
.nautilus-window gridview item:hover,
.nautilus-window .view.grid-view item:hover {{
    background-color: alpha(currentColor, 0.08);
    border-color: transparent;
}}

.nautilus-window gridview > child:selected,
.nautilus-window gridview > child:selected:focus,
.nautilus-window gridview item:selected,
.nautilus-window .view.grid-view item:selected {{
    background-color: alpha(currentColor, 0.18);
    border: 1px solid alpha(currentColor, 0.35);
    border-radius: {r_small}px;
    color: @view_fg_color;
    outline: none;
}}

.nautilus-window columnview row,
.nautilus-window listview row {{
    min-height: 36px;
    padding: 4px 8px;
    margin: 1px 4px;
    border-radius: {r_small}px;
    border: 1px solid transparent;
    transition: background-color 150ms ease, border-color 150ms ease;
}}

.nautilus-window columnview row:hover,
.nautilus-window listview row:hover {{
    background-color: alpha(currentColor, 0.08);
    border-color: transparent;
}}

.nautilus-window columnview row:selected,
.nautilus-window columnview row:selected:focus,
.nautilus-window listview row:selected {{
    background-color: alpha(currentColor, 0.18);
    border: 1px solid alpha(currentColor, 0.35);
    border-radius: {r_small}px;
    color: @view_fg_color;
    outline: none;
}}

.nautilus-window columnview header button,
.nautilus-window columnview header {{
    background-color: @headerbar_bg_color;
    border-bottom: 1px solid @border_color;
    color: alpha(currentColor, 0.70);
    font-weight: 600;
    padding: 6px 10px;
    border-top: none;
    border-left: none;
    border-right: none;
}}

.nautilus-window columnview header button:hover {{
    color: @view_fg_color;
    background-color: alpha(currentColor, 0.08);
}}

/* Rubberband selection */
.nautilus-window rubberband,
.nautilus-window .rubberband {{
    background-color: alpha(currentColor, 0.12);
    border: 1px solid alpha(currentColor, 0.40);
    border-radius: 4px;
}}

/* --- Floating Status Bar (Pill) --- */
.nautilus-window .floating-bar,
.nautilus-window nautilus-floating-bar,
.nautilus-floating-bar {{
    background-color: @popover_bg_color;
    color: @popover_fg_color;
    border: 1px solid @border_color;
    border-radius: 9999px;
    padding: 5px 14px;
    margin: 12px;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.40);
    font-size: 12px;
}}

/* --- Popovers & Context Menus --- */
.nautilus-window popover > contents,
.nautilus-window popover.menu > contents {{
    background-color: @popover_bg_color;
    color: @popover_fg_color;
    border: 1px solid @border_color;
    border-radius: {r_med}px;
    padding: 6px;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.60);
}}

.nautilus-window popover modelbutton,
.nautilus-window popover listview row,
.nautilus-window popover button {{
    min-height: 30px;
    padding: 5px 12px;
    border-radius: {r_small}px;
    color: @popover_fg_color;
    border: 1px solid transparent;
}}

.nautilus-window popover modelbutton:hover,
.nautilus-window popover modelbutton:selected,
.nautilus-window popover listview row:hover,
.nautilus-window popover listview row:selected,
.nautilus-window popover button:hover {{
    background-color: alpha(currentColor, 0.12);
    color: @popover_fg_color;
}}

.nautilus-window popover separator {{
    background-color: @border_color;
    min-height: 1px;
    margin: 4px 6px;
}}

/* --- Scrollbars --- */
.nautilus-window scrollbar {{
    background-color: transparent;
}}

.nautilus-window scrollbar slider {{
    min-width: 6px;
    min-height: 6px;
    border-radius: 6px;
    background-color: alpha(currentColor, 0.25);
    transition: all 150ms ease;
}}

.nautilus-window scrollbar slider:hover {{
    min-width: 9px;
    min-height: 9px;
    background-color: alpha(currentColor, 0.50);
}}

/* --- Progress / Operations --- */
.nautilus-window progressbar trough {{
    background-color: alpha(currentColor, 0.12);
    border-radius: 4px;
}}

.nautilus-window progressbar progress {{
    background-color: @accent_bg_color;
    border-radius: 4px;
}}
"""


def write_gtk4_modular_themes(gtk4_dir: Path, radius: dict, dry_run: bool = False):
    """Write modular GTK4 stylesheets (deloway-dark.css, deloway-glass.css, deloway-light.css, nautilus.css)
    into ~/.config/gtk-4.0/themes/."""
    themes_dir = gtk4_dir / "themes"
    if not dry_run:
        themes_dir.mkdir(parents=True, exist_ok=True)

    for mode in ("dark", "glass", "light"):
        content = build_gtk4_modular_theme(mode)
        atomic_write_if_changed(themes_dir / f"deloway-{mode}.css", content, dry_run=dry_run)

    nautilus_content = build_nautilus_css(radius)
    atomic_write_if_changed(themes_dir / "nautilus.css", nautilus_content, dry_run=dry_run)


def build_gtk4_css(radius: dict, theme_name: str = "dark") -> str:
    """DeloWay GTK4 / libadwaita root stylesheet.
    Imports active modular theme palette and dedicated Nautilus styling."""
    r = radius
    target_theme = theme_name if theme_name in ("dark", "glass", "light") else "dark"

    return f"""/* ========================================================================== */
/* DeloWay GTK4 / Libadwaita Stylesheet — Dynamic Theme Loader                 */
/* Mode: {target_theme:<10} Identity: Strict Monochrome (OLED / Light / Glass) */
/* ========================================================================== */

@import url("themes/deloway-{target_theme}.css");
@import url("themes/nautilus.css");

/* --- Global Shape Language (Settings → Appearance → Shell Corner Radius) --- */
button, entry, spinbutton, dropdown > button, combobox > box > button,
switch, .linked > button, searchbar entry {{ border-radius: {r["small"]}px; }}
switch > slider {{ border-radius: {max(r["small"] - 2, 2)}px; }}
.card, list.boxed-list, .boxed-list, row.expander, preferencesgroup .boxed-list,
listview.card, .navigation-sidebar > row, popover > contents,
popover.menu > contents, toast, .osd {{ border-radius: {r["medium"]}px; }}
window.dialog, dialog-host > dialog > sheet, .dialog-sheet, window.messagedialog,
floating-sheet > sheet, bottom-sheet > sheet {{ border-radius: {r["large"]}px; }}

/* Global Selection & Focus */
selection {{ background-color: alpha(currentColor, 0.18); }}
*:focus-visible {{ outline-color: alpha(currentColor, 0.55); }}
"""


def build_gtk3_theme(mode: str, radius: dict, base_url: str) -> str:
    """GTK3 theme CSS: adw-gtk3 (or GTK's own Adwaita) + DeloWay monochrome overrides + shape tokens."""
    r = radius
    return (f'@import url("{base_url}");\n\n'
            + build_gtk_css(mode)
            + f"""
/* --- Shape language (Settings → Appearance → Shell Corner Radius) --- */
button, entry, spinbutton, combobox button, .linked > button {{ border-radius: {r["small"]}px; }}
.linked > button:not(:first-child):not(:last-child) {{ border-radius: 0; }}
popover, popover.background, menu, .menu, .context-menu, tooltip.background {{ border-radius: {r["medium"]}px; }}
window.csd.dialog, messagedialog.csd {{ border-radius: {r["large"]}px; }}
""")


def write_gtk3_themes(radius: dict, dry_run: bool = False):
    """Install ~/.local/share/themes/DeloWay-{Dark,Light,Glass} (index.theme + gtk-3.0)."""
    themes_root = Path.home() / ".local" / "share" / "themes"
    for mode, name in DELOWAY_THEME_NAMES.items():
        # Base: adw-gtk3 (adw-gtk-theme) when installed, else the Adwaita GTK3 compiles in.
        # There is no /usr/share/themes/Adwaita-dark/gtk-3.0/gtk.css file to import — that
        # path made GTK3 apps render the DeloWay overrides with no base theme at all.
        adw = Path("/usr/share/themes") / ("adw-gtk3-dark" if mode in ("dark", "glass") else "adw-gtk3") / "gtk-3.0" / "gtk.css"
        if adw.is_file():
            base_url, base_name = f"file://{adw}", adw.parent.parent.name
        else:
            base_url = ("resource:///org/gtk/libgtk/theme/Adwaita/"
                        + ("gtk-contained-dark.css" if mode in ("dark", "glass") else "gtk-contained.css"))
            base_name = "Adwaita"
        tdir = themes_root / name
        index = (f"[Desktop Entry]\nType=X-GNOME-Metatheme\nName={name}\n"
                 f"Comment=DeloWay strict monochrome ({mode}) on top of {base_name}\n"
                 f"Encoding=UTF-8\n\n[X-GNOME-Metatheme]\nGtkTheme={name}\n")
        if not dry_run:
            (tdir / "gtk-3.0").mkdir(parents=True, exist_ok=True)
        atomic_write_if_changed(tdir / "index.theme", index, dry_run=dry_run)
        atomic_write_if_changed(tdir / "gtk-3.0" / "gtk.css", build_gtk3_theme(mode, radius, base_url), dry_run=dry_run)


GTK3_USER_CSS = """/* DeloWay: GTK3 styling lives in the DeloWay-Dark / DeloWay-Light themes
   (~/.local/share/themes). This user stylesheet is intentionally mode-agnostic:
   GTK3 loads it only once at startup, so mode-specific colours here would stick
   after a live dark/light switch. */
"""


# Terminal fonts: DeloWay's kitty profile uses this family (config/kitty/kitty.conf).
TERMINAL_FONT = "JetBrainsMono Nerd Font"
# Monospace face with Arabic glyphs (ttf-dejavu): what a terminal falls back to for Arabic.
TERMINAL_ARABIC_FALLBACK = "DejaVu Sans Mono"


def write_fontconfig(font_family: str = "Cairo", dry_run: bool = False):
    """Managed fontconfig.

    - The UI typeface (Cairo by default) is the preferred font of the generic UI families
      (sans-serif, system-ui, serif) in every language, so GTK, Qt, browsers, Electron
      apps and the compositor all render it.
    - Terminals are exempt: monospace requests never resolve to it. A terminal font
      without Arabic glyphs falls back to a monospace face that has them, instead of
      fontconfig's default sans-serif fallback (which would be the UI typeface).
    """
    ui = font_family.replace("&", "&amp;").replace("<", "&lt;")
    extra_prefer = ""
    if font_family == "SF Pro":
        extra_prefer = "<family>SF Arabic</family>"
    elif font_family == "SF Arabic":
        extra_prefer = "<family>SF Pro</family>"

    conf = f"""<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<!-- Managed by DeloWay (deloway-theme-apply.py). -->
<fontconfig>
  <!-- Legibility: grayscale AA (no colour fringes on OLED), slight hinting -->
  <match target="font">
    <edit name="antialias" mode="assign"><bool>true</bool></edit>
    <edit name="hinting" mode="assign"><bool>true</bool></edit>
    <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
    <edit name="rgba" mode="assign"><const>none</const></edit>
    <edit name="lcdfilter" mode="assign"><const>lcddefault</const></edit>
    <edit name="embeddedbitmap" mode="assign"><bool>false</bool></edit>
  </match>

  <!-- The UI typeface for every generic UI family, in every language -->
  <alias binding="strong"><family>sans-serif</family><prefer><family>{ui}</family>{extra_prefer}</prefer></alias>
  <alias binding="strong"><family>system-ui</family><prefer><family>{ui}</family>{extra_prefer}</prefer></alias>
  <alias binding="strong"><family>serif</family><prefer><family>{ui}</family>{extra_prefer}</prefer></alias>

  <!-- Pair Apple's SF Pro and SF Arabic bidirectionally for seamless multilingual typography -->
  <match target="pattern">
    <test name="family"><string>SF Pro</string></test>
    <edit name="family" mode="append" binding="strong"><string>SF Arabic</string></edit>
  </match>
  <match target="pattern">
    <test name="family"><string>SF Arabic</string></test>
    <edit name="family" mode="append" binding="strong"><string>SF Pro</string></edit>
  </match>

  <!-- Terminals keep their monospace font. Characters it lacks (Arabic) come from a
       monospace face placed right after it, ahead of the sans-serif fallback. -->
  <match target="pattern">
    <test name="family"><string>monospace</string></test>
    <edit name="family" mode="append" binding="strong"><string>{TERMINAL_ARABIC_FALLBACK}</string></edit>
  </match>
  <match target="pattern">
    <test name="family"><string>{TERMINAL_FONT}</string></test>
    <edit name="family" mode="append" binding="strong"><string>{TERMINAL_ARABIC_FALLBACK}</string></edit>
  </match>
</fontconfig>
"""
    target = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "fontconfig" / "conf.d" / "60-deloway.conf"
    if not dry_run:
        target.parent.mkdir(parents=True, exist_ok=True)
    return atomic_write_if_changed(target, conf, dry_run=dry_run)


QT_ENV = {"QT_QPA_PLATFORMTHEME": "gtk3"}


def qt_environment() -> dict:
    """The Qt variables for the session: the gtk3 platform theme, and the Breeze style
    when installed — KDE apps started on their own (Ark, Okular…) ignore kdeglobals'
    widgetStyle and fell back to the flat Fusion style."""
    env = dict(QT_ENV)
    if breeze_style_installed():
        env["QT_STYLE_OVERRIDE"] = "Breeze"
    return env


# KDE apps (Dolphin, Kate, Okular…) take colours, icons and fonts from ~/.config/kdeglobals,
# not from the Qt platform theme: without it they fell back to Breeze — blue selection,
# blue folders — whatever GTK and qt6ct said. Same monochrome palette as the GTK themes.
KDE_MANAGED_HEADER = "# Colours, icons and fonts below are managed by DeloWay (scripts/deloway-theme-apply.py)"


def _kde_rgb(hex_color: str) -> str:
    h = hex_color.lstrip("#")
    return ",".join(str(int(h[i:i + 2], 16)) for i in (0, 2, 4))


def breeze_style_installed() -> bool:
    return any(Path(d, "styles", "breeze6.so").exists()
               for d in ("/usr/lib/qt6/plugins", "/usr/lib64/qt6/plugins"))


def build_kdeglobals_groups(mode: str, font_family: str, font_scale: float, icon_theme: str) -> dict:
    pal = PALETTES["dark" if mode == "dark" else "light"]
    dark = mode == "dark"
    muted = "#8a8a8a" if dark else "#64748b"
    alt = "#0a0a0a" if dark else "#f8fafc"
    button = "#141414" if dark else "#f1f5f9"
    tooltip = "#111111" if dark else "#ffffff"
    # Selection: the identity's active colour (white on black / slate on white), as the GTK
    # themes use it. Breeze fills progress bars, sliders and checked boxes with it: the
    # dark grey used before (#2e2e2e) left a copy's progress nearly invisible.
    # In an inactive window the places panel keeps the selected row filled but draws its
    # name in the normal text colour (KFilePlacesView), so white there was white on white:
    # inactive windows get their own mid-grey selection ([Colors:Selection][Inactive]),
    # readable under the normal text and still visible as a fill.
    selection = pal["accent_bg"]
    selection_inactive = "#5c5c5c" if dark else "#cbd5e1"

    def role(bg, fg, bg_alt=None):
        return {
            "BackgroundNormal": _kde_rgb(bg), "BackgroundAlternate": _kde_rgb(bg_alt or bg),
            "ForegroundNormal": _kde_rgb(fg), "ForegroundInactive": _kde_rgb(muted),
            "ForegroundActive": _kde_rgb(fg), "ForegroundLink": _kde_rgb(fg),
            "ForegroundVisited": _kde_rgb(muted),
            # Focus rings and hover: the neutral high-contrast colour, never an accent.
            "DecorationFocus": _kde_rgb(pal["accent_bg"]), "DecorationHover": _kde_rgb(muted),
            # The only three semantic colours.
            "ForegroundNegative": _kde_rgb(pal["destructive"]),
            "ForegroundNeutral": _kde_rgb(pal["warning"]),
            "ForegroundPositive": _kde_rgb(pal["success"]),
        }

    size = max(6, round(11 * font_scale))
    groups = {
        "General": {
            "ColorScheme": "DeloWay" + ("Dark" if dark else "Light"),
            "font": f"{font_family},{size},-1,5,400,0,0,0,0,0,0,0,0,0,0,1",
            "menuFont": f"{font_family},{size},-1,5,400,0,0,0,0,0,0,0,0,0,0,1",
            "toolBarFont": f"{font_family},{max(6, size - 1)},-1,5,400,0,0,0,0,0,0,0,0,0,0,1",
            "smallestReadableFont": f"{font_family},{max(6, size - 2)},-1,5,400,0,0,0,0,0,0,0,0,0,0,1",
            "fixed": f"{TERMINAL_FONT},{size},-1,5,400,0,0,0,0,0,0,0,0,0,0,1",
        },
        "Icons": {"Theme": icon_theme},
        # Breeze draws KDE apps as designed (rounded selection, framed location bar) and
        # takes every colour from the scheme; Fusion (square, flat) only when it is missing.
        "KDE": {"widgetStyle": "Breeze" if breeze_style_installed() else "Fusion"},
        # KDE apps with a colour-scheme menu (Dolphin, Kate, Okular…) read the scheme from
        # their own rc, falling back to kdeglobals; unset, they picked Breeze (Dark)
        # themselves on a non-Plasma desktop. Set once here for all of them.
        "UiSettings": {"ColorScheme": "DeloWay" + ("Dark" if dark else "Light")},
        # Window (sidebars, status bar, dialogs) one step above View (the file list, text
        # areas), as the GTK themes layer sidebar_bg over view_bg: with both pure black
        # Dolphin's places panel, toolbar and files ran together as one flat surface.
        "Colors:Window": role(pal["sidebar_bg"], pal["window_fg"], alt),
        "Colors:View": role(pal["view_bg"], pal["view_fg"], alt),
        "Colors:Button": role(button, pal["window_fg"]),
        "Colors:Header": role(pal["headerbar_bg"], pal["headerbar_fg"]),
        "Colors:Tooltip": role(tooltip, pal["window_fg"]),
        "Colors:Complementary": role(pal["window_bg"], pal["window_fg"]),
        "Colors:Selection": role(selection, pal["accent_fg"]),
        "Colors:Selection][Inactive": role(selection_inactive, pal["window_fg"]),
        "WM": {
            "activeBackground": _kde_rgb(pal["headerbar_bg"]), "activeForeground": _kde_rgb(pal["headerbar_fg"]),
            "inactiveBackground": _kde_rgb(pal["headerbar_bg"]), "inactiveForeground": _kde_rgb(muted),
        },
        # No tinting of inactive windows: it shifted the monochrome palette.
        "ColorEffects:Inactive": {"Enable": "false", "ChangeSelectionColor": "false"},
    }
    return groups


COLOR_GROUPS = ("Colors:Window", "Colors:View", "Colors:Button", "Colors:Header", "Colors:Tooltip",
                "Colors:Complementary", "Colors:Selection", "Colors:Selection][Inactive", "WM",
                "ColorEffects:Inactive")


def write_kde_color_schemes(data_home: Path, dry_run: bool = False):
    """~/.local/share/color-schemes/DeloWay{Dark,Light}.colors. KDE apps resolve the
    ColorScheme named in kdeglobals to one of these files; a name with no file made
    them fall back to Breeze (Dark) — grey background, blue selection."""
    for mode in ("dark", "light"):
        groups = build_kdeglobals_groups(mode, "Cairo", 1.0, "")
        name = groups["General"]["ColorScheme"]
        lines = ["[General]", f"ColorScheme={name}", f"Name=DeloWay {'Dark' if mode == 'dark' else 'Light'}", ""]
        for group in COLOR_GROUPS:
            lines.append(f"[{group}]")
            lines.extend(f"{k}={v}" for k, v in groups[group].items())
            lines.append("")
        if not dry_run:
            (data_home / "color-schemes").mkdir(parents=True, exist_ok=True)
        atomic_write_if_changed(data_home / "color-schemes" / f"{name}.colors", "\n".join(lines), dry_run=dry_run)


def write_kdeglobals(mode: str, font_family: str, font_scale: float, icon_theme: str,
                     config_home: Path, dry_run: bool = False) -> bool:
    """Merge DeloWay's groups into kdeglobals: our keys are set, anything else the user
    (or another KDE app) keeps there is left as it is."""
    import configparser
    target = config_home / "kdeglobals"
    cfg = configparser.RawConfigParser(strict=False, delimiters=("=",), comment_prefixes=("#",))
    cfg.optionxform = str   # KConfig keys are case-sensitive
    if target.exists():
        try:
            cfg.read(target, encoding="utf-8")
        except configparser.Error as e:
            print(f"[deloway-theme] kdeglobals unreadable, left alone: {e}", file=sys.stderr)
            return False
    for group, keys in build_kdeglobals_groups(mode, font_family, font_scale, icon_theme).items():
        if not cfg.has_section(group):
            cfg.add_section(group)
        for k, v in keys.items():
            cfg.set(group, k, v)
    lines = [KDE_MANAGED_HEADER, ""]
    for group in cfg.sections():
        lines.append(f"[{group}]")
        lines.extend(f"{k}={v}" for k, v in cfg.items(group))
        lines.append("")
    return atomic_write_if_changed(target, "\n".join(lines), dry_run=dry_run)


# Dolphin's side panels live in QMainWindow dock areas, which Qt places physically: in an
# Arabic UI the places panel stayed on the left while everything else read right to
# left. On a language switch the saved layout (~/.local/state/dolphinstaterc) is mirrored
# — left and right dock areas swap, every other choice (sizes, hidden panels, toolbars)
# is kept — and the side it was mirrored for is remembered, so it happens once.
DOCK_STATE_MARKER, DOCK_SEQUENCE, DOCK_WIDGET, DOCK_TABBED = 0xfd, 0xfc, 0xfb, 0xfa


def _dock_area_offsets(blob: bytes) -> list:
    """Offsets of each dock area's position int in a QMainWindow::saveState() blob."""
    import struct
    p = 0

    def u8():
        nonlocal p
        p += 1
        return blob[p - 1]

    def i32():
        nonlocal p
        p += 4
        return struct.unpack_from(">i", blob, p - 4)[0]

    def skip_string():
        nonlocal p
        n = struct.unpack_from(">I", blob, p)[0]
        p += 4 + (0 if n == 0xFFFFFFFF else n)

    def area_info():
        marker = u8()
        if marker == DOCK_TABBED:
            i32()
        elif marker != DOCK_SEQUENCE:
            raise ValueError("unexpected dock layout marker")
        u8()                                   # orientation
        for _ in range(i32()):
            item = u8()
            if item == DOCK_WIDGET:
                skip_string()                  # object name
                u8()                           # flags
                for _ in range(4):
                    i32()                      # pos/size (or floating geometry)
            elif item == DOCK_SEQUENCE:
                for _ in range(4):
                    i32()
                area_info()
            else:
                raise ValueError("unexpected dock item marker")

    if i32() != 0xFF:
        raise ValueError("not a QMainWindow state")
    i32()                                      # version
    if u8() != DOCK_STATE_MARKER:
        raise ValueError("no dock areas")
    offsets = []
    for _ in range(i32()):
        offsets.append(p)
        i32()                                  # position: 0 left, 1 right, 2 top, 3 bottom
        i32()
        i32()                                  # area size
        area_info()
    return offsets


def mirror_dock_areas(blob: bytes) -> bytes:
    import struct
    out = bytearray(blob)
    for off in _dock_area_offsets(blob):
        pos = struct.unpack_from(">i", blob, off)[0]
        if pos in (0, 1):
            struct.pack_into(">i", out, off, 1 - pos)
    return bytes(out)


def dolphin_window_open() -> bool:
    try:
        out = subprocess.run(["hyprctl", "clients", "-j"], capture_output=True, text=True, timeout=3).stdout
        return any(c.get("class") == "org.kde.dolphin" for c in json.loads(out or "[]"))
    except (OSError, ValueError, subprocess.SubprocessError):
        return True   # cannot tell: leave the layout alone this time


def sync_dolphin_panel_side(ui_language: str, dry_run: bool = False) -> bool:
    import base64
    import configparser
    state_home = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local" / "state")
    target = state_home / "dolphinstaterc"
    want = "right" if ui_language == "ar" else "left"
    if not target.exists():
        return False                            # no saved layout yet: next time
    cfg = configparser.RawConfigParser(strict=False, delimiters=("=",), comment_prefixes=("#",))
    cfg.optionxform = str
    try:
        cfg.read(target, encoding="utf-8")
    except configparser.Error:
        return False
    side = cfg.get("DeloWay", "PlacesPanelSide", fallback="left")   # Dolphin's own default
    if side == want or not cfg.has_option("State", "State"):
        return False
    # An open window writes its layout back when it closes, over ours.
    if dolphin_window_open():
        return False
    try:
        blob = base64.b64decode(cfg.get("State", "State"))
        mirrored = base64.b64encode(mirror_dock_areas(blob)).decode("ascii")
    except (ValueError, IndexError):
        return False                            # unknown layout format: leave it
    cfg.set("State", "State", mirrored)
    if not cfg.has_section("DeloWay"):
        cfg.add_section("DeloWay")
    cfg.set("DeloWay", "PlacesPanelSide", want)
    lines = []
    for group in cfg.sections():
        lines.append(f"[{group}]")
        lines.extend(f"{k}={v}" for k, v in cfg.items(group))
        lines.append("")
    return atomic_write_if_changed(target, "\n".join(lines), dry_run=dry_run)


def apply_qt_environment(dry_run: bool = False):
    """Qt5/Qt6 → gtk3 platform theme (palette + fonts from the DeloWay GTK theme).
    Persisted for new sessions (environment.d) and pushed into the running one."""
    env_file = Path.home() / ".config" / "environment.d" / "80-deloway-toolkits.conf"
    qt_env = qt_environment()
    body = "# Managed by DeloWay: Qt apps take palette/fonts from the DeloWay GTK theme\n" + \
           "".join(f"{k}={v}\n" for k, v in qt_env.items())
    if not dry_run:
        env_file.parent.mkdir(parents=True, exist_ok=True)
    atomic_write_if_changed(env_file, body, dry_run=dry_run)
    if dry_run:
        return
    for k, v in qt_env.items():
        subprocess.run(["hyprctl", "keyword", "env", f"{k},{v}"], capture_output=True, timeout=3)
    subprocess.run(["dbus-update-activation-environment", "--systemd"] + [f"{k}={v}" for k, v in qt_env.items()],
                   capture_output=True, timeout=5)


def configure_flatpak_theming(dry_run: bool = False):
    """Flatpak apps built on libadwaita (GNOME Calendar…) cannot see ~/.config/gtk-4.0 and
    drew Adwaita: dark grey, blue accent. A user-wide, read-only override lets every one of
    them load the DeloWay stylesheet (self-contained, no imports; it follows the colour
    scheme the portal reports, so they switch with the shell). Set once; nothing else in
    the user's Flatpak overrides is touched. GTK3 Flatpaks are not covered: our GTK3
    themes import adw-gtk3 from /usr/share, which a Flatpak does not have."""
    grant = "xdg-config/gtk-4.0:ro"
    try:
        shown = subprocess.run(["flatpak", "override", "--user", "--show"], capture_output=True,
                               text=True, timeout=5).stdout
    except (OSError, subprocess.SubprocessError):
        return                                    # no Flatpak on this system
    if grant in shown:
        return
    if dry_run:
        print(f"[dry-run] flatpak override --user --filesystem={grant}")
        return
    subprocess.run(["flatpak", "override", "--user", f"--filesystem={grant}"], capture_output=True, timeout=10)
    print(f"[deloway-theme] Flatpak apps may read the DeloWay GTK4 stylesheet ({grant})")


def set_gsettings_raw(schema: str, key: str, val: str, dry_run: bool = False):
    """Set any schema/key (skips missing keys on older GNOME schemas)."""
    try:
        cur = subprocess.run(["gsettings", "get", schema, key], capture_output=True, text=True, timeout=3)
        if cur.returncode != 0:
            return
        if cur.stdout.strip().strip("'") == val:
            return
        if dry_run:
            print(f"[dry-run] gsettings set {schema} {key} '{val}'")
            return
        subprocess.run(["gsettings", "set", schema, key, val], capture_output=True, timeout=3)
        print(f"[deloway-theme] gsettings set {key} -> {val}")
    except Exception as e:
        print(f"[deloway-theme] gsettings {key} failed: {e}", file=sys.stderr)


def signal_kitty_instances() -> int:
    """Send SIGUSR1 to all Kitty processes belonging to the current user."""
    import signal
    uid = os.getuid()
    pids = []
    try:
        res = subprocess.run(["pgrep", "-u", str(uid), "-x", "kitty"], capture_output=True, text=True, check=False)
        for line in res.stdout.strip().splitlines():
            if line.strip().isdigit():
                pids.append(int(line.strip()))
    except Exception:
        for p in os.listdir("/proc"):
            if not p.isdigit():
                continue
            try:
                if os.stat(f"/proc/{p}").st_uid != uid:
                    continue
                with open(f"/proc/{p}/comm", "r") as f:
                    if f.read().strip() == "kitty":
                        pids.append(int(p))
            except Exception:
                continue

    signaled_count = 0
    for pid in pids:
        try:
            os.kill(pid, signal.SIGUSR1)
            signaled_count += 1
        except (ProcessLookupError, PermissionError):
            pass
    return signaled_count


def sync_kitty_theme(theme_name: str, project_dir: Path, config_home: Path, dry_run: bool = False) -> bool:
    """Generate ~/.config/deloway/kitty-theme.conf from the active theme and signal running Kitty instances."""
    themes_dir = project_dir / "shell" / "theme" / "themes"
    theme_json_path = themes_dir / f"deloos-{theme_name}.json"
    if not theme_json_path.exists():
        theme_json_path = themes_dir / "deloos-dark.json"

    try:
        with open(theme_json_path, "r", encoding="utf-8") as f:
            theme_data = json.load(f)
    except Exception as e:
        print(f"[deloway-theme] Warning: Cannot read {theme_json_path}: {e}", file=sys.stderr)
        return False

    colors = theme_data.get("colors", {})
    ansi = theme_data.get("ansi", {})

    bg = colors.get("background", "#000000")
    fg = colors.get("text", "#ffffff")
    opacity = colors.get("backgroundAlpha", 1.0)
    if theme_name == "glass":
        opacity = 0.85
    else:
        opacity = 1.0

    lines = [
        "# ==============================================================================",
        "# DeloWay Kitty Theme (Auto-generated from Theme.qml — do not edit manually)",
        f"# Active Theme: {theme_name} | Background Opacity: {opacity:.2f}",
        "# ==============================================================================",
        "dynamic_background_opacity yes",
        f"background {bg}",
        f"foreground {fg}",
        f"background_opacity {opacity:.2f}",
        "",
        "# Selection & Cursor (from Theme.qml)",
        f"selection_foreground   {colors.get('selectionForeground', fg)}",
        f"selection_background   {colors.get('selectionBackground', bg)}",
        f"cursor                 {colors.get('cursor', fg)}",
        f"cursor_text_color      {colors.get('cursorTextColor', bg)}",
        f"url_color              {colors.get('urlColor', fg)}",
        "",
        "# Tab Bar & Window Borders (from Theme.qml)",
        f"active_tab_foreground   {colors.get('activeTabForeground', fg)}",
        f"active_tab_background   {colors.get('activeTabBackground', bg)}",
        f"inactive_tab_foreground {colors.get('inactiveTabForeground', fg)}",
        f"inactive_tab_background {colors.get('inactiveTabBackground', bg)}",
        f"tab_bar_background      {colors.get('tabBarBackground', bg)}",
        f"active_border_color     {colors.get('borderHighlight', fg)}",
        f"inactive_border_color   {colors.get('borderSubtle', bg)}",
        "",
        "# 16-color ANSI Palette (Calibrated for strict monochrome & WCAG AA)",
    ]
    for i in range(16):
        key = f"color{i}"
        hex_code = ansi.get(key, "#ffffff")
        lines.append(f"{key:<8} {hex_code}")

    content = "\n".join(lines) + "\n"
    deloway_conf_dir = config_home / "deloway"
    target_file = deloway_conf_dir / "kitty-theme.conf"

    if dry_run:
        print(f"[dry-run] Would write {target_file} for theme '{theme_name}' (opacity: {opacity})")
        return True

    deloway_conf_dir.mkdir(parents=True, exist_ok=True)
    target_file.write_text(content, encoding="utf-8")
    print(f"[deloway-theme] Kitty theme written -> {target_file} (mode: {theme_name}, opacity: {opacity})")

    signaled = signal_kitty_instances()
    if signaled > 0:
        print(f"[deloway-theme] Signaled {signaled} running Kitty instance(s) with SIGUSR1")
    return True


def main():
    parser = argparse.ArgumentParser(description="DeloWay Dynamic System Theme Engine")
    parser.add_argument("--dry-run", action="store_true", help="Preview changes without writing files or setting gsettings")
    parser.add_argument("--theme-json", type=str, default="", help="Path to theme.json (defaults to project theme.json)")
    parser.add_argument("--theme", type=str, default="", choices=["dark", "light", "glass"], help="Theme name")
    parser.add_argument("--mode", type=str, default="", choices=["dark", "light"], help="Force theme mode")
    parser.add_argument("--font-scale", type=float, default=0.0, help="Override font size scale factor (e.g. 0.85, 1.0, 1.15)")
    parser.add_argument("--radius", type=float, default=-1.0, help="Shell corner radius setting in px (Settings → Appearance)")
    args = parser.parse_args()

    project_dir = Path(__file__).resolve().parent.parent
    theme_json_path = Path(args.theme_json) if args.theme_json else project_dir / "shell" / "theme" / "theme.json"
    user_config_path = Path.home() / ".config" / "deloway" / "deloway.json"

    # 1. Determine theme mode, font scale, system language, and font family
    theme_name = "dark"
    mode = "dark"
    font_scale = 1.0
    ui_language = "ar"
    font_family = "Cairo"
    element_radius = 8.0

    if user_config_path.exists():
        try:
            with open(user_config_path, "r", encoding="utf-8") as f:
                u_cfg = json.load(f)
            t_cfg = u_cfg.get("theme", {})
            theme_name = t_cfg.get("themeName", "dark")
            mode = t_cfg.get("mode", mode)
            font_scale = float(t_cfg.get("fontSizeScale", font_scale))
            font_family = t_cfg.get("fontFamily", font_family)
            element_radius = float(t_cfg.get("elementRadius", 8))
            s_cfg = u_cfg.get("system", {})
            ui_language = s_cfg.get("uiLanguage", ui_language)
        except Exception as e:
            print(f"[deloway-theme] Warning reading {user_config_path}: {e}", file=sys.stderr)

    # The mode comes from deloway.json (or --mode) only. shell/theme/theme.json is no
    # longer written by the shell, so it must not override the user's choice.

    if args.theme:
        theme_name = args.theme
        if theme_name == "glass":
            mode = "glass"
        elif theme_name == "light":
            mode = "light"
        else:
            mode = "dark"
    elif args.mode:
        mode = args.mode
        if not args.theme:
            theme_name = mode
    elif theme_name == "glass":
        mode = "glass"
    elif theme_name == "light":
        mode = "light"
    else:
        mode = "dark"

    if args.font_scale > 0.0:
        font_scale = args.font_scale
    if args.radius >= 0:
        element_radius = args.radius

    is_dark = (mode in ("dark", "glass"))

    # 2. DeloWay GTK3 themes (adw-gtk3 + overrides) — switching them reloads apps live
    gtk_theme = DELOWAY_THEME_NAMES.get(theme_name, DELOWAY_THEME_NAMES["dark" if is_dark else "light"])
    color_scheme = "prefer-dark" if is_dark else "prefer-light"
    radius = radius_tokens(element_radius)

    # 3. Read authoritative system settings from gsettings
    cur_icon = get_gsettings_value("icon-theme")
    # Any Reversal variant (the DeloWay default family) follows the mode — the list
    # used to miss Reversal-black(-dark), so icons never switched. A non-Reversal
    # theme the user picked is left alone. Only installed themes are ever written:
    # a missing one leaves GTK/Qt apps with no icons at all.
    if not cur_icon or cur_icon.startswith("Reversal") or not icon_theme_installed(cur_icon):
        icon_theme = resolve_icon_theme(is_dark)
    else:
        icon_theme = cur_icon
    cursor_theme = get_gsettings_value("cursor-theme") or "default"
    # Regular weight: "Cairo Medium" named a face Cairo does not ship, and with a
    # variable-weight build it would render at 500 instead of the regular text weight.
    base_font = f"{font_family} 11"
    font_name = get_font_name_with_scale(font_scale, base_font)

    print(f"[deloway-theme] Mode: {mode} | Identity: Monochrome | GTK Theme: {gtk_theme}")
    print(f"[deloway-theme] Language: {ui_language} | Font: '{font_name}' (scale: {font_scale}) | Icons: '{icon_theme}'")

    # 4. Build INI contents (CSS is generated per toolkit below)
    settings_ini_content = build_settings_ini(gtk_theme, icon_theme, cursor_theme, font_name, is_dark)

    # 5. Target config directories (support XDG_CONFIG_HOME)
    config_home = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    gtk3_dir = config_home / "gtk-3.0"
    gtk4_dir = config_home / "gtk-4.0"

    # 6. Toolkit files: GTK3 themes, mode-agnostic GTK4 CSS, settings.ini, fonts, Qt
    if not args.dry_run:
        gtk3_dir.mkdir(parents=True, exist_ok=True)
        gtk4_dir.mkdir(parents=True, exist_ok=True)
    write_gtk3_themes(radius, dry_run=args.dry_run)
    write_gtk4_modular_themes(gtk4_dir, radius, dry_run=args.dry_run)
    atomic_write_if_changed(gtk3_dir / "gtk.css", GTK3_USER_CSS, dry_run=args.dry_run)
    atomic_write_if_changed(gtk4_dir / "gtk.css", build_gtk4_css(radius, theme_name), dry_run=args.dry_run)
    atomic_write_if_changed(gtk3_dir / "settings.ini", settings_ini_content, dry_run=args.dry_run)
    atomic_write_if_changed(gtk4_dir / "settings.ini", settings_ini_content, dry_run=args.dry_run)
    generate_qt6ct_palette(mode, config_home, dry_run=args.dry_run)   # used if qt6ct is installed
    write_kde_color_schemes(Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share"),
                            dry_run=args.dry_run)
    write_kdeglobals(mode, font_family, font_scale, icon_theme, config_home, dry_run=args.dry_run)
    sync_dolphin_panel_side(ui_language, dry_run=args.dry_run)
    deloway_dolphin.apply(dry_run=args.dry_run)      # layout, toolbar, sidebar, Breeze style
    fonts_changed = write_fontconfig(font_family, dry_run=args.dry_run)
    apply_qt_environment(dry_run=args.dry_run)
    configure_flatpak_theming(dry_run=args.dry_run)

    # 7. Apply gsettings — these are what running apps react to (via the portal):
    #    color-scheme → libadwaita/GTK4 + Qt6; gtk-theme → GTK3 (+ Qt via gtk3 theme)
    ifc = "org.gnome.desktop.interface"
    set_gsettings_value("gtk-theme", gtk_theme, dry_run=args.dry_run)
    set_gsettings_value("color-scheme", color_scheme, dry_run=args.dry_run)
    set_gsettings_value("font-name", font_name, dry_run=args.dry_run)
    set_gsettings_value("icon-theme", icon_theme, dry_run=args.dry_run)
    set_gsettings_raw(ifc, "document-font-name", get_font_name_with_scale(font_scale, f"{font_family} 11"), dry_run=args.dry_run)
    set_gsettings_raw(ifc, "monospace-font-name", get_font_name_with_scale(font_scale, f"{TERMINAL_FONT} 11"), dry_run=args.dry_run)
    set_gsettings_raw(ifc, "font-antialiasing", "grayscale", dry_run=args.dry_run)
    set_gsettings_raw(ifc, "font-hinting", "slight", dry_run=args.dry_run)
    set_gsettings_raw(ifc, "accent-color", "slate", dry_run=args.dry_run)   # neutral fallback; CSS overrides it
    if fonts_changed and not args.dry_run:
        subprocess.run(["fc-cache", "-f"], capture_output=True, timeout=60)

    # 8. Sync system language environment (Hyprland, D-Bus, environment.d)
    sync_system_language(ui_language, dry_run=args.dry_run)

    # 9. Configure Thunar defaults & default file manager service
    configure_thunar_defaults(dry_run=args.dry_run)
    sync_default_file_manager(dry_run=args.dry_run)

    # 10. Sync Kitty terminal theme & live signal
    sync_kitty_theme(theme_name, project_dir, config_home, dry_run=args.dry_run)

    # 11. Safely reload Nautilus if running
    if not args.dry_run:
        try:
            p = subprocess.run(["pgrep", "-x", "nautilus"], capture_output=True, text=True)
            if p.returncode == 0:
                subprocess.run(["nautilus", "-q"], capture_output=True, check=False)
                print("[deloway-theme] Signaled running Nautilus to reload theme.")
        except Exception as e:
            print(f"[deloway-theme] Note on Nautilus reload: {e}", file=sys.stderr)

    print("[deloway-theme] Completed successfully.")


if __name__ == "__main__":
    main()
