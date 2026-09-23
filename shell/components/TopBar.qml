import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../services"

// TopBar — the ONE layer surface that hosts the three top capsules:
//   TimeCapsule (leading) · Notch (centre) · QuickSettingsCapsule (trailing)
//
// Why a single window: the capsules used to be three independent layer surfaces that
// tried to keep clear of each other through runtime layer-shell margin updates. Those
// updates are applied by the compositor asynchronously (and, for the quick-settings
// surface, sometimes not at all), so an expanding Notch could overlap its neighbours.
// Composing all three in one surface makes every frame self-consistent: the capsules
// reflow around the Notch inside the scene graph, in lock-step with its animation.
//
// The surface is full-width but input passes through everywhere except the union of the
// three capsule frames (see `mask`), so it never steals clicks from windows below.
PanelWindow {
    id: root

    required property ShellScreen targetScreen
    screen: targetScreen

    anchors {
        top: true
        left: true
        right: true
    }

    // Tallest capsule state (TimeCapsule dashboard) must fit; transparent + masked, so
    // the extra height never intercepts input.
    implicitHeight: 620
    color: "transparent"
    visible: !ShellState.shellHidden

    WlrLayershell.namespace: "deloway:topbar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: (ShellState.smartNotchExpanded
                                  || ShellState.timeCapsuleExpanded
                                  || ShellState.quickSettingsCapsuleExpanded)
                                 ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Only the Notch reserves space (same values as before the merge).
    exclusionMode: ShellState.shellHidden ? ExclusionMode.Ignore : ExclusionMode.Normal
    exclusiveZone: ShellState.shellHidden ? 0 : notch.reservedZone

    // Input region = union of the three capsule frames; everything else is click-through.
    mask: Region {
        item: notch.maskItem
        regions: [
            Region { item: timeCapsule.maskItem },
            Region { item: quickSettings.maskItem }
        ]
    }

    Notch {
        id: notch
        targetScreen: root.targetScreen
        z: 1
    }

    TimeCapsule {
        id: timeCapsule
        targetScreen: root.targetScreen
        z: 2
    }

    QuickSettingsCapsule {
        id: quickSettings
        targetScreen: root.targetScreen
        z: 2
    }
}
