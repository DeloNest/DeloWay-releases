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
    """Generate dynamic GTK CSS with libadwaita named colors and component styles (Monochrome OLED / High Contrast)."""
    is_dark = (mode == "dark")

    # Strict Monochrome Tokens
    if is_dark:
        # OLED Pure Black & Neutral Elevated Surfaces
        window_bg = "#000000"
        window_fg = "#ffffff"
        view_bg = "#000000"
        view_fg = "#ffffff"
        sidebar_bg = "#0a0a0a"
        sidebar_fg = "#ffffff"
        headerbar_bg = "#0a0a0a"
        headerbar_fg = "#ffffff"
        headerbar_border = "#222222"
        card_bg = "#111111"
        popover_bg = "#111111"
        border = "#222222"
        text_muted = "#888888"

        # Neutral Contrast Active/Selection
        sel_bg = "#ffffff"
        sel_fg = "#000000"

        # Translucent row selection matching Notch/Capsule cards
        thunar_row_sel_bg = "alpha(#ffffff, 0.16)"
        thunar_row_sel_fg = "#ffffff"
        thunar_row_sel_border = "alpha(#ffffff, 0.35)"
        thunar_row_hover_bg = "alpha(#ffffff, 0.08)"

        # Semantic Status Indicators (strictly constrained)
        destructive = "#ef4444"
        warning = "#f59e0b"
        success = "#10b981"
    else:
        # Crisp High-Contrast Light Mode
        window_bg = "#ffffff"
        window_fg = "#0f172a"
        view_bg = "#ffffff"
        view_fg = "#0f172a"
        sidebar_bg = "#f8fafc"
        sidebar_fg = "#0f172a"
        headerbar_bg = "#f8fafc"
        headerbar_fg = "#0f172a"
        headerbar_border = "#e2e8f0"
        card_bg = "#ffffff"
        popover_bg = "#ffffff"
        border = "#d5dbe6"
        text_muted = "#64748b"

        # Neutral Contrast Active/Selection
        sel_bg = "#0f172a"
        sel_fg = "#ffffff"

        # Translucent row selection matching Notch/Capsule cards
        thunar_row_sel_bg = "alpha(#0f172a, 0.12)"
        thunar_row_sel_fg = "#0f172a"
        thunar_row_sel_border = "alpha(#0f172a, 0.25)"
        thunar_row_hover_bg = "alpha(#0f172a, 0.06)"

        # Semantic Status Indicators
        destructive = "#ef4444"
        warning = "#d97706"
        success = "#10b981"

    return f"""/* ========================================================================== */
/* DeloWay Dynamic GTK Stylesheet (Generated by deloway-theme-apply.py)        */
/* Mode: {mode:<10}  Identity: Strict Monochrome (OLED / Light)           */
/* ========================================================================== */

/* --- Libadwaita & Standard GTK Named Colors --- */
@define-color theme_bg_color {window_bg};
@define-color theme_fg_color {window_fg};
@define-color theme_base_color {sidebar_bg};
@define-color theme_selected_bg_color {sel_bg};
@define-color theme_selected_fg_color {sel_fg};
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
@define-color borders {border};
@define-color border_color {border};
@define-color text_muted {text_muted};

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

menu, .menu, popover, window.popup {{
    background-color: @popover_bg_color;
    color: @popover_fg_color;
    border: 1px solid @border_color;
    border-radius: 8px;
    padding: 4px;
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
}}

/* Global Selection */
:selected {{
    background-color: @theme_selected_bg_color;
    color: @theme_selected_fg_color;
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

window.thunar .sidebar row,
window.thunar .sidebar treeview row,
.thunar .sidebar treeview:hover {{
    border-radius: 6px;
    margin: 1px 4px;
    padding: 3px 6px;
}}

window.thunar .sidebar row:hover,
window.thunar .sidebar treeview row:hover {{
    background-color: {thunar_row_hover_bg};
}}

window.thunar .sidebar row:selected,
window.thunar .sidebar treeview row:selected,
window.thunar .sidebar treeview:selected {{
    background-color: {thunar_row_sel_bg};
    color: {thunar_row_sel_fg};
    border: 1px solid {thunar_row_sel_border};
    border-radius: 6px;
}}

/* Main File View (Grid & Detailed List) */
window.thunar .standard-view,
window.thunar .view,
window.thunar exo-icon-view,
window.thunar treeview.view,
.thunar exo-icon-view,
.thunar treeview.view {{
    background-color: @view_bg_color;
    color: @view_fg_color;
}}

window.thunar .standard-view:hover,
window.thunar .view:hover,
window.thunar exo-icon-view:hover,
window.thunar treeview.view:hover {{
    background-color: {thunar_row_hover_bg};
}}

window.thunar .standard-view:selected,
window.thunar .view:selected,
window.thunar exo-icon-view:selected,
window.thunar treeview.view:selected,
.thunar exo-icon-view:selected,
.thunar treeview.view:selected {{
    background-color: {thunar_row_sel_bg};
    color: {thunar_row_sel_fg};
    border: 1px solid {thunar_row_sel_border};
    border-radius: 6px;
    outline: none;
}}

/* Location Bar & Pathbar */
window.thunar .location-bar,
window.thunar .path-bar,
window.thunar toolbar.location-bar,
.thunar .location-bar {{
    background-color: @headerbar_bg_color;
    border-bottom: 1px solid @border_color;
    padding: 3px 6px;
}}

window.thunar .path-bar button,
.thunar .path-bar button {{
    background-color: transparent;
    border: 1px solid transparent;
    border-radius: 6px;
    padding: 3px 8px;
    color: @headerbar_fg_color;
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
    padding: 2px 4px;
}}

window.thunar toolbar button,
.thunar toolbar button {{
    background-color: transparent;
    border: 1px solid transparent;
    border-radius: 6px;
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

/* Treeview column headers in RTL & LTR */
window.thunar treeview.view:dir(rtl),
.thunar treeview.view:dir(rtl),
window.thunar treeview.view header button:dir(rtl),
.thunar treeview.view header button:dir(rtl) {{
    text-align: right;
}}

window.thunar treeview.view:dir(ltr),
.thunar treeview.view:dir(ltr),
window.thunar treeview.view header button:dir(ltr),
.thunar treeview.view header button:dir(ltr) {{
    text-align: left;
}}

/* Entries (Search & Path Input) */
window.thunar entry,
.thunar entry,
window.thunar .location-bar entry {{
    background-color: @view_bg_color;
    border: 1px solid @border_color;
    border-radius: 6px;
    color: @theme_fg_color;
    padding: 4px 8px;
}}

window.thunar entry:dir(rtl),
.thunar entry:dir(rtl),
window.thunar .location-bar entry:dir(rtl) {{
    text-align: right;
    direction: rtl;
}}

window.thunar entry:dir(ltr),
.thunar entry:dir(ltr),
window.thunar .location-bar entry:dir(ltr) {{
    text-align: left;
    direction: ltr;
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
    background-color: @theme_bg_color;
}}

window.thunar notebook tab,
.thunar notebook tab {{
    background-color: @headerbar_bg_color;
    color: @headerbar_fg_color;
    padding: 4px 12px;
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
    background-color: @sidebar_bg_color;
    border-top: 1px solid @border_color;
    color: @text_muted;
    padding: 2px 8px;
}}

window.thunar statusbar:dir(rtl),
.thunar statusbar:dir(rtl) {{
    direction: rtl;
    padding: 2px 8px;
}}

/* Menus & Popovers in RTL */
window.thunar menuitem:dir(rtl),
.thunar menuitem:dir(rtl) {{
    padding: 4px 8px;
    text-align: right;
}}

/* Scrollbars */
window.thunar scrollbar,
.thunar scrollbar {{
    background-color: transparent;
}}

window.thunar scrollbar slider,
.thunar scrollbar slider {{
    min-width: 6px;
    min-height: 6px;
    border-radius: 3px;
    background-color: alpha(@border_color, 0.6);
}}

window.thunar scrollbar slider:hover,
.thunar scrollbar slider:hover {{
    background-color: @theme_selected_bg_color;
}}

/* Dialogs & Preferences */
window.thunar dialog,
dialog.thunar,
.thunar-dialog,
window.thunar .dialog-action-area {{
    background-color: @window_bg_color;
    color: @window_fg_color;
}}

window.thunar dialog notebook,
window.thunar dialog notebook stack {{
    background-color: @window_bg_color;
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

DELOWAY_THEME_NAMES = {"dark": "DeloWay-Dark", "light": "DeloWay-Light"}

PALETTES = {
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


def build_gtk4_css(radius: dict) -> str:
    """Mode-agnostic libadwaita stylesheet: light by default, dark via media query."""
    r = radius
    return f"""/* ========================================================================== */
/* DeloWay GTK4 / libadwaita stylesheet — generated by deloway-theme-apply.py  */
/* Both palettes live here; the active one follows the portal colour scheme,   */
/* so running apps switch instantly with the shell (no restart).               */
/* Strict monochrome: accent = neutral high contrast. Do not edit by hand.     */
/* ========================================================================== */

:root {{
{_adw_vars(PALETTES["light"])}
}}

@media (prefers-color-scheme: dark) {{
    :root {{
{_adw_vars(PALETTES["dark"]).replace("    --", "        --")}
    }}
}}

/* --- Shape language (Settings → Appearance → Shell Corner Radius) --- */
button, entry, spinbutton, dropdown > button, combobox > box > button,
switch, .linked > button, searchbar entry {{ border-radius: {r["small"]}px; }}
switch > slider {{ border-radius: {max(r["small"] - 2, 2)}px; }}
.card, list.boxed-list, .boxed-list, row.expander, preferencesgroup .boxed-list,
listview.card, .navigation-sidebar > row, popover > contents,
popover.menu > contents, toast, .osd {{ border-radius: {r["medium"]}px; }}
window.dialog, dialog-host > dialog > sheet, .dialog-sheet, window.messagedialog,
floating-sheet > sheet, bottom-sheet > sheet {{ border-radius: {r["large"]}px; }}

/* Selection + focus in neutral contrast (never a hue) */
selection, *:selected {{ background-color: alpha(currentColor, 0.18); }}
*:focus-visible {{ outline-color: alpha(currentColor, 0.55); }}
"""


def build_gtk3_theme(mode: str, radius: dict, base_theme_dir: Path) -> str:
    """GTK3 theme CSS: adw-gtk3 variant + DeloWay monochrome overrides + shape tokens."""
    r = radius
    return (f'@import url("file://{base_theme_dir}/gtk-3.0/gtk.css");\n\n'
            + build_gtk_css(mode)
            + f"""
/* --- Shape language (Settings → Appearance → Shell Corner Radius) --- */
button, entry, spinbutton, combobox button, .linked > button {{ border-radius: {r["small"]}px; }}
.linked > button:not(:first-child):not(:last-child) {{ border-radius: 0; }}
popover, popover.background, menu, .menu, .context-menu, tooltip.background {{ border-radius: {r["medium"]}px; }}
window.csd.dialog, messagedialog.csd {{ border-radius: {r["large"]}px; }}
""")


def write_gtk3_themes(radius: dict, dry_run: bool = False):
    """Install ~/.local/share/themes/DeloWay-{Dark,Light} (index.theme + gtk-3.0)."""
    themes_root = Path.home() / ".local" / "share" / "themes"
    for mode, name in DELOWAY_THEME_NAMES.items():
        base = Path("/usr/share/themes") / ("adw-gtk3-dark" if mode == "dark" else "adw-gtk3")
        if not base.exists():
            base = Path("/usr/share/themes") / ("Adwaita-dark" if mode == "dark" else "Adwaita")
        tdir = themes_root / name
        index = (f"[Desktop Entry]\nType=X-GNOME-Metatheme\nName={name}\n"
                 f"Comment=DeloWay strict monochrome ({mode}) on top of {base.name}\n"
                 f"Encoding=UTF-8\n\n[X-GNOME-Metatheme]\nGtkTheme={name}\n")
        if not dry_run:
            (tdir / "gtk-3.0").mkdir(parents=True, exist_ok=True)
        atomic_write_if_changed(tdir / "index.theme", index, dry_run=dry_run)
        atomic_write_if_changed(tdir / "gtk-3.0" / "gtk.css", build_gtk3_theme(mode, radius, base), dry_run=dry_run)


GTK3_USER_CSS = """/* DeloWay: GTK3 styling lives in the DeloWay-Dark / DeloWay-Light themes
   (~/.local/share/themes). This user stylesheet is intentionally mode-agnostic:
   GTK3 loads it only once at startup, so mode-specific colours here would stick
   after a live dark/light switch. */
"""


def write_fontconfig(dry_run: bool = False):
    """Managed fontconfig: rendering quality + Cairo for Arabic generic sans text.
    Latin generic families keep the user's own fonts.conf preferences."""
    conf = """<?xml version="1.0"?>
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
  <!-- Arabic text in generic sans/serif resolves to Cairo (the shell's typeface) -->
  <match target="pattern">
    <test name="lang" compare="contains"><string>ar</string></test>
    <test name="family"><string>sans-serif</string></test>
    <edit name="family" mode="prepend" binding="strong"><string>Cairo</string></edit>
  </match>
  <match target="pattern">
    <test name="lang" compare="contains"><string>ar</string></test>
    <test name="family"><string>serif</string></test>
    <edit name="family" mode="prepend" binding="strong"><string>Cairo</string></edit>
  </match>
</fontconfig>
"""
    target = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "fontconfig" / "conf.d" / "60-deloway.conf"
    if not dry_run:
        target.parent.mkdir(parents=True, exist_ok=True)
    return atomic_write_if_changed(target, conf, dry_run=dry_run)


QT_ENV = {"QT_QPA_PLATFORMTHEME": "gtk3"}


def apply_qt_environment(dry_run: bool = False):
    """Qt5/Qt6 → gtk3 platform theme (palette + fonts from the DeloWay GTK theme).
    Persisted for new sessions (environment.d) and pushed into the running one."""
    env_file = Path.home() / ".config" / "environment.d" / "80-deloway-toolkits.conf"
    body = "# Managed by DeloWay: Qt apps take palette/fonts from the DeloWay GTK theme\n" + \
           "".join(f"{k}={v}\n" for k, v in QT_ENV.items())
    if not dry_run:
        env_file.parent.mkdir(parents=True, exist_ok=True)
    atomic_write_if_changed(env_file, body, dry_run=dry_run)
    if dry_run:
        return
    for k, v in QT_ENV.items():
        subprocess.run(["hyprctl", "keyword", "env", f"{k},{v}"], capture_output=True, timeout=3)
    subprocess.run(["dbus-update-activation-environment", "--systemd"] + [f"{k}={v}" for k, v in QT_ENV.items()],
                   capture_output=True, timeout=5)


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


def main():
    parser = argparse.ArgumentParser(description="DeloWay Dynamic System Theme Engine")
    parser.add_argument("--dry-run", action="store_true", help="Preview changes without writing files or setting gsettings")
    parser.add_argument("--theme-json", type=str, default="", help="Path to theme.json (defaults to project theme.json)")
    parser.add_argument("--mode", type=str, default="", choices=["dark", "light"], help="Force theme mode")
    parser.add_argument("--font-scale", type=float, default=0.0, help="Override font size scale factor (e.g. 0.85, 1.0, 1.15)")
    parser.add_argument("--radius", type=float, default=-1.0, help="Shell corner radius setting in px (Settings → Appearance)")
    args = parser.parse_args()

    project_dir = Path(__file__).resolve().parent.parent
    theme_json_path = Path(args.theme_json) if args.theme_json else project_dir / "shell" / "theme" / "theme.json"
    user_config_path = Path.home() / ".config" / "deloway" / "deloway.json"

    # 1. Determine theme mode, font scale, system language, and font family
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

    if args.mode:
        mode = args.mode
    if args.font_scale > 0.0:
        font_scale = args.font_scale
    if args.radius >= 0:
        element_radius = args.radius

    is_dark = (mode == "dark")

    # 2. DeloWay GTK3 themes (adw-gtk3 + overrides) — switching them reloads apps live
    gtk_theme = DELOWAY_THEME_NAMES["dark" if is_dark else "light"]
    color_scheme = "prefer-dark" if is_dark else "prefer-light"
    radius = radius_tokens(element_radius)

    # 3. Read authoritative system settings from gsettings
    icon_theme_default = "Reversal-black-dark" if is_dark else "Reversal-black"
    cur_icon = get_gsettings_value("icon-theme")
    # Any Reversal variant (the DeloWay default family) follows the mode — the list
    # used to miss Reversal-black(-dark), so icons never switched. A non-Reversal
    # theme the user picked is left alone.
    if not cur_icon or cur_icon.startswith("Reversal"):
        icon_theme = icon_theme_default
    else:
        icon_theme = cur_icon
    cursor_theme = get_gsettings_value("cursor-theme") or "default"
    if font_family == "Cairo":
        base_font = f"{font_family} Medium 11"
    else:
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
    atomic_write_if_changed(gtk3_dir / "gtk.css", GTK3_USER_CSS, dry_run=args.dry_run)
    atomic_write_if_changed(gtk4_dir / "gtk.css", build_gtk4_css(radius), dry_run=args.dry_run)
    atomic_write_if_changed(gtk3_dir / "settings.ini", settings_ini_content, dry_run=args.dry_run)
    atomic_write_if_changed(gtk4_dir / "settings.ini", settings_ini_content, dry_run=args.dry_run)
    generate_qt6ct_palette(mode, config_home, dry_run=args.dry_run)   # used if qt6ct is installed
    fonts_changed = write_fontconfig(dry_run=args.dry_run)
    apply_qt_environment(dry_run=args.dry_run)

    # 7. Apply gsettings — these are what running apps react to (via the portal):
    #    color-scheme → libadwaita/GTK4 + Qt6; gtk-theme → GTK3 (+ Qt via gtk3 theme)
    ifc = "org.gnome.desktop.interface"
    set_gsettings_value("gtk-theme", gtk_theme, dry_run=args.dry_run)
    set_gsettings_value("color-scheme", color_scheme, dry_run=args.dry_run)
    set_gsettings_value("font-name", font_name, dry_run=args.dry_run)
    set_gsettings_value("icon-theme", icon_theme, dry_run=args.dry_run)
    set_gsettings_raw(ifc, "document-font-name", get_font_name_with_scale(font_scale, f"{font_family} 11"), dry_run=args.dry_run)
    set_gsettings_raw(ifc, "monospace-font-name", get_font_name_with_scale(font_scale, "JetBrainsMono Nerd Font 11"), dry_run=args.dry_run)
    set_gsettings_raw(ifc, "font-antialiasing", "grayscale", dry_run=args.dry_run)
    set_gsettings_raw(ifc, "font-hinting", "slight", dry_run=args.dry_run)
    set_gsettings_raw(ifc, "accent-color", "slate", dry_run=args.dry_run)   # neutral fallback; CSS overrides it
    if fonts_changed and not args.dry_run:
        subprocess.run(["fc-cache", "-f"], capture_output=True, timeout=60)

    # 8. Sync system language environment (Hyprland, D-Bus, environment.d)
    sync_system_language(ui_language, dry_run=args.dry_run)

    # 9. Configure Thunar defaults (hidden menubar, hamburger menu fallback)
    configure_thunar_defaults(dry_run=args.dry_run)

    # 10. No Thunar restart needed any more: GTK3 reloads the DeloWay theme live on
    #     the gtk-theme switch above. (reload_thunar_safely kept for manual use.)

    print("[deloway-theme] Completed successfully.")


if __name__ == "__main__":
    main()
