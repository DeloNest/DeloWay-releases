import "../services"
import "../theme"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property ShellScreen targetScreen
    readonly property bool isActive: (!ConfigManager.setupCompleted || ShellState.setupWizardOpen)
    readonly property bool dismissible: ConfigManager.setupCompleted
    property int currentStep: 0
    readonly property int totalSteps: 7
    property int previousStep: 0

    function stepTitle(step) {
        if (I18n.isRTL) {
            switch (step) {
            case 0:
                return "لغة واجهة النظام والتخطيط";
            case 1:
                return "المظهر البصري وهوية النظام";
            case 2:
                return "نمط مساحة سطح المكتب";
            case 3:
                return "الشريط العائم وشاشة نوتش";
            case 4:
                return "التطبيقات والبرامج الأساسية";
            case 5:
                return "إدارة وترتيب النوافذ";
            case 6:
                return "اختصارات التحكم والإطلاق";
            default:
                return "إعداد DeloWay";
            }
        } else {
            switch (step) {
            case 0:
                return "Interface Language & Layout";
            case 1:
                return "Visual Appearance & Theme";
            case 2:
                return "Desktop Experience Mode";
            case 3:
                return "Dock & Dynamic Notch";
            case 4:
                return "Default Applications";
            case 5:
                return "Window Management & Layout";
            case 6:
                return "Keybindings & Finish";
            default:
                return "DeloWay Setup";
            }
        }
    }

    function stepSubtitle(step) {
        if (I18n.isRTL) {
            switch (step) {
            case 0:
                return "اختر لغة النظام المفضلة لديك وتخطيط الاتجاه لتجربة استخدام متقنة ومريحة.";
            case 1:
                return "اختر بيئة العرض المناسبة لشاشتك: داكن لشاشات OLED، أو زجاجي أكريليك، أو فاتح ناصع.";
            case 2:
                return "حدد أسلوب مساحة سطح المكتب المناسب لإنتاجيتك بين البساطة والأدوات التفاعلية.";
            case 3:
                return "تخصيص سلوك إخفاء شريط التطبيقات، وشكل الساعة، وتكامل شاشة النوتش الحية.";
            case 4:
                return "حدد البرامج الافتراضية لكل مهمة من مهام النظام الأساسية.";
            case 5:
                return "اختر المسافات الهندسية بين النوافذ وتدوير الحواف الملائم لشاشتك.";
            case 6:
                return "أهم الاختصارات السريعة للتحكم بالنظام بفعالية وسرعة.";
            default:
                return "";
            }
        } else {
            switch (step) {
            case 0:
                return "Choose your preferred interface language and layout direction for optimal ergonomics.";
            case 1:
                return "Select your visual environment: Dark for pure OLED blacks, Glass acrylic, or Crisp Light.";
            case 2:
                return "Configure your workspace surface between minimal canvas or interactive widgets.";
            case 3:
                return "Configure application dock auto-hide behavior, clock display, and Dynamic Notch integration.";
            case 4:
                return "Select your primary default applications for essential daily workflows.";
            case 5:
                return "Choose geometric window gaps and corner radiuses tailored to your display.";
            case 6:
                return "Essential keyboard shortcuts to navigate and control DeloWay efficiently.";
            default:
                return "";
            }
        }
    }

    function goToStep(step) {
        var target = Math.max(0, Math.min(root.totalSteps - 1, step));
        if (target !== root.currentStep) {
            root.previousStep = root.currentStep;
            root.currentStep = target;
        }
    }

    function nextStep() {
        if (root.currentStep < root.totalSteps - 1)
            root.goToStep(root.currentStep + 1);
        else
            root.finishSetup();
    }

    function prevStep() {
        if (root.currentStep > 0)
            root.goToStep(root.currentStep - 1);

    }

    function finishSetup() {
        ConfigManager.completeSetup();
        ShellState.closeSetupWizard();
    }

    screen: targetScreen
    color: "transparent"
    WlrLayershell.namespace: "deloway:setup-wizard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.isActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    visible: root.isActive || wizardCard.opacity > 0.01

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Connections {
        function onSetupWizardStepRequested(step) {
            root.goToStep(step);
        }

        target: ShellState
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.isActive && root.dismissible
        onActivated: ShellState.closeSetupWizard()
    }

    Shortcut {
        sequence: "Return"
        enabled: root.isActive
        onActivated: root.nextStep()
    }

    Shortcut {
        sequence: "Right"
        enabled: root.isActive && (I18n.isRTL ? root.currentStep > 0 : root.currentStep < root.totalSteps - 1)
        onActivated: I18n.isRTL ? root.prevStep() : root.nextStep()
    }

    Shortcut {
        sequence: "Left"
        enabled: root.isActive && (I18n.isRTL ? root.currentStep < root.totalSteps - 1 : root.currentStep > 0)
        onActivated: I18n.isRTL ? root.nextStep() : root.prevStep()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Surface Backdrop Scrim
    // Prevents desktop clicks and provides cinematic dimming
    // ─────────────────────────────────────────────────────────────────────────
    Rectangle {
        id: backdropRect

        anchors.fill: parent
        color: Theme.isDark ? Theme.oobeBackdropDark : Theme.oobeBackdropLight
        opacity: root.isActive ? 1 : 0

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            onWheel: function(wheel) {
                wheel.accepted = true;
            }
            onClicked: {
                if (root.dismissible)
                    ShellState.closeSetupWizard();

            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Theme.easingEnter
            }

        }

    }

    // ─────────────────────────────────────────────────────────────────────────
    // Centered Setup Card
    // ─────────────────────────────────────────────────────────────────────────
    Rectangle {
        id: wizardCard

        anchors.centerIn: parent
        width: Math.min(Theme.oobePanelWidth, root.width - 48)
        height: Math.min(Theme.oobePanelHeight, root.height - 48)
        radius: Theme.radiusLarge
        color: Theme.capsuleFill
        border.color: Theme.capsuleBorder
        border.width: 1
        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true
        opacity: root.isActive ? 1 : 0
        scale: root.isActive ? 1 : 0.96
        transformOrigin: Item.Center

        MouseArea {
            anchors.fill: parent
            // Intercept clicks on empty card surfaces so backdrop dismiss is not triggered
            onClicked: {
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.space24
            spacing: Theme.space16

            // ─────────────────────────────────────────────────────────────
            // HEADER: Monogram, Step Title, Progress Bar, Close Button
            // ─────────────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                // DeloWay Geometric Monogram
                Rectangle {
                    width: 44
                    height: 44
                    radius: Theme.radiusMedium
                    color: Theme.notchSurfaceElevated
                    border.color: Theme.notchBorderSubtle
                    border.width: 1

                    Grid {
                        anchors.centerIn: parent
                        columns: 2
                        rows: 2
                        spacing: 3

                        Repeater {
                            model: 4

                            Rectangle {
                                width: 8
                                height: 8
                                radius: 2
                                color: Theme.colors.text
                            }

                        }

                    }

                }

                // Brand Wordmark & Dynamic Step Header
                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true

                    Text {
                        text: "DELOWAY"
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(10)
                        font.weight: Font.Bold
                        font.letterSpacing: Theme.oobeLetterSpacing
                        color: Theme.colors.textSecondary
                        renderType: Theme.renderType
                    }

                    Text {
                        text: root.stepTitle(root.currentStep)
                        font.family: Theme.typography.fontFamily
                        font.hintingPreference: Theme.hintingPreference
                        font.pixelSize: Theme.fontSize(16)
                        font.weight: Font.DemiBold
                        renderType: Theme.renderType
                        color: Theme.colors.text
                    }

                }

                // Interactive Step Navigation Pills
                RowLayout {
                    spacing: 6

                    Repeater {
                        model: root.totalSteps

                        Rectangle {
                            id: pill

                            required property int index
                            readonly property bool isCurrent: index === root.currentStep
                            readonly property bool isPast: index < root.currentStep

                            width: isCurrent ? 26 : 8
                            height: 8
                            radius: 4
                            color: isCurrent ? Theme.inverseSurface : (isPast ? Theme.colors.borderHighlight : Theme.colors.surfaceHover)

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: (pill.isPast || pill.isCurrent) ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (pill.isPast)
                                        root.goToStep(pill.index);

                                }
                            }

                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.motionFast
                                    easing.type: Theme.easingEnter
                                }

                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.motionFast
                                    easing.type: Theme.easingEnter
                                }

                            }

                        }

                    }

                }

                // Dismiss Button (Only when opened post-install)
                Rectangle {
                    visible: root.dismissible
                    width: 30
                    height: 30
                    radius: 15
                    color: closeMa.containsMouse ? Theme.colors.surfaceHover : "transparent"
                    border.color: closeMa.containsMouse ? Theme.colors.borderSubtle : "transparent"
                    border.width: 1

                    SymbolicIcon {
                        anchors.centerIn: parent
                        iconSize: 14
                        source: "window-close-symbolic"
                        iconColor: Theme.colors.textSecondary
                    }

                    MouseArea {
                        id: closeMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShellState.closeSetupWizard()
                    }

                }

            }

            // Header Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.colors.borderSubtle
            }

            // ─────────────────────────────────────────────────────────────
            // BODY: Container for the 7 Step Views
            // ─────────────────────────────────────────────────────────────
            Item {
                id: bodyContainer

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // =========================================================
                // STEP 0: LANGUAGE & REGIONAL ALIGNMENT
                // =========================================================
                ColumnLayout {
                    id: step0View

                    anchors.fill: parent
                    spacing: Theme.space16
                    visible: opacity > 0.001
                    opacity: root.currentStep === 0 ? 1 : 0
                    enabled: root.currentStep === 0

                    Text {
                        text: root.stepSubtitle(0)
                        font.family: Theme.typography.fontFamily
                        font.hintingPreference: Theme.hintingPreference
                        font.pixelSize: Theme.fontSize(12)
                        renderType: Theme.renderType
                        color: Theme.colors.textSecondary
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Theme.space16

                        // English (LTR)
                        DeloCard {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            hoverable: true
                            selected: ConfigManager.uiLanguage === "en"
                            cardRadius: Theme.radiusMedium
                            onClicked: ConfigManager.setUiLanguage("en")

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: Theme.space12

                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    width: 46
                                    height: 32
                                    radius: Theme.radiusSmall
                                    color: ConfigManager.uiLanguage === "en" ? Theme.inverseSurface : Theme.colors.surfaceElevated

                                    Text {
                                        anchors.centerIn: parent
                                        text: "EN"
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(13)
                                        font.weight: Font.Bold
                                        color: ConfigManager.uiLanguage === "en" ? Theme.inverseText : Theme.colors.text
                                    }

                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "English (United States)"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(14)
                                    font.weight: Font.DemiBold
                                    renderType: Theme.renderType
                                    color: Theme.colors.text
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Left-to-Right (LTR) desktop layout\nSF Pro & Inter typography"
                                    horizontalAlignment: Text.AlignHCenter
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(11)
                                    renderType: Theme.renderType
                                    color: Theme.colors.textSecondary
                                }

                                // Selection Status Pill
                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    implicitWidth: enStatusText.implicitWidth + 16
                                    height: 22
                                    radius: 11
                                    color: ConfigManager.uiLanguage === "en" ? Theme.inverseSurface : Theme.colors.surfaceHover

                                    Text {
                                        id: enStatusText

                                        anchors.centerIn: parent
                                        text: ConfigManager.uiLanguage === "en" ? "Selected" : "Select"
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(10)
                                        font.weight: Font.DemiBold
                                        color: ConfigManager.uiLanguage === "en" ? Theme.inverseText : Theme.colors.textSecondary
                                    }

                                }

                            }

                        }

                        // Arabic (RTL)
                        DeloCard {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            hoverable: true
                            selected: ConfigManager.uiLanguage === "ar"
                            cardRadius: Theme.radiusMedium
                            onClicked: ConfigManager.setUiLanguage("ar")

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: Theme.space12

                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    width: 46
                                    height: 32
                                    radius: Theme.radiusSmall
                                    color: ConfigManager.uiLanguage === "ar" ? Theme.inverseSurface : Theme.colors.surfaceElevated

                                    Text {
                                        anchors.centerIn: parent
                                        text: "ع"
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(15)
                                        font.weight: Font.Bold
                                        color: ConfigManager.uiLanguage === "ar" ? Theme.inverseText : Theme.colors.text
                                    }

                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "العربية (المملكة العربية السعودية)"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(14)
                                    font.weight: Font.DemiBold
                                    renderType: Theme.renderType
                                    color: Theme.colors.text
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "واجهة متكاملة من اليمين إلى اليسار (RTL)\nخط Cairo العربي المتقن"
                                    horizontalAlignment: Text.AlignHCenter
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(11)
                                    renderType: Theme.renderType
                                    color: Theme.colors.textSecondary
                                }

                                // Selection Status Pill
                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    implicitWidth: arStatusText.implicitWidth + 16
                                    height: 22
                                    radius: 11
                                    color: ConfigManager.uiLanguage === "ar" ? Theme.inverseSurface : Theme.colors.surfaceHover

                                    Text {
                                        id: arStatusText

                                        anchors.centerIn: parent
                                        text: ConfigManager.uiLanguage === "ar" ? "محدد" : "اختيار"
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(10)
                                        font.weight: Font.DemiBold
                                        color: ConfigManager.uiLanguage === "ar" ? Theme.inverseText : Theme.colors.textSecondary
                                    }

                                }

                            }

                        }

                    }

                    // Regional Info Banner
                    DeloCard {
                        Layout.fillWidth: true
                        height: 48
                        cardRadius: Theme.radiusSmall
                        surfaceColor: Theme.colors.surfaceVariant

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.space16
                            anchors.rightMargin: Theme.space16
                            spacing: 10

                            SymbolicIcon {
                                iconSize: 16
                                source: "preferences-desktop-locale-symbolic"
                                iconColor: Theme.colors.textSecondary
                            }

                            Text {
                                Layout.fillWidth: true
                                text: I18n.isRTL ? "يمكنك تخصيص نوع الخط، والأرقام، وتنسيق التواريخ في أي وقت من الإعدادات ← اللغة والمنطقة." : "You can adjust fonts, numbering systems, and date formats anytime in Settings → Region & Language."
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                color: Theme.colors.textSecondary
                                elide: Text.ElideRight
                            }

                        }

                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.motionFast
                            easing.type: Theme.easingEnter
                        }

                    }

                }

                // =========================================================
                // STEP 1: SYSTEM THEME & ACRYLIC FINISH (DARK / GLASS / LIGHT)
                // =========================================================
                ColumnLayout {
                    id: step1View

                    anchors.fill: parent
                    spacing: Theme.space12
                    visible: opacity > 0.001
                    opacity: root.currentStep === 1 ? 1 : 0
                    enabled: root.currentStep === 1

                    Text {
                        text: root.stepSubtitle(1)
                        font.family: Theme.typography.fontFamily
                        font.hintingPreference: Theme.hintingPreference
                        font.pixelSize: Theme.fontSize(12)
                        renderType: Theme.renderType
                        color: Theme.colors.textSecondary
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 12

                        // ── Theme 1: Dark (OLED) ──
                        DeloCard {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            hoverable: true
                            selected: ConfigManager.themeName === "dark"
                            cardRadius: Theme.radiusMedium
                            onClicked: ConfigManager.setTheme("dark")

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.space12
                                spacing: 8

                                // Mini Desktop Preview (Dark OLED)
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 110
                                    radius: Theme.radiusSmall
                                    color: Theme.darkPalette.background
                                    border.color: Theme.darkPalette.borderSubtle
                                    border.width: 1

                                    // Mini Notch (Solid White Contrast)
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.topMargin: 4
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 44
                                        height: 8
                                        radius: 4
                                        color: Theme.darkPalette.activeTabBackground
                                    }

                                    // Mini Window Card
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 116
                                        height: 48
                                        radius: 5
                                        color: Theme.darkPalette.inactiveTabBackground
                                        border.color: Theme.darkPalette.borderSubtle
                                        border.width: 1

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 4

                                            Rectangle {
                                                width: 50
                                                height: 3
                                                radius: 1.5
                                                color: Theme.darkPalette.text
                                            }

                                            Rectangle {
                                                width: 80
                                                height: 3
                                                radius: 1.5
                                                color: Theme.darkPalette.inactiveTabForeground
                                            }

                                        }

                                    }

                                    // Mini Dock
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 4
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 60
                                        height: 8
                                        radius: 4
                                        color: Theme.darkPalette.inactiveTabBackground
                                        border.color: Theme.darkPalette.borderSubtle
                                        border.width: 1

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 3

                                            Repeater {
                                                model: 4

                                                Rectangle {
                                                    width: 4
                                                    height: 4
                                                    radius: 1
                                                    color: Theme.darkPalette.text
                                                }

                                            }

                                        }

                                    }

                                }

                                Text {
                                    text: I18n.isRTL ? "داكن OLED" : "Dark (OLED)"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(13)
                                    font.weight: Font.DemiBold
                                    renderType: Theme.renderType
                                    color: Theme.colors.text
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: I18n.isRTL ? "أسود نقي (#000000)، تباين بصري فائق وموفر للطاقة." : "Pure OLED blacks (#000000), battery efficient, zero glare."
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(10)
                                    renderType: Theme.renderType
                                    color: Theme.colors.textSecondary
                                    wrapMode: Text.WordWrap
                                }

                            }

                        }

                        // ── Theme 2: Glass (Acrylic) ──
                        DeloCard {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            hoverable: true
                            selected: ConfigManager.themeName === "glass"
                            cardRadius: Theme.radiusMedium
                            onClicked: ConfigManager.setTheme("glass")

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.space12
                                spacing: 8

                                // Mini Desktop Preview (Glass Acrylic)
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 110
                                    radius: Theme.radiusSmall
                                    color: Theme.glassPalette.background
                                    border.color: Theme.glassPalette.borderSubtle
                                    border.width: 1

                                    // Subtle Frosted Sheen Overlay
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.radiusSmall
                                        color: Qt.rgba(1, 1, 1, 0.05)
                                    }

                                    // Mini Notch (Frosted Glass)
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.topMargin: 4
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 44
                                        height: 8
                                        radius: 4
                                        color: Qt.rgba(1, 1, 1, 0.22)
                                        border.color: Qt.rgba(1, 1, 1, 0.35)
                                        border.width: 1
                                    }

                                    // Mini Floating Window Card
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 116
                                        height: 48
                                        radius: 5
                                        color: Qt.rgba(1, 1, 1, 0.12)
                                        border.color: Qt.rgba(1, 1, 1, 0.25)
                                        border.width: 1

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 4

                                            Rectangle {
                                                width: 50
                                                height: 3
                                                radius: 1.5
                                                color: Theme.glassPalette.text
                                            }

                                            Rectangle {
                                                width: 80
                                                height: 3
                                                radius: 1.5
                                                color: Theme.glassPalette.inactiveTabForeground
                                            }

                                        }

                                    }

                                    // Mini Frosted Dock
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 4
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 60
                                        height: 8
                                        radius: 4
                                        color: Qt.rgba(1, 1, 1, 0.15)
                                        border.color: Qt.rgba(1, 1, 1, 0.3)
                                        border.width: 1

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 3

                                            Repeater {
                                                model: 4

                                                Rectangle {
                                                    width: 4
                                                    height: 4
                                                    radius: 1
                                                    color: Theme.glassPalette.text
                                                }

                                            }

                                        }

                                    }

                                }

                                Text {
                                    text: I18n.isRTL ? "زجاجي أكريليك" : "Glass (Acrylic)"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(13)
                                    font.weight: Font.DemiBold
                                    renderType: Theme.renderType
                                    color: Theme.colors.text
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: I18n.isRTL ? "ضبابية حية، أسطح شفافة عائمة وعمق معاصر." : "Live compositor blur, floating frosted panels, depth."
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(10)
                                    renderType: Theme.renderType
                                    color: Theme.colors.textSecondary
                                    wrapMode: Text.WordWrap
                                }

                            }

                        }

                        // ── Theme 3: Light (Crisp Paper) ──
                        DeloCard {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            hoverable: true
                            selected: ConfigManager.themeName === "light"
                            cardRadius: Theme.radiusMedium
                            onClicked: ConfigManager.setTheme("light")

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.space12
                                spacing: 8

                                // Mini Desktop Preview (Clean Light)
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 110
                                    radius: Theme.radiusSmall
                                    color: Theme.lightPalette.background
                                    border.color: Theme.lightPalette.borderSubtle
                                    border.width: 1

                                    // Mini Notch (Deep Slate Contrast)
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.topMargin: 4
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 44
                                        height: 8
                                        radius: 4
                                        color: Theme.lightPalette.activeTabBackground
                                    }

                                    // Mini Window Card
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 116
                                        height: 48
                                        radius: 5
                                        color: Theme.lightPalette.inactiveTabBackground
                                        border.color: Theme.lightPalette.borderSubtle
                                        border.width: 1

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 4

                                            Rectangle {
                                                width: 50
                                                height: 3
                                                radius: 1.5
                                                color: Theme.lightPalette.text
                                            }

                                            Rectangle {
                                                width: 80
                                                height: 3
                                                radius: 1.5
                                                color: Theme.lightPalette.inactiveTabForeground
                                            }

                                        }

                                    }

                                    // Mini Dock
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 4
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 60
                                        height: 8
                                        radius: 4
                                        color: Theme.lightPalette.tabBarBackground
                                        border.color: Theme.lightPalette.borderSubtle
                                        border.width: 1

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 3

                                            Repeater {
                                                model: 4

                                                Rectangle {
                                                    width: 4
                                                    height: 4
                                                    radius: 1
                                                    color: Theme.lightPalette.text
                                                }

                                            }

                                        }

                                    }

                                }

                                Text {
                                    text: I18n.isRTL ? "فاتح ناصع" : "Clean Light"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(13)
                                    font.weight: Font.DemiBold
                                    renderType: Theme.renderType
                                    color: Theme.colors.text
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: I18n.isRTL ? "وضوح نهاري عالي مع درجات رصاصية عميقة ومريحة." : "High daylight clarity and crisp slate neutrals."
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(10)
                                    renderType: Theme.renderType
                                    color: Theme.colors.textSecondary
                                    wrapMode: Text.WordWrap
                                }

                            }

                        }

                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.motionFast
                            easing.type: Theme.easingEnter
                        }

                    }

                }

                // =========================================================
                // STEP 2: DESKTOP WORKSPACE MODE
                // =========================================================
                ColumnLayout {
                    id: step2View

                    anchors.fill: parent
                    spacing: Theme.space12
                    visible: opacity > 0.001
                    opacity: root.currentStep === 2 ? 1 : 0
                    enabled: root.currentStep === 2

                    Text {
                        text: root.stepSubtitle(2)
                        font.family: Theme.typography.fontFamily
                        font.hintingPreference: Theme.hintingPreference
                        font.pixelSize: Theme.fontSize(12)
                        renderType: Theme.renderType
                        color: Theme.colors.textSecondary
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 12

                        Repeater {
                            model: [{
                                "id": "clean",
                                "title": I18n.tr("wiz_desk_clean"),
                                "desc": I18n.tr("wiz_desk_clean_desc"),
                                "icon": "applications-graphics-symbolic"
                            }, {
                                "id": "widgets",
                                "title": I18n.tr("wiz_desk_widgets"),
                                "desc": I18n.tr("wiz_desk_widgets_desc"),
                                "icon": "preferences-system-symbolic"
                            }, {
                                "id": "traditional",
                                "title": I18n.tr("wiz_desk_traditional"),
                                "desc": I18n.tr("wiz_desk_traditional_desc"),
                                "icon": "user-home-symbolic"
                            }]

                            delegate: DeloCard {
                                id: dCard

                                required property var modelData
                                readonly property bool isSelected: dCard.modelData.id === "clean" ? !ConfigManager.showDesktopContent : (ConfigManager.showDesktopContent && ConfigManager.desktopMode === dCard.modelData.id)

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                hoverable: true
                                selected: isSelected
                                cardRadius: Theme.radiusMedium
                                onClicked: ConfigManager.setDesktopMode(dCard.modelData.id)

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.space12
                                    spacing: 8

                                    // Mini Desktop Wireframe Preview
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 90
                                        radius: Theme.radiusSmall
                                        color: Theme.colors.surfaceElevated
                                        border.color: dCard.isSelected ? Theme.colors.borderHighlight : Theme.colors.borderSubtle
                                        border.width: 1
                                        clip: true

                                        // Notch Capsule at top
                                        Rectangle {
                                            anchors.top: parent.top
                                            anchors.topMargin: 4
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: 36
                                            height: 5
                                            radius: 2.5
                                            color: Theme.colors.text
                                        }

                                        // Clean Canvas Wireframe
                                        Item {
                                            anchors.fill: parent
                                            visible: dCard.modelData.id === "clean"

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 32
                                                height: 32
                                                radius: 16
                                                color: Theme.colors.surface
                                                border.color: Theme.colors.borderSubtle
                                                border.width: 1

                                                SymbolicIcon {
                                                    anchors.centerIn: parent
                                                    iconSize: 14
                                                    source: "applications-graphics-symbolic"
                                                    iconColor: Theme.colors.textSecondary
                                                }

                                            }

                                        }

                                        // Widgets Canvas Wireframe
                                        Item {
                                            anchors.fill: parent
                                            visible: dCard.modelData.id === "widgets"

                                            // Mini Clock/Weather Widget
                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.leftMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 54
                                                height: 34
                                                radius: 4
                                                color: Theme.colors.surface
                                                border.color: Theme.colors.borderHighlight
                                                border.width: 1

                                                Column {
                                                    anchors.centerIn: parent
                                                    spacing: 3

                                                    Rectangle {
                                                        width: 30
                                                        height: 4
                                                        radius: 2
                                                        color: Theme.colors.text
                                                    }

                                                    Rectangle {
                                                        width: 18
                                                        height: 3
                                                        radius: 1.5
                                                        color: Theme.colors.textSecondary
                                                    }

                                                }

                                            }

                                            // Mini Stats Widget
                                            Rectangle {
                                                anchors.right: parent.right
                                                anchors.rightMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 54
                                                height: 34
                                                radius: 4
                                                color: Theme.colors.surface
                                                border.color: Theme.colors.borderHighlight
                                                border.width: 1

                                                Row {
                                                    anchors.centerIn: parent
                                                    spacing: 3

                                                    Rectangle {
                                                        width: 4
                                                        height: 12
                                                        radius: 1
                                                        color: Theme.colors.textSecondary
                                                    }

                                                    Rectangle {
                                                        width: 4
                                                        height: 18
                                                        radius: 1
                                                        color: Theme.colors.text
                                                    }

                                                    Rectangle {
                                                        width: 4
                                                        height: 8
                                                        radius: 1
                                                        color: Theme.colors.textSecondary
                                                    }

                                                    Rectangle {
                                                        width: 4
                                                        height: 14
                                                        radius: 1
                                                        color: Theme.colors.text
                                                    }

                                                }

                                            }

                                        }

                                        // Traditional Icons Wireframe
                                        Item {
                                            anchors.fill: parent
                                            visible: dCard.modelData.id === "traditional"

                                            Grid {
                                                anchors.left: parent.left
                                                anchors.leftMargin: 10
                                                anchors.verticalCenter: parent.verticalCenter
                                                columns: 2
                                                rows: 2
                                                spacing: 6

                                                Repeater {
                                                    model: 4

                                                    Column {
                                                        spacing: 2

                                                        Rectangle {
                                                            width: 16
                                                            height: 14
                                                            radius: 2
                                                            color: Theme.colors.surface
                                                            border.color: Theme.colors.borderHighlight
                                                            border.width: 1

                                                            SymbolicIcon {
                                                                anchors.centerIn: parent
                                                                iconSize: 9
                                                                source: index === 0 ? "user-home-symbolic" : (index === 1 ? "folder-symbolic" : "text-x-generic-symbolic")
                                                                iconColor: Theme.colors.text
                                                            }

                                                        }

                                                        Rectangle {
                                                            width: 16
                                                            height: 2
                                                            radius: 1
                                                            color: Theme.colors.textSecondary
                                                        }

                                                    }

                                                }

                                            }

                                        }

                                        // Dock Pill at bottom
                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: 4
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: 44
                                            height: 5
                                            radius: 2.5
                                            color: Theme.colors.surface
                                            border.color: Theme.colors.borderHighlight
                                            border.width: 1
                                        }

                                    }

                                    Text {
                                        text: dCard.modelData.title
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(13)
                                        font.weight: Font.DemiBold
                                        renderType: Theme.renderType
                                        color: dCard.isSelected ? Theme.colors.text : Theme.colors.textSecondary
                                    }

                                    Text {
                                        horizontalAlignment: Text.AlignLeft
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        text: dCard.modelData.desc
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(10)
                                        renderType: Theme.renderType
                                        color: Theme.colors.textSecondary
                                        wrapMode: Text.WordWrap
                                    }

                                }

                            }

                        }

                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.motionFast
                            easing.type: Theme.easingEnter
                        }

                    }

                }

                // =========================================================
                // STEP 3: DOCK & TOP BAR BEHAVIOR
                // =========================================================
                ColumnLayout {
                    id: step3View

                    anchors.fill: parent
                    spacing: Theme.space12
                    visible: opacity > 0.001
                    opacity: root.currentStep === 3 ? 1 : 0
                    enabled: root.currentStep === 3

                    Text {
                        text: root.stepSubtitle(3)
                        font.family: Theme.typography.fontFamily
                        font.hintingPreference: Theme.hintingPreference
                        font.pixelSize: Theme.fontSize(12)
                        renderType: Theme.renderType
                        color: Theme.colors.textSecondary
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space16

                        // Dock Auto-Hide Option
                        DeloCard {
                            Layout.fillWidth: true
                            height: 80
                            cardRadius: Theme.radiusMedium

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 12

                                SymbolicIcon {
                                    iconSize: 24
                                    source: "preferences-system-windows-symbolic"
                                    iconColor: Theme.colors.text
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: I18n.tr("wiz_dock_autohide")
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(12)
                                        font.weight: Font.DemiBold
                                        renderType: Theme.renderType
                                        color: Theme.colors.text
                                    }

                                    Text {
                                        text: ConfigManager.dockAutoHide ? I18n.tr("wiz_dock_autohide_on") : I18n.tr("wiz_dock_autohide_off")
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.typography.scaleCaption.size
                                        renderType: Theme.renderType
                                        color: Theme.colors.textSecondary
                                    }

                                }

                                // Switch Pill
                                Rectangle {
                                    width: 44
                                    height: 24
                                    radius: 12
                                    color: ConfigManager.dockAutoHide ? Theme.inverseSurface : Theme.colors.surfaceHover

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.leftMargin: ConfigManager.dockAutoHide ? 22 : 2
                                        y: 2
                                        width: 20
                                        height: 20
                                        radius: 10
                                        color: ConfigManager.dockAutoHide ? Theme.inverseText : Theme.colors.text

                                        Behavior on anchors.leftMargin {
                                            NumberAnimation {
                                                duration: Theme.motionFast
                                                easing.type: Theme.easingEnter
                                            }

                                        }

                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: ConfigManager.setDockAutoHide(!ConfigManager.dockAutoHide)
                                    }

                                }

                            }

                        }

                        // Clock Format Option
                        DeloCard {
                            Layout.fillWidth: true
                            height: 80
                            cardRadius: Theme.radiusMedium

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 12

                                SymbolicIcon {
                                    iconSize: 24
                                    source: "preferences-system-time-symbolic"
                                    iconColor: Theme.colors.text
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: I18n.tr("wiz_clock_format")
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(12)
                                        font.weight: Font.DemiBold
                                        renderType: Theme.renderType
                                        color: Theme.colors.text
                                    }

                                    Text {
                                        text: ConfigManager.clockFormat === "24h" ? I18n.tr("wiz_clock_24") : I18n.tr("wiz_clock_12")
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.typography.scaleCaption.size
                                        renderType: Theme.renderType
                                        color: Theme.colors.textSecondary
                                    }

                                }

                                DeloButton {
                                    implicitWidth: 70
                                    implicitHeight: 28
                                    variant: "secondary"
                                    text: ConfigManager.clockFormat.toUpperCase()
                                    onClicked: ConfigManager.setClockFormat(ConfigManager.clockFormat === "12h" ? "24h" : "12h")
                                }

                            }

                        }

                    }

                    // Dynamic Notch Spotlight Banner
                    DeloCard {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        cardRadius: Theme.radiusMedium
                        surfaceColor: Theme.colors.surfaceVariant

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.space16
                            spacing: 10

                            // Dynamic Notch Capsule Simulation
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: Math.min(360, parent.width - 24)
                                height: 38
                                radius: 19
                                color: Theme.notchBackground
                                border.color: Theme.notchBorderSubtle
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 8

                                    // Music Icon Pill
                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: 11
                                        color: Theme.notchSurfaceElevated

                                        SymbolicIcon {
                                            anchors.centerIn: parent
                                            iconSize: 12
                                            source: "audio-x-generic-symbolic"
                                            iconColor: Theme.notchText
                                        }

                                    }

                                    // Mini Equalizer Bars
                                    Row {
                                        spacing: 2
                                        Layout.alignment: Qt.AlignVCenter

                                        Rectangle {
                                            width: 2
                                            height: 8
                                            radius: 1
                                            color: Theme.notchText
                                        }

                                        Rectangle {
                                            width: 2
                                            height: 14
                                            radius: 1
                                            color: Theme.notchText
                                        }

                                        Rectangle {
                                            width: 2
                                            height: 10
                                            radius: 1
                                            color: Theme.notchText
                                        }

                                        Rectangle {
                                            width: 2
                                            height: 16
                                            radius: 1
                                            color: Theme.notchText
                                        }

                                        Rectangle {
                                            width: 2
                                            height: 6
                                            radius: 1
                                            color: Theme.notchText
                                        }

                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: I18n.isRTL ? "موسيقى النظام • DeloWay" : "DeloWay Ambient Stream"
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(11)
                                        font.weight: Font.DemiBold
                                        color: Theme.notchText
                                        elide: Text.ElideRight
                                    }

                                    // Status Glyphs
                                    Row {
                                        spacing: 6
                                        Layout.alignment: Qt.AlignVCenter

                                        SymbolicIcon {
                                            iconSize: 12
                                            source: "audio-volume-high-symbolic"
                                            iconColor: Theme.notchTextSecondary
                                        }

                                        SymbolicIcon {
                                            iconSize: 12
                                            source: "battery-level-80-symbolic"
                                            iconColor: Theme.notchTextSecondary
                                        }

                                        Text {
                                            text: ConfigManager.clockFormat === "24h" ? "14:30" : "2:30 PM"
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: Theme.fontSize(10)
                                            font.weight: Font.DemiBold
                                            color: Theme.notchText
                                        }

                                    }

                                }

                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                SymbolicIcon {
                                    iconSize: 22
                                    source: "preferences-desktop-display-symbolic"
                                    iconColor: Theme.colors.text
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: I18n.isRTL ? "النوتش التفاعلي (Dynamic Notch)" : "Dynamic Island Notch"
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(12)
                                        font.weight: Font.DemiBold
                                        color: Theme.colors.text
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: I18n.isRTL ? "تتحكم بالنظام، ومستوى الصوت، والوسائط، والإشعارات من خلال النوتش التفاعلي أعلى الشاشة. اضغط مفتاح Super في أي وقت للكشف عن Notch Home." : "Media playback, audio visualizer, volume, and notifications live inside the interactive top capsule. Tap or press Super anytime to reveal Notch Home."
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(10)
                                        color: Theme.colors.textSecondary
                                        wrapMode: Text.WordWrap
                                    }

                                }

                            }

                        }

                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.motionFast
                            easing.type: Theme.easingEnter
                        }

                    }

                }

                // =========================================================
                // STEP 4: DEFAULT APPLICATIONS
                // =========================================================
                ColumnLayout {
                    id: step4View

                    anchors.fill: parent
                    spacing: 12
                    visible: opacity > 0.001
                    opacity: root.currentStep === 4 ? 1 : 0
                    enabled: root.currentStep === 4

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignLeft
                        wrapMode: Text.WordWrap
                        text: root.stepSubtitle(4)
                        font.family: Theme.typography.fontFamily
                        font.hintingPreference: Theme.hintingPreference
                        font.pixelSize: Theme.fontSize(12)
                        renderType: Theme.renderType
                        color: Theme.colors.textSecondary
                    }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentHeight: rolesCol.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: rolesCol

                            width: parent.width
                            spacing: 14

                            Repeater {
                                model: [{
                                    "role": "browser",
                                    "label": I18n.tr("web_browser")
                                }, {
                                    "role": "terminal",
                                    "label": I18n.tr("terminal_emulator")
                                }, {
                                    "role": "fileManager",
                                    "label": I18n.tr("file_manager")
                                }, {
                                    "role": "editor",
                                    "label": I18n.tr("text_editor")
                                }, {
                                    "role": "monitor",
                                    "label": I18n.tr("system_monitor")
                                }]

                                delegate: ColumnLayout {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignLeft
                                        text: modelData.label
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(12)
                                        font.weight: Font.DemiBold
                                        renderType: Theme.renderType
                                        color: Theme.colors.text
                                    }

                                    DefaultAppChooser {
                                        Layout.fillWidth: true
                                        role: modelData.role
                                    }

                                }

                            }

                        }

                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.motionFast
                            easing.type: Theme.easingEnter
                        }

                    }

                }

                // =========================================================
                // STEP 5: WINDOW MANAGEMENT STYLE & TILING
                // =========================================================
                ColumnLayout {
                    id: step5View

                    anchors.fill: parent
                    spacing: Theme.space12
                    visible: opacity > 0.001
                    opacity: root.currentStep === 5 ? 1 : 0
                    enabled: root.currentStep === 5

                    Text {
                        text: root.stepSubtitle(5)
                        font.family: Theme.typography.fontFamily
                        font.hintingPreference: Theme.hintingPreference
                        font.pixelSize: Theme.fontSize(12)
                        renderType: Theme.renderType
                        color: Theme.colors.textSecondary
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 14

                        Repeater {
                            model: [{
                                "id": "compact",
                                "title": I18n.tr("wiz_win_compact"),
                                "gapsIn": 3,
                                "gapsOut": 6,
                                "rounding": 6,
                                "desc": I18n.tr("wiz_win_compact_desc")
                            }, {
                                "id": "standard",
                                "title": I18n.tr("wiz_win_standard"),
                                "gapsIn": 5,
                                "gapsOut": 10,
                                "rounding": 10,
                                "desc": I18n.tr("wiz_win_standard_desc")
                            }, {
                                "id": "spacious",
                                "title": I18n.tr("wiz_win_spacious"),
                                "gapsIn": 10,
                                "gapsOut": 18,
                                "rounding": 14,
                                "desc": I18n.tr("wiz_win_spacious_desc")
                            }]

                            delegate: DeloCard {
                                id: styleCard

                                required property var modelData
                                readonly property bool isSelected: ConfigManager.windowGapsIn === styleCard.modelData.gapsIn && ConfigManager.windowRounding === styleCard.modelData.rounding

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                hoverable: true
                                selected: isSelected
                                cardRadius: Theme.radiusMedium
                                onClicked: {
                                    ConfigManager.setWindowGaps(styleCard.modelData.gapsIn, styleCard.modelData.gapsOut);
                                    ConfigManager.setWindowRounding(styleCard.modelData.rounding);
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.space16
                                    spacing: 8

                                    // Mini Geometric Tiling Diagram
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 70
                                        radius: styleCard.modelData.rounding
                                        color: Theme.colors.surfaceElevated
                                        border.color: Theme.colors.borderSubtle
                                        border.width: 1

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: styleCard.modelData.gapsIn

                                            Rectangle {
                                                width: 50
                                                height: 48
                                                radius: Math.max(2, styleCard.modelData.rounding - 2)
                                                color: Theme.colors.surface
                                                border.color: Theme.colors.borderHighlight
                                                border.width: 1
                                            }

                                            Column {
                                                spacing: styleCard.modelData.gapsIn

                                                Rectangle {
                                                    width: 50
                                                    height: 22
                                                    radius: Math.max(2, styleCard.modelData.rounding - 2)
                                                    color: Theme.colors.surface
                                                    border.color: Theme.colors.borderHighlight
                                                    border.width: 1
                                                }

                                                Rectangle {
                                                    width: 50
                                                    height: 22
                                                    radius: Math.max(2, styleCard.modelData.rounding - 2)
                                                    color: Theme.colors.surface
                                                    border.color: Theme.colors.borderHighlight
                                                    border.width: 1
                                                }

                                            }

                                        }

                                    }

                                    Text {
                                        text: styleCard.modelData.title
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(13)
                                        font.weight: Font.DemiBold
                                        renderType: Theme.renderType
                                        color: styleCard.isSelected ? Theme.colors.text : Theme.colors.textSecondary
                                    }

                                    Text {
                                        text: I18n.uiLine(I18n.tr("wiz_win_metrics").replace("%1", I18n.ltr(styleCard.modelData.gapsIn + "/" + styleCard.modelData.gapsOut + "px")).replace("%2", I18n.ltr(styleCard.modelData.rounding + "px")))
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(10)
                                        color: Theme.colors.textSecondary
                                    }

                                    Text {
                                        horizontalAlignment: Text.AlignLeft
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        text: styleCard.modelData.desc
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(11)
                                        renderType: Theme.renderType
                                        color: Theme.colors.textSecondary
                                        wrapMode: Text.WordWrap
                                    }

                                }

                            }

                        }

                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.motionFast
                            easing.type: Theme.easingEnter
                        }

                    }

                }

                // =========================================================
                // STEP 6: SHORTCUTS & LAUNCH
                // =========================================================
                ColumnLayout {
                    id: step6View

                    anchors.fill: parent
                    spacing: 12
                    visible: opacity > 0.001
                    opacity: root.currentStep === 6 ? 1 : 0
                    enabled: root.currentStep === 6

                    Text {
                        text: root.stepSubtitle(6)
                        font.family: Theme.typography.fontFamily
                        font.hintingPreference: Theme.hintingPreference
                        font.pixelSize: Theme.fontSize(12)
                        renderType: Theme.renderType
                        color: Theme.colors.textSecondary
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 8
                        columnSpacing: 16

                        Repeater {
                            model: [{
                                "key": "Super",
                                "desc": I18n.tr("wiz_sc_start")
                            }, {
                                "key": "Super + Space",
                                "desc": I18n.tr("wiz_sc_search")
                            }, {
                                "key": "Super + Return",
                                "desc": I18n.tr("wiz_sc_terminal")
                            }, {
                                "key": "Super + E",
                                "desc": I18n.tr("wiz_sc_files")
                            }, {
                                "key": "Super + I",
                                "desc": I18n.tr("wiz_sc_settings")
                            }, {
                                "key": "Super + Shift + S",
                                "desc": I18n.tr("wiz_sc_screenshot")
                            }, {
                                "key": "Super + Q",
                                "desc": I18n.tr("wiz_sc_close")
                            }, {
                                "key": "Super + /",
                                "desc": I18n.tr("wiz_sc_all")
                            }]

                            delegate: DeloCard {
                                Layout.fillWidth: true
                                height: 38
                                cardRadius: Theme.radiusSmall
                                surfaceColor: Theme.colors.surfaceVariant
                                borderColor: Theme.colors.borderSubtle

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.space8
                                    spacing: 10

                                    Rectangle {
                                        implicitWidth: keyText.implicitWidth + 12
                                        implicitHeight: 22
                                        radius: 4
                                        color: Theme.notchSurfaceElevated
                                        border.color: Theme.notchBorderSubtle
                                        border.width: 1

                                        Text {
                                            id: keyText

                                            anchors.centerIn: parent
                                            text: modelData.key
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: Theme.typography.scaleCaption.size
                                            font.weight: Font.DemiBold
                                            color: Theme.colors.text
                                        }

                                    }

                                    Text {
                                        horizontalAlignment: Text.AlignLeft
                                        Layout.fillWidth: true
                                        text: modelData.desc
                                        font.family: Theme.typography.fontFamily
                                        font.hintingPreference: Theme.hintingPreference
                                        font.pixelSize: Theme.fontSize(11)
                                        renderType: Theme.renderType
                                        color: Theme.colors.text
                                        elide: Text.ElideRight
                                    }

                                }

                            }

                        }

                    }

                    // Summary Status Pill Bar
                    DeloCard {
                        Layout.fillWidth: true
                        height: 40
                        cardRadius: Theme.radiusSmall
                        surfaceColor: Theme.colors.surfaceElevated

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.space12
                            anchors.rightMargin: Theme.space12
                            spacing: 8

                            Text {
                                text: I18n.isRTL ? "الإعدادات المختارة:" : "Active Setup:"
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: Font.DemiBold
                                color: Theme.colors.textSecondary
                            }

                            Rectangle {
                                implicitWidth: summaryTheme.implicitWidth + 12
                                height: 22
                                radius: 11
                                color: Theme.colors.surfaceHover

                                Text {
                                    id: summaryTheme

                                    anchors.centerIn: parent
                                    text: ConfigManager.themeName.toUpperCase()
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(10)
                                    font.weight: Font.Bold
                                    color: Theme.colors.text
                                }

                            }

                            Rectangle {
                                implicitWidth: summaryLang.implicitWidth + 12
                                height: 22
                                radius: 11
                                color: Theme.colors.surfaceHover

                                Text {
                                    id: summaryLang

                                    anchors.centerIn: parent
                                    text: ConfigManager.uiLanguage.toUpperCase()
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(10)
                                    font.weight: Font.Bold
                                    color: Theme.colors.text
                                }

                            }

                            Rectangle {
                                implicitWidth: summaryDesk.implicitWidth + 12
                                height: 22
                                radius: 11
                                color: Theme.colors.surfaceHover

                                Text {
                                    id: summaryDesk

                                    anchors.centerIn: parent
                                    text: ConfigManager.desktopMode.toUpperCase()
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(10)
                                    font.weight: Font.Bold
                                    color: Theme.colors.text
                                }

                            }

                        }

                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.motionFast
                            easing.type: Theme.easingEnter
                        }

                    }

                }

            }

            // Footer Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.colors.borderSubtle
            }

            // ─────────────────────────────────────────────────────────────
            // FOOTER: Back, Step Counter, Next / Finish Actions
            // ─────────────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                // Back Button
                DeloButton {
                    visible: root.currentStep > 0
                    implicitWidth: 100
                    implicitHeight: 38
                    variant: "secondary"
                    text: I18n.tr("back_btn")
                    onClicked: root.prevStep()
                }

                Item {
                    Layout.preferredWidth: 8
                }

                // Step Counter
                Text {
                    text: I18n.isRTL ? ("الخطوة " + I18n.digits(root.currentStep + 1) + " من " + I18n.digits(root.totalSteps)) : ("Step " + (root.currentStep + 1) + " of " + root.totalSteps)
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(11)
                    color: Theme.colors.textSecondary
                }

                Item {
                    Layout.fillWidth: true
                }

                // Next or Finish Button
                DeloButton {
                    implicitWidth: (root.currentStep < root.totalSteps - 1) ? 140 : 180
                    implicitHeight: 38
                    variant: "primary"
                    text: (root.currentStep < root.totalSteps - 1) ? I18n.tr("next_step") : (I18n.isRTL ? "ابدأ تجربة DeloWay" : "Start Exploring DeloWay")
                    onClicked: root.nextStep()
                }

            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.motionThemeFade
                easing.type: Theme.easingTheme
            }

        }

        Behavior on border.color {
            ColorAnimation {
                duration: Theme.motionThemeFade
                easing.type: Theme.easingTheme
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Theme.easingEnter
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Theme.easingEnter
            }

        }

    }

}
