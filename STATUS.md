# DeloWay Shell — وثيقة المعمارية والحالة الفنية (STATUS.md)

> **الغرض من الملف**: مرجع شامل وكافٍ بذاته لأي نموذج ذكاء اصطناعي "عقل تخطيط" (مثل Claude أو Kimi أو غيرهما) للعمل والتخطيط وتقديم حلول وتشخيصات تقنية دقيقة ومتسقة مع الكود الحالي دون الحاجة للوصول المباشر إلى ملفات المشروع على القرص.
> **قاعدة التحديث الإلزامية**: في نهاية أي مهمة برمجية معتمدة ولها commit، يتم تحديث الأقسام (6، 7، 8، 9) فقط لتعكس واقع Git والقرص الفعلي. الأقسام (1 إلى 5) شبه ثابتة، ولا تُعدّل إلا عند حدوث قرار معماري أو تعديل جذري في نظام التصميم.

---

## 1. نظرة عامة ورؤية المشروع (Project Overview & Vision)
- **المشروع**: DeloWay Shell (DeloOS).
- **الهدف**: بيئة سطح مكتب وقشرة نظام (Desktop Shell) عصرية ومتطورة لأنظمة لينكس مبنية على بروتوكول Wayland ومدير النوافذ Hyprland، تدمج بين أناقة macOS (مثل النوتش التفاعلي Smart Notch والكبسولة QuickSettings) وسرعة وخفة بيئة Arch Linux المستقلة.
- **فلسفة الواجهة**: 
  - لغة تصميم داكنة متباينة OLED Black (`#000000`) مع أسطح زجاجية خافتة وحدود دقيقة متناهية الصغر.
  - دعم كامل وأصيل لاتجاه الكتابة من اليمين لليسار (RTL / اللغة العربية) جنباً إلى جنب مع الإنجليزية.
  - تفاعل فيزيائي انسيابي يعتمد منحنيات تسارع حادة وسريعة (`OutCubic` / 120-220ms).
  - معيارية عالية وفصل صارم بين منطق الخدمات الخلفية (Services) ومكونات العرض البصري (Components).

---

## 2. حزمة التقنيات والبيئة التشغيلية (Tech Stack & Runtime Environment)
- **محرك الواجهة الأساسي**: [Quickshell](https://quickshell.outfoxxed.me/) (مبني على Qt 6 و QML الحديث).
- **مدير النوافذ (Compositor)**: Hyprland (إصدار v0.56.2+).
- **بروتوكول العرض**: Wayland (مع استخدام `wlr_layer_shell_v1` للأسطح الممتدة، و `xdg_popup` للقوائم المنبثقة).
- **التكاملات والخدمات الخلفية**:
  - `Quickshell.Hyprland`: لمراقبة الشاشات، مساحات العمل، والنوافذ وإدارة التركيز (`HyprlandFocusGrab`).
  - `Quickshell.Services.SystemTray`: للتعامل مع بروتوكول StatusNotifierItem (D-Bus) لتطبيقات الخلفية.
  - `Quickshell.Services.Mpris`: للتحكم في مشغلات الموسيقى والوسائط (Spotify وغيرها).
  - `Quickshell.Services.Notifications`: خادم إشعارات مدمج (`NotificationServer`).
  - **بايثون / سكربتات مساعدة**:
    - `scripts/deloway-network.py`: الاتصال بالشبكات اللاسلكية، إدارة نقطة الاتصال (Hotspot) ونقطة الوصول عبر NetworkManager.
    - `scripts/deloway-localsend.py`: وسيط لمشاركة ونقل الملفات عبر بروتوكول LocalSend المدمج بالنوتش.
- **بيئة الاختبار والتشغيل**:
  - **جلسة المضيف (Host)**: شاشة `DP-1` (`wayland-1`) تشغل بيئة المستخدم الأساسية (end-4 / illogical-impulse `qs -c ii`).
  - **جلسة DeloWay المتداخلة (Nested)**: شاشة `WAYLAND-1` (`wayland-2`) بنافذة Aquamarine مستقلة لعزل التطوير والاختبار وحماية المضيف من الكراش.

---

## 3. خريطة المعمارية والملفات الرئيسية (Architecture Map & Core Files)

### أ) ملفات النواة والإطار الهيكلي (Shell Core)
1. **`shell/shell.qml` (287 سطراً)**:
   - **الغرض**: نقطة الإدخال الرئيسية للواجهة (`ShellRoot`). يقوم بتهيئة الجلسة، تسجيل الاختصارات العالمية، وتوزيع الأسطح على كل شاشة متصلة.
   - **الأقسام الداخلية**:
     - `السطور 1-96`: الاستيرادات، المتغيرات العامة، والاختصارات العالمية (`GlobalShortcut`).
     - `السطور 97-216`: موزع أوامر IPC الرئيسي (`IpcHandler { target: "deloway" }`) للتحكم بالشل من الخارج (فتح/إغلاق النوتش، الكبسولة، الإعدادات، مقياس الخط).
     - `السطور 217-238`: العناصر الفردية العامة للجلسة مثل شاشة القفل (`LockScreen`).
     - `السطور 239-275`: حلقة `Variants` للشاشات (`Quickshell.screens`)، تُنشئ لكل شاشة أسطحها المستقلة (`Background`, `Dock`, `Notch`, `QuickSettingsCapsule`, `AppDrawer`, `SettingsAppV2`).
   - **الاعتماديات**: `ShellState`, `Theme`, `ConfigManager`, `DesktopManager`.

2. **`shell/theme/Theme.qml` (364 سطراً)**:
   - **الغرض**: سنجلتون الثيم الشامل ومصدر الحقيقة لكافة الرموز البصرية (Colors, Tokens, Typography, Motion, Dimensions).
   - **الأقسام الداخلية**:
     - `السطور 13-23`: منطق تحجيم الخط الديناميكي `Theme.fontSize(baseSize)` وتتبعه لـ `ConfigManager.fontSizeScale`.
     - `السطور 55-70`: ثوابت الحركة والزوايا (`motionFast`, `motionBase`, `radiusSmall`, `radiusMedium`, `radiusLarge`).
     - `السطور 162-210`: لوحة الألوان الأساسية (`background`, `surface`, `border`, `accent`, `urgent`).
     - `السطور 211-230`: رموز النوتش واللون الأسود الداكن (`notchBackground`, `notchSurface`, `notchBorder`, `notchRadius`).
     - `السطور 231-250`: رموز الـ Dock المتخصصة (`dockGlass`, `dockDot`, `dockBorder`, `dockTooltipBg`).
     - `السطور 290-340`: تعريفات الخطوط الأساسية والمقاييس (`scaleDisplay`, `scaleTitle`, `scaleBody`).
   - **الاعتماديات**: `ConfigManager`.

---

### ب) أسطح العرض النشطة في التطوير (Active Surfaces)
3. **`shell/components/NotchFrame.qml` (124 سطراً)**:
   - **الغرض**: المكوّن الهيكلي الموحد والمشترك لهندسة وشكل النوتش والكبسولة الموسعة؛ يوفر الأذنين العلويتين المنحنيتين (Concave fillet ears: 18px)، الزوايا السفلية المنحنية (26px)، خلفية OLED Black (`Theme.notchBackground`)، الظل المحيطي الناعم، ودعم `LayoutMirroring` التلقائي للعربية.
   - **الاعتماديات**: `Theme`, `I18n`.

4. **`shell/components/Notch.qml` (369 سطراً)**:
   - **الغرض**: حاوية النوتش الذكي في أعلى منتصف الشاشة (مستوحى من macOS NotchNook)، يعتمد على `NotchFrame` ويدعم التوسع الفيزيائي السلس مع تبويبات مُموضعة بالمنتصف الهندسي الدقيق.
   - **الأقسام الداخلية**:
     - `السطور 20-45`: أبعاد الحالات (`compactHeight: 44`, `expandedWidth: 600`, `expandedHeight: 176`, `earRadius: 18`) وتتبع العرض اللحظي بـ `ShellState`.
     - `السطور 56-65`: استدعاء المكون الهيكلي الموحد `NotchFrame`.
     - `السطور 66-140`: حاوية النوتش المصغر (تضم `NotchHome.qml` وتتعامل مع عجلة الفأرة للتوسيع وسحب الملفات).
     - `السطور 170-329`: شريط التبويبات العلوي للوضع الموسع في المنتصف تماماً (Home, Share, Notifications مع ترجمة I18n)، وزر الترس للإعدادات مفصول ومثبت على الحافة الجانبية.
     - `السطور 330-366`: حاوية محتوى التبويبات الموسعة عبر `SwipeView` (`NotchHome`, `NotchLocalSend`, `NotchNotifications`).
   - **الاعتماديات**: `NotchFrame`, `NotchHome`, `ShellState`, `Theme`, `LocalSendService`, `I18n`.

5. **`shell/components/NotchHome.qml` (798 سطراً)**:
   - **الغرض**: المحتوى الرئيسي للنوتش في الحالتين المصغرة والموسعة (مساحات العمل، مشغل الموسيقى، الإشعارات، والتقويم).
   - **الأقسام الداخلية**:
     - `السطور 1-118`: إدارة أولوية العرض (`viewMode`: الإشعار يتفوق على الموسيقى، والموسيقى تتفوق على الخمول).
     - `السطور 119-186`: مظهر الإشعار المصغر مع شريط التناقص الزمني وزر الإلغاء.
     - `السطور 187-364`: مظهر النوتش المصغر الافتراضي:
       - `190-248`: مؤشرات مساحات العمل 1-5 (ظاهرة دائماً).
       - `249-257`: فاصل رأسي خافت عند تشغيل الموسيقى.
       - `258-364`: مشغل الموسيقى المصغر (غلاف 32x32 بزاوية 8، عنوان المقطع بخط 14 DemiBold، أزرار بأيقونات `SymbolicIcon` بحجم 14px).
     - `السطور 365-485`: بطاقة الإشعار الموسعة بالكامل.
     - `السطور 486-701`: الجانب الأيسر الموسع: مشغل الموسيقى الكبير أو الساعة والطقس عند الخمول.
     - `السطور 702-798`: الجانب الأيمن الموسع: شريط التقويم الأسبوعي (اليوم، الشهر، والأيام السبعة).
   - **الاعتماديات**: `Theme`, `MediaService`, `NotificationManager`, `I18n`.

6. **`shell/components/QuickSettingsCapsule.qml` (2575 سطراً)**:
   - **الغرض**: كبسولة الإعدادات السريعة في الشريط العلوي؛ تلتصق بسقف الشاشة عند التوسع وتعتمد على `NotchFrame` لمطابقة هندسة النوتش بالكامل (الأذنان، الزوايا، والظلال).
   - **الأقسام الداخلية**:
     - `السطور 1-67`: تعريف النافذة (`PanelWindow`)، التموضع النسبي للنوتش، الالتصاق بالسقف (`margins.top: root.isExpanded ? 0 : 10`)، والأبعاد (`compactHeight: 44`, `expandedWidth: 440`).
     - `السطور 662-672`: الحاوية الهيكلية المشتركة `NotchFrame`.
     - `السطور 673-900`: المظهر المصغر (المرحلة 1): مؤشر البطارية، مؤشرات برامج الخلفية `SystemTrayIndicators`، الصوت، الشبكة، وشارة اللغة.
     - `السطور 901-1750`: المظهر الموسع (المرحلة 2 - الشاشة الرئيسية `main`):
       - الساعة الحية وكبسولة البطارية وزر الإغلاق.
       - بطاقات الشبكة والبلوتوث ونقطة الاتصال والإضاءة الليلية.
       - بطاقات التحكم بالصوت والسطوع مع مزلاجات محسنة ومقابض تفاعلية.
     - `السطور 1751-2575`: الشاشات الفرعية التفصيلية (Wi-Fi Manager, Bluetooth Scanner, Hotspot Detail).
   - **الاعتماديات**: `NotchFrame`, `Theme`, `ShellState`, `SystemTrayIndicators`, `SystemMonitor`, `NetworkManager`.

7. **`shell/components/SystemTrayIndicators.qml` (112 سطراً)**:
   - **الغرض**: قراءة وعرض أيقونات تطبيقات الخلفية (System Tray / Applets) داخل الكبسولة السريعة.
   - **الأقسام الداخلية**:
     - `السطور 1-23`: التحقق من وجود أيقونات نشطة وتحديث خاصية `hasVisibleItems`.
     - `السطور 24-99`: مصفوفة التراي (`Repeater` على `SystemTray.items`)؛ توفر قرص تمييز عند التحويم، نقر يسار للتفعيل، نقر يمين لعرض قائمة D-Bus عبر `QsMenuAnchor`، وتمرير الفأرة (Wheel) للصوت/التحكم. (تمت إزالة الـ Tooltip المسبب لتشوه الخط الأسود نهائياً).
     - `السطور 100-111`: فاصل رأسي خافت يعزل التطبيقات عن مؤشرات النظام.
   - **الاعتماديات**: `Quickshell.Services.SystemTray`, `Theme`.

8. **`shell/components/Dock.qml` (331 سطراً)**:
   - **الغرض**: شريط التطبيقات السفلي العائم (Dock) بنمط OLED الأسود العميق والزجاج المصقول.
   - **الأقسام الداخلية**:
     - `السطور 1-85`: هندسة الكبسولة، التموضع السفلي، ارتفاع `dockH: 52`، والظلال الناعمة.
     - `السطور 86-220`: مصفوفة أيقونات التطبيقات المثبتة والنشطة (`appRepeater`):
       - تكبير الأيقونة 1.08x وارتفاع 2px عند التحويم.
       - نقطة مضيئة سفلية (`Theme.dockDot`) للتطبيق النشط.
       - النقر الأيمن يفتح `DockContextMenu` متموضعاً فوق الأيقونة بدقة.
       - دوران عجلة الفأرة يفتح/يغلق درج التطبيقات (`AppDrawer`).
     - `السطور 221-327`: ملحقات الـ Dock (سلة المهملات، الفاصل، وزر الدرج إن وُجد).
     - `السطور 328-331`: استدعاء وربط قائمة الكلك يمين `DockContextMenu`.
   - **الاعتماديات**: `ApplicationManager`, `Theme`, `ShellState`, `DockContextMenu`.

9. **`shell/components/DockContextMenu.qml` (284 سطراً)**:
   - **الغرض**: قائمة السياق (الكلك يمين) لتطبيقات الـ Dock (تثبيت، فتح، إغلاق).
   - **الأقسام الداخلية**:
     - `السطور 1-38`: نافذة منبثقة (`PopupWindow`) مع تمكين `grabFocus: true` وربط `HyprlandFocusGrab` لإغلاق القائمة فوراً عند النقر بالخارج.
     - `السطور 39-55`: دوال `show()` و `hide()`. تستدعي `show()` دالة `menuCard.forceActiveFocus()`.
     - `السطور 99-130`: بطاقة القائمة (`menuCard`) مفعلة بـ `focus: true` والتقاط مفتاح `Keys.onEscapePressed: root.hide()`.
     - `السطور 131-165`: ترويسة التطبيق بحجم خط `Theme.fontSize(12)` ونقطة الحالة الخضراء.
     - `السطور 166-255`: الخيارات الثلاثة (Pin, Open, Close) بارتفاع موحد 32px، حجم أيقونة 14px، وخط `Theme.fontSize(12)`.
   - **الاعتماديات**: `Quickshell.Hyprland`, `Theme`, `ApplicationManager`, `I18n`.

10. **`shell/components/SymbolicIcon.qml` (213 سطراً)**:
   - **الغرض**: مكوّن الأيقونات الرمزية القياسي. يقوم بمطابقة أسماء الأيقونات القياسية مع مسارات SVG المحلية وتلوينها بدقة عبر قناع لوني.
   - **الاعتماديات**: `Theme`.

11. **`shell/components/settings/SettingsAppV2.qml` (598 سطراً)**:
   - **الغرض**: نافذة إعدادات النظام الرئيسية المحدثة؛ نافذة عائمة قابلة للسحب والتحريك بحرية، تدعم تعدد المهام بالعمل جنباً إلى جنب مع التطبيقات الأخرى، وتوفر تكبيراً واستعادة سلسة لملء الشاشة.
   - **الأقسام الداخلية**:
     - `السطور 1-35`: إعدادات النافذة (`PanelWindow`)، قناع التفاعل `mask: Region { item: root.isOpen ? windowCard : null }` الذي يعزل تفاعل النافذة عن باقي الشاشة ويسمح بالنقرات على النوافذ الأخرى، وخصائص السحب والتموضع المقيد (`clampedX`, `clampedY`).
     - `السطور 107-160`: اختصارات لوحة المفاتيح (`Escape`, `Super+Q`, `F11`, `Super+F`).
     - `السطور 178-230`: بطاقة النافذة (`windowCard`) العائمة مع زوايا `Theme.notchRadiusWindow` (26px) في الوضع العائم وزوايا 0 في ملء الشاشة، وانتقالات انسيابية معطلة أثناء السحب لاستجابة فورية بدون أي تأخير.
     - `السطور 231-315`: ترويسة النافذة (`windowHeader`) مع منطقة سحب متكاملة (`headerDragArea`)، مؤشر سحب اليد المقفلة، نقر مزدوج للتكبير، وأزرار التكبير والإغلاق.
     - `السطور 316-598`: الشريط الجانبي للتبويبات (`SettingsSidebar`) وحاوية المحتوى الزجاجية العائمة.
   - **الاعتماديات**: `Quickshell`, `Theme`, `ShellState`, `I18n`.

---

### ج) الخدمات السنجلتون والبيانات (Singletons & Services)
11. **`shell/services/NotificationManager.qml` (124 سطراً)**:
    - **الغرض**: سنجلتون استقبال وإدارة الإشعارات من النظام عبر `NotificationServer`.
    - **الوظائف**: تتبع آخر 50 إشعاراً، إرسال تنبيه `toastRequested` للنافذة العائمة، ومزامنة الإشعارات مع النوتش.
12. **`shell/services/ConfigManager.qml` (711 سطراً)**:
    - **الغرض**: سنجلتون إدارة إعدادات وتفضيلات المستخدم، وحفظها وقراءتها من ملف JSON على القرص.
    - **الوظائف**: مقياس الخط (`fontSizeScale`: 0.85, 1.0, 1.15)، الثيم، خلفية الشاشة، إعدادات الدوك والنوتش.
13. **`shell/services/ShellState.qml` (271 سطراً)**:
    - **الغرض**: سنجلتون إدارة الحالات اللحظية للشاشات (الحالة المفتوحة/المغلقة للنوتش، الكبسولة، الدرج، والإعدادات).
14. **`shell/services/DesktopManager.qml` (496 سطراً)**:
    - **الغرض**: إدارة ملفات سطح المكتب، الأيقونات، وحالة القائمة المنبثقة لسطح المكتب.

---

## 4. نظام التصميم والرموز البصرية المعتمدة (Design System & Visual Tokens)

### أ) لوحة الألوان (Color Tokens)
| اسم التوكن البرمجي | القيمة الفعلية (الوضع الداكن) | الاستخدام المعتمد |
| :--- | :--- | :--- |
| `Theme.notchBackground` | `#000000` (OLED Pure Black) | خلفية النوتش، الكبسولة، والـ Dock والقوائم |
| `Theme.notchText` | `#ffffff` | النص الأساسي عالي التباين |
| `Theme.notchTextSecondary`| `rgba(255, 255, 255, 0.70)` | النصوص الفرعية والتفاصيل الثانوية |
| `Theme.notchTextTertiary` | `rgba(255, 255, 255, 0.45)` | التلميحات والأيقونات الخاملة والفواصل |
| `Theme.notchSurface` | `rgba(255, 255, 255, 0.05)` | أسطح البطاقات والعناصر الافتراضية |
| `Theme.notchSurfaceElevated` | `rgba(255, 255, 255, 0.08)` | الأسطح المرتفعة وحاويات الصور المصغرة |
| `Theme.notchSurfaceHover` | `rgba(255, 255, 255, 0.12)` | لون الخلفية عند تحويم الفأرة (Hover) |
| `Theme.notchSurfaceActive`| `rgba(255, 255, 255, 0.18)` | لون الخلفية عند الضغط أو التفعيل (Active) |
| `Theme.notchBorder` | `rgba(255, 255, 255, 0.12)` | الحدود الخارجية للنوافذ والبطاقات (1px) |
| `Theme.notchBorderSubtle` | `rgba(255, 255, 255, 0.06)` | الفواصل الداخلية الخافتة بين العناصر |
| `Theme.notchShadow` | `rgba(0, 0, 0, 0.50)` | ظلال العمق تحت الأسطح العائمة |
| `Theme.colors.urgent` / `danger` | `#ef4444` | أزرار الإغلاق، الحذف، والعمليات الخطرة |
| `Theme.colors.success` | `#10b981` | نقطة تشغيل التطبيق وحالات النجاح |
| `Theme.colors.accent` | `#0ea5e9` | مؤشرات مساحات العمل والأزرار المؤكدة |

### ب) أبعاد الزوايا ومقاييس الحواف (Radii Tokens)
- `Theme.notchRadiusWindow`: **26px** (الزوايا الخارجية الكبرى للنوافذ العائمة).
- `Theme.notchRadius`: **22px** (الزوايا القياسية للكبسولة والنوتش).
- `Theme.notchRadiusPanel`: **16px** (حاويات الأقسام والبطاقات الداخلية الكبيرة).
- `Theme.notchRadiusCard`: **12px** (بطاقات الخدمات مثل Wi-Fi, Bluetooth).
- `Theme.notchRadiusPill`: **8px** (أغلفة الألبومات والأزرار النحيفة).
- `Theme.radiusSmall`: **6px** (خيارات قوائم الكلك يمين وعناصر القوائم المدمجة).

### ج) معايير القوائم المنبثقة المشتركة (ContextMenu Sizing Standard)
للحفاظ على التناسق التام بين `DesktopContextMenu` و `DockContextMenu`:
- **ارتفاع العنصر الواحد (`Layout.preferredHeight`)**: **32px**.
- **حجم الأيقونة الرمزية (`iconSize`)**: **14px**.
- **حجم الخط (`font.pixelSize`)**: **`Theme.fontSize(12)`** (يرتبط تلقائياً بمقياس الخط العام).
- **حجم خط الترويسة**: **`Theme.fontSize(12)`** بوزن `Font.DemiBold`.

### د) نظام الخطوط والتحجيم الديناميكي (Typography & Font Scaling)
- **عائلة الخط المعتمدة**: `Inter` للإنجليزية واللاتينية، مع `Cairo` / `Noto Kufi Arabic` كبدائل للعربية.
- **معادلة التحجيم الإلزامية**: يُمنع استخدام `font.pixelSize: 12` أو `13` كقيمة ثابتة. يجب استخدام:
  $$\text{font.pixelSize} = \text{Theme.fontSize}(\text{baseSize}) = \text{Math.round}(\text{baseSize} \times \text{Theme.fontScale})$$
- **المقاييس المتاحة من `ConfigManager.fontSizeScale`**:
  - `صغير (Small - 0.85)`: يحول قاعدة 12px إلى **10px**، وقاعدة 14px إلى **12px**.
  - `قياسي (Standard - 1.00)`: يحافظ على القيم الأساسية (12px = **12px**).
  - `كبير (Large - 1.15)`: يحول قاعدة 12px إلى **14px**، وقاعدة 14px إلى **16px**.

---

## 5. القواعد والمعايير المعمارية الإلزامية (Architectural Guidelines)
1. **عزل جلسة التطوير ومنع المساس بالمضيف**:
   - لا يجوز تشغيل أوامر تؤثر على Hyprland الأساسي للمستخدم (`wayland-1`). يجب حصر التجارب والشاشات في الجلسة المتداخلة (`wayland-2` / Aquamarine).
   - تجنب إرسال أوامر مدخلات أجهزة افتراضية (`ydotool`) بشكل أعمى أثناء وجود المستخدم على شاشة أخرى.
2. **التعامل مع نوافذ `PopupWindow` وإدارة التركيز**:
   - `PopupWindow` في Quickshell هو نافذة من نوع `QQuickWindow` وليس `QQuickItem`. لذلك، يُمنع وضع `focus: true` مباشرة على جذر `PopupWindow` (يسبب خطأ تشغيلي).
   - التركيز يجب أن يوضع على العنصر الداخلي (`Rectangle` أو `Item` الرئيسي) مع استدعاء `forceActiveFocus()` عند الفتح.
   - لإغلاق القوائم المنبثقة عند النقر خارجها، يجب استخدام `grabFocus: true` مع `HyprlandFocusGrab { windows: [root]; active: root.visible; onCleared: root.hide() }`.
3. **التكامل البصري وتجنب التلميحات المكسورة (Tooltips)**:
   - يُمنع وضع عناصر `ToolTip` العادية داخل أسطح ذات حواف مقصوصة (`clip: true`) لأنها ستقتطع وتظهر كخطوط سوداء مشوهة.
4. **الالتزام الكامل بتوكنز `Theme`**:
   - تجنب استخدام قيم ألوان هيدروديكية مثل `#ffffff` أو `rgba(...)` مباشرة داخل المكونات العامة، بل استخدم توكنز `Theme.notch*` و `Theme.colors.*`.

---

## 6. سجل التغييرات والـ Commits الأخيرة (Recent Commits & Changelog)
*(مستخرج مباشرة من سجل Git الفعلي)*:
* `b13a75e` - docs: update STATUS.md with system theming completion, ADR, Qt report, and roadmap (2026-09-19)
* `728c600` - feat(theme): add deloway-theme-apply.py engine and integrate with ConfigManager (2026-09-19)
* `4e21ce7` - refactor(theme): replace hardcoded colors with Theme tokens across Notch, Desktop, and Dock (2026-09-19)
* `4982d64` - feat(theme): add system theme backup, restore script, and applySystemTheme toggle (2026-09-19)
* `08b2d8a` - docs: update STATUS.md changelog and state for persistent music player (2026-09-19)
* `c3e91b0` - fix(notch): keep music player visible on pause and bind viewMode to player presence (2026-09-19)
* `f7d44e6` - feat(settings): make settings window draggable, resizable to fullscreen, and allow side-by-side multitasking (2026-09-19)
* `c15d1b3` - docs: update STATUS.md changelog, active state, and architecture map for NotchFrame and tabs (2026-09-19)
* `a1976fe` - feat(i18n): update Notch tab names to Home, Share, and Notifications with Arabic localization (2026-09-19)
* `d089ff5` - fix(notch): center expanded tab row and decouple settings gear button (2026-09-19)
* `373c94d` - refactor(capsule): extract NotchFrame component and unify QuickSettingsCapsule with Notch geometry and ceiling attachment (2026-09-19)
* `1a5a204` - chore: add STATUS.md as self-contained architecture and state reference for planning-only AI models (2026-09-19)
* `f561833` - style: unify DockContextMenu typography with Theme.fontSize() and DesktopContextMenu sizing standard (2026-09-19)
* `0f41291` - fix: dismiss DockContextMenu on outside click and Escape via HyprlandFocusGrab (2026-09-19)
* `2943330` - style: replace unicode glyphs with SymbolicIcon and enlarge compact mini music player elements (2026-09-19)
* `c9d24bc` - chore: track status icons and add mappings for hotspot, localsend, session, and font settings (2026-09-19)
* `fa44abb` - fix(capsule): slim sliders 5px+thumb, clip cards, compact edge geometry, premium compact bar icons (2026-09-17)
* `3ad1bf9` - perf(capsule): accelerate expansion physics with snappy OutCubic easing (2026-09-17)
* `d916a9d` - fix(drawer): bind typography and dimensions dynamically to font scale (2026-09-17)
* `ae7f825` - fix(settings): add inset hover capsule and resolve RTL alignment (2026-09-17)
* `59b229e` - feat(settings): add common components library (Section, Row, Toggle) (2026-09-16)

---

## 7. حالة العمل الحالية والتعديلات غير الملتزمة (Current Working State & Uncommitted Changes)
*(مفحوصة بالكامل من واقع القرص عبر `git status -s`)*:
- **المهام المنجزة والمثبتة في HEAD**:
  - **تطبيق ثيم DeloWay على برامج النظام (GTK 3.0 / GTK 4.0 / Libadwaita / Electron / Chromium)**:
    - **المرحلة 1 (الحماية والنسخ الاحتياطي)**: تم حفظ نسخة احتياطية كاملة ودائمة لملفات `~/.config/gtk-3.0` و `gtk-4.0` و `gsettings` في `~/.config/deloway/backups/original/`، وتوفير سكربت استرجاع فوري `scripts/restore-system-theme.sh` مع دعم `--dry-run`، وإضافة مفتاح تحكم اختياري `applySystemTheme` في إعدادات الواجهة (`AppearanceTab.qml`) مع ترجمة كاملة للعربية والإنجليزية (`4982d64`).
    - **المرحلة 2 (تنظيف الألوان الثابتة وتوسيع التوكنز)**: استبدال كافة الألوان الصلبة (Hardcoded) في `NotchHome.qml` و `NotchNotifications.qml` و `NotchLocalSend.qml` و `TraditionalDesktop.qml` و `DockTab.qml` بتوكنز `Theme` الدلالية، وإضافة توكنز التكيف اللوني (`musicBadge`, `calendarPast`, `calendarFuture`) في `Theme.qml` (`4e21ce7`).
    - **المرحلة 3 (محرك الثيم الخارجي `deloway-theme-apply.py`)**: فصل توليد ملفات الثيم إلى سكربت بايثون مستقل ينفذ عمليات كتابة ذرية (Atomic Writes)، ويدعم وضع المعاينة `--dry-run`، ويقرأ الخطوط (`Google Sans Flex Medium 11`) والأيقونات (`Reversal-dark`) والمؤشرات (`default`) من `gsettings` للمضيف كمصدر وحيد للحقيقة، وتوليد ملفات `gtk.css` و `settings.ini` لكل من GTK 3 و GTK 4، وتوليد `theme.json` متكامل من `ConfigManager.qml` (`728c600`).
    - **المرحلة 4 (التحقق من تطبيقات Electron/Chromium والتقرير الفني لـ Qt)**: التحقق من توافقية برامج Brave و VSCodium و Discord مع `color-scheme`، وتوثيق معمارية وخطوات ثيم برامج Qt المستقبلية دون المساس بالملفات (`b13a75e`).
  - **ضبط حجز المساحة (Exclusive Zones) والطبقات للشريط العلوي والدوك**:
    - حل مشكلة تغطية النوتش والكبسولة لشريط تبويبات النوافذ بتعيين `exclusiveZone` ثابت في `Notch.qml` يضمن حجز 62px في أعلى الشاشة (`44px` ارتفاع النوتش المصغر + `10px` هامش علوي + `8px` فراغ تنفسي).
    - منع ازدواجية الحجز بجعل الكبسولة (`QuickSettingsCapsule.qml`) في وضع `ExclusionMode.Ignore` لمشاركة نفس المساحة العلوية المحجوزة.
    - ثبات النوافذ التام ومنع قفزها عند توسيع النوتش أو الكبسولة عبر معادلة تعويضية ذكية تحافظ على قيمة 62px المحجوزة بدقة دون أي حركة للنوافذ الخلفية.
    - تصحيح الفراغ الكبير فوق الدوك بفصل قيمة الحجز عن ارتفاع النافذة الكامل (`implicitHeight: dockH + 46`)، وضبط `exclusiveZone` على الارتفاع الفعلي عبر توكن `Theme.dockExclusiveZoneFor(dockH)` ليحجز 86px فقط (68px كبسولة + 10px هامش + 8px فراغ) بدلاً من 124px المتضخمة سابقاً.
    - تحويل طبقة النوتش والكبسولة من `WlrLayer.Overlay` إلى `WlrLayer.Top` لضمان اختفائهما التام تحت مقاطع الفيديو والتطبيقات بملء الشاشة (Fullscreen).
  - **مشغل الموسيقى المستمر في النوتش (MPRIS Persistence)**: تم ربط ظهور المشغل بوجود مصدر الموسيقى (`hasPlayer`) بدلاً من حالة التشغيل اللحظية (`isMusicPlaying`)، ليبقى ظاهراً بكامل تفاصيله عند الإيقاف المؤقت (Paused)، مع تمكين زر التشغيل من استئناف العزف، ولا يختفي إلا عند إغلاق التطبيق كلياً (`c3e91b0`).
  - **نافذة الإعدادات العائمة متعددة المهام (`SettingsAppV2.qml`)**: نافذة عائمة قابلة للسحب والتحريك بحرية، مع إزالة حجب النقرات الخارجية وتطبيق قناع `Region` لتتيح العمل جنباً إلى جنب مع التطبيقات الأخرى (Multitasking)، ودعم التبديل السلس بين الحجم العائم وملء الشاشة (`f7d44e6`).
  - **توحيد شكل وهندسة النوتش والكبسولة (`NotchFrame.qml`)**: استخراج المكون المشترك وتوحيد التصاق الكبسولة والنوتش بسقف الشاشة مع نفس الأذنين (18px) والزوايا السفلية (26px) والظل الناعم (`373c94d`).
  - **توسيط تبويبات النوتش وتعريبها**: توسيط شريط التبويبات الموسعة هندسياً وفصل زر الترس، وتحديث مسميات التبويبات (Home / الرئيسية، Share / مشاركة، Notifications / الإشعارات) مع دعم كامل للغتين عبر `I18n.qml` (`d089ff5`, `a1976fe`).
- **ملفات قيد التطوير / معدلة وموجودة على القرص بانتظار مهامها المخصصة**:
  - `shell/components/SystemTrayIndicators.qml` (غير متتبع بعد): مكوّن تطبيقات الخلفية الجاهز والمحذوف منه الـ tooltip المكسور، بانتظار الـ commit المستقل.
  - `shell/components/settings/tabs/WindowsTab.qml`: تبويب النوافذ ضمن هيكلة تطبيق الإعدادات الجديد `SettingsAppV2`.
  - `shell/components/NotchLocalSend.qml` و `scripts/deloway-localsend.py` و `LocalSendService.qml`: تكامل سحب وإفلات الملفات لنقلها عبر LocalSend المدمج بالنوتش.
  - `shell/components/desktop/DesktopContextMenu.qml`: تحسينات شبكة سطح المكتب وتوحيد مقاييس القائمة المنبثقة.
  - `config/hyprland.conf`: إعدادات نوافذ Hyprland وتنسيق الحدود.

---

## 8. المشاكل المعروفة والتحديات التقنية وسجل القرارات المعمارية (Known Issues, Technical Constraints & ADR)

### أ) ADR-001: فصل محرك تطبيق الثيم إلى سكربت خارجي (`scripts/deloway-theme-apply.py`)
- **السياق**: كان `ConfigManager.qml` يولد نصوص CSS و INI ضخمة تصل لأكثر من 160 سطراً عبر سلاسل نصية مدمجة (Inline Bash Script) تُمرر إلى `Process`.
- **القرار**: فصل المنطق بالكامل إلى سكربت بايثون تنفيذي مستقل `scripts/deloway-theme-apply.py` يستقبل `theme.json`، مع تفويض `ConfigManager.qml` لتحديث `theme.json` فقط ثم استدعاء المحرك.
- **الأسباب والمزايا المعمارية**:
  1. **الكتابة الذرية (Atomic Writes)**: استخدام ملف مؤقت (`.tmp.<pid>`) ثم النقل الفوري بـ `os.replace` يمنع كلياً تلف أو قصور ملفات تكوين المستخدم في حال تعطل العملية أو انقطاع الطاقة.
  2. **التحديث المشروط الذكي (Diff-aware & Idempotent)**: فحص محتوى الملفات الموجودة على القرص قبل الكتابة، وعدم كتابة أي بايت أو استدعاء `gsettings set` إلا عند وجود اختلاف حقيقي، لتجنب عمليات I/O الزائدة وتفادي إعادة تحميل واجهات GTK بلا داعٍ.
  3. **دعم وضع المعاينة الجافة (`--dry-run`)**: توفير إمكانية تشغيل المحرك من الطرفية لمعاينة ما سيتم تطبيقه وكتابته بالتفصيل دون المساس بأي ملف على القرص.
  4. **الحفاظ على إعدادات المضيف كمصدر وحيد للحقيقة**: قراءة قيم الخطوط (`font-name`) والأيقونات (`icon-theme`) والمؤشرات (`cursor-theme`) لحظياً من `gsettings` وتثبيتها، بدلاً من افتراض قيم ثابتة غير دقيقة قد تفسد مظهر بيئة المستخدم.
  5. **تحرير مسار واجهة المستخدم (UI Thread)**: نقل معالجة السلاسل النصية وحسابات الألوان من بيئة QML إلى عملية خارجية خفيفة وسريعة.

### ب) التقرير الفني: سلوك وتوافقية تطبيقات Electron / Chromium مع ثيم DeloWay
1. **Brave Browser (`/usr/bin/brave`)**:
   - **السلوك الملاحظ فعلياً**: عند تغيير `color-scheme` إلى `prefer-light`، يتغير شريط العنوان وإطار النافذة فوراً. أما صفحة الويب (مثل YouTube) فلا تتغير تلقائياً إلا إذا كان خيار المظهر داخل الموقع مضبوطاً على "حسب الجهاز (Device theme)" بدلاً من خيار يدوي ثابت.
   - **المعاملات**: لا يتطلب flags إضافية في الوضع العادي.
2. **VSCodium (`/usr/bin/vscodium`)**:
   - **السلوك الملاحظ فعلياً**: بعد الفحص المخبري لملف `~/.config/VSCodium/User/settings.json`، تبين وجود ثيم مخصص صريح `"workbench.colorTheme": "Abyss"`، وبالتالي لم يتغير المحرر تلقائياً عند تغيير `color-scheme` لأن إعداد `"window.autoDetectColorScheme"` غير مفعل. يتطلب التبديل التلقائي تفعيل هذا الإعداد في إعدادات المستخدم.
3. **Discord (`/usr/bin/discord`)**:
   - **السلوك الملاحظ فعلياً**: يعتمد إصدار Electron خاصاً على لينكس ومثبت في `settings.json` على `"BACKGROUND_COLOR": "#121214"`. لا يتغير تلقائياً مع `gsettings` مباشرة إلا عند تفعيل "Sync with computer" داخل إعدادات التطبيق وقد يتطلب إعادة تشغيل لقراءة المتغير.

### ج) التقرير الفني: خارطة طريق تطبيق ثيم DeloWay على تطبيقات Qt (`pavucontrol-qt`, `RPCS3`)
- **الواقع الحالي للنظام**:
  - تطبيقات Qt المثبتة: `pavucontrol-qt` (`/usr/bin/pavucontrol-qt`)، `RPCS3` (`/home/waleed/.local/bin/rpcs3`).
  - الأدوات غير المثبتة: `qt5ct`، `qt6ct`، `kvantummanager`.
  - متغيرات البيئة: `QT_QPA_PLATFORMTHEME` و `QT_STYLE_OVERRIDE` غير معينة حالياً، مما يجعل تطبيقات Qt تستخدم مظهر Qt الافتراضي (Fusion أو Breeze المشتق من نمط النظام).
- **خيارات التنفيذ المستقبلية (مكتوبة فقط دون أي تعديل فعلي على النظام)**:
  1. **الخيار الأول (الموصى به - خفيف ومباشر): `qt6ct` / `qt5ct` مع باليت ألوان مخصصة**:
     - *آلية العمل*: تثبيت حزمتي `qt5ct` و `qt6ct`، وتعيين `QT_QPA_PLATFORMTHEME=qt6ct` في بيئة جلسة Hyprland.
     - *التكامل مع DeloWay*: إضافة دالة في `deloway-theme-apply.py` لتوليد ملف باليت ألوان مخصص `~/.config/qt6ct/colors/deloway.conf` يستمد ألوانه من `theme.json` (الخلفية `#101318`، السطح `#1b202c`، الـ Accent `#0ea5e9` للداكن ومقابلاتها للفاتح)، وتعيين اسم الباليت في `~/.config/qt6ct/qt6ct.conf`.
     - *الميزات*: يدعم تطبيقات Qt5 و Qt6 معاً، تحكم كامل بالألوان والخطوط بدون استهلاك موارد، خالي من أي تعارضات مع بيئة المضيف.
  2. **الخيار الثاني: محرك Kvantum (`kvantummanager`)**:
     - *آلية العمل*: تعيين `QT_STYLE_OVERRIDE=kvantum` وإنشاء ثيم مخصص `DeloWay.kvconfig` و `DeloWay.svg`.
     - *الميزات*: يتيح مؤثرات بصرية متقدمة مثل زوايا النوافذ المنحنية، والشفافية مع الـ Blur في نوافذ Qt.
     - *السلبيات*: يتطلب حزمة إضافية كبيرة وملفات SVG معقدة، وقد يسبب ثقلاً أو تشوهات مع بعض برامج المحاكاة مثل RPCS3.
  3. **الخيار الثالث: توليد ملف `~/.config/kdeglobals` مباشرة**:
     - *آلية العمل*: كتابة أقسام `[Colors:Window]` و `[Colors:View]` و `[Colors:Button]` و `[Colors:Selection]` في `~/.config/kdeglobals` مباشرة.
     - *الميزات*: تقرأه معظم تطبيقات Qt الحديثة (Qt 6) و KF6 بدون وسيط.
     - *التوصية*: اعتماد الخيار الأول (`qt6ct` + باليت مخصص) في المرحلة المستقبلية كحل قياسي موثوق.

### د) التحديات التقنية السابقة المثبتة
1. **استمرارية ظهور مشغل الموسيقى وتعدد المشغلات (MPRIS Persistence & Player Priority)**:
   - تم حل مشكلة اختفاء المشغل عند الإيقاف المؤقت (Paused) عبر دالة `updateActivePlayer()` التفاعلية مع `Instantiator` لمراقبة تغيرات حالة التشغيل (`isPlaying`, `playbackState`).
2. **التصاق الكبسولة الموسعة بسقف الشاشة (Ceiling Attachment & Geometry)**:
   - تم حل الفراغ العلوي (8px gap) واعتماد المكون الموحد `NotchFrame` لضمان أن كلاً من النوتش والكبسولة يخرجان بسلاسة من سقف الشاشة مع نفس الأذنين المنحنيتين وزوايا الحواف.
3. **التعامل مع الـ Popups المنبثقة من Layer-Shell**:
   - بروتوكول `wlr_layer_shell_v1` يقيد أحياناً ارتباط قوائم `xdg_popup` به إذا لم يتم تمرير التركيز وإدارته عبر `HyprlandFocusGrab` بشكل صريح.
4. **حساسية الـ REPL والتعديل على إعدادات Hyprland للمضيف**:
   - قصر التحكم على استدعاءات `hyprctl dispatch` الآمنة وتجنب `hyprctl repl` أو تقييم دوال Lua عشوائية.
5. **كراش Quickshell أثناء الـ Hot-Reload والتعديل السريع (SIGSEGV in RootWrapper / PopupAnchor)**:
   - **المشكلة**: عند حفظ ملفات متعددة في أجزاء من الثانية (مثل حفظ عدة ملفات QML متزامنة عبر أدوات التحرير أو git checkout)، يستلم محرك `quickshell-git` إشعار مراقبة الملفات `EngineGeneration::filesChanged()` ويبدأ إعادة بناء الشجرة فورياً عبر `RootWrapper::reloadGraph()`. أثناء فك ارتباط نوافذ layer-shell (`WlrLayershell::disownWindow`)، تستدعي نوافذ الـ popup المعلقة دالة `PopupAnchor::onItemWindowChanged()` على كائن تم تحريره بالفعل (Use-After-Free / Null pointer dereference)، مما يسبب انهياراً فورياً للعملية بإشارة `SIGSEGV` (Signal 11).
   - **الـ Stack Trace المختصر (من `coredumpctl`)**:
     ```text
     #0  0x00005d54da80dc18 PopupAnchor::onItemWindowChanged() (quickshell)
     #1  0x000078ce09f3ee51 QCallableObject::impl(int, QSlotObjectBase*, QObject*, void**, bool*)
     #2  0x000078ce0a02cb06 QObject::event(QEvent*) (libQt6Core.so.6)
     #3  0x000078ce0a0e5b7b QCoreApplication::notifyInternal2(QObject*, QEvent*) (libQt6Core.so.6)
     #4  0x00005d54da828fe7 WlrLayershell::disownWindow(WlrLayershellWindow*) (quickshell)
     #5  0x00005d54da81fc8a RootWrapper::reloadGraph() (quickshell)
     #6  0x00005d54da8202d6 EngineGeneration::filesChanged() (quickshell)
     ```
   - **الإجراء الوقائي والعلاج**:
     1. تعديل ملف واحد في كل مرة والانتظار حتى اكتمال المعالجة لتجنب تتابع أحداث `filesChanged`.
     2. التحقق دائماً من صحة ملفات QML عبر `qmllint` قبل الحفظ.
     3. في حال حدوث الانهيار، يتم إعادة إطلاق الواجهة بأمر صريح ونظيف: `hyprctl dispatch exec "quickshell -p /home/waleed/Projects/Deloway/shell"`.
6. **حساب المساحة المحجوزة في بروتوكول Layer-Shell على Hyprland**:
   - في بروتوكول `wlr_layer_shell_v1` تحت Hyprland، تُحسب المساحة المحجوزة الإجمالية من حافة الشاشة وفق المعادلة:
     $$\text{reserved} = \text{exclusiveZone} + \text{margin}$$
   - لذلك، لحجز 62px في الأعلى مع وجود `marginTop = 10px` في الوضع المصغر، يجب تعيين `exclusiveZone = 52px`. وعند توسيع النوتش ليلتصق بالسقف (`marginTop = 0`)، يتم ضبط `exclusiveZone = 62px` تعويضياً لتبقى المساحة المحجوزة ثابتة عند 62px تماماً، مما يمنع قفز النوافذ أو تحركها بمقدار بكسل واحد.
   - بالمثل للدوك، بدلاً من ترك الحجز تلقائياً على كامل ارتفاع النافذة (`implicitHeight = 114px` الذي يحجز 124px)، تم تعيين `exclusiveZone` مستقلاً عبر توكن `dockExclusiveZoneFor(dockH)` ليكون 76px، فينتج حجز إجمالي قدره `76 + 10 = 86px` بالضبط.

---

## 9. خارطة الطريق والمسار القادم (Roadmap & Next Steps)
1. **تطبيق ثيم DeloWay على تطبيقات Qt (Qt Theming Integration)**:
   - دعم الخيار الموصى به عبر `qt6ct` / `qt5ct` أو `kdeglobals` لتطبيق باليت ألوان DeloWay للوضعين الداكن والفاتح على تطبيقات Qt مثل `pavucontrol-qt` و `RPCS3` دون المساس بإعدادات المضيف.
2. **تثبيت مهمة أيقونات التراي**:
   - عمل Commit مخصص لملف `SystemTrayIndicators.qml`:
     `fix: remove broken clipped tooltip causing black line artifact under system tray icons`
3. **استكمال وتثبيت تبويبات الإعدادات**:
   - مراجعة وتثبيت `DockTab.qml` و `WindowsTab.qml` ودمجهما بالكامل في `SettingsAppV2`.
4. **إتمام تكامل LocalSend في النوتش**:
   - تثبيت ودعم سحب الملفات (Drag & Drop) إلى تبويب Share (Tray سابقاً) داخل النوتش لبدء إرسالها الفوري عبر الشبكة المحلية.
5. **تكامل Syncthing**:
   - إعداد ومزامنة المجلدات المحلية ومراقبة حالة المزامنة اللحظية عبر كبسولة أو تبويب مخصص.
6. **الفحص الشامل لاتجاه RTL والترجمة العربية**:
   - مراجعة كافة المحاذاة الأفقية للتأكد من أن جميع الحاويات والنصوص تنعكس تلقائياً بدقة عند اختيار اللغة العربية.


