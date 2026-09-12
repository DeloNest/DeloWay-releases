#!/usr/bin/env bash
set -e

echo "=== [DeloOS] Setting up Bundled Applications & Rebranding Pipeline (§7 & §7.4) ==="

APP_DIR="$HOME/.local/share/applications"
mkdir -p "$APP_DIR"
mkdir -p "$HOME/.config/gtk-3.0"
mkdir -p "$HOME/.config/gtk-4.0"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1. Delo Terminal Desktop Override
cat << EOF > "$APP_DIR/delo-terminal.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Delo Terminal
GenericName=Terminal Emulator
Comment=Fast, GPU-accelerated Calm Mica terminal for DeloOS
Exec=kitty --config $PROJECT_ROOT/config/kitty.conf
Icon=terminal
Terminal=false
Categories=System;TerminalEmulator;Utility;
StartupWMClass=kitty
Keywords=terminal;shell;prompt;command;delo;
EOF

# 2. Delo Files Desktop Override
cat << 'EOF' > "$APP_DIR/delo-files.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Delo Files
GenericName=File Manager
Comment=Fast, modern file manager for DeloOS
Exec=thunar %F
Icon=system-file-manager
Terminal=false
Categories=System;FileManager;Utility;
StartupWMClass=thunar
Keywords=files;folders;explorer;delo;thunar;
EOF


# 4. Delo Store Desktop Entry
cat << 'EOF' > "$APP_DIR/delo-store.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Delo Store
GenericName=App Store
Comment=Discover, install, and manage applications and software packages
Exec=pamac-manager %U
Icon=software-store
Terminal=false
Categories=System;PackageManager;Settings;
StartupWMClass=pamac-manager
Keywords=store;apps;packages;install;software;delo;pamac;
EOF

chmod +x "$APP_DIR"/delo-*.desktop
update-desktop-database "$APP_DIR" 2>/dev/null || true

echo "✓ Branded .desktop entries created in $APP_DIR"

# 5. GTK 3 & GTK 4 Theme Integration (§7.3)
cat << 'EOF' > "$HOME/.config/gtk-3.0/gtk.css"
/* DeloOS Fluent Mica Design Tokens */
@define-color accent_color #0084ff;
@define-color accent_bg_color #0084ff;
@define-color accent_fg_color #ffffff;

@define-color window_bg_color #101318;
@define-color window_fg_color #ffffff;
@define-color view_bg_color #1b202c;
@define-color view_fg_color #ffffff;
@define-color headerbar_bg_color #151924;
@define-color headerbar_fg_color #ffffff;
@define-color headerbar_border_color #2a3142;
@define-color card_bg_color #1b202c;
@define-color popover_bg_color #1b202c;

window, dialog {
    background-color: @window_bg_color;
    color: @window_fg_color;
}

headerbar {
    background-color: @headerbar_bg_color;
    border-bottom: 1px solid @headerbar_border_color;
}

/* Scoped Thunar Custom Styling */
.thunar window,
.thunar .sidebar,
.thunar placessidebar {
    background-color: #101318;
    color: #ffffff;
    border-right: 1px solid rgba(255, 255, 255, 0.06);
}

.thunar .standard-view,
.thunar view {
    background-color: #151924;
    color: #ffffff;
}

.thunar .sidebar row:selected,
.thunar .standard-view:selected {
    background-color: #0084ff;
    color: #ffffff;
}

.thunar scrollbar slider {
    background-color: rgba(255, 255, 255, 0.15);
    border-radius: 4px;
    min-width: 6px;
}

.thunar scrollbar slider:hover {
    background-color: #0084ff;
}

/* Scoped Pamac (App Store) Styling */
.pamac window,
.pamac headerbar {
    background-color: #151924;
    color: #ffffff;
}

.pamac .sidebar,
.pamac placessidebar {
    background-color: #101318;
    border-right: 1px solid rgba(255, 255, 255, 0.06);
}
EOF

rm -f "$HOME/.config/gtk-4.0/gtk.css"
cp "$HOME/.config/gtk-3.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"
echo "✓ GTK 3 and GTK 4 stylesheets synchronized with DeloOS palette tokens"
echo "=== Setup complete! ==="
