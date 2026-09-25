pragma Singleton
import QtQuick
import "."

Item {
    id: root

    property string locale: ConfigManager.uiLanguage || "en"
    readonly property bool isRTL: locale === "ar"
    readonly property int layoutDirection: isRTL ? Qt.RightToLeft : Qt.LeftToRight

    readonly property var translations: ({
        "en": {
            // Navigation

            // Smart Notch Tabs
            "notch_tab_home": "Home",
            "notch_tab_share": "Share",
            "notch_tab_notifications": "Notifications",

            // Common
            "settings": "Settings",
            "settings_app_desc": "System settings and desktop configuration",
            "app_store": "App Store",
            "app_store_desc": "Install, remove and update apps",
            "search_settings": "Search settings...",
            "system_overview": "System Overview",
            "active": "Active",
            "enabled": "Enabled",
            "disabled": "Disabled",
            "default": "Default",
            "primary": "Primary",
            "secondary": "Secondary",
            "add": "Add",
            "remove": "Remove",
            "browse": "Browse...",
            "change": "Change",
            "apply": "Apply",
            "refresh": "Refresh",
            "connected": "Connected",
            "disconnected": "Disconnected",
            "connecting": "Connecting...",
            "copy": "Copy",
            "copied": "Copied!",
            "password": "Password",
            "windows_default": "Windows Default",

            // Language & Keyboard
            "language_desc": "Configure keyboard layouts, input languages, and switching hotkeys",
            "ui_language_title": "Interface Language",
            "ui_language_desc": "Select the primary display language for the DeloWay desktop interface",
            "keyboard_layouts_title": "Keyboard Layouts",
            "keyboard_layouts_desc": "Manage installed keyboard input methods and switching hotkey",
            "active_layout": "Active Layout",
            "installed_layouts": "Installed Layouts",
            "add_language": "Add Language",
            "switch_shortcut": "Switching Shortcut",
            "switch_shortcut_desc": "Standard Windows shortcut for rapid layout switching",
            "shift_alt_label": "Shift + Alt (Windows Standard)",
            "super_space_label": "Super + Space",
            "lang_en": "English (United States)",
            "lang_ar": "العربية (Arabic)",
            "layout_us": "English (US)",
            "layout_ara": "Arabic (العربية)",
            "layout_fr": "French (Français)",
            "layout_de": "German (Deutsch)",
            "layout_es": "Spanish (Español)",
            "layout_tr": "Turkish (Türkçe)",

            // Appearance
            "display_scaling": "Display Text Size",
            "display_scaling_desc": "Adjust font scale across all system elements",
            "wallpaper_title": "Desktop Wallpaper",
            "wallpaper_desc": "Select desktop background or browse your local files",
            "open_pictures_folder": "Open Pictures Folder",
            "open_image": "Open Image",
            "open_folder": "Open Folder",
            "browse_wallpaper": "Choose Image File...",
            "theme_mode": "Theme Mode",
            "theme_mode_desc": "Switch between dark and light appearance",
            "dark_mode": "Dark",
            "light_mode": "Light",
            "apply_system_theme": "Apply Theme to System Applications",
            "apply_system_theme_desc": "Apply DeloWay dark and light color palette to GTK and system applications",
            "corner_radius": "Window Corner Radius",
            "corner_radius_desc": "Adjust roundness of desktop windows and panels",

            // Default Apps
            "applications_desc": "Configure preferred applications for common web, terminal, and editing tasks",
            "default_apps_desc": "Configure preferred applications for common web, terminal, and editing tasks",
            "web_browser": "Web Browser",
            "web_browser_desc": "Default browser for opening web links and HTML files",
            "terminal_emulator": "Terminal Emulator",
            "terminal_emulator_desc": "Default terminal for running shell scripts and command line",
            "file_manager": "File Manager",
            "file_manager_desc": "Default application for browsing folders and files",
            "code_editor": "Text / Code Editor",
            "code_editor_desc": "Default editor for opening source code and configuration files",

            // Desktop & Dock
            "desktop": "Desktop",
            "desktop_mode": "Desktop Mode",
            "desktop_mode_desc": "Choose between minimal clean surface or widget-enabled workspace",
            "clean_mode": "Clean Desktop",
            "widgets_mode": "Widgets Mode",
            "desktop_icons": "Desktop Icons",
            "desktop_icons_desc": "Show shortcuts for Home, Trash, and mounted drives on desktop",
            "dock_desc": "Configure dock position, icon scaling, and auto-hide behavior",
            "dock_position": "Dock Position",
            "dock_position_desc": "Choose which edge of the screen the dock is anchored to",
            "bottom": "Bottom",
            "left": "Left",
            "right": "Right",
            "dock_autohide": "Auto-Hide Dock",
            "dock_autohide_desc": "Automatically conceal dock when windows overlap it",
            "dock_icon_size": "Dock Icon Size",
            "dock_icon_size_desc": "Size of application icons rendered in the dock",

            // Top Bar
            "topbar_desc": "Customize top status bar components, clock display, and indicators",
            "show_brand": "Show DeloWay Brand Icon",
            "show_brand_desc": "Display the DeloWay logo launcher in top left corner",
            "show_workspaces": "Show Workspace Indicators",
            "show_workspaces_desc": "Display numeric workspace pills in the top bar",
            "clock_format": "Clock Format",
            "clock_format_desc": "Switch between 12-hour (AM/PM) and 24-hour military clock",
            "12h": "12-Hour (AM/PM)",
            "24h": "24-Hour",

            // Windows
            "windows_desc": "Configure window management, inner/outer gaps, and border styling",
            "window_gaps": "Window Gaps",
            "window_gaps_desc": "Adjust spacing between tiled windows and outer screen edges",
            "gaps_in": "Inner Gaps",
            "gaps_out": "Outer Gaps",
            "active_border": "Active Window Border",
            "active_border_desc": "Accent color highlight applied to the currently focused window",

            // Network & Wi-Fi
            "network_desc": "Manage network interfaces, Wi-Fi connections, and IP addresses",
            "network_status": "Connection Status",
            "network_details": "Network Connection Details",
            "ip_address": "IP Address",
            "gateway": "Gateway",
            "dns": "DNS Server",
            "mac_address": "MAC Address",
            "wifi_networks": "Available Wi-Fi Networks",
            "connect_btn": "Connect",

            // Bluetooth
            "bluetooth_desc": "Manage Bluetooth adapter, discovered devices, and pairings",
            "bluetooth_status": "Bluetooth Status",
            "bluetooth_devices": "Paired & Discovered Devices",
            "pair": "Pair",
            "forget": "Forget",

            // Power
            "power_desc": "Manage power profiles, screen blanking, and battery optimization",
            "power_profile": "Power Profile",
            "power_profile_desc": "Select performance vs energy savings balance",
            "balanced": "Balanced",
            "performance": "Performance",
            "power_saver": "Power Saver",
            "screen_sleep": "Screen Sleep Timeout",
            "screen_sleep_desc": "Turn off screen after inactivity (0 = never)",

            // Notifications
            "dnd_mode": "Do Not Disturb",
            "dnd_mode_desc": "Suppress all incoming desktop notifications",
            "notif_timeout": "Notification Duration",
            "notif_timeout_desc": "Time notification cards stay on screen",
            "notif_sound": "Notification Sound",
            "notif_sound_desc": "Play an audible alert when notifications arrive",
            "sec_short": "s",

            // Shortcuts

            // About
            "about_desc": "System hardware, distribution details, and environment specifications",
            "about_hardware_overview": "System & Hardware Overview",
            "about_hardware_desc": "Host kernel and device details",
            "os_name": "Operating System",
            "hyprland_ver": "Window Manager",
            "compositor": "Shell Engine",
            "kernel": "Linux Kernel",
            "hardware_platform": "Architecture",
            "uptime": "Uptime",
            "processor": "Processor",
            "system_memory": "System Memory",
            "shell_font": "Shell Font",
            "mono_font": "Monospace Font",
            "loading": "Loading…",

            // Controls & Headers
            "drag_hint": "Drag header to move window • Super+F to maximize",
            "dock_underline": "Active Window Underline",
            "dock_underline_desc": "Show indicator bar beneath focused app icon",
            "pinned_apps": "Pinned Apps",
            "pinned_apps_count": "apps currently pinned to dock",
            "workspaces_count": "Workspaces Count",
            "workspaces_count_desc": "Number of virtual desktop workspaces",
            "layout_presets": "Layout Presets",
            "layout_presets_desc": "Quick configurations for gaps and window corners",
            "preset_compact": "Compact",
            "preset_standard": "Standard",
            "preset_spacious": "Spacious",
            "gaps_in_desc": "Spacing between adjacent tiled windows",
            "gaps_out_desc": "Spacing between windows and screen boundary",
            "wired_network": "Wired Network (Ethernet)",
            "wired_network_desc": "Active physical cable connection",
            "interface_label": "Interface",
            "copy_ip": "Copy IP",
            "wifi_title": "Wi-Fi",
            "wifi_desc": "Wireless networks and radio control",
            "radio_on": "Radio On",
            "radio_off": "Radio Off",
            "wifi_enabled": "Wi-Fi is enabled",
            "wifi_disabled": "Wi-Fi radio is turned off",
            "enable_wifi": "Enable Wi-Fi",
            "disable_wifi": "Disable Wi-Fi",
            "scan_networks": "Scan Networks",
            "scanning": "Scanning…",
            "no_wifi_adapter": "No wireless adapter detected on this system. Operating on high-speed Ethernet (eno1).",
            "no_wifi_range": "No wireless networks found in range.",
            "bluetooth_status_desc": "Hardware adapter and radio power state",
            "adapter_on": "Adapter On",
            "adapter_off": "Adapter Off",
            "bt_enabled": "Bluetooth is active",
            "bt_disabled": "Bluetooth adapter is turned off",
            "enable_bt": "Enable Bluetooth",
            "disable_bt": "Disable Bluetooth",
            "scan_devices": "Scan Devices",
            "bluetooth_devices_desc": "Bluetooth devices paired with this computer",
            "devices": "Devices",
            "no_bt_devices": "No paired Bluetooth devices found. Click 'Scan Devices' above to search for nearby hardware.",
            "connect": "Connect",
            "disconnect": "Disconnect",
            "paired": "Paired",
            "power_perf": "Performance (Max CPU)",
            "power_bal": "Balanced (Recommended)",
            "power_sav": "Power Saver",
            "never": "Never",
            "min": "min",

            // Setup Wizard & General
            "welcome_deloos": "Welcome to DeloOS",
            "setup_wizard_desc": "Configure your personalized desktop experience (§5.10)",
            "icon_theme_missing_title": "Icon theme not installed",
            "icon_theme_missing_body": "“%1” is missing, so apps show letters instead of icons. Run install.sh in the DeloWay folder to install it.",
            "step_language": "0. Interface Language",
            "step_language_desc": "Choose your preferred interface language and desktop layout.",
            "step_theme": "1. System Theme & Accent Color",
            "step_theme_desc": "Choose between Dark Mica or Crisp Light theme, and pick your primary accent color.",
            "step_desktop": "2. Desktop Experience Mode",
            "step_desktop_desc": "Select how your desktop surface behaves. You can switch modes at any time from Desktop settings.",
            "step_dock": "3. Dock & Top Bar Preferences",
            "step_dock_desc": "Configure the position and auto-hide behavior of the application Dock and the Top Bar.",
            "step_apps": "4. Recommended Applications",
            "step_apps_desc": "Install the curated suite of native applications for Deloway.",
            "step_windows": "5. Window Management & Tiling Style",
            "step_windows_desc": "Configure window gaps and corner rounding. Powered by Hyprland Dwindle tiling.",
            "step_review": "6. Essential Keybindings & Review",
            "step_review_desc": "You are all set! Here is a quick reference for the most essential shortcuts:",
            "next_step": "Next Step →",
            "finish_start": "Finish & Start →",
            "back_btn": "← Back",
            "install_btn": "Install",
            "installed_btn": "Installed",

            // Cheat Sheet
            "widget_time_date": "TIME & DATE",
            "widget_weather": "WEATHER",
            "widget_system": "SYSTEM MONITOR",
            "widget_notes": "QUICK NOTES",
            "widget_humidity": "Humidity:",
            "widget_wind": "Wind:",
            "widget_uv": "UV index:",
            "widget_cpu": "CPU load",
            "widget_memory": "Memory usage",
            "widget_notes_placeholder": "Type notes or tasks here…",
            "cs_title": "Keyboard Shortcuts",
            "cs_general": "General",
            "cs_shell": "Shell",
            "cs_utilities": "Utilities",
            "cs_window": "Window",
            "cs_workspace": "Workspace",
            "cs_media": "Media",
            "cs_apps": "Apps",

            // App Drawer
            "pinned": "Pinned",
            "all_apps": "All Apps",
            "pin_to_dock": "Pin to Dock",
            "unpin_from_dock": "Unpin from Dock",
            "open_app": "Open",
            "trash_title": "Trash",
            "app_menu_title": "Apps",
            "app_info": "App Info",
            "app_uninstall": "Uninstall…",
            "app_uninstall_confirm": "Uninstall %1?",
            "app_uninstall_action": "Uninstall",
            "app_cancel": "Cancel",
            "app_uninstalled": "%1 was uninstalled",
            "app_uninstalled_shortcut": "Only the launcher was removed. It is in the Trash.",
            "app_uninstall_failed": "Couldn't uninstall %1",
            "app_uninstall_cancelled": "Authorization was cancelled.",
            "app_uninstalling": "Uninstalling…",
            "app_reason_protected": "Part of the core system. It can't be removed from here.",
            "app_reason_required": "Required by:",
            "app_reason_unmanaged": "Not managed by a package manager.",
            "app_reason_lookup": "Couldn't read package information.",
            "app_remove_shortcut": "Moves the launcher to the Trash. The program itself stays.",
            "app_remove_package": "Removes package %1",
            "app_checking": "Checking…",
            "app_source_pacman": "System package",
            "app_source_aur": "AUR package",
            "app_source_flatpak": "Flatpak",
            "app_source_webapp": "Web app",
            "app_source_user": "User shortcut",
            "app_source_unowned": "Unmanaged",
            "app_details": "App Details",
            "app_package": "Package",
            "app_size": "Installed size",
            "app_installed_on": "Installed on",
            "app_homepage": "Homepage",
            "app_launcher_file": "Launcher file",
            "app_command": "Command",
            "app_view_in_store": "View in Store",
            "drawer_cat_internet": "Internet",
            "drawer_cat_media": "Media",
            "drawer_cat_office": "Office",
            "drawer_cat_graphics": "Graphics",
            "drawer_cat_development": "Development",
            "drawer_cat_games": "Games",
            "drawer_cat_education": "Education & Science",
            "drawer_cat_system": "System",
            "drawer_cat_utilities": "Utilities",
            "drawer_cat_other": "Other",
            "drawer_view_folders": "Folders",
            "drawer_view_az": "A–Z",
            "lock_placeholder": "Enter password",
            "lock_verifying": "Verifying…",
            "lock_wrong": "Incorrect password",
            "lock_max_tries": "Too many attempts. Try again later.",
            "lock_error": "Authentication error",
            "lock_unavailable": "Authentication service unavailable",
            "lock_unlock": "Unlock",
            "dock_new_window": "New Window",
            "dock_close_window": "Close Window",
            "dock_close_all": "Close All Windows",
            "dock_maximize": "Maximize",
            "dock_unmaximize": "Restore Size",
            "dock_minimize": "Minimize",
            "dock_restore": "Restore",
            "screenshot_selection": "Selection",
            "screenshot_window": "Active Window",
            "screenshot_fullscreen": "Full Screen",

            // Smart Notch & LocalSend
            "notch_now_playing": "Now Playing",
            "notch_sending_to": "Sending to",
            "notch_sent_success": "Sent successfully!",
            "notch_sent_failed": "Transfer failed",
            "notch_try_again": "Try Again",
            "common_cancel": "Cancel",
            "notch_today_events": "Nothing for today",
            "settings_group_connectivity": "CONNECTIVITY",
            "settings_group_personalization": "PERSONALIZATION",
            "settings_group_system": "SYSTEM",
            "settings_page_network": "Network & Internet",
            "settings_page_network_desc": "Wi-Fi, personal hotspot, saved networks and IP details",
            "settings_page_bluetooth": "Bluetooth",
            "settings_page_bluetooth_desc": "Turn Bluetooth on or off and manage paired devices",
            "settings_page_appearance": "Appearance",
            "settings_page_appearance_desc": "Theme, fonts, corner radius and visual effects",
            "settings_page_wallpaper": "Wallpaper",
            "settings_page_wallpaper_desc": "Choose a desktop background from the gallery or your files",
            "settings_page_topbar": "Top Bar",
            "settings_page_topbar_desc": "Smart Notch workspaces, time capsule and hardware monitor",
            "settings_page_dock": "Dock",
            "settings_page_dock_desc": "Size, position, behaviour and pinned applications",
            "settings_page_windows": "Windows & Workspaces",
            "settings_page_windows_desc": "Gaps, rounding, focus behaviour and workspace count",
            "settings_page_notifications": "Notifications",
            "settings_page_notifications_desc": "Do Not Disturb, sounds, timeout and Notch banners",
            "settings_page_power": "Power & Display",
            "settings_page_power_desc": "Power profile and screen sleep timeout",
            "settings_page_apps": "Apps",
            "settings_page_apps_desc": "Default browser, terminal and file manager, and music player",
            "settings_page_time_language": "Time & Language",
            "settings_page_time_language_desc": "Interface language, time format and calendar",
            "settings_page_about": "About",
            "settings_page_about_desc": "System information, keyboard shortcuts and reset",
            "tk_tab_time": "Time",
            "tk_tab_system": "System",
            "tk_alarm": "Alarm",
            "tk_timer": "Timer",
            "tk_timer_done": "Time's up",
            "tk_reminder": "Reminder",
            "tk_today": "Today",
            "tk_no_events": "No reminders",
            "tk_new_event": "New reminder…",
            "tk_daily": "Daily",
            "tk_once": "Once",
            "tk_off": "Off",
            "tk_rings_in": "Rings in",
            "tk_ringing": "Ringing",
            "tk_snooze": "Snooze",
            "tk_stop": "Stop",
            "tk_done": "Done",
            "tk_uptime": "up",
            "tk_hw_disabled": "Hardware monitoring is turned off in Settings",
            "tc_processor": "Processor",
            "tc_processes": "Processes",
            "tc_disk": "Disk",
            "tc_load": "Load",
            "tc_threads": "threads",
            "tc_free": "free",
            "notch_select_device": "Select Recipient Device",
            "notch_send_more": "Send More Files",
            "notch_files_ready": "files ready to send",
            "notch_file_ready": "file ready to send",
            "notch_status_ready": "Ready to send & receive",
            "notch_status_stopped": "Service stopped",
            "notch_open_app": "Open App",
            "notch_no_devices": "No devices found on local network",
            "notch_no_devices_hint": "Open LocalSend on your phone or other device on the same Wi-Fi",
            "notch_scan_network": "Scan Network",
            "notch_scanning": "Scanning network..."
        },
        "ar": {
            // Navigation

            // Smart Notch Tabs
            "notch_tab_home": "الرئيسية",
            "notch_tab_share": "مشاركة",
            "notch_tab_notifications": "الإشعارات",

            // Common
            "settings": "الإعدادات",
            "settings_app_desc": "إعدادات النظام وتخصيص سطح المكتب",
            "app_store": "متجر التطبيقات",
            "app_store_desc": "تثبيت التطبيقات وإزالتها وتحديثها",
            "search_settings": "بحث في الإعدادات...",
            "system_overview": "نظرة عامة على النظام",
            "active": "نشط",
            "enabled": "مفعل",
            "disabled": "معطل",
            "default": "افتراضي",
            "primary": "أساسي",
            "secondary": "إضافي",
            "add": "إضافة",
            "remove": "إزالة",
            "browse": "استعراض...",
            "change": "تغيير",
            "apply": "تطبيق",
            "refresh": "تحديث",
            "connected": "متصل",
            "disconnected": "غير متصل",
            "connecting": "جارٍ الاتصال...",
            "copy": "نسخ",
            "copied": "تم النسخ!",
            "password": "كلمة المرور",
            "windows_default": "الافتراضي لويندوز",

            // Language & Keyboard
            "language_desc": "إدارة لغات الإدخال المثبتة وتخطيطات لوحة المفاتيح واختصارات التبديل",
            "ui_language_title": "لغة واجهة النظام",
            "ui_language_desc": "حدد لغة العرض الأساسية لكافة عناصر وقوائم سطح مكتب DeloWay",
            "keyboard_layouts_title": "تخطيطات لوحة المفاتيح",
            "keyboard_layouts_desc": "إدارة لغات الإدخال المثبتة وتخصيص اختصار التبديل السريع",
            "active_layout": "اللغة الحالية",
            "installed_layouts": "اللغات المثبتة",
            "add_language": "إضافة لغة كيبورد",
            "switch_shortcut": "اختصار تبديل اللغة",
            "switch_shortcut_desc": "الاختصار القياسي لنظام ويندوز للتبديل الفوري بين اللغات",
            "shift_alt_label": "Shift + Alt (الافتراضي لويندوز)",
            "super_space_label": "Super + Space",
            "lang_en": "English (United States)",
            "lang_ar": "العربية (المملكة العربية السعودية)",
            "layout_us": "الإنجليزية (English US)",
            "layout_ara": "العربية (Arabic)",
            "layout_fr": "الفرنسية (Français)",
            "layout_de": "الألمانية (Deutsch)",
            "layout_es": "الإسبانية (Español)",
            "layout_tr": "التركية (Türkçe)",

            // Appearance
            "display_scaling": "حجم خطوط النظام",
            "display_scaling_desc": "ضبط مقياس النصوص والخطوط عبر كافة عناصر الواجهة",
            "wallpaper_title": "خلفية سطح المكتب",
            "wallpaper_desc": "اختر خلفية سطح المكتب المفضلة أو استعرض ملفات جهازك",
            "open_pictures_folder": "فتح مجلد الصور",
            "open_image": "فتح الصورة",
            "open_folder": "فتح المجلد",
            "browse_wallpaper": "اختيار صورة من الملفات...",
            "theme_mode": "وضع المظهر",
            "theme_mode_desc": "التبديل بين المظهر الداكن والمظهر الفاتح",
            "dark_mode": "داكن",
            "light_mode": "فاتح",
            "apply_system_theme": "تطبيق الثيم على برامج النظام",
            "apply_system_theme_desc": "تطبيق لوحة ألوان DeloWay (الداكنة/الفاتحة) على تطبيقات GTK وبرامج النظام",
            "corner_radius": "استدارة حواف النوافذ",
            "corner_radius_desc": "ضبط درجة انحناء زوايا النوافذ والقوائم",

            // Default Apps
            "applications_desc": "تحديد التطبيقات الافتراضية لتصفح الويب، الطرفية، وتحرير الأكواد",
            "default_apps_desc": "تحديد التطبيقات الافتراضية لتصفح الويب، الطرفية، وتحرير الأكواد",
            "web_browser": "متصفح الويب",
            "web_browser_desc": "المتصفح الافتراضي لفتح الروابط وصفحات الويب",
            "terminal_emulator": "مشغل الأوامر (الطرفية)",
            "terminal_emulator_desc": "الطرفية الافتراضية لتشغيل الأوامر والسكربتات البرمجية",
            "file_manager": "مدير الملفات",
            "file_manager_desc": "التطبيق الافتراضي لتصفح المجلدات والملفات",
            "code_editor": "محرر النصوص البرمجية",
            "code_editor_desc": "المحرر الافتراضي لفتح ملفات البرمجة والإعدادات",

            // Desktop & Dock
            "desktop": "سطح المكتب",
            "desktop_mode": "نمط سطح المكتب",
            "desktop_mode_desc": "الاختيار بين سطح مكتب نظيف وبسيط أو مدمج بأدوات ذكية",
            "clean_mode": "سطح مكتب نظيف",
            "widgets_mode": "وضع الأدوات (Widgets)",
            "desktop_icons": "أيقونات سطح المكتب",
            "desktop_icons_desc": "عرض اختصارات مجلد المستخدم وسلة المهملات على سطح المكتب",
            "dock_desc": "تخصيص موقع شريط المهام وحجم الأيقونات وسلوك الإخفاء التلقائي",
            "dock_position": "موضع شريط المهام",
            "dock_position_desc": "تحديد جهة الشاشة التي يرتكز عليها شريط المهام",
            "bottom": "أسفل",
            "left": "يسار",
            "right": "يمين",
            "dock_autohide": "الإخفاء التلقائي",
            "dock_autohide_desc": "إخفاء شريط المهام تلقائياً عند تداخل النوافذ معه",
            "dock_icon_size": "حجم أيقونات الشريط",
            "dock_icon_size_desc": "التحكم في أبعاد أيقونات البرامج في شريط المهام",

            // Top Bar
            "topbar_desc": "تخصيص مكونات الشريط العلوي، وتنسيق الساعة، والمؤشرات",
            "show_brand": "شعار نظام DeloWay",
            "show_brand_desc": "إظهار أيقونة DeloWay لفتح القائمة في الزاوية العلوية",
            "show_workspaces": "مؤشرات مساحات العمل",
            "show_workspaces_desc": "عرض أرقام مساحات العمل للتبديل السريع بينها",
            "clock_format": "تنسيق الساعة",
            "clock_format_desc": "التبديل بين نظام 12 ساعة (ص/م) ونظام 24 ساعة العسكري",
            "12h": "12 ساعة (ص / م)",
            "24h": "24 ساعة",

            // Windows
            "windows_desc": "إدارة إطارات النوافذ والمسافات الفاصلة وسلوك التركيز",
            "window_gaps": "المسافات بين النوافذ (Gaps)",
            "window_gaps_desc": "ضبط المسافات الفاصلة بين النوافذ وحدود الشاشة الخارجية",
            "gaps_in": "المسافة الداخلية",
            "gaps_out": "المسافة الخارجية",
            "active_border": "لون إطار النافذة النشطة",
            "active_border_desc": "لون التمييز المحيط بالنافذة المحددة حالياً",

            // Network & Wi-Fi
            "network_desc": "إدارة بطاقات الشبكة، اتصالات الواي فاي، وعناوين IP",
            "network_status": "حالة الاتصال",
            "network_details": "تفاصيل اتصال الشبكة",
            "ip_address": "عنوان IP",
            "gateway": "البوابة الافتراضية",
            "dns": "خادم DNS",
            "mac_address": "عنوان MAC",
            "wifi_networks": "شبكات الواي فاي المتاحة",
            "connect_btn": "اتصال",

            // Bluetooth
            "bluetooth_desc": "إدارة محول البلوتوث، والأجهزة المكتشفة، والاقتران",
            "bluetooth_status": "حالة البلوتوث",
            "bluetooth_devices": "الأجهزة المقترنة والمكتشفة",
            "pair": "اقتران",
            "forget": "إلغاء الاقتران",

            // Power
            "power_desc": "إدارة خطط الطاقة، إيقاف تشغيل الشاشة، وتوفير البطارية",
            "power_profile": "خطة الطاقة",
            "power_profile_desc": "الموازنة بين الأداء العالي وتوفير استهلاك الطاقة",
            "balanced": "متوازن",
            "performance": "أداء عالي",
            "power_saver": "توفير الطاقة",
            "screen_sleep": "مهلة إيقاف الشاشة",
            "screen_sleep_desc": "إيقاف الشاشة عند عدم الاستخدام (0 = أبداً)",

            // Notifications
            "dnd_mode": "عدم الإزعاج (DND)",
            "dnd_mode_desc": "كتم وإيقاف ظهور كافة الإشعارات على سطح المكتب",
            "notif_timeout": "مدة ظهور الإشعار",
            "notif_timeout_desc": "المدة الزمنية لبقاء بطاقة التنبيه على الشاشة",
            "notif_sound": "صوت الإشعار",
            "notif_sound_desc": "تشغيل نغمة تنبيه صوتية عند وصول إشعار جديد",
            "sec_short": " ثوانٍ",

            // Shortcuts

            // About
            "about_desc": "مواصفات عتاد الجهاز، وتفاصيل التوزيعة، وبيئة سطح المكتب",
            "about_hardware_overview": "نظرة عامة على العتاد والنظام",
            "about_hardware_desc": "تفاصيل النواة ومواصفات الجهاز",
            "os_name": "نظام التشغيل",
            "hyprland_ver": "مدير النوافذ",
            "compositor": "محرك الواجهة",
            "kernel": "نواة لينكس (Kernel)",
            "hardware_platform": "المعمارية",
            "uptime": "مدة تشغيل الجهاز",
            "processor": "المعالج (CPU)",
            "system_memory": "الذاكرة العشوائية (RAM)",
            "shell_font": "خط الواجهة الأساسي",
            "mono_font": "خط الأكواد البرمجية",
            "loading": "جارٍ التحميل…",

            // Controls & Headers
            "drag_hint": "اسحب الشريط لتحريك النافذة • Super+F للتكبير",
            "dock_underline": "شريط تمييز التطبيق النشط",
            "dock_underline_desc": "إظهار خط مميز أسفل أيقونة التطبيق المفتوح حالياً",
            "pinned_apps": "التطبيقات المثبتة",
            "pinned_apps_count": "تطبيقات مثبتة حالياً على الشريط",
            "workspaces_count": "عدد مساحات العمل",
            "workspaces_count_desc": "عدد مساحات سطح المكتب الافتراضية المتاحة",
            "layout_presets": "قوالب توزيع النوافذ",
            "layout_presets_desc": "إعدادات مسبقة سريعة للمسافات واستدارة زوايا النوافذ",
            "preset_compact": "مدمج",
            "preset_standard": "قياسي",
            "preset_spacious": "فسيح",
            "gaps_in_desc": "التباعد بين النوافذ المتجاورة في الشاشة",
            "gaps_out_desc": "المسافة الفاصلة بين حواف النوافذ وحدود الشاشة",
            "wired_network": "الشبكة السلكية (Ethernet)",
            "wired_network_desc": "اتصال كابل الشبكة الفيزيائي الفعّال",
            "interface_label": "المنفذ",
            "copy_ip": "نسخ الـ IP",
            "wifi_title": "شبكة الواي فاي",
            "wifi_desc": "إدارة الشبكات اللاسلكية والراديو",
            "radio_on": "الراديو يعمل",
            "radio_off": "الراديو متوقف",
            "wifi_enabled": "الواي فاي مفعل",
            "wifi_disabled": "راديو الواي فاي متوقف حالياً",
            "enable_wifi": "تشغيل الواي فاي",
            "disable_wifi": "إيقاف الواي فاي",
            "scan_networks": "فحص الشبكات",
            "scanning": "جارٍ الفحص…",
            "no_wifi_adapter": "لا يوجد كارت واي فاي متصل بالجهاز. الاتصال الحالي عبر شبكة الإيثرنت السلكية الفائقة (eno1).",
            "no_wifi_range": "لم يتم العثور على أي شبكات واي فاي في النطاق.",
            "bluetooth_status_desc": "حالة محول البلوتوث والراديو",
            "adapter_on": "المحول يعمل",
            "adapter_off": "المحول متوقف",
            "bt_enabled": "البلوتوث نشط ويعمل",
            "bt_disabled": "محول البلوتوث متوقف حالياً",
            "enable_bt": "تشغيل البلوتوث",
            "disable_bt": "إيقاف البلوتوث",
            "scan_devices": "البحث عن أجهزة",
            "bluetooth_devices_desc": "أجهزة البلوتوث المقترنة بهذا الجهاز",
            "devices": "أجهزة",
            "no_bt_devices": "لم يتم العثور على أجهزة بلوتوث مقترنة. انقر على 'البحث عن أجهزة' أعلاه للاكتشاف.",
            "connect": "اتصال",
            "disconnect": "فصل",
            "paired": "مقترن",
            "power_perf": "أداء عالي (أقصى تردد)",
            "power_bal": "متوازن (موصى به)",
            "power_sav": "توفير الطاقة",
            "never": "أبداً",
            "min": "دقيقة",

            // Setup Wizard & General
            "welcome_deloos": "مرحباً بك في DeloOS",
            "setup_wizard_desc": "معالج الإعداد لأول مرة — خصص تجربة وإعدادات سطح مكتبك (§5.10)",
            "icon_theme_missing_title": "سمة الأيقونات غير مثبّتة",
            "icon_theme_missing_body": "السمة “%1” غير موجودة، لذلك تظهر التطبيقات بحروف بدل أيقوناتها. شغّل install.sh من مجلد DeloWay لتثبيتها.",
            "step_language": "٠. لغة واجهة النظام",
            "step_language_desc": "اختر لغة الواجهة وتخطيط اتجاه سطح المكتب المفضل لديك.",
            "step_theme": "١. مظهر النظام ولون التمييز",
            "step_theme_desc": "اختر بين المظهر الداكن أو الفاتح، وحدد لون التمييز الأساسي.",
            "step_desktop": "٢. نمط تجربة سطح المكتب",
            "step_desktop_desc": "اختر كيفية تفاعل سطح المكتب. يمكنك تغيير النمط في أي وقت من الإعدادات.",
            "step_dock": "٣. تفضيلات شريط المهام والشريط العلوي",
            "step_dock_desc": "تخصيص موضع وسلوك الإخفاء التلقائي لشريط المهام والشريط العلوي.",
            "step_apps": "٤. التطبيقات الافتراضية المعتمدة",
            "step_apps_desc": "تثبيت حزمة التطبيقات الأساسية المعتمدة لبيئة Deloway.",
            "step_windows": "٥. إدارة النوافذ ونمط التقسيم",
            "step_windows_desc": "ضبط مسافات النوافذ واستدارة الزوايا بنظام Hyprland.",
            "step_review": "٦. اختصارات لوحة المفاتيح والبدء",
            "step_review_desc": "أنت الآن جاهز تماماً! إليك ملخص لأهم اختصارات لوحة المفاتيح:",
            "next_step": "الخطوة التالية ←",
            "finish_start": "إنهاء وبدء الاستخدام ←",
            "back_btn": "→ السابق",
            "install_btn": "تثبيت",
            "installed_btn": "مثبت",

            // Cheat Sheet
            "widget_time_date": "الوقت والتاريخ",
            "widget_weather": "الطقس",
            "widget_system": "مراقب النظام",
            "widget_notes": "ملاحظات سريعة",
            "widget_humidity": "الرطوبة:",
            "widget_wind": "الرياح:",
            "widget_uv": "مؤشر الأشعة:",
            "widget_cpu": "حمل المعالج",
            "widget_memory": "استخدام الذاكرة",
            "widget_notes_placeholder": "اكتب ملاحظاتك أو مهامك هنا…",
            "cs_title": "اختصارات لوحة المفاتيح",
            "cs_general": "عام",
            "cs_shell": "الواجهة واللانشر",
            "cs_utilities": "الأدوات المساعدة",
            "cs_window": "إدارة النوافذ",
            "cs_workspace": "مساحات العمل",
            "cs_media": "الوسائط والصوت",
            "cs_apps": "التطبيقات",

            // App Drawer
            "pinned": "المثبتة",
            "all_apps": "كافة التطبيقات",
            "pin_to_dock": "تثبيت في الشريط",
            "unpin_from_dock": "إلغاء التثبيت من الشريط",
            "open_app": "فتح",
            "app_menu_title": "التطبيقات",
            "app_info": "معلومات التطبيق",
            "app_uninstall": "إلغاء التثبيت…",
            "app_uninstall_confirm": "إلغاء تثبيت %1؟",
            "app_uninstall_action": "إلغاء التثبيت",
            "app_cancel": "تراجع",
            "app_uninstalled": "تم إلغاء تثبيت %1",
            "app_uninstalled_shortcut": "أُزيل المشغّل فقط، وهو الآن في سلة المهملات.",
            "app_uninstall_failed": "تعذّر إلغاء تثبيت %1",
            "app_uninstall_cancelled": "أُلغي طلب الصلاحية.",
            "app_uninstalling": "جارٍ إلغاء التثبيت…",
            "app_reason_protected": "جزء من النظام الأساسي ولا يمكن إزالته من هنا.",
            "app_reason_required": "مطلوب من:",
            "app_reason_unmanaged": "لا يديره أي مدير حزم.",
            "app_reason_lookup": "تعذّرت قراءة معلومات الحزمة.",
            "app_remove_shortcut": "ينقل المشغّل إلى سلة المهملات، ويبقى البرنامج نفسه.",
            "app_remove_package": "يزيل الحزمة %1",
            "app_checking": "جارٍ التحقق…",
            "app_source_pacman": "حزمة نظام",
            "app_source_aur": "حزمة AUR",
            "app_source_flatpak": "Flatpak",
            "app_source_webapp": "تطبيق ويب",
            "app_source_user": "اختصار مستخدم",
            "app_source_unowned": "غير مُدار",
            "app_details": "تفاصيل التطبيق",
            "app_package": "الحزمة",
            "app_size": "الحجم بعد التثبيت",
            "app_installed_on": "تاريخ التثبيت",
            "app_homepage": "الموقع",
            "app_launcher_file": "ملف المشغّل",
            "app_command": "أمر التشغيل",
            "app_view_in_store": "عرض في المتجر",
            "drawer_cat_internet": "الإنترنت",
            "drawer_cat_media": "الوسائط",
            "drawer_cat_office": "المكتب",
            "drawer_cat_graphics": "الرسوميات",
            "drawer_cat_development": "التطوير",
            "drawer_cat_games": "الألعاب",
            "drawer_cat_education": "التعليم والعلوم",
            "drawer_cat_system": "النظام",
            "drawer_cat_utilities": "الأدوات",
            "drawer_cat_other": "أخرى",
            "drawer_view_folders": "مجلدات",
            "drawer_view_az": "أ–ي",
            "lock_placeholder": "أدخل كلمة المرور",
            "lock_verifying": "جارٍ التحقق…",
            "lock_wrong": "كلمة المرور غير صحيحة",
            "lock_max_tries": "محاولات كثيرة، حاول لاحقاً.",
            "lock_error": "خطأ في نظام المصادقة",
            "lock_unavailable": "خدمة المصادقة غير متاحة",
            "lock_unlock": "فتح القفل",
            "dock_new_window": "نافذة جديدة",
            "dock_close_window": "إغلاق النافذة",
            "dock_close_all": "إغلاق كل النوافذ",
            "dock_maximize": "تكبير",
            "dock_unmaximize": "استعادة الحجم",
            "dock_minimize": "تصغير",
            "dock_restore": "استعادة",
            "trash_title": "سلة المهملات",
            "screenshot_selection": "تحديد منطقة",
            "screenshot_window": "النافذة النشطة",
            "screenshot_fullscreen": "كامل الشاشة",

            // Smart Notch & LocalSend
            "notch_now_playing": "يتم التشغيل الآن",
            "notch_sending_to": "جارٍ الإرسال إلى",
            "notch_sent_success": "تم الإرسال بنجاح!",
            "notch_sent_failed": "فشل الإرسال",
            "notch_try_again": "إعادة المحاولة",
            "common_cancel": "إلغاء",
            "notch_today_events": "لا توجد أحداث اليوم",
            "settings_group_connectivity": "الاتصال",
            "settings_group_personalization": "التخصيص",
            "settings_group_system": "النظام",
            "settings_page_network": "الشبكة والإنترنت",
            "settings_page_network_desc": "الواي فاي ونقطة الاتصال الشخصية والشبكات المحفوظة وتفاصيل IP",
            "settings_page_bluetooth": "البلوتوث",
            "settings_page_bluetooth_desc": "تشغيل البلوتوث وإيقافه وإدارة الأجهزة المقترنة",
            "settings_page_appearance": "المظهر",
            "settings_page_appearance_desc": "السمة والخطوط واستدارة الحواف والتأثيرات الرسومية",
            "settings_page_wallpaper": "الخلفية",
            "settings_page_wallpaper_desc": "اختيار خلفية سطح المكتب من المعرض أو من ملفاتك",
            "settings_page_topbar": "الشريط العلوي",
            "settings_page_topbar_desc": "مساحات العمل في النوتش الذكي وكبسولة الوقت ومراقبة العتاد",
            "settings_page_dock": "شريط المهام",
            "settings_page_dock_desc": "الحجم والموضع وطريقة العرض والتطبيقات المثبتة",
            "settings_page_windows": "النوافذ ومساحات العمل",
            "settings_page_windows_desc": "التباعد والاستدارة وسلوك التركيز وعدد مساحات العمل",
            "settings_page_notifications": "الإشعارات",
            "settings_page_notifications_desc": "عدم الإزعاج والأصوات ومدة الظهور وإشعارات النوتش",
            "settings_page_power": "الطاقة والشاشة",
            "settings_page_power_desc": "وضع الطاقة ومهلة سكون الشاشة",
            "settings_page_apps": "التطبيقات",
            "settings_page_apps_desc": "المتصفح والطرفية ومدير الملفات الافتراضية، ومشغّل الموسيقى",
            "settings_page_time_language": "الوقت واللغة",
            "settings_page_time_language_desc": "لغة الواجهة وتنسيق الوقت والتقويم",
            "settings_page_about": "حول",
            "settings_page_about_desc": "معلومات النظام واختصارات لوحة المفاتيح وإعادة الضبط",
            "tk_tab_time": "الوقت",
            "tk_tab_system": "النظام",
            "tk_alarm": "المنبه",
            "tk_timer": "المؤقت",
            "tk_timer_done": "انتهى الوقت",
            "tk_reminder": "تذكير",
            "tk_today": "اليوم",
            "tk_no_events": "لا توجد تذكيرات",
            "tk_new_event": "تذكير جديد…",
            "tk_daily": "يومياً",
            "tk_once": "مرة",
            "tk_off": "متوقف",
            "tk_rings_in": "يرن بعد",
            "tk_ringing": "يرن الآن",
            "tk_snooze": "غفوة",
            "tk_stop": "إيقاف",
            "tk_done": "انتهى",
            "tk_uptime": "تشغيل",
            "tk_hw_disabled": "مراقبة العتاد متوقفة من الإعدادات",
            "tc_processor": "المعالج",
            "tc_processes": "العمليات",
            "tc_disk": "القرص",
            "tc_load": "الحمل",
            "tc_threads": "مسار",
            "tc_free": "متاح",
            "notch_select_device": "اختر الجهاز المستلم",
            "notch_send_more": "إرسال ملفات أخرى",
            "notch_files_ready": "ملفات جاهزة للإرسال",
            "notch_file_ready": "ملف جاهز للإرسال",
            "notch_status_ready": "جاهز للاستقبال والإرسال",
            "notch_status_stopped": "الخدمة متوقفة",
            "notch_open_app": "فتح التطبيق",
            "notch_no_devices": "لم يتم العثور على أجهزة متصلة حالياً",
            "notch_no_devices_hint": "تأكد من فتح تطبيق LocalSend على هاتفك أو جهازك الآخر متصلاً بنفس شبكة الـ Wi-Fi",
            "notch_scan_network": "إعادة الفحص",
            "notch_scanning": "جارٍ فحص الشبكة..."
        }
    })

    // "3 windows" / Arabic dual & plural forms (١ نافذة، نافذتان، ٣ نوافذ، ١١ نافذة).
    // ── Locale-aware date & time (Qt.formatDate uses the process C locale, not the
    // shell language, so Arabic names/digits must be produced here). Shared by the lock
    // screen, the Notch idle view, desktop widgets and the Time capsule.
    readonly property var arDays: ["الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت"]
    readonly property var arMonths: ["يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
                                     "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"]
    readonly property var enDays: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    readonly property var enMonths: ["January", "February", "March", "April", "May", "June",
                                     "July", "August", "September", "October", "November", "December"]
    readonly property bool arabicDigits: root.isRTL && !!(typeof ConfigManager !== "undefined" && ConfigManager.timeCapsuleArabicDigits)

    function digits(v) {
        const s = String(v === undefined || v === null ? "" : v);
        return root.arabicDigits ? s.replace(/\d/g, d => "٠١٢٣٤٥٦٧٨٩"[d]) : s;
    }
    // Clock honouring Settings → clock format (24h / 12h). Arabic uses ص/م.
    function clockText(d, withSeconds) {
        if (!d) return "--:--";
        const h24 = (typeof ConfigManager !== "undefined" && ConfigManager.clockFormat === "24h");
        const mm = String(d.getMinutes()).padStart(2, "0");
        const ss = withSeconds ? ":" + String(d.getSeconds()).padStart(2, "0") : "";
        if (h24) return root.digits(String(d.getHours()).padStart(2, "0") + ":" + mm + ss);
        const h = d.getHours() % 12 || 12;
        const ap = d.getHours() < 12 ? (root.isRTL ? "ص" : "AM") : (root.isRTL ? "م" : "PM");
        return root.digits(h + ":" + mm + ss) + " " + ap;
    }
    // Digits only ("8:04", "20:04") and the separate meridiem ("ص"/"PM", "" in 24h),
    // for layouts that style them apart.
    function clockDigits(d) {
        if (!d) return "--:--";
        const h24 = (typeof ConfigManager !== "undefined" && ConfigManager.clockFormat === "24h");
        const mm = String(d.getMinutes()).padStart(2, "0");
        return root.digits((h24 ? String(d.getHours()).padStart(2, "0") : String(d.getHours() % 12 || 12)) + ":" + mm);
    }
    function meridiem(d) {
        if (!d || (typeof ConfigManager !== "undefined" && ConfigManager.clockFormat === "24h")) return "";
        return d.getHours() < 12 ? (root.isRTL ? "ص" : "AM") : (root.isRTL ? "م" : "PM");
    }
    // "الأربعاء، 23 سبتمبر 2026" / "Wednesday, September 23, 2026"
    function fullDateText(d) {
        if (!d) return "";
        if (root.isRTL)
            return root.arDays[d.getDay()] + "، " + root.digits(d.getDate()) + " " + root.arMonths[d.getMonth()] + " " + root.digits(d.getFullYear());
        return root.enDays[d.getDay()] + ", " + root.enMonths[d.getMonth()] + " " + d.getDate() + ", " + d.getFullYear();
    }
    // "الأربعاء، 23 سبتمبر" / "Wed, Sep 23"
    function shortDateText(d) {
        if (!d) return "";
        if (root.isRTL)
            return root.arDays[d.getDay()] + "، " + root.digits(d.getDate()) + " " + root.arMonths[d.getMonth()];
        return root.enDays[d.getDay()].slice(0, 3) + ", " + root.enMonths[d.getMonth()].slice(0, 3) + " " + d.getDate();
    }

    // Bidi helpers for embedding runs in a sentence of the other direction.
    //   isolate(s): user/system text of unknown direction (SSIDs, device and app names)
    //   ltr(s):     always-LTR runs (versions, paths, CLI flags, key combos)
    function isolate(s) { return "\u2068" + (s === undefined || s === null ? "" : s) + "\u2069"; }
    function ltr(s) { return "\u2066" + (s === undefined || s === null ? "" : s) + "\u2069"; }

    // "8 apps" / Arabic: تطبيق واحد، تطبيقان، ٣–١٠ تطبيقات، ١١+ تطبيقًا
    function appsCount(n) {
        if (!root.isRTL) return n + (n === 1 ? " app" : " apps");
        if (n === 1) return "تطبيق واحد";
        if (n === 2) return "تطبيقان";
        if (n >= 3 && n <= 10) return n + " تطبيقات";
        return n + " تطبيقًا";
    }

    function windowsCount(n) {
        if (!root.isRTL) return n + (n === 1 ? " window" : " windows");
        if (n === 1) return "نافذة واحدة";
        if (n === 2) return "نافذتان";
        if (n >= 3 && n <= 10) return n + " نوافذ";
        return n + " نافذة";
    }

    function tr(key, fallback) {
        if (!key) return "";
        var currentDict = translations[root.locale];
        if (currentDict && currentDict[key] !== undefined) {
            return currentDict[key];
        }
        var enDict = translations["en"];
        if (enDict && enDict[key] !== undefined) {
            return enDict[key];
        }
        return (fallback !== undefined) ? fallback : key;
    }

    function setLanguage(lang) {
        if (lang === "en" || lang === "ar") {
            ConfigManager.setUiLanguage(lang);
        }
    }
}
