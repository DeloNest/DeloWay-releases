import QtQuick
import Quickshell
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects
import "../theme"
import "../services"

Item {
    id: root

    property string source: ""
    property real iconSize: 16
    property color iconColor: Theme.colors.textSecondary

    implicitWidth: iconSize
    implicitHeight: iconSize

    readonly property var iconMap: ({
        // Status Icons
        "network-wireless": "status/network-wireless.svg",
        "network-wireless-symbolic": "status/network-wireless.svg",
        "network-wireless-hotspot": "status/network-wireless-hotspot.svg",
        "network-wireless-hotspot-symbolic": "status/network-wireless-hotspot.svg",
        "hotspot": "status/network-wireless-hotspot.svg",
        "network-wired": "status/network-wired.svg",
        "network-wired-symbolic": "status/network-wired.svg",
        "ethernet": "status/network-wired.svg",
        "computer": "status/device.svg",
        "computer-symbolic": "status/device.svg",
        "device": "status/device.svg",
        "device-symbolic": "status/device.svg",
        "phone": "status/phone.svg",
        "phone-symbolic": "status/phone.svg",
        "smartphone": "status/phone.svg",
        "smartphone-symbolic": "status/phone.svg",
        "send": "status/send.svg",
        "send-symbolic": "status/send.svg",
        "document-send": "status/send.svg",
        "document-send-symbolic": "status/send.svg",
        "send-to-symbolic": "status/send.svg",
        "refresh": "status/refresh.svg",
        "refresh-symbolic": "status/refresh.svg",
        "view-refresh": "status/refresh.svg",
        "view-refresh-symbolic": "status/refresh.svg",
        "wifi": "status/wifi.svg",
        "bluetooth": "status/bluetooth.svg",
        "bluetooth-active": "status/bluetooth.svg",
        "bluetooth-active-symbolic": "status/bluetooth.svg",
        "bluetooth-symbolic": "status/bluetooth.svg",
        "audio-volume-high": "status/audio-volume-high.svg",
        "audio-volume-high-symbolic": "status/audio-volume-high.svg",
        "audio-volume-medium": "status/audio-volume-medium.svg",
        "audio-volume-medium-symbolic": "status/audio-volume-medium.svg",
        "audio-volume-low": "status/audio-volume-low.svg",
        "audio-volume-low-symbolic": "status/audio-volume-low.svg",
        "audio-volume-muted": "status/audio-volume-muted.svg",
        "audio-volume-muted-symbolic": "status/audio-volume-muted.svg",
        "speaker": "status/speaker.svg",
        "speaker-mute": "status/speaker-mute.svg",
        "battery": "status/battery.svg",
        "battery-level-100": "status/battery-full.svg",
        "battery-level-100-symbolic": "status/battery-full.svg",
        "battery-full": "status/battery-full.svg",

        // Quick Settings Controls
        "display-brightness": "status/display-brightness.svg",
        "display-brightness-symbolic": "status/display-brightness.svg",
        "weather-sunny": "status/weather-sunny.svg",
        "weather-sunny-symbolic": "status/weather-sunny.svg",
        "sun": "status/weather-sunny.svg",
        "weather-clear-night-symbolic": "status/weather-moon.svg",
        "night-light-symbolic": "status/night-light-symbolic.svg",
        "power-profile-balanced-symbolic": "status/power-profile-balanced.svg",
        "system-shutdown": "status/power-symbolic.svg",
        "system-shutdown-symbolic": "status/power-symbolic.svg",
        "power": "status/power-symbolic.svg",
        "power-symbolic": "status/power-symbolic.svg",
        "changes-prevent": "status/alert.svg",
        "changes-prevent-symbolic": "status/alert.svg",
        "system-lock-screen": "status/lock.svg",
        "system-lock-screen-symbolic": "status/lock.svg",
        "lock": "status/lock.svg",
        "lock-symbolic": "status/lock.svg",
        "dialog-warning": "status/dialog-warning.svg",
        "dialog-warning-symbolic": "status/dialog-warning.svg",
        "warning": "status/dialog-warning.svg",
        "warning-symbolic": "status/dialog-warning.svg",
        "user-home-symbolic": "categories/all-symbolic.svg",
        "preferences-desktop-keyboard-shortcuts-symbolic": "categories/utilities-symbolic.svg",
        "preferences-desktop-font-symbolic": "status/preferences-desktop-font.svg",
        "preferences-desktop-font": "status/preferences-desktop-font.svg",
        "applications-other-symbolic": "categories/all-symbolic.svg",
        "avatar-default-symbolic": "status/avatar-default.svg",
        "view-app-grid-symbolic": "status/view-app-grid.svg",
        "view-app-grid": "status/view-app-grid.svg",
        "dialog-information-symbolic": "status/alert.svg",
        "preferences-system-notifications-symbolic": "status/alert.svg",
        "focus": "status/focus-symbolic.svg",
        "focus-symbolic": "status/focus-symbolic.svg",
        "dnd": "status/focus-symbolic.svg",
        "dnd-symbolic": "status/focus-symbolic.svg",
        "expand": "status/search.svg",
        "audio-x-generic": "status/audio-x-generic.svg",
        "audio-x-generic-symbolic": "status/audio-x-generic.svg",
        "music": "status/music-note.svg",
        "music-note": "status/music-note.svg",
        "media-playback-start": "status/media-playback-start-symbolic.svg",
        "media-playback-start-symbolic": "status/media-playback-start-symbolic.svg",
        "media-playback-pause": "status/media-playback-pause-symbolic.svg",
        "media-playback-pause-symbolic": "status/media-playback-pause-symbolic.svg",
        "media-skip-forward": "status/media-skip-forward-symbolic.svg",
        "media-skip-forward-symbolic": "status/media-skip-forward-symbolic.svg",
        "media-skip-backward": "status/media-skip-backward-symbolic.svg",
        "media-skip-backward-symbolic": "status/media-skip-backward-symbolic.svg",

        // Common Actions
        "search": "status/search.svg",
        "system-search": "status/system-search.svg",
        "system-search-symbolic": "status/system-search.svg",
        "preferences-system": "status/settings-symbolic.svg",
        "preferences-system-symbolic": "status/settings-symbolic.svg",
        "settings": "status/settings-symbolic.svg",
        "settings-symbolic": "status/settings-symbolic.svg",
        "user-trash": "status/user-trash-symbolic.svg",
        "user-trash-symbolic": "status/user-trash-symbolic.svg",
        "trash": "status/user-trash-symbolic.svg",
        "apps": "apps/deloway-launcher.svg",
        "apps-symbolic": "apps/deloway-launcher.svg",
        "view-app-grid": "apps/deloway-launcher.svg",
        "view-app-grid-symbolic": "apps/deloway-launcher.svg",
        "store": "status/store-symbolic.svg",
        "store-symbolic": "status/store-symbolic.svg",
        "software-store": "status/store-symbolic.svg",
        "software-store-symbolic": "status/store-symbolic.svg",

        // Categories
        "all": "categories/all-symbolic.svg",
        "applications-all": "categories/all-symbolic.svg",
        "applications-all-symbolic": "categories/all-symbolic.svg",
        "system": "categories/system-symbolic.svg",
        "applications-system": "categories/system-symbolic.svg",
        "applications-system-symbolic": "categories/system-symbolic.svg",
        "development": "categories/development-symbolic.svg",
        "applications-development": "categories/development-symbolic.svg",
        "applications-development-symbolic": "categories/development-symbolic.svg",
        "internet": "categories/internet-symbolic.svg",
        "applications-internet": "categories/internet-symbolic.svg",
        "applications-internet-symbolic": "categories/internet-symbolic.svg",
        "multimedia": "categories/multimedia-symbolic.svg",
        "applications-multimedia": "categories/multimedia-symbolic.svg",
        "applications-multimedia-symbolic": "categories/multimedia-symbolic.svg",
        "office": "categories/office-symbolic.svg",
        "applications-office": "categories/office-symbolic.svg",
        "applications-office-symbolic": "categories/office-symbolic.svg",
        "graphics": "categories/graphics-symbolic.svg",
        "applications-graphics": "categories/graphics-symbolic.svg",
        "applications-graphics-symbolic": "categories/graphics-symbolic.svg",
        "games": "categories/games-symbolic.svg",
        "applications-games": "categories/games-symbolic.svg",
        "applications-games-symbolic": "categories/games-symbolic.svg",
        "input-gaming": "categories/games-symbolic.svg",
        "input-gaming-symbolic": "categories/games-symbolic.svg",
        "audio-headphones": "status/audio-x-generic.svg",
        "audio-headphones-symbolic": "status/audio-x-generic.svg",
        "utilities": "categories/utilities-symbolic.svg",
        "applications-utilities": "categories/utilities-symbolic.svg",
        "applications-utilities-symbolic": "categories/utilities-symbolic.svg",
        "notch-nook": "status/notch-nook.svg",
        "notch-tray": "status/notch-tray.svg"
    })

    readonly property string resolvedSource: {
        if (!source) return "";
        if (source.startsWith("/") || source.startsWith("file://")) return source;

        const clean = source.toLowerCase().replace(/\.svg$/, "").trim();
        const mapped = iconMap[clean];
        if (mapped) {
            return "file://" + ConfigManager.projectDir + "/assets/icons/" + mapped;
        }

        return "";
    }

    property bool isDirectional: false
    property bool autoMirror: false

    readonly property bool isDirectionalSource: {
        if (!source) return false;
        const s = source.toLowerCase();
        return s.includes("go-previous") || s.includes("go-next") ||
               s.includes("arrow") ||
               s.includes("pan-start") || s.includes("pan-end");
    }

    Image {
        id: rawIcon
        anchors.fill: parent
        source: root.resolvedSource
        sourceSize.width: Math.round(root.iconSize * 2)
        sourceSize.height: Math.round(root.iconSize * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        mirror: (root.isDirectional || root.autoMirror || isDirectionalSource) && I18n.isRTL
        visible: false
        asynchronous: false
    }

    ColorOverlay {
        id: overlay
        anchors.fill: rawIcon
        source: rawIcon
        color: root.iconColor
        visible: rawIcon.status === Image.Ready
    }

    // Theme symbolic icons (not in the bundled map) are tinted too, so every "*-symbolic"
    // glyph follows the monochrome tokens (e.g. black on an active white tile) instead of
    // the theme's baked-in colour. Mirroring is intentionally NOT applied here: callers
    // that pick a direction per locale for unmapped icons keep working unchanged.
    readonly property bool themeSymbolic: !root.resolvedSource && root.source.length > 0
                                          && /-symbolic(-rtl)?$/.test(root.source) && IconResolver.has(root.source)

    Image {
        id: themeIcon
        anchors.fill: parent
        source: root.themeSymbolic ? IconResolver.themeUrl(root.source) : ""
        sourceSize.width: Math.round(root.iconSize * 2)
        sourceSize.height: Math.round(root.iconSize * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        visible: false
    }

    ColorOverlay {
        anchors.fill: themeIcon
        source: themeIcon
        color: root.iconColor
        visible: root.themeSymbolic && themeIcon.status === Image.Ready
    }

    // Fallback: non-symbolic names keep the theme's own rendering. An icon the theme does
    // not have renders nothing (IconResolver), never Quickshell's checkerboard.
    IconImage {
        anchors.fill: parent
        source: (root.resolvedSource || root.themeSymbolic) ? "" : IconResolver.safeUrl(root.source)
        implicitSize: root.iconSize
        visible: rawIcon.status !== Image.Ready && !(root.themeSymbolic && themeIcon.status === Image.Ready)
    }
}
