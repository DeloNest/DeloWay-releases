pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../services"

Item {
    id: root

    property string mode: (typeof ConfigManager !== "undefined" && ConfigManager.themeMode)
                          ? ConfigManager.themeMode : "dark"
    readonly property bool isDark: mode === "dark"
    readonly property real fontScale: (typeof ConfigManager !== "undefined" && ConfigManager.fontSizeScale)
                                     ? ConfigManager.fontSizeScale : 1.0

    function fontSize(baseSize) {
        return Math.round(baseSize * root.fontScale);
    }

    function scaleFont(baseSize) {
        return root.fontSize(baseSize);
    }

    Connections {
        target: (typeof ConfigManager !== "undefined") ? ConfigManager : null
        function onThemeModeChanged() {
            if (ConfigManager.themeMode && ConfigManager.themeMode !== root.mode) {
                root.setMode(ConfigManager.themeMode);
            }
        }
        function onAccentColorChanged() {
            root.setMode(root.mode);
        }
    }

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
    // Dynamic Deep Black / Notch Surface Tokens (Unified OLED / Clean Light)
    // -------------------------------------------------------------------------
    readonly property color notchBackground: isDark ? "#000000" : "#ffffff"
    readonly property color notchText: isDark ? "#ffffff" : "#0f172a"
    readonly property color notchTextSecondary: isDark ? Qt.rgba(1, 1, 1, 0.70) : Qt.rgba(0, 0, 0, 0.65)
    readonly property color notchTextTertiary: isDark ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(0, 0, 0, 0.45)
    readonly property color notchSurface: isDark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.04)
    readonly property color notchSurfaceElevated: isDark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.07)
    readonly property color notchSurfaceHover: isDark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08)
    readonly property color notchSurfaceActive: isDark ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.12)
    readonly property color notchBorder: isDark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.10)
    readonly property color notchBorderSubtle: isDark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.06)
    readonly property color notchBorderHighlight: isDark ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(0, 0, 0, 0.18)
    readonly property color notchShadow: isDark ? Qt.rgba(0, 0, 0, 0.50) : Qt.rgba(0, 0, 0, 0.12)
    readonly property int notchRadius: 22
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
    readonly property color dockDot: isDark ? Qt.rgba(1, 1, 1, 0.95) : Qt.rgba(0, 0, 0, 0.85)
    readonly property color dockDivider: notchBorderHighlight
    readonly property color dockTooltipBg: notchBackground
    readonly property color dockTooltipBorder: notchBorder

    // Semantic Component Tokens (Dark / Light adaptive)
    readonly property color musicBadge: isDark ? "#fa243c" : "#e11d48"
    readonly property color calendarPast: isDark ? "#3b82f6" : "#2563eb"
    readonly property color calendarFuture: isDark ? "#ef5350" : "#dc2626"
    readonly property color sliderTrack: isDark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08)
    readonly property color sliderFill: isDark ? "#ffffff" : colors.textPrimary
    readonly property color sliderThumb: isDark ? "#ffffff" : colors.textPrimary

    // Quick Settings Capsule Tokens
    readonly property int qsTileHeight: 64
    readonly property int qsTileRadius: 32
    readonly property int qsIconCircleSize: 40
    readonly property int qsIconCircleRadius: 20
    readonly property int qsRoundButtonSize: 64
    readonly property int qsRoundButtonRadius: 32
    readonly property int qsSliderCardHeight: 84
    readonly property int qsSliderTrackHeight: 32
    readonly property int qsSliderTrackRadius: 16
    readonly property int qsCardRadius: 20
    readonly property int qsSpacing: 10
    readonly property int qsPadding: 16

    readonly property color qsTileBackground: isDark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.04)
    readonly property color qsTileBackgroundHover: isDark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.07)
    readonly property color qsTileBackgroundActive: isDark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.06)
    readonly property color qsTileBorder: isDark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.06)
    readonly property color qsTileIconCircleInactive: isDark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.07)
    readonly property color qsTileIconInactive: isDark ? Qt.rgba(1, 1, 1, 0.70) : Qt.rgba(0, 0, 0, 0.60)
    readonly property color qsTileIconActive: isDark ? "#000000" : "#ffffff"
    readonly property color qsSliderTrack: notchSurfaceElevated
    readonly property color qsSliderTrackHover: notchSurfaceHover
    readonly property color notchSliderFill: isDark ? "#ffffff" : "#0f172a"
    readonly property color qsSliderFill: notchSliderFill
    readonly property color qsSliderIconActive: isDark ? "#000000" : "#ffffff"
    readonly property color qsSliderIconInactive: isDark ? Qt.rgba(1, 1, 1, 0.60) : Qt.rgba(0, 0, 0, 0.50)

    // Workspace Indicator Tokens
    readonly property int wsDotSize:            6
    readonly property int wsCircleSize:         28
    readonly property int wsPillHeight:         32
    readonly property int wsPillBase:           30    // pill width: number only (active, no icons)
    readonly property int wsPillIconGap:        4     // gap between number and icon area in pill
    readonly property int wsIconSizeSingle:     15    // icon size when 1 shown (circle or pill)
    readonly property int wsIconSizeDouble:     12    // each icon size when 2 overlapping
    readonly property int wsIconOverlapOffset:  8     // horizontal offset of 2nd icon centre
    readonly property int wsBadgeSize:          13
    readonly property int wsIndicatorSpacing:   5

    // kept for back-compat
    readonly property int wsPillWidth:  wsPillBase
    readonly property int wsIconSize:   wsIconSizeSingle

    // Workspace colours — OLED monochrome identity
    readonly property color wsActiveBg:    isDark ? "#ffffff" : "#0f172a"
    readonly property color wsActiveText:  isDark ? "#000000" : "#ffffff"
    readonly property color wsOccupiedBg:  isDark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(0, 0, 0, 0.09)
    readonly property color wsEmptyBg:     "transparent"

    // Exclusion & Strut Geometry Tokens (Reserved Space)
    readonly property int topBarHeight: 44
    readonly property int topBarMarginTop: 10
    readonly property int topBarGap: 0
    // In layer-shell, Hyprland calculates total reserved space as (exclusiveZone + margin).
    // To achieve total reserved = topBarHeight + topBarMarginTop + topBarGap (54px),
    // the exclusiveZone is set to (topBarHeight + topBarGap) = 44px.
    readonly property int topBarExclusiveZone: topBarHeight + topBarGap // 44px
    readonly property int topBarReserved: topBarHeight + topBarMarginTop + topBarGap // 54px

    readonly property int dockMarginBottom: 10
    readonly property int dockGap: 8
    function dockExclusiveZoneFor(dockHeight) {
        return Math.round((dockHeight > 0 ? dockHeight : 68) + dockGap); // 76px
    }
    function dockReservedFor(dockHeight) {
        return Math.round((dockHeight > 0 ? dockHeight : 68) + dockMarginBottom + dockGap); // 86px
    }
    readonly property int dockExclusiveZone: dockExclusiveZoneFor(68) // 76px
    readonly property int dockReserved: dockReservedFor(68) // 86px

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
    readonly property var fontFamilies: ["Inter", "Inter Display", "Cairo", "Noto Kufi Arabic", "SF Pro Display", "SF Arabic", "Noto Sans", "sans-serif"]

    property var baseTypography: ({
        "fontFamily": "Inter",
        "fontFamilies": ["Inter", "Inter Display", "Cairo", "Noto Kufi Arabic", "SF Pro Display", "SF Arabic", "Noto Sans", "sans-serif"],
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

    readonly property var typography: ({
        "fontFamily": baseTypography.fontFamily || "Inter",
        "fontFamilies": baseTypography.fontFamilies || ["Inter", "Inter Display", "Cairo", "Noto Kufi Arabic", "SF Pro Display", "SF Arabic", "Noto Sans", "sans-serif"],
        "terminalFont": baseTypography.terminalFont || "JetBrainsMono Nerd Font",

        // 4-Level Semantic Type Scale (Scaled dynamically)
        "scaleDisplay":  { "size": Math.round(((baseTypography.scaleDisplay && baseTypography.scaleDisplay.size) ? baseTypography.scaleDisplay.size : 16) * root.fontScale), "weight": 600 },
        "scaleTitle":    { "size": Math.round(((baseTypography.scaleTitle && baseTypography.scaleTitle.size) ? baseTypography.scaleTitle.size : 13) * root.fontScale), "weight": 600 },
        "scaleBody":     { "size": Math.round(((baseTypography.scaleBody && baseTypography.scaleBody.size) ? baseTypography.scaleBody.size : 13) * root.fontScale), "weight": 400 },
        "scaleCaption":  { "size": Math.round(((baseTypography.scaleCaption && baseTypography.scaleCaption.size) ? baseTypography.scaleCaption.size : 11) * root.fontScale), "weight": 400 },
        "scaleMenuTitle": { "size": Math.round(((baseTypography.scaleMenuTitle && baseTypography.scaleMenuTitle.size) ? baseTypography.scaleMenuTitle.size : 12) * root.fontScale), "weight": 600 },

        // Legacy compat keys (Scaled dynamically)
        "fontSizeSmall":   Math.round((baseTypography.fontSizeSmall || 11) * root.fontScale),
        "fontSizeRegular": Math.round((baseTypography.fontSizeRegular || 13) * root.fontScale),
        "fontSizeMedium":  Math.round((baseTypography.fontSizeMedium || 15) * root.fontScale),
        "fontSizeLarge":   Math.round((baseTypography.fontSizeLarge || 18) * root.fontScale),
        "fontSizeTitle":   Math.round((baseTypography.fontSizeTitle || 22) * root.fontScale)
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
                if (parsed.mode && parsed.mode !== root.mode) {
                    root.setMode(parsed.mode);
                }
                const activePalette = (root.mode === "light")
                    ? (parsed.light || parsed.colors || {})
                    : (parsed.dark || parsed.colors || {});
                root.colors = Object.assign({}, (root.mode === "light" ? root.lightPalette : root.darkPalette), activePalette);
                if (parsed.radius) root.radius = Object.assign({}, root.radius, parsed.radius);
                if (parsed.spacing) root.spacing = Object.assign({}, root.spacing, parsed.spacing);
                if (parsed.typography) root.baseTypography = Object.assign({}, root.baseTypography, parsed.typography);
            } catch (e) {
                console.warn("[Deloway/Theme] Failed to parse theme.json:", e);
            }
        }

        onLoaded: reloadTheme()
        onTextChanged: reloadTheme()
    }

    Component.onCompleted: {
        root.setMode(root.mode);
    }
}
