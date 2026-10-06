// Keyboard shortcuts: every shortcut of the desktop by group, searchable, each one
// changeable — click it, press the new keys. A combination already in use says by what
// and offers to take it over; fixed families (workspace numbers, arrows, media keys) are
// listed but not re-keyed. Also: whether the wheel opens the capsules.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../theme"
import "../../../services"
import "../common"
import "../../"

Item {
    id: root

    implicitWidth: 500
    implicitHeight: mainCol.implicitHeight + (Theme.space24 * 2)
    width: parent ? parent.width : implicitWidth
    height: implicitHeight
    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    property string query: ""
    property string recordingId: ""       // the action being re-keyed
    property var pending: null            // a captured combination waiting on a conflict
    property var pendingConflict: null
    property string message: ""           // a short note under the recording row

    function startRecording(id) {
        root.pending = null;
        root.pendingConflict = null;
        root.message = "";
        root.recordingId = id;
        ShortcutService.startRecording();
        recorder.forceActiveFocus();
    }
    function stopRecording() {
        root.recordingId = "";
        root.pending = null;
        root.pendingConflict = null;
        ShortcutService.stopRecording();
    }

    // Leaving the page (or closing Settings) mid-recording gives the keys back.
    Component.onDestruction: ShortcutService.stopRecording()
    onVisibleChanged: if (!visible) root.stopRecording()

    function matches(a) {
        const q = root.query.trim().toLowerCase();
        if (!q) return true;
        if (a.ar.toLowerCase().indexOf(q) >= 0 || a.en.toLowerCase().indexOf(q) >= 0) return true;
        return a.binds.some(b => ShortcutService.comboKeys(b).join(" ").toLowerCase().indexOf(q) >= 0);
    }

    // Key capture while a row is recording. Esc cancels, Backspace (alone) removes the
    // shortcut; anything else is the new combination.
    Item {
        id: recorder
        focus: root.recordingId !== ""
        Keys.onPressed: event => {
            event.accepted = true;
            if (root.recordingId === "") return;
            const bare = (event.modifiers & (Qt.MetaModifier | Qt.ControlModifier | Qt.AltModifier | Qt.ShiftModifier)) === 0;
            if (bare && event.key === Qt.Key_Escape) { root.stopRecording(); return; }
            if (bare && event.key === Qt.Key_Backspace) {
                ShortcutService.clear(root.recordingId);
                root.stopRecording();
                return;
            }
            const combo = ShortcutService.comboFromEvent(event);
            if (!combo) return;                               // a modifier on its own: keep waiting
            if (ShortcutService.needsModifier(combo)) {
                root.message = I18n.tr("sc_needs_modifier");
                return;
            }
            const c = ShortcutService.conflict(root.recordingId, combo);
            if (c) {
                root.pending = combo;
                root.pendingConflict = c;
                ShortcutService.stopRecording();              // the keys work again while deciding
                return;
            }
            ShortcutService.assign(root.recordingId, combo, "");
            root.stopRecording();
        }
    }

    ColumnLayout {
        id: mainCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.space24
        spacing: Theme.space24

        // ── Search, guide, reset ─────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space8

            DeloTextField {
                Layout.fillWidth: true
                implicitHeight: 38
                showSearchIcon: true
                placeholderText: I18n.tr("sc_search")
                text: root.query
                onTextChanged: root.query = text
            }
            PillButton {
                text: I18n.tr("sc_open_guide")
                onClicked: ShellState.toggleCheatSheet()
            }
            PillButton {
                visible: ShortcutService.customizedCount > 0
                text: I18n.tr("sc_reset_all")
                onClicked: { root.stopRecording(); ShortcutService.resetAll(); }
            }
        }

        // ── Mouse ─────────────────────────────────────────────────────
        SettingsSection {
            visible: root.query === ""
            title: I18n.tr("sc_section_mouse")

            SettingsRow {
                title: I18n.tr("sc_capsule_wheel")
                subtitle: I18n.tr("sc_capsule_wheel_desc")
                icon: "input-mouse-symbolic"
                showDivider: false
                clickable: true
                onClicked: ConfigManager.setCapsuleWheel(!ConfigManager.capsuleWheel)

                SettingsToggle {
                    checked: ConfigManager.capsuleWheel
                    onToggled: ch => ConfigManager.setCapsuleWheel(ch)
                }
            }
        }

        // ── One section per group ─────────────────────────────────────
        Repeater {
            model: ShortcutService.groups

            delegate: SettingsSection {
                id: groupSection
                required property var modelData
                readonly property var rows: ShortcutService.actions.filter(a => a.group === groupSection.modelData.id
                                                                             && root.matches(a))
                visible: rows.length > 0
                Layout.fillWidth: true
                title: I18n.isRTL ? modelData.ar : modelData.en

                Repeater {
                    model: groupSection.rows

                    delegate: ShortcutRow {
                        required property var modelData
                        required property int index
                        action: modelData
                        showDivider: index < groupSection.rows.length - 1
                    }
                }
            }
        }

        Text {
            visible: root.query !== "" && !ShortcutService.actions.some(a => root.matches(a))
            Layout.alignment: Qt.AlignHCenter
            text: I18n.tr("sc_no_match")
            font.family: Theme.typography.fontFamily
            font.pixelSize: Theme.fontSize(12)
            color: Theme.notchTextTertiary
            renderType: Theme.renderType
        }
    }

    // ── A shortcut row ──────────────────────────────────────────────────
    component ShortcutRow: SettingsRow {
        id: row
        property var action
        readonly property bool isRecording: root.recordingId === action.id
        readonly property bool isDeciding: isRecording && root.pendingConflict !== null
        readonly property var extra: action.binds.slice(1)

        title: ShortcutService.label(action)
        subtitle: {
            if (isRecording && root.message) return root.message;
            if (isDeciding) {
                const c = root.pendingConflict;
                return (c.fixed || c.foreign) ? I18n.tr("sc_reserved").arg(I18n.isolate(c.label))
                                              : I18n.tr("sc_in_use").arg(I18n.isolate(c.label));
            }
            if (isRecording) return I18n.tr("sc_recording_hint");
            if (action.fixed) return I18n.tr("sc_fixed");
            if (action.binds.length === 0) return I18n.tr("sc_none");
            if (extra.length > 0)
                return I18n.tr("sc_also") + " " + extra.map(b => I18n.ltr(ShortcutService.comboKeys(b).join(" + "))).join("  ·  ");
            return action.customized ? I18n.tr("sc_customized") : "";
        }

        // While deciding on a conflict: take it over, or cancel
        RowLayout {
            visible: row.isDeciding
            spacing: Theme.space4
            PillButton {
                visible: row.isDeciding && !root.pendingConflict.fixed && !root.pendingConflict.foreign
                primary: true
                text: I18n.tr("sc_replace")
                onClicked: {
                    ShortcutService.assign(row.action.id, root.pending, root.pendingConflict.id);
                    root.stopRecording();
                }
            }
            PillButton {
                text: I18n.tr("sc_cancel")
                onClicked: root.stopRecording()
            }
        }

        // Reset to the default
        Rectangle {
            visible: row.action.customized && !row.isRecording
            implicitWidth: 28
            implicitHeight: 28
            radius: 14
            color: resetMa.containsMouse ? Theme.notchSurfaceHover : "transparent"
            SymbolicIcon {
                anchors.centerIn: parent
                source: "edit-undo-symbolic"
                iconSize: 14
                iconColor: resetMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
            }
            MouseArea {
                id: resetMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ShortcutService.reset(row.action.id)
            }
        }

        // The combination: click to record a new one
        Rectangle {
            visible: !row.isDeciding
            implicitHeight: 32
            implicitWidth: row.isRecording ? recLabel.implicitWidth + Theme.space24
                                           : Math.max(64, combo.implicitWidth + Theme.space16)
            radius: Theme.radiusSmall + 2
            color: row.isRecording ? Theme.notchSurfaceActive
                 : (comboMa.containsMouse && !row.action.fixed ? Theme.notchSurfaceHover : "transparent")
            border.width: 1
            border.color: row.isRecording ? Theme.notchBorderHighlight
                        : (comboMa.containsMouse && !row.action.fixed ? Theme.notchBorder : "transparent")
            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

            KeyCombo {
                id: combo
                anchors.centerIn: parent
                visible: !row.isRecording && row.action.binds.length > 0
                keys: ShortcutService.actionKeys(row.action)
                dim: !!row.action.fixed
            }
            Text {
                anchors.centerIn: parent
                visible: !row.isRecording && row.action.binds.length === 0
                text: I18n.tr("sc_set")
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(11)
                color: Theme.notchTextSecondary
                renderType: Theme.renderType
            }
            Text {
                id: recLabel
                anchors.centerIn: parent
                visible: row.isRecording
                text: I18n.tr("sc_press_keys")
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(11)
                font.weight: Font.DemiBold
                color: Theme.notchText
                renderType: Theme.renderType
                SequentialAnimation on opacity {
                    running: row.isRecording
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.45; duration: 600; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                }
            }
            MouseArea {
                id: comboMa
                anchors.fill: parent
                hoverEnabled: true
                enabled: !row.action.fixed
                cursorShape: row.action.fixed ? Qt.ArrowCursor : Qt.PointingHandCursor
                onClicked: row.isRecording ? root.stopRecording() : root.startRecording(row.action.id)
            }
        }
    }

    // ── A small pill button ─────────────────────────────────────────────
    component PillButton: Rectangle {
        id: btn
        property string text: ""
        property bool primary: false
        signal clicked()
        implicitHeight: 30
        implicitWidth: btnText.implicitWidth + Theme.space24
        radius: 15
        color: btn.primary ? Theme.inverseSurface : (btnMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
        border.width: 1
        border.color: btn.primary ? Theme.inverseSurface : Theme.notchBorderSubtle
        Text {
            id: btnText
            anchors.centerIn: parent
            text: btn.text
            font.family: Theme.typography.fontFamily
            font.pixelSize: Theme.fontSize(11)
            font.weight: Font.Medium
            color: btn.primary ? Theme.inverseText : Theme.notchText
            renderType: Theme.renderType
        }
        MouseArea {
            id: btnMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }
}
