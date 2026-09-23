pragma Singleton
import QtQuick
import Quickshell
import "../services"

Item {
    id: root

    // ── Single source of truth: ConfigManager.themeMode (persisted in deloway.json).
    // Everything here is DERIVED — nothing assigns mode/colors imperatively, and
    // nothing is read from or written to theme.json at runtime any more (that file
    // used to override the mode and fed scaled font sizes back in as the base).
    // The typeof guard stays: Theme and ConfigManager import each other.
    readonly property string mode: (typeof ConfigManager !== "undefined" && ConfigManager.themeMode === "light")
                                   ? "light" : "dark"
    readonly property bool isDark: mode === "dark"
    readonly property real fontScale: (typeof ConfigManager !== "undefined" && ConfigManager.fontSizeScale)
                                     ? ConfigManager.fontSizeScale : 1.0
    readonly property string fontFamily: (typeof ConfigManager !== "undefined" && ConfigManager.fontFamily)
                                         ? ConfigManager.fontFamily : "Cairo"

    function fontSize(baseSize) {
        return Math.round(baseSize * root.fontScale);
    }


    // -------------------------------------------------------------------------
    // Performance Tiers (NewPlan.md §3)
    // 0 = Efficient (No blur, opacity-only fades, no heavy shadows)
    // 1 = Balanced  (Controlled blur on primary layer, standard motion)
    // 2 = High      (Full Mica/Acrylic glass, layered shadows, full curves)
    // -------------------------------------------------------------------------
    readonly property int performanceTier: (typeof ConfigManager !== "undefined" && ConfigManager.performanceTier !== undefined)
                                           ? ConfigManager.performanceTier : 1

    readonly property bool enableShadows: performanceTier >= 1

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
    // "Shell Corner Radius" (Settings → Appearance) scales every card/tile/control radius.
    // 8px = 1.0 (design default); 4px ≈ 0.67 (sharp); 14px = 1.5 (rounded).
    // Outer capsule/notch/dock silhouettes are geometry, not "corners", and stay fixed.
    readonly property real radiusScale: {
        const r = (typeof ConfigManager !== "undefined" && ConfigManager.elementRadius !== undefined) ? ConfigManager.elementRadius : 8;
        return Math.max(0.5, Math.min(1.6, 1 + (r - 8) / 12));
    }
    function scaledRadius(base) { return Math.round(base * root.radiusScale); }

    readonly property int radiusSmall: scaledRadius(6)
    readonly property int radiusMedium: scaledRadius(10)
    readonly property int radiusLarge: scaledRadius(14)

    // -------------------------------------------------------------------------
    // Spacing Tokens (NewPlan.md §4.3) - 8pt Grid
    // -------------------------------------------------------------------------
    readonly property int space4: 4
    readonly property int space6: 6
    readonly property int space8: 8
    readonly property int space12: 12
    readonly property int space16: 16
    readonly property int space20: 20
    readonly property int space24: 24
    readonly property int space48: 48

    // Legacy palette, re-based on neutral greys (was blue-slate: #101318, #1b202c,
    // #9da7be…). Tertiary/muted text meet WCAG AA on their surfaces.
    readonly property var darkPalette: ({
        "background": "#000000",
        "backgroundAlt": "#0a0a0a",
        "surface": "#0d0d0d",
        "surfaceLayer1": "#0d0d0d",
        "surfaceLayer2": "#141414",
        "surfaceCard": "#0d0d0d",
        "surfaceElevated": "#141414",
        "surfaceHover": "#1c1c1c",
        "surfaceActive": "#262626",
        "surfaceVariant": "#0a0a0a",
        "border": "#262626",
        "borderSubtle": "#1a1a1a",
        "borderHighlight": "#404040",
        "primary": "#ffffff",
        "primaryHover": "#e5e5e5",
        "primaryActive": "#d4d4d4",
        "accent": "#ffffff",
        "accentSecondary": "#a3a3a3",
        "accentText": "#000000",
        "text": "#ffffff",
        "textPrimary": "#ffffff",
        "textSecondary": "#a3a3a3",
        "textTertiary": "#808080",
        "textMuted": "#808080",
        "activeIndicator": "#ffffff",
        "urgent": "#ef4444",
        "danger": "#ef4444",
        "warning": "#f59e0b",
        "success": "#10b981",
        "folderBase": "#d4d4d4",
        "folderAccent": "#a3a3a3",
        "folderHighlight": "#e5e5e5",
        "folderEmblem": "#ffffff"
    })

    readonly property var lightPalette: ({
        "background": "#f5f5f5",
        "backgroundAlt": "#ebebeb",
        "surface": "#ffffff",
        "surfaceLayer1": "#ffffff",
        "surfaceLayer2": "#fafafa",
        "surfaceCard": "#ffffff",
        "surfaceElevated": "#ffffff",
        "surfaceHover": "#f0f0f0",
        "surfaceActive": "#e5e5e5",
        "surfaceVariant": "#fafafa",
        "border": "#d4d4d4",
        "borderSubtle": "#e5e5e5",
        "borderHighlight": "#a3a3a3",
        "primary": "#0f172a",
        "primaryHover": "#262626",
        "primaryActive": "#404040",
        "accent": "#0f172a",
        "accentSecondary": "#525252",
        "accentText": "#ffffff",
        "text": "#111827",
        "textPrimary": "#111827",
        "textSecondary": "#525252",
        "textTertiary": "#6b6b6b",
        "textMuted": "#6b6b6b",
        "activeIndicator": "#0f172a",
        "urgent": "#ef4444",
        "danger": "#ef4444",
        "warning": "#d97706",
        "success": "#059669",
        "folderBase": "#525252",
        "folderAccent": "#404040",
        "folderHighlight": "#737373",
        "folderEmblem": "#ffffff"
    })

    readonly property var colors: isDark ? darkPalette : lightPalette

    // ── Mode-aware tokens that replace raw `isDark ? "#hex" : "#hex"` in components ──
    readonly property color inverseSurface: isDark ? "#ffffff" : "#0f172a"   // selected pill / primary fill
    readonly property color inverseText: isDark ? "#000000" : "#ffffff"      // text/knob on inverseSurface
    readonly property color textSelection: isDark ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(0, 0, 0, 0.20)
    readonly property color selectedSurface: isDark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)
    readonly property color toggleKnobOff: isDark ? "#ffffff" : "#737373"
    readonly property color wallpaperTint: isDark ? Qt.alpha(colors.background, 0.15) : Qt.alpha(colors.text, 0.07)
    readonly property color captionScrim: Qt.alpha(notchBackground, 0.85)   // text strips over images
    readonly property color modalScrim: Qt.rgba(0, 0, 0, 0.60)             // neutral dim behind dialogs
    readonly property color primaryHover: colors.primaryHover

    // Direct color accessors for cleaner QML code
    readonly property color accent: colors.accent || (isDark ? "#ffffff" : "#0f172a")
    readonly property color textOnAccent: isDark ? "#000000" : "#ffffff"
    readonly property color textOnPrimary: isDark ? "#000000" : "#ffffff"
    readonly property color urgent: colors.urgent || "#ef4444"
    readonly property color danger: colors.danger || urgent
    readonly property color warning: colors.warning || "#f59e0b"


    // Fluent materials — opacity used for Mica / Acrylic surfaces

    // Reactive overlays — derive from text so they invert with the theme mode
    readonly property color overlayHover: Qt.alpha(colors.text, 0.065)
    readonly property color overlayHoverStrong: Qt.alpha(colors.text, 0.10)
    readonly property color hairline: Qt.alpha(colors.text, 0.08)

    // -------------------------------------------------------------------------
    // Dynamic Deep Black / Notch Surface Tokens (Unified OLED / Clean Light)
    // -------------------------------------------------------------------------
    readonly property color notchBackground: isDark ? "#000000" : "#ffffff"
    readonly property color notchText: isDark ? "#ffffff" : "#0f172a"
    readonly property color notchTextSecondary: isDark ? Qt.rgba(1, 1, 1, 0.70) : Qt.rgba(0, 0, 0, 0.65)
    readonly property color notchTextTertiary: isDark ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(0, 0, 0, 0.45)
    // Reading-text tokens for dense surfaces (notifications). OPAQUE neutral greys instead of
    // alpha: alpha text over black/blur renders thin and washed-out with native hinting,
    // especially for Arabic strokes. Body ≈ 88% luminance, meta ≈ 70% (dark mode).
    readonly property color notchTextBody: isDark ? Qt.rgba(0.88, 0.88, 0.88, 1) : Qt.rgba(0.14, 0.14, 0.14, 1)
    readonly property color notchTextMeta: isDark ? Qt.rgba(0.70, 0.70, 0.70, 1) : Qt.rgba(0.34, 0.34, 0.34, 1)
    readonly property color notchSurface: isDark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.04)
    readonly property color notchSurfaceElevated: isDark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.07)
    readonly property color notchSurfaceHover: isDark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08)
    readonly property color notchSurfaceActive: isDark ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.12)
    readonly property color notchBorder: isDark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.10)
    readonly property color notchBorderSubtle: isDark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.06)
    readonly property color notchBorderHighlight: isDark ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(0, 0, 0, 0.18)
    readonly property color notchShadow: isDark ? Qt.rgba(0, 0, 0, 0.50) : Qt.rgba(0, 0, 0, 0.12)
    readonly property int notchRadiusWindow: 26
    readonly property int notchRadiusPanel: scaledRadius(16)
    readonly property int notchRadiusCard: scaledRadius(12)
    readonly property int notchRadiusPill: scaledRadius(8)
    readonly property int radiusDock: 24

    // Dock Tokens (Unified with OLED Notch/Capsule aesthetic)
    // Flat and opaque: no blur, shadow or glow around the Dock (clean edges on any wallpaper).
    readonly property color dockGlass: notchBackground
    readonly property color dockBorder: notchBorder
    readonly property color dockDot: isDark ? Qt.rgba(1, 1, 1, 0.95) : Qt.rgba(0, 0, 0, 0.85)
    readonly property color dockDivider: notchBorderHighlight
    readonly property color dockDividerFaint: notchBorder               // pinned | running
    readonly property color dockIndicator: dockDot                        // focused app pill
    readonly property color dockIndicatorIdle: isDark ? Qt.rgba(1, 1, 1, 0.50) : Qt.rgba(0, 0, 0, 0.42)
    readonly property color dockActiveWell: isDark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.06)

    // Semantic Component Tokens (Dark / Light adaptive)
    readonly property color calendarPast: isDark ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(0, 0, 0, 0.45)
    readonly property color calendarFuture: isDark ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(0, 0, 0, 0.45)

    // Quick Settings Capsule Tokens (4px unit grid, refined scale)
    readonly property int qsTileHeight: 52
    readonly property int qsTileRadius: scaledRadius(16)
    readonly property int qsCardRadius: scaledRadius(16)
    readonly property int qsPadding: 12

    readonly property color qsTileBackground: isDark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.04)
    readonly property color qsTileBackgroundHover: isDark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.07)
    readonly property color qsTileBorder: isDark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.06)
    readonly property color qsTileIconCircleInactive: isDark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.07)
    readonly property color qsTileActive: isDark ? "#ffffff" : colors.textPrimary
    readonly property color qsTileIconActive: isDark ? "#000000" : "#ffffff"
    readonly property color qsSliderTrack: notchSurfaceElevated
    readonly property color qsSliderTrackHover: notchSurfaceHover
    readonly property color notchSliderFill: isDark ? "#ffffff" : "#0f172a"
    readonly property color qsSliderFill: notchSliderFill
    readonly property color qsSliderIconActive: isDark ? "#000000" : "#ffffff"

    // Workspace Indicator Tokens (collapsed Notch)
    // Every state has a FIXED slot width that never depends on hover, so hovering can
    // never change the row width (and therefore never resizes the Notch).
    readonly property int wsDotSize:            7     // empty workspace dot
    readonly property int wsEmptySlot:          12    // fixed slot around the dot (hit target)
    readonly property int wsCircleSize:         30    // occupied workspace
    readonly property int wsPillHeight:         32    // active workspace
    readonly property int wsPillBase:           32    // pill width: number only (active, no icons)
    readonly property int wsPillIconGap:        5     // gap between number and icon area in pill
    readonly property int wsIconSizeSingle:     17    // icon size when 1 shown (circle or pill)
    readonly property int wsIconSizeDouble:     14    // each icon size when 2 overlapping
    readonly property int wsIconOverlapOffset:  9     // horizontal offset of 2nd icon centre
    readonly property int wsBadgeSize:          14
    readonly property int wsIndicatorSpacing:   6

    // kept for back-compat

    // Workspace colours — OLED monochrome identity
    readonly property color wsActiveBg:    isDark ? "#ffffff" : "#0f172a"
    readonly property color wsActiveText:  isDark ? "#000000" : "#ffffff"
    readonly property color wsOccupiedBg:  isDark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(0, 0, 0, 0.09)
    readonly property color wsEmptyBg:     isDark ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(0, 0, 0, 0.22)

    // Exclusion & Strut Geometry Tokens (Reserved Space)
    readonly property int topBarMarginTop: 8
    // In layer-shell on Hyprland, windows are placed at (exclusiveZone + gaps_out).
    // With gaps_out = 6, setting exclusiveZone = 54 results in window top at 60px.
    // Since capsules sit from y = topBarMarginTop (8px) to 8 + 44 = 52px,
    // this leaves exactly an 8px gap above (from screen top) and an 8px gap below (to window border).
    readonly property int topBarExclusiveZone: 54 // 54px
    readonly property int topBarReserved: 54 // 54px

    // Top-bar capsule geometry (single source of truth for Notch + side capsules).
    // Side capsules are positioned INSIDE their own fixed layer surface relative to
    // the screen centre, so reflow never depends on runtime layer-shell margin updates.
    readonly property int notchEarRadius: 18
    readonly property int notchExpandedWidth: 600
    readonly property int capsuleGap: space20        // minimum clearance between notch and a side capsule
    readonly property int capsuleEdgeMargin: space8  // minimum clearance between a capsule and the screen edge

    readonly property int dockMarginBottom: 10
    readonly property int dockGap: 8
    function dockExclusiveZoneFor(dockHeight) {
        return Math.round((dockHeight > 0 ? dockHeight : 68) + dockGap); // 76px
    }
    function dockReservedFor(dockHeight) {
        return Math.round((dockHeight > 0 ? dockHeight : 68) + dockMarginBottom + dockGap); // 86px
    }
    readonly property int dockReserved: dockReservedFor(68) // 86px

    property var baseRadius: ({
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

    readonly property var radius: {
        const out = {};
        for (const k in root.baseRadius) {
            const v = root.baseRadius[k];
            out[k] = (k === "pill" || k === "none") ? v : Math.round(v * root.radiusScale);
        }
        return out;
    }

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

    property var baseTypography: ({
        "fontFamily": root.fontFamily,
        "fontFamilies": ["Cairo", "Readex Pro", "Rubik", "Noto Kufi Arabic", "Inter", "sans-serif"],
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
        "fontFamily": root.fontFamily,
        "fontFamilies": baseTypography.fontFamilies || ["Cairo", "Readex Pro", "Rubik", "Noto Kufi Arabic", "Inter", "sans-serif"],
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
}
