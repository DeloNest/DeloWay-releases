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

        // Desktop Folders (Reversal Places)
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
        "folder-documents": "desktop/folder-documents.svg",
        "work": "desktop/folder-documents.svg",
        "folder-download": "desktop/folder-download.svg",
        "folder-downloads": "desktop/folder-download.svg",
        "downloads": "desktop/folder-download.svg",
        "folder": "desktop/folder.svg",
        "inode-directory": "desktop/folder.svg"
    })

    readonly property string localAssetUrl: {
        if (!source) return "";
        if (source.startsWith("/") || source.startsWith("file://")) return source;

        const clean = source.toLowerCase().replace(/\.desktop$/, "").replace(/\.svg$/, "").trim();
        const mapped = directAppMap[clean];
        if (mapped) {
            return "file://" + ConfigManager.projectDir + "/assets/icons/" + mapped;
        }
        return "";
    }

    // 1. First Tier: Local high-fidelity bundled vector SVG
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

    // 2. Second Tier: Quickshell IconImage (queries current system theme, e.g. Reversal-dark)
    IconImage {
        id: sysIcon
        anchors.fill: parent
        source: Quickshell.iconPath(root.source, "application-x-executable")
        implicitSize: root.iconSize
        visible: localImg.status !== Image.Ready && status === Image.Ready
    }

    // 3. Third Tier: Kirigami Icon fallback
    Kirigami.Icon {
        id: kiriIcon
        anchors.fill: parent
        source: root.source || "application-x-executable"
        fallback: "application-x-executable"
        roundToIconSize: false
        visible: localImg.status !== Image.Ready && sysIcon.status !== Image.Ready && valid
    }

    // 4. Fourth Tier: Clean Fluent Monogram Fallback
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: Theme.colors.surfaceElevated
        border.color: Theme.colors.border
        border.width: 1
        visible: localImg.status !== Image.Ready && sysIcon.status !== Image.Ready && (!kiriIcon.valid)

        Text {
            anchors.centerIn: parent
            text: root.source ? root.source.replace(/.*[\/\-]/, "").charAt(0).toUpperCase() : "A"
            font.weight: Font.DemiBold
            font.pixelSize: root.iconSize * 0.45
            color: Theme.colors.accent
        }
    }
}
