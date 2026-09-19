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
* `478837b` - feat(workspace): phase3+4 — wheel scroll (throttled, no propagation), animate behaviors already in WorkspaceItem (2026-09-20)
* `0b75c80` - feat(workspace): phase1+2 — WorkspaceIndicator with dots/circles/pill states, AppIcon, OLED tokens (2026-09-20)
* `6f55691` - fix(quicksettings): phase2 — wifi tile & page reflect wifiAvailable from parser (no hardware = disabled state) (2026-09-20)
* `39f5558` - fix(quicksettings): phase1 — remove hardcoded colors; QSSliderCard, power button, notchSliderFill tokens (2026-09-20)
* `aabcd19` - feat(quicksettings): redesign main capsule page with modern pill tiles, header & slider cards (phase 1) (2026-09-20)
* `084d30c` - fix(notch): fix settings icon placement, remove black line artifacts, enhance hover states, and reduce window spacing (2026-09-20)
* `2999f02` - fix(shell): configure exclusive zones, margins, and top layer for Notch, Capsule, and Dock (2026-09-20)
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


## 7. حالة العمل الحالية والتعديلات غير الملتزمة (Current Working State & Uncommitted Changes)
*(مفحوصة بالكامل من واقع القرص عبر `git status -s`)*:
- **المهام المنجزة والمثبتة في HEAD**:
  - **مؤشر مساحات العمل الديناميكي (WorkspaceIndicator) — مكتمل (commits 0b75c80, 478837b)**:
    - مكوّنان جديدان: `WorkspaceIndicator.qml` (منسق البيانات) و `WorkspaceItem.qml` (الشكل الفردي).
    - ثلاث حالات بصرية: نقطة 6px (فارغة) ← دائرة 28px بأيقونة AppIcon (مشغولة) ← كبسولة 36×32px (نشطة).
    - بيانات event-driven: `ToplevelManager.toplevels.values → .handle → HyprlandToplevel.workspace.id`.
    - عجلة الفأرة throttled (300ms)، `wheel.accepted = true` يمنع propagation للنوتش.
    - 14 توكن جديدة في `Theme.qml` بقيمتين (داكن/فاتح): wsDotSize, wsCircleSize, wsPillWidth/Height, wsIconSize, wsBadgeSize, wsIndicatorSpacing, wsActiveBg/Text, wsOccupiedBg, wsEmptyBg.
    - أداء: CPU مستقر 11.7% ← 11.6% بعد 8 تبديلات متتالية. صفر أخطاء `qs log`.
  - **إصلاح ألوان كبسولة الإعدادات السريعة (commits 39f5558, 6f55691)**:
    - إزالة كل الألوان الصلبة. Wi-Fi tile تعرض "غير متوفر" عند `WIFI-HW: missing`.
  - **تصميم كبسولة الإعدادات السريعة - المرحلة 1 (commit aabcd19)**:
    - ترويسة الوقت، كبسولات Wi-Fi/Focus/Lock/BT/Hotspot/NightLight، مزالج الصوت والسطوع.
  - **إصلاحات Smart Notch وتقليل تباعد النوافذ (commit 084d30c)**.
  - **ثيم DeloWay للنظام GTK/Electron (commits 728c600, b13a75e)**.
  - **حجز المساحة Exclusive Zones للشريط والدوك (commit 2999f02)**.
- **ملفات قيد التطوير / بانتظار commit مستقل**:
  - `shell/components/SystemTrayIndicators.qml`: غير متتبع بعد.
  - `shell/components/NotchLocalSend.qml` وملفاته: تكامل LocalSend.

---

## 8. المشاكل المعروفة والتحديات التقنية وسجل القرارات المعمارية (Known Issues, Technical Constraints & ADR)

### أ) ADR-001: فصل محرك تطبيق الثيم إلى سكربت خارجي (`scripts/deloway-theme-apply.py`)
- **القرار**: سكربت بايثون مستقل يستقبل `theme.json` ويكتب ملفات GTK ذرياً مع `--dry-run`.

### ب) ADR-002: عزل باليت الألوان في `Theme.qml` ومنع تسرب الألوان بين الوضعين
- **القرار**: `reloadTheme()` يختار `parsed.light` أو `parsed.dark` بناءً على `mode` النشط.

### ج) ADR-003: WorkspaceIndicator يستخدم ToplevelManager لا Hyprland.toplevels (IPC)
- **السبب**: `ToplevelManager.toplevels` (Wayland) يوفر `appId` للأيقونات. الربط الصحيح: `WlrToplevel.handle → HyprlandToplevel.workspace.id`.

### د) كراش Hot-Reload (SIGSEGV في PopupAnchor::onItemWindowChanged)
- **الإجراء الوقائي**: دائماً `killall quickshell && hyprctl dispatch exec "quickshell -p ..."`. لا hot-reload.

### هـ) لا يوجد كرت Wi-Fi فعلي (`WIFI-HW: missing`)
- طبيعي — الكبسولة تعرض "غير متوفر" وهو السلوك المقصود.

---

## 9. خارطة الطريق والمسار القادم (Roadmap & Next Steps)
1. **تحسينات WorkspaceIndicator**: خيار "نمط المؤشر" في الإعدادات (أيقونات / أرقام / نقاط)، قائمة سياق النوافذ عند rightClick.
2. **كبسولة الإعدادات السريعة — قسم الإشعارات**: بناء section الإشعارات أسفل مزالج الصوت والسطوع.
3. **صفحات التفاصيل (Drill-down Overlay Sheets)**: Wi-Fi و Bluetooth و Hotspot تنزلق للأعلى.
4. **تثبيت SystemTrayIndicators وتكامل LocalSend**.

