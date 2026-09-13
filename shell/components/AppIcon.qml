import QtQuick
import Quickshell
import Quickshell.Widgets
import org.kde.kirigami as Kirigami
import "../services"
import "../theme"

Item {
    id: root

    property string source: ""
    property real iconSize: 32

    implicitWidth: iconSize
    implicitHeight: iconSize

    readonly property var directAppMap: ({
        // Showcase & Popular Apps
        "firefox": "apps/firefox.svg",
        "visual-studio-code": "apps/visual-studio-code.svg",
        "code": "apps/visual-studio-code.svg",
        "terminal": "apps/terminal.svg",
        "utilities-terminal": "apps/terminal.svg",
        "kitty": "apps/terminal.svg",
        "files": "apps/system-file-manager.svg",
        "system-file-manager": "apps/system-file-manager.svg",
        "thunar": "apps/system-file-manager.svg",
        "settings": "apps/settings.svg",
        "preferences-system": "apps/settings.svg",
        "preferences-system-network": "apps/settings.svg",
        "nm-connection-editor": "apps/settings.svg",
        "network": "apps/settings.svg",
        "spotify": "apps/spotify.svg",
        "jellyfin": "apps/jellyfin.svg",
        "com.github.iwalton3.jellyfin-mpv-shim": "apps/jellyfin.svg",
        "discord": "apps/discord.svg",
        "steam": "apps/steam.svg",
        "vim": "apps/vim.svg",
        "gvim": "apps/vim.svg",
        "slack": "apps/slack.svg",
        "postman": "apps/postman.svg",
        "com.getpostman.postman": "apps/postman.svg",
        "docker": "apps/docker.svg",
        "docker-desktop": "apps/docker.svg",
        "git": "apps/git.svg",
        "folder-git": "apps/git.svg",
        "obs": "apps/obs.svg",
        "obs-studio": "apps/obs.svg",
        "com.obsproject.studio": "apps/obs.svg",
        "store": "apps/store.svg",
        "software-store": "apps/store.svg",
        "app-store": "apps/store.svg",
        "package": "apps/store.svg",
        "gimp": "apps/gimp.svg",
        "vlc": "apps/vlc.svg",
        "blender": "apps/blender.svg",
        "inkscape": "apps/inkscape.svg",
        "libreoffice": "apps/libreoffice-main.svg",
        "libreoffice-main": "apps/libreoffice-main.svg",
        "telegram": "apps/telegram.svg",
        "telegram-desktop": "apps/telegram.svg",
        "celluloid": "apps/celluloid.svg",
        "audacity": "apps/audacity.svg",
        "obsidian": "apps/obsidian.svg",

        // Desktop Folders & Files (Reversal Places & Mimes)
        "user-home": "desktop/user-home.svg",
        "home": "desktop/user-home.svg",
        "user-trash": "desktop/user-trash.svg",
        "folder-trash": "desktop/folder-trash.svg",
        "trash": "desktop/user-trash.svg",
        "folder-projects": "desktop/folder-projects.svg",
        "projects": "desktop/folder-projects.svg",
        "folder-development": "desktop/folder-projects.svg",
        "folder-videos": "desktop/folder-videos.svg",
        "media": "desktop/folder-videos.svg",
        "media-video": "desktop/folder-videos.svg",
        "video-x-generic": "desktop/folder-videos.svg",
        "image-x-generic": "categories/graphics.svg",
        "package-x-generic": "apps/store.svg",
        "folder-documents": "desktop/folder-documents.svg",
        "text-x-generic": "desktop/folder-documents.svg",
        "text-plain": "desktop/folder-documents.svg",
        "document": "desktop/folder-documents.svg",
        "audio-x-generic": "status/audio-x-generic.svg",
        "work": "desktop/folder-documents.svg",
        "folder-download": "desktop/folder-download.svg",
        "folder-downloads": "desktop/folder-download.svg",
        "downloads": "desktop/folder-download.svg",
        "folder": "desktop/folder.svg",
        "inode-directory": "desktop/folder.svg"
    })

    readonly property string localAssetUrl: {
        if (!source) return "";
        if (source.startsWith("file://")) return source;
        if (source.startsWith("/")) return "file://" + source;

        const clean = source.toLowerCase().replace(/\.desktop$/, "").replace(/\.svg$/, "").trim();
        const mapped = directAppMap[clean];
        if (mapped) {
            return "file://" + ConfigManager.projectDir + "/assets/icons/" + mapped;
        }
        return "";
    }

    // Check if the icon exists in the system icon theme before requesting it
    // This prevents Quickshell from returning a missingPixmap checkerboard texture
    readonly property bool hasSysThemeIcon: {
        if (!source || source.startsWith("/") || source.startsWith("file://")) return false;
        const clean = source.toLowerCase().replace(/\.desktop$/, "").replace(/\.svg$/, "").trim();
        return Quickshell.hasThemeIcon(clean) || Quickshell.hasThemeIcon(source);
    }

    // 1. First Tier: Local high-fidelity bundled vector SVG or direct file path
    Image {
        id: localImg
        anchors.fill: parent
        source: root.localAssetUrl
        sourceSize.width: root.iconSize * 2
        sourceSize.height: root.iconSize * 2
        fillMode: Image.PreserveAspectFit
        asynchronous: false
        visible: status === Image.Ready
    }

    // 2. Second Tier: Quickshell IconImage (only queried if the theme actually contains the icon)
    IconImage {
        id: sysIcon
        anchors.fill: parent
        source: root.hasSysThemeIcon ? Quickshell.iconPath(root.source, "") : ""
        implicitSize: root.iconSize
        visible: localImg.status !== Image.Ready && root.hasSysThemeIcon && status === Image.Ready
    }

    // 3. Third Tier: Kirigami Icon fallback (only if successfully loaded, status === Image.Ready)
    Kirigami.Icon {
        id: kiriIcon
        anchors.fill: parent
        source: (!root.hasSysThemeIcon && localImg.status !== Image.Ready) ? (root.source || "") : ""
        roundToIconSize: false
        visible: localImg.status !== Image.Ready && (!sysIcon.visible) && status === Image.Ready
    }

    // 4. Fourth Tier: Clean Fluent Monogram Fallback
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: Theme.colors.surfaceElevated
        border.color: Theme.colors.border
        border.width: 1
        visible: localImg.status !== Image.Ready && (!sysIcon.visible) && (!kiriIcon.visible)

        Text {
            anchors.centerIn: parent
            text: root.source ? root.source.replace(/.*[\/\-]/, "").charAt(0).toUpperCase() : "A"
            font.family: Theme.typography.fontFamily
            font.pixelSize: Math.max(10, Math.round(root.iconSize * 0.44))
            font.weight: Font.DemiBold
            color: Theme.colors.text
            renderType: Theme.renderType
        }
    }
}
