import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../services"
import "../common"

Item {
    id: root

    implicitWidth: 500
    implicitHeight: mainCol.implicitHeight + (Theme.space24 * 2)
    width: parent ? parent.width : implicitWidth
    height: implicitHeight
    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    ColumnLayout {
        id: mainCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.space24
        spacing: Theme.space24
        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        // ── 1. Workspaces Indicator Settings ─────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "مساحات العمل (Workspaces)" : "Workspaces"

            // Style Selector: icons | numbers | dots
            SettingsRow {
                title: I18n.isRTL ? "نمط مؤشر مساحات العمل" : "Workspace Indicator Style"
                subtitle: I18n.isRTL
                    ? "اختر أسلوب عرض مساحات العمل في النوتش (أيقونات التطبيقات، أرقام ثابتة، أو نقاط)"
                    : "Choose how workspaces appear in the smart notch (app icons, fixed numbers, or dots)"
                icon: "view-app-grid-symbolic"
                showDivider: true

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [
                            { id: "icons",   label: I18n.isRTL ? "أيقونات (افتراضي)" : "Icons (Default)" },
                            { id: "numbers", label: I18n.isRTL ? "أرقام فقط" : "Numbers Only" },
                            { id: "dots",    label: I18n.isRTL ? "نقاط فقط" : "Dots Only" }
                        ]
                        delegate: Rectangle {
                            id: stylePill
                            required property var modelData
                            readonly property bool isSelected: (ConfigManager.workspaceIndicatorStyle || "icons") === modelData.id

                            height: 28
                            implicitWidth: styleText.implicitWidth + Theme.space16
                            radius: 14
                            color: stylePill.isSelected ? Theme.notchSurfaceActive : (styleMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: stylePill.isSelected ? Theme.notchBorderHighlight : (styleMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                id: styleText
                                anchors.centerIn: parent
                                text: stylePill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: stylePill.isSelected ? Font.DemiBold : Font.Normal
                                color: stylePill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: styleMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConfigManager.setWorkspaceIndicatorStyle(stylePill.modelData.id)
                            }
                        }
                    }
                }
            }

            // Fixed Workspaces Count
            SettingsRow {
                title: I18n.isRTL ? "عدد مساحات العمل الثابتة" : "Fixed Workspaces Count"
                subtitle: I18n.isRTL ? "الحد الأدنى لمساحات العمل المعروضة دائماً دون إخفاء" : "Minimum workspace slots shown permanently"
                icon: "view-paged-symbolic"
                showDivider: true

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [3, 5, 8, 10]
                        delegate: Rectangle {
                            id: countPill
                            required property int modelData
                            readonly property bool isSelected: ConfigManager.workspacesCount === modelData

                            height: 28
                            implicitWidth: countText.implicitWidth + Theme.space16
                            radius: 14
                            color: countPill.isSelected ? Theme.notchSurfaceActive : (countMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: countPill.isSelected ? Theme.notchBorderHighlight : (countMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                id: countText
                                anchors.centerIn: parent
                                text: countPill.modelData.toString()
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: countPill.isSelected ? Font.DemiBold : Font.Normal
                                color: countPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: countMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConfigManager.setWorkspacesCount(countPill.modelData)
                            }
                        }
                    }
                }
            }

            // Show Workspaces Toggle
            SettingsRow {
                title: I18n.isRTL ? "إظهار مؤشر مساحات العمل" : "Show Workspaces Indicator"
                subtitle: I18n.isRTL ? "عرض قسم مساحات العمل في النوتش والشريط العلوي" : "Display workspace indicator in the smart notch and top bar"
                icon: "view-visible-symbolic"
                showDivider: false
                clickable: true
                onClicked: {
                    ConfigManager.topBarShowWorkspaces = !ConfigManager.topBarShowWorkspaces;
                    ConfigManager.saveConfig();
                }

                SettingsToggle {
                    checked: ConfigManager.topBarShowWorkspaces
                    onToggled: ch => {
                        ConfigManager.topBarShowWorkspaces = ch;
                        ConfigManager.saveConfig();
                    }
                }
            }
        }

        // ── 2. Clock & TopBar Display ────────────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "الساعة والشريط العلوي" : "Clock & Top Bar"

            // Clock Format: 12h / 24h
            SettingsRow {
                title: I18n.isRTL ? "تنسيق الوقت" : "Time Format"
                subtitle: I18n.isRTL ? "التبديل بين نظام 12 ساعة و24 ساعة" : "Toggle between 12-hour and 24-hour time format"
                icon: "preferences-system-time-symbolic"
                showDivider: true

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [
                            { id: "12h", label: I18n.isRTL ? "12 ساعة (ص/م)" : "12-hour" },
                            { id: "24h", label: I18n.isRTL ? "24 ساعة" : "24-hour" }
                        ]
                        delegate: Rectangle {
                            id: clockPill
                            required property var modelData
                            readonly property bool isSelected: ConfigManager.clockFormat === modelData.id

                            height: 28
                            implicitWidth: clockText.implicitWidth + Theme.space16
                            radius: 14
                            color: clockPill.isSelected ? Theme.notchSurfaceActive : (clockMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: clockPill.isSelected ? Theme.notchBorderHighlight : (clockMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                id: clockText
                                anchors.centerIn: parent
                                text: clockPill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: clockPill.isSelected ? Font.DemiBold : Font.Normal
                                color: clockPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: clockMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ConfigManager.clockFormat = clockPill.modelData.id;
                                    ConfigManager.saveConfig();
                                }
                            }
                        }
                    }
                }
            }

            // Show Brand / Logo
            SettingsRow {
                title: I18n.isRTL ? "إظهار شعار DeloWay" : "Show DeloWay Brand"
                subtitle: I18n.isRTL ? "عرض شعار النظام في الزاوية العلوية" : "Display brand logo in the top corner"
                icon: "distributor-logo-symbolic"
                showDivider: false
                clickable: true
                onClicked: {
                    ConfigManager.topBarShowBrand = !ConfigManager.topBarShowBrand;
                    ConfigManager.saveConfig();
                }

                SettingsToggle {
                    checked: ConfigManager.topBarShowBrand
                    onToggled: ch => {
                        ConfigManager.topBarShowBrand = ch;
                        ConfigManager.saveConfig();
                    }
                }
            }
        }

        // ── 3. Time & Date Capsule Settings ──────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "كبسولة الوقت والتقويم" : "Time & Calendar Capsule"

            // Main Toggle: Enable TimeCapsule
            SettingsRow {
                title: I18n.isRTL ? "إظهار كبسولة الوقت والتاريخ" : "Show Time & Date Capsule"
                subtitle: I18n.isRTL
                    ? "عرض كبسولة الوقت في أقصى يسار الشريط العلوي مع التقويم وقراءات الهاردوير عند التوسع"
                    : "Display time capsule on the far left of the top bar with calendar and hardware info on expand"
                icon: "preferences-system-time-symbolic"
                showDivider: true
                clickable: true
                onClicked: {
                    ConfigManager.setTimeCapsuleEnabled(!ConfigManager.timeCapsuleEnabled);
                }

                SettingsToggle {
                    checked: ConfigManager.timeCapsuleEnabled
                    onToggled: ch => {
                        ConfigManager.setTimeCapsuleEnabled(ch);
                    }
                }
            }

            // Week Start Day
            SettingsRow {
                title: I18n.isRTL ? "بداية الأسبوع في التقويم" : "Calendar Week Start"
                subtitle: I18n.isRTL
                    ? "اليوم الأول في شبكة تقويم الشهر الموسعة"
                    : "First day of the week displayed in the monthly calendar grid"
                icon: "view-calendar-symbolic"
                showDivider: true

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [
                            { id: "saturday", label: I18n.isRTL ? "السبت" : "Saturday" },
                            { id: "sunday",   label: I18n.isRTL ? "الأحد" : "Sunday" },
                            { id: "monday",   label: I18n.isRTL ? "الاثنين" : "Monday" }
                        ]
                        delegate: Rectangle {
                            id: weekStartPill
                            required property var modelData
                            readonly property bool isSelected: (ConfigManager.timeCapsuleWeekStart || "saturday") === modelData.id

                            height: 28
                            implicitWidth: weekStartText.implicitWidth + Theme.space16
                            radius: 14
                            color: weekStartPill.isSelected ? Theme.notchSurfaceActive : (weekStartMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: weekStartPill.isSelected ? Theme.notchBorderHighlight : (weekStartMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                id: weekStartText
                                anchors.centerIn: parent
                                text: weekStartPill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: weekStartPill.isSelected ? Font.DemiBold : Font.Normal
                                color: weekStartPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: weekStartMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConfigManager.setTimeCapsuleWeekStart(weekStartPill.modelData.id)
                            }
                        }
                    }
                }
            }

            // Show Seconds in Expanded Clock
            SettingsRow {
                title: I18n.isRTL ? "إظهار الثواني في الساعة الموسعة" : "Show Seconds in Expanded Clock"
                subtitle: I18n.isRTL
                    ? "عرض عداد الثواني مع الساعات والدقائق داخل نافذة الكبسولة الموسعة"
                    : "Display seconds counter alongside hours and minutes in the expanded capsule"
                icon: "appointment-soon-symbolic"
                showDivider: true
                clickable: true
                onClicked: {
                    ConfigManager.setTimeCapsuleShowSeconds(!ConfigManager.timeCapsuleShowSeconds);
                }

                SettingsToggle {
                    checked: ConfigManager.timeCapsuleShowSeconds
                    onToggled: ch => {
                        ConfigManager.setTimeCapsuleShowSeconds(ch);
                    }
                }
            }

            // Show Short Date in Compact Capsule
            SettingsRow {
                title: I18n.isRTL ? "إظهار التاريخ في الكبسولة المصغّرة" : "Show Date in Compact Capsule"
                subtitle: I18n.isRTL
                    ? "عرض اليوم والشهر المختصر بجانب الوقت في الشريط العلوي"
                    : "Display short day and month next to the time in the top bar"
                icon: "x-office-calendar-symbolic"
                showDivider: true
                clickable: true
                onClicked: {
                    ConfigManager.setTimeCapsuleShowShortDate(!ConfigManager.timeCapsuleShowShortDate);
                }

                SettingsToggle {
                    checked: ConfigManager.timeCapsuleShowShortDate
                    onToggled: ch => {
                        ConfigManager.setTimeCapsuleShowShortDate(ch);
                    }
                }
            }

            // Show Hijri Date (Umm al-Qura)
            SettingsRow {
                title: I18n.isRTL ? "إظهار التاريخ الهجري (تقويم أم القرى)" : "Show Hijri Date (Umm al-Qura)"
                subtitle: I18n.isRTL
                    ? "حساب وعرض التاريخ الهجري بدقة فلكية في ترويسة الكبسولة الموسعة"
                    : "Calculate and display astronomical Umm al-Qura Hijri date in expanded header"
                icon: "weather-clear-night-symbolic"
                showDivider: true
                clickable: true
                onClicked: {
                    ConfigManager.setTimeCapsuleShowHijri(!ConfigManager.timeCapsuleShowHijri);
                }

                SettingsToggle {
                    checked: ConfigManager.timeCapsuleShowHijri
                    onToggled: ch => {
                        ConfigManager.setTimeCapsuleShowHijri(ch);
                    }
                }
            }

            // Eastern Arabic Numerals (٠١٢)
            SettingsRow {
                title: I18n.isRTL ? "الأرقام المشرقية (٠١٢٣٤)" : "Eastern Arabic Numerals (٠١٢)"
                subtitle: I18n.isRTL
                    ? "استخدام الأرقام العربية المشرقية للأوقات والتواريخ عند اختيار الواجهة العربية"
                    : "Use Eastern Arabic digits for times and calendar dates when using Arabic UI"
                icon: "format-text-bold-symbolic"
                showDivider: true
                clickable: true
                onClicked: {
                    ConfigManager.setTimeCapsuleArabicDigits(!ConfigManager.timeCapsuleArabicDigits);
                }

                SettingsToggle {
                    checked: ConfigManager.timeCapsuleArabicDigits
                    onToggled: ch => {
                        ConfigManager.setTimeCapsuleArabicDigits(ch);
                    }
                }
            }

            // Show Hardware Section
            SettingsRow {
                title: I18n.isRTL ? "إظهار قسم الهاردوير" : "Show Hardware Telemetry"
                subtitle: I18n.isRTL
                    ? "عرض بطاقات مراقبة الاستهلاك والحرارة والمخططات البيانية الحية أسفل التقويم"
                    : "Display CPU, RAM, and GPU usage cards with real-time sparklines below calendar"
                icon: "utilities-system-monitor-symbolic"
                showDivider: ConfigManager.timeCapsuleShowHardware
                clickable: true
                onClicked: {
                    ConfigManager.setTimeCapsuleShowHardware(!ConfigManager.timeCapsuleShowHardware);
                }

                SettingsToggle {
                    checked: ConfigManager.timeCapsuleShowHardware
                    onToggled: ch => {
                        ConfigManager.setTimeCapsuleShowHardware(ch);
                    }
                }
            }

            // Sub-options for Hardware metrics (visible only if hardware telemetry is enabled)
            SettingsRow {
                visible: ConfigManager.timeCapsuleShowHardware
                title: I18n.isRTL ? "عناصر الهاردوير النشطة" : "Active Hardware Metrics"
                subtitle: I18n.isRTL
                    ? "تحديد المقاييس المعروضة في بطاقات الهاردوير (المعالج، الذاكرة، كرت الشاشة)"
                    : "Select which telemetry cards to display (CPU, RAM, GPU)"
                icon: "network-server-symbolic"
                showDivider: ConfigManager.timeCapsuleShowHardware

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    // CPU Pill Toggle
                    Rectangle {
                        id: cpuPill
                        height: 28
                        implicitWidth: cpuPillText.implicitWidth + Theme.space16
                        radius: 14
                        color: ConfigManager.timeCapsuleShowCpu ? Theme.notchSurfaceActive : (cpuMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                        border.color: ConfigManager.timeCapsuleShowCpu ? Theme.notchBorderHighlight : (cpuMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                        Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                        Text {
                            id: cpuPillText
                            anchors.centerIn: parent
                            text: "CPU"
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            font.weight: ConfigManager.timeCapsuleShowCpu ? Font.DemiBold : Font.Normal
                            color: ConfigManager.timeCapsuleShowCpu ? Theme.notchText : Theme.notchTextSecondary
                        }

                        MouseArea {
                            id: cpuMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ConfigManager.setTimeCapsuleShowCpu(!ConfigManager.timeCapsuleShowCpu)
                        }
                    }

                    // RAM Pill Toggle
                    Rectangle {
                        id: ramPill
                        height: 28
                        implicitWidth: ramPillText.implicitWidth + Theme.space16
                        radius: 14
                        color: ConfigManager.timeCapsuleShowRam ? Theme.notchSurfaceActive : (ramMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                        border.color: ConfigManager.timeCapsuleShowRam ? Theme.notchBorderHighlight : (ramMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                        Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                        Text {
                            id: ramPillText
                            anchors.centerIn: parent
                            text: "RAM"
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            font.weight: ConfigManager.timeCapsuleShowRam ? Font.DemiBold : Font.Normal
                            color: ConfigManager.timeCapsuleShowRam ? Theme.notchText : Theme.notchTextSecondary
                        }

                        MouseArea {
                            id: ramMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ConfigManager.setTimeCapsuleShowRam(!ConfigManager.timeCapsuleShowRam)
                        }
                    }

                    // GPU Pill Toggle
                    Rectangle {
                        id: gpuPill
                        height: 28
                        implicitWidth: gpuPillText.implicitWidth + Theme.space16
                        radius: 14
                        color: ConfigManager.timeCapsuleShowGpu ? Theme.notchSurfaceActive : (gpuMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                        border.color: ConfigManager.timeCapsuleShowGpu ? Theme.notchBorderHighlight : (gpuMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                        Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                        Text {
                            id: gpuPillText
                            anchors.centerIn: parent
                            text: "GPU"
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            font.weight: ConfigManager.timeCapsuleShowGpu ? Font.DemiBold : Font.Normal
                            color: ConfigManager.timeCapsuleShowGpu ? Theme.notchText : Theme.notchTextSecondary
                        }

                        MouseArea {
                            id: gpuMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ConfigManager.setTimeCapsuleShowGpu(!ConfigManager.timeCapsuleShowGpu)
                        }
                    }
                }
            }

            // Show Temperatures Toggle
            SettingsRow {
                visible: ConfigManager.timeCapsuleShowHardware
                title: I18n.isRTL ? "إظهار درجات الحرارة" : "Show Temperatures"
                subtitle: I18n.isRTL
                    ? "عرض درجات حرارة المعالج وكرت الشاشة بجانب نسبة الاستهلاك"
                    : "Display CPU and GPU core temperatures alongside usage percentage"
                icon: "sensors-temperature-symbolic"
                showDivider: false
                clickable: true
                onClicked: {
                    ConfigManager.setTimeCapsuleShowTemps(!ConfigManager.timeCapsuleShowTemps);
                }

                SettingsToggle {
                    checked: ConfigManager.timeCapsuleShowTemps
                    onToggled: ch => {
                        ConfigManager.setTimeCapsuleShowTemps(ch);
                    }
                }
            }
        }
    }
}
