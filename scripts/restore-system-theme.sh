#!/usr/bin/env bash
set -e

# ==============================================================================
# DeloWay System Theme Restoration Script
# Restores GTK 3.0, GTK 4.0 configuration and gsettings values from original backup.
# ==============================================================================

BACKUP_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/deloway/backups/original"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "Error: Original backup directory not found at $BACKUP_DIR"
    exit 1
fi

echo "==> Restoring DeloWay system theme from original backup: $BACKUP_DIR"

DRY_RUN=0
if [ "$1" == "--dry-run" ]; then
    DRY_RUN=1
    echo "[DRY-RUN] No files will be modified."
fi

# 1. Restore GTK 3.0
if [ -d "$BACKUP_DIR/gtk-3.0" ]; then
    echo " -> Restoring ~/.config/gtk-3.0..."
    if [ $DRY_RUN -eq 0 ]; then
        mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0"
        cp -a "$BACKUP_DIR/gtk-3.0/." "${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/"
    fi
fi

# 2. Restore GTK 4.0
if [ -d "$BACKUP_DIR/gtk-4.0" ]; then
    echo " -> Restoring ~/.config/gtk-4.0..."
    if [ $DRY_RUN -eq 0 ]; then
        mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/gtk-4.0"
        cp -a "$BACKUP_DIR/gtk-4.0/." "${XDG_CONFIG_HOME:-$HOME/.config}/gtk-4.0/"
    fi
fi

# 3. Restore gsettings
ENV_FILE="$BACKUP_DIR/gsettings.env"
if [ -f "$ENV_FILE" ]; then
    echo " -> Restoring gsettings values from $ENV_FILE..."
    # Source the environment file safely
    # Expected variables: color_scheme, gtk_theme, icon_theme, cursor_theme, font_name
    while IFS='=' read -r key val || [ -n "$key" ]; do
        # Strip comments and empty lines
        [[ "$key" =~ ^#.* ]] && continue
        [[ -z "$key" ]] && continue
        # Strip single quotes around value
        val="${val#\'}"
        val="${val%\'}"
        case "$key" in
            color_scheme)
                echo "    color-scheme -> $val"
                [ $DRY_RUN -eq 0 ] && gsettings set org.gnome.desktop.interface color-scheme "$val" || true
                ;;
            gtk_theme)
                echo "    gtk-theme -> $val"
                [ $DRY_RUN -eq 0 ] && gsettings set org.gnome.desktop.interface gtk-theme "$val" || true
                ;;
            icon_theme)
                echo "    icon-theme -> $val"
                [ $DRY_RUN -eq 0 ] && gsettings set org.gnome.desktop.interface icon-theme "$val" || true
                ;;
            cursor_theme)
                echo "    cursor-theme -> $val"
                [ $DRY_RUN -eq 0 ] && gsettings set org.gnome.desktop.interface cursor-theme "$val" || true
                ;;
            font_name)
                echo "    font-name -> $val"
                [ $DRY_RUN -eq 0 ] && gsettings set org.gnome.desktop.interface font-name "$val" || true
                ;;
        esac
    done < "$ENV_FILE"
fi

echo "==> System theme restoration complete!"
