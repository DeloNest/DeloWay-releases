pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../services"

QtObject {
    id: root

    property string mode: "dark"

    // -------------------------------------------------------------------------
    // Performance Tiers (NewPlan.md §3)
    // 0 = Efficient (No blur, opacity-only fades, no heavy shadows)
    // 1 = Balanced  (Controlled blur on primary layer, standard motion)
    // 2 = High      (Full Mica/Acrylic glass, layered shadows, full curves)
    // -------------------------------------------------------------------------
    readonly property int performanceTier: (typeof ConfigManager !== "undefined" && ConfigManager.performanceTier !== undefined)
                                           ? ConfigManager.performanceTier : 1

    readonly property real blurRadius: performanceTier >= 2 ? 64 : (performanceTier === 1 ? 32 : 0)
    readonly property bool enableBlur: performanceTier >= 1
    readonly property bool enableComplexMotion: performanceTier >= 1
    readonly property bool enableShadows: performanceTier >= 1
    readonly property bool enableLayeredShadows: performanceTier >= 2

    // -------------------------------------------------------------------------
    // Motion Tokens (NewPlan.md §4.4)
    // Two canonical durations only. Standardized cubic curves.
    // -------------------------------------------------------------------------
    readonly property int motionFast: 120
    readonly property int motionBase: (performanceTier === 0) ? 140 : 220
    readonly property int easingEnter: Easing.OutCubic
    readonly property int easingExit: Easing.InCubic

    // -------------------------------------------------------------------------
    // Radius Tokens (NewPlan.md §4.2)
    // 3 canonical values only: Small (buttons, inputs), Medium (cards), Large (windows, Dock, Notch).
    // -------------------------------------------------------------------------
    readonly property int radiusSmall: 6
    readonly property int radiusMedium: 10
    readonly property int radiusLarge: 14

    // -------------------------------------------------------------------------
    // Spacing Tokens (NewPlan.md §4.3) - 8pt Grid
    // -------------------------------------------------------------------------
    readonly property int space4: 4
    readonly property int space8: 8
    readonly property int space16: 16
    readonly property int space24: 24
    readonly property int space32: 32
    readonly property int space48: 48

    // -------------------------------------------------------------------------
    // Canonical Accent Palette Options
    // -------------------------------------------------------------------------
    readonly property var accentPaletteOptions: [
        { "name": "Slate Cyan", "color": "#0ea5e9" },
        { "name": "DeloOS Blue", "color": "#0284c7" },
        { "name": "Emerald Green", "color": "#10b981" },
        { "name": "Violet", "color": "#8b5cf6" },
        { "name": "Coral Pink", "color": "#f43f5e" },
        { "name": "Amber Gold", "color": "#f59e0b" }
    ]

    readonly property var darkPalette: ({
        "background": "#101318",
        "backgroundAlt": "#151922",
        "surface": "#1b202c",
        "surfaceLayer1": "#1b202c",
        "surfaceLayer2": "#222736",
        "surfaceCard": "#1b202c",
        "surfaceElevated": "#222736",
        "surfaceHover": "#262c3d",
        "surfaceActive": "#2f374c",
        "surfaceVariant": "#151924",
        "border": "#2a3142",
        "borderSubtle": "#202533",
        "borderHighlight": "#3d465c",
        "primary": "#0ea5e9",
        "primaryHover": "#38bdf8",
        "primaryActive": "#0284c7",
        "accent": "#0ea5e9",
        "accentSecondary": "#38bdf8",
        "accentText": "#ffffff",
        "text": "#ffffff",
        "textPrimary": "#ffffff",
        "textSecondary": "#9da7be",
        "textTertiary": "#626c82",
        "textMuted": "#626c82",
        "activeIndicator": "#0ea5e9",
        "urgent": "#ef4444",
        "danger": "#ef4444",
        "warning": "#f59e0b",
        "success": "#10b981",
        "folderBase": "#f5aa1e",
        "folderAccent": "#f08705",
        "folderHighlight": "#ffc841",
        "folderEmblem": "#ffffff"
    })

    readonly property var lightPalette: ({
        "background": "#f4f6f9",
        "backgroundAlt": "#e9edf3",
        "surface": "#ffffff",
        "surfaceLayer1": "#ffffff",
        "surfaceLayer2": "#f8fafc",
        "surfaceCard": "#ffffff",
        "surfaceElevated": "#ffffff",
        "surfaceHover": "#f1f3f7",
        "surfaceActive": "#e2e6ed",
        "surfaceVariant": "#f8fafc",
        "border": "#d5dbe6",
        "borderSubtle": "#e5e9f0",
        "borderHighlight": "#b8c3d6",
        "primary": "#0ea5e9",
        "primaryHover": "#38bdf8",
        "primaryActive": "#0284c7",
        "accent": "#0ea5e9",
        "accentSecondary": "#38bdf8",
        "accentText": "#ffffff",
        "text": "#111827",
        "textPrimary": "#111827",
        "textSecondary": "#4b5563",
        "textTertiary": "#9ca3af",
        "textMuted": "#9ca3af",
        "activeIndicator": "#0ea5e9",
        "urgent": "#ef4444",
        "danger": "#ef4444",
        "warning": "#d97706",
        "success": "#10b981",
        "folderBase": "#f5aa1e",
        "folderAccent": "#f08705",
        "folderHighlight": "#ffc841",
        "folderEmblem": "#ffffff"
    })

    property var colors: Object.assign({}, darkPalette)

    // Direct color accessors for cleaner QML code
    readonly property color background: colors.background || "#101318"
    readonly property color surface: colors.surface || "#1b202c"
    readonly property color surfaceLayer1: colors.surfaceLayer1 || surface
    readonly property color surfaceLayer2: colors.surfaceLayer2 || surfaceElevated
    readonly property color surfaceCard: colors.surfaceCard || surface
    readonly property color surfaceElevated: colors.surfaceElevated || "#222736"
    readonly property color surfaceHover: colors.surfaceHover || "#262c3d"
    readonly property color surfaceActive: colors.surfaceActive || "#2f374c"
    readonly property color surfaceVariant: colors.surfaceVariant || "#151924"
    readonly property color border: colors.border || "#2a3142"
    readonly property color borderSubtle: colors.borderSubtle || "#202533"
    readonly property color borderHighlight: colors.borderHighlight || "#3d465c"
    readonly property color accent: colors.accent || "#0ea5e9"
    readonly property color primary: colors.primary || "#0ea5e9"
    readonly property color textOnAccent: "#ffffff"
    readonly property color textOnPrimary: "#ffffff"
    readonly property color text: colors.text || "#ffffff"
    readonly property color textPrimary: colors.textPrimary || text
    readonly property color textSecondary: colors.textSecondary || "#9da7be"
    readonly property color textTertiary: colors.textTertiary || "#626c82"
    readonly property color textMuted: colors.textMuted || textTertiary
    readonly property color urgent: colors.urgent || "#ef4444"
    readonly property color danger: colors.danger || urgent
    readonly property color success: colors.success || "#10b981"
    readonly property color warning: colors.warning || "#f59e0b"

    readonly property color folderBase: colors.folderBase || "#f5aa1e"
    readonly property color folderAccent: colors.folderAccent || "#f08705"
    readonly property color folderHighlight: colors.folderHighlight || "#ffc841"
    readonly property color folderEmblem: colors.folderEmblem || "#ffffff"

    // Fluent materials — opacity used for Mica / Acrylic surfaces
    property var material: ({
        "acrylic": 0.82,
        "mica": 0.88,
        "solid": 0.98
    })

    // Reactive overlays — derive from text so they invert with the theme mode
    readonly property color overlayHover: Qt.alpha(colors.text, 0.065)
    readonly property color overlayHoverStrong: Qt.alpha(colors.text, 0.10)
    readonly property color hairline: Qt.alpha(colors.text, 0.08)
    readonly property color hairlineSoft: Qt.alpha(colors.text, 0.05)

    // -------------------------------------------------------------------------
    // Deep Black / Notch Surface Tokens (Unified OLED aesthetic)
    // -------------------------------------------------------------------------
    readonly property color notchBackground: "#000000"
    readonly property color notchSurface: Qt.rgba(1, 1, 1, 0.05)
    readonly property color notchSurfaceElevated: Qt.rgba(1, 1, 1, 0.08)
    readonly property color notchSurfaceHover: Qt.rgba(1, 1, 1, 0.12)
    readonly property color notchSurfaceActive: Qt.rgba(1, 1, 1, 0.18)
    readonly property color notchBorder: Qt.rgba(1, 1, 1, 0.12)
    readonly property color notchBorderSubtle: Qt.rgba(1, 1, 1, 0.06)
    readonly property color notchBorderHighlight: Qt.rgba(1, 1, 1, 0.25)
    readonly property color notchText: "#ffffff"
    readonly property color notchTextSecondary: Qt.rgba(1, 1, 1, 0.70)
    readonly property color notchTextTertiary: Qt.rgba(1, 1, 1, 0.45)
    readonly property color notchShadow: Qt.rgba(0, 0, 0, 0.50)
    readonly property int notchRadiusWindow: 26
    readonly property int notchRadiusPanel: 16
    readonly property int notchRadiusCard: 12
    readonly property int notchRadiusPill: 8
    readonly property int radiusDock: 24

    // Dock Tokens (Unified with OLED Notch/Capsule aesthetic)
    readonly property color dockGlass: notchBackground
    readonly property color dockGlassSheen: notchBorderSubtle
    readonly property color dockBorder: notchBorder
    readonly property color dockShadow: notchShadow
    readonly property color dockDot: Qt.rgba(1, 1, 1, 0.95)
    readonly property color dockDivider: notchBorderHighlight
    readonly property color dockTooltipBg: notchBackground
    readonly property color dockTooltipBorder: notchBorder

    function setMode(newMode) {
        if (newMode !== "dark" && newMode !== "light") return;
        root.mode = newMode;
        const currentAccent = (root.colors && root.colors.accent) ? root.colors.accent : "#0ea5e9";
        const currentPrimary = (root.colors && root.colors.primary) ? root.colors.primary : "#0ea5e9";
        const targetPalette = (newMode === "light") ? root.lightPalette : root.darkPalette;
        const updated = Object.assign({}, targetPalette);
        if (currentAccent) {
            updated.accent = currentAccent;
            updated.primary = currentPrimary;
            updated.activeIndicator = currentAccent;
        }
        root.colors = updated;
    }

    property var radius: ({
        "xsmall": 4,
        "small": 6,
        "medium": 10,
        "large": 14,
        "xlarge": 18,
        "pill": 9999,
        "barCard": 12,
        "barPill": 8,
        "barTile": 7,
        "tooltip": 7,
        "dockCard": 16,
        "dockItem": 11,
        "none": 0
    })

    property var spacing: ({
        "xsmall": 4,
        "small": 8,
        "medium": 12,
        "large": 16,
        "xlarge": 24,
        "panel": 18,
        "gutter": 14,
        "tight": 10,
        "fine": 6,
        "inset": 5,
        "tiny": 3,
        "micro": 2,
        "none": 0
    })

    // High-fidelity typography rendering helpers
    readonly property int renderType: Text.NativeRendering
    readonly property int hintingPreference: Font.PreferFullHinting
    readonly property var fontFamilies: ["SF Pro Display", "SF Arabic", "Cairo", "Readex Pro", "Rubik", "Noto Sans", "sans-serif"]

    property var typography: ({
        "fontFamily": "SF Pro Display",
        "fontFamilies": ["SF Pro Display", "SF Arabic", "Cairo", "Readex Pro", "Rubik", "Noto Sans", "sans-serif"],
        "terminalFont": "JetBrainsMono Nerd Font",

        // 4-Level Semantic Type Scale
        // Level 1: Display — section/panel headers (e.g. "Quick Settings", "Notifications")
        "scaleDisplay":  { "size": 16, "weight": 600 },   // Font.DemiBold
        // Level 2: Title — card titles, section labels
        "scaleTitle":    { "size": 13, "weight": 600 },   // Font.DemiBold
        // Level 3: Body — primary content text
        "scaleBody":     { "size": 13, "weight": 400 },   // Font.Normal
        // Level 4: Caption — secondary, dates, descriptions, badges
        "scaleCaption":  { "size": 11, "weight": 400 },   // Font.Normal
        "scaleMenuTitle": { "size": 12, "weight": 600 },   // Font.DemiBold

        // Legacy compat keys (updated values for better readability)
        "fontSizeSmall":   11,
        "fontSizeRegular": 13,
        "fontSizeMedium":  15,
        "fontSizeLarge":   18,
        "fontSizeTitle":   22
    })

    property FileView themeWatcher: FileView {
        path: Qt.resolvedUrl("theme.json")
        watchChanges: true
        preload: true

        function reloadTheme() {
            try {
                const textContent = themeWatcher.text();
                if (!textContent || textContent.trim() === "") return;
                const parsed = JSON.parse(textContent);
                if (parsed.mode && parsed.mode !== root.mode) root.setMode(parsed.mode);
                if (parsed.colors) root.colors = Object.assign({}, root.colors, parsed.colors);
                if (parsed.radius) root.radius = Object.assign({}, root.radius, parsed.radius);
                if (parsed.spacing) root.spacing = Object.assign({}, root.spacing, parsed.spacing);
                if (parsed.typography) root.typography = Object.assign({}, root.typography, parsed.typography);
            } catch (e) {
                console.warn("[Deloway/Theme] Failed to parse theme.json:", e);
            }
        }

        onLoaded: reloadTheme()
        onTextChanged: reloadTheme()
    }
}
