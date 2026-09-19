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
3. **`shell/components/Notch.qml` (458 سطراً)**:
   - **الغرض**: حاوية النوتش الذكي في أعلى منتصف الشاشة (مستوحى من macOS NotchNook)، يدعم التوسع الفيزيائي السلس.
   - **الأقسام الداخلية**:
     - `السطور 20-45`: أبعاد الحالات (`compactHeight: 44`, `expandedWidth: 600`, `expandedHeight: 176`, `earRadius: 18`) ومنحنيات الحركة.
     - `السطور 46-130`: هندسة زوايا الأذن المنحنية والظلال عبر مسارات `ShapePath`.
     - `السطور 131-228`: حاوية النوتش المصغر (تضم `NotchHome.qml` وتتعامل مع عجلة الفأرة للتوسيع وسحب الملفات).
     - `السطور 229-423`: شريط التبويبات العلوي للوضع الموسع (Nook, Tray/LocalSend, Notify) وأيقونة الترس للإعدادات.
     - `السطور 424-458`: حاوية محتوى التبويبات الموسعة عبر `SwipeView`.
   - **الاعتماديات**: `NotchHome`, `ShellState`, `Theme`, `LocalSendService`.

4. **`shell/components/NotchHome.qml` (798 سطراً)**:
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

5. **`shell/components/QuickSettingsCapsule.qml` (2624 سطراً)**:
   - **الغرض**: كبسولة الإعدادات السريعة في الشريط العلوي (بجوار النوتش من اليمين)، تمثل لوحة التحكم الشاملة.
   - **الأقسام الداخلية**:
     - `السطور 1-140`: تعريف النافذة (`PanelWindow`)، التموضع النسبي للنوتش، الأبعاد (`compactHeight: 44`, `expandedWidth: 440`)، وفيزياء التسارع `OutCubic`.
     - `السطور 722-950`: المظهر المصغر (المرحلة 1): مؤشر البطارية، مؤشرات برامج الخلفية `SystemTrayIndicators`، الصوت، الشبكة، شارة اللغة، وترس فتح الإعدادات.
     - `السطور 951-1802`: المظهر الموسع (المرحلة 2 - الشاشة الرئيسية `main`):
       - `974-1103`: الترويسة الغنية (الساعة، كبسولة البطارية، زر الإغلاق).
       - `1112-1328`: بطاقات الشبكة والبلوتوث في شبكة متوازية ذات عمودين.
       - `1329-1525`: بطاقات نقطة الاتصال (Hotspot) والإضاءة الليلية (Night Light).
       - `1526-1802`: بطاقات التحكم الدقيق بالصوت والسطوع (مزلاجات نحيفة 5px مع مقبض دائري thumb).
     - `السطور 1803-2624`: الشاشات الفرعية التفصيلية (Wi-Fi Manager, Bluetooth Scanner, Hotspot Detail).
   - **الاعتماديات**: `Theme`, `ShellState`, `SystemTrayIndicators`, `SystemMonitor`, `NetworkManager`.

6. **`shell/components/SystemTrayIndicators.qml` (112 سطراً)**:
   - **الغرض**: قراءة وعرض أيقونات تطبيقات الخلفية (System Tray / Applets) داخل الكبسولة السريعة.
   - **الأقسام الداخلية**:
     - `السطور 1-23`: التحقق من وجود أيقونات نشطة وتحديث خاصية `hasVisibleItems`.
     - `السطور 24-99`: مصفوفة التراي (`Repeater` على `SystemTray.items`)؛ توفر قرص تمييز عند التحويم، نقر يسار للتفعيل، نقر يمين لعرض قائمة D-Bus عبر `QsMenuAnchor`، وتمرير الفأرة (Wheel) للصوت/التحكم. (تمت إزالة الـ Tooltip المسبب لتشوه الخط الأسود نهائياً).
     - `السطور 100-111`: فاصل رأسي خافت يعزل التطبيقات عن مؤشرات النظام.
   - **الاعتماديات**: `Quickshell.Services.SystemTray`, `Theme`.

7. **`shell/components/Dock.qml` (331 سطراً)**:
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

8. **`shell/components/DockContextMenu.qml` (284 سطراً)**:
   - **الغرض**: قائمة السياق (الكلك يمين) لتطبيقات الـ Dock (تثبيت، فتح، إغلاق).
   - **الأقسام الداخلية**:
     - `السطور 1-38`: نافذة منبثقة (`PopupWindow`) مع تمكين `grabFocus: true` وربط `HyprlandFocusGrab` لإغلاق القائمة فوراً عند النقر بالخارج.
     - `السطور 39-55`: دوال `show()` و `hide()`. تستدعي `show()` دالة `menuCard.forceActiveFocus()`.
     - `السطور 99-130`: بطاقة القائمة (`menuCard`) مفعلة بـ `focus: true` والتقاط مفتاح `Keys.onEscapePressed: root.hide()`.
     - `السطور 131-165`: ترويسة التطبيق بحجم خط `Theme.fontSize(12)` ونقطة الحالة الخضراء.
     - `السطور 166-255`: الخيارات الثلاثة (Pin, Open, Close) بارتفاع موحد 32px، حجم أيقونة 14px، وخط `Theme.fontSize(12)`.
   - **الاعتماديات**: `Quickshell.Hyprland`, `Theme`, `ApplicationManager`, `I18n`.

9. **`shell/components/SymbolicIcon.qml` (213 سطراً)**:
   - **الغرض**: مكوّن الأيقونات الرمزية القياسي. يقوم بمطابقة أسماء الأيقونات القياسية مع مسارات SVG المحلية وتلوينها بدقة عبر قناع لوني.
   - **الاعتماديات**: `Theme`.

---

### ج) الخدمات السنجلتون والبيانات (Singletons & Services)
10. **`shell/services/NotificationManager.qml` (124 سطراً)**:
    - **الغرض**: سنجلتون استقبال وإدارة الإشعارات من النظام عبر `NotificationServer`.
    - **الوظائف**: تتبع آخر 50 إشعاراً، إرسال تنبيه `toastRequested` للنافذة العائمة، ومزامنة الإشعارات مع النوتش.
11. **`shell/services/ConfigManager.qml` (711 سطراً)**:
    - **الغرض**: سنجلتون إدارة إعدادات وتفضيلات المستخدم، وحفظها وقراءتها من ملف JSON على القرص.
    - **الوظائف**: مقياس الخط (`fontSizeScale`: 0.85, 1.0, 1.15)، الثيم، خلفية الشاشة، إعدادات الدوك والنوتش.
12. **`shell/services/ShellState.qml` (271 سطراً)**:
    - **الغرض**: سنجلتون إدارة الحالات اللحظية للشاشات (الحالة المفتوحة/المغلقة للنوتش، الكبسولة، الدرج، والإعدادات).
13. **`shell/services/DesktopManager.qml` (496 سطراً)**:
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
*(مستخرج مباشرة من سجل Git الفعلي لآخر 20 commit)*:
* `affac6c` - chore: add STATUS.md as self-contained architecture and state reference for planning-only AI models (2026-09-19)
* `f561833` - style: unify DockContextMenu typography with Theme.fontSize() and DesktopContextMenu sizing standard (2026-09-19)
* `0f41291` - fix: dismiss DockContextMenu on outside click and Escape via HyprlandFocusGrab (2026-09-19)
* `2943330` - style: replace unicode glyphs with SymbolicIcon and enlarge compact mini music player elements (2026-09-19)
* `c9d24bc` - chore: track status icons and add mappings for hotspot, localsend, session, and font settings (2026-09-19)
* `fa44abb` - fix(capsule): slim sliders 5px+thumb, clip cards, compact edge geometry, premium compact bar icons (2026-09-17)
* `3ad1bf9` - perf(capsule): accelerate expansion physics with snappy OutCubic easing (2026-09-17)
* `d916a9d` - fix(drawer): bind typography and dimensions dynamically to font scale (2026-09-17)
* `ae7f825` - fix(settings): add inset hover capsule and resolve RTL alignment (2026-09-17)
* `59b229e` - feat(settings): add common components library (Section, Row, Toggle) (2026-09-16)
* `8cde84a` - style(settings): elevate visual identity with pill capsules, OLED black, and glowing active states (2026-09-16)
* `5ce240b` - refactor: wire SettingsAppV2 and remove legacy SettingsApp (2026-09-16)
* `d90b9d4` - refactor: remove expandedContentReady — expanded view now shows/fades directly with isExpanded (2026-09-16)
* `d046548` - fix: decouple scroll-wheel from App Drawer on Notch/QuickSettingsCapsule — wheel now expands/collapses each surface itself; App Drawer scroll-control stays Dock-only (2026-09-16)
* `79a00ef` - fix: pass scroll-wheel events from child elements in Notch and QuickSettings to App Drawer (2026-09-16)
* `c2fadd8` - feat: add scroll-wheel open/close for App Drawer on Dock, Notch, and QuickSettingsCapsule (2026-09-16)
* `e67c4fd` - refactor: remove App Drawer icon from Dock (2026-09-16)
* `2ce81fe` - fix: correct dock icon hover overflow, radius consistency, and tooltip clipping (2026-09-16)
* `1255313` - feat: add hotspot support to deloway-network.py (2026-09-14)
* `6137334` - fix: scope hyprsunset daemon detection to DeloWay's own Hyprland session (avoid conflict with host compositor) (2026-09-14)
* `8fe482f` - refactor: switch night light to persistent daemon + hyprctl temperature control (end-4 pattern) (2026-09-14)

---

## 7. حالة العمل الحالية والتعديلات غير الملتزمة (Current Working State & Uncommitted Changes)
*(مفحوصة بالكامل من واقع القرص عبر `git status -s`)*:
- **ملفات قيد التطوير / معدلة وموجودة على القرص**:
  - `shell/components/QuickSettingsCapsule.qml`: نقل موضع الكبسولة لليمين بجوار النوتش، تحديث تصميم بطاقات Wi-Fi/Bluetooth وتنسيق المزلاجات.
  - `shell/components/SystemTrayIndicators.qml` (غير متتبع بعد): مكوّن تطبيقات الخلفية الجاهز والمحذوف منه الـ tooltip المكسور، بانتظار الـ commit المستقل.
  - `shell/components/settings/tabs/DockTab.qml` و `WindowsTab.qml`: التبويبات المكتملة ضمن هيكلة تطبيق الإعدادات الجديد `SettingsAppV2`.
  - `shell/components/NotchLocalSend.qml` و `scripts/deloway-localsend.py` و `LocalSendService.qml`: تكامل سحب وإفلات الملفات لنقلها عبر LocalSend المدمج بالنوتش.
  - `shell/components/desktop/DesktopContextMenu.qml` و `TraditionalDesktop.qml`: تحسينات شبكة سطح المكتب وتوحيد مقاييس القائمة المنبثقة.
  - `shell/services/ConfigManager.qml` و `Theme.qml`: دعم تبديل مقاييس الخط والأوضاع اللونية.

---

## 8. المشاكل المعروفة والتحديات التقنية (Known Issues & Technical Constraints)
1. **التعامل مع الـ Popups المنبثقة من Layer-Shell**:
   - بروتوكول `wlr_layer_shell_v1` يقيد أحياناً ارتباط قوائم `xdg_popup` به إذا لم يتم تمرير التركيز وإدارته عبر `HyprlandFocusGrab` بشكل صريح، مما كان يسبب بقاء القوائم معلقة عند النقر بالخارج (تم حلها وتثبيتها في `DockContextMenu`).
2. **حساسية الـ REPL والتعديل على إعدادات Hyprland للمضيف**:
   - إرسال أوامر عبر `hyprctl repl` أو تقييم دوال Lua عشوائية على جلسة المضيف قد يؤدي لـ SIGSEGV ودخول Compositor المضيف في وضع الأمان (`--safe-mode`). يجب قصر التحكم على استدعاءات `hyprctl dispatch` الآمنة.
3. **أيقونات تطبيقات التراي الخارجية**:
   - بعض تطبيقات التراي الخارجية ترسل مسارات أيقونات نقطية (Pixmaps) أو أسماء لا تطابق نسق Symbolic. يعتمد `SystemTrayIndicators` على مكوّن `Image` المباشر بدلاً من `SymbolicIcon` لتجنب فشل التحميل.

---

## 9. خارطة الطريق والمهام القادمة (Roadmap & Next Steps)
1. **تثبيت مهمة أيقونات التراي**:
   - عمل Commit مخصص لملف `SystemTrayIndicators.qml`:
     `fix: remove broken clipped tooltip causing black line artifact under system tray icons`
2. **استكمال وتثبيت تبويبات الإعدادات**:
   - مراجعة وتثبيت `DockTab.qml` و `WindowsTab.qml` ودمجهما بالكامل في `SettingsAppV2`.
3. **إتمام تكامل LocalSend في النوتش**:
   - تثبيت ودعم سحب الملفات (Drag & Drop) إلى تبويب Tray داخل النوتش لبدء إرسالها الفوري عبر الشبكة المحلية.
4. **تكامل Syncthing**:
   - إعداد ومزامنة المجلدات المحلية ومراقبة حالة المزامنة اللحظية عبر كبسولة أو تبويب مخصص.
5. **الفحص الشامل لاتجاه RTL والترجمة العربية**:
   - مراجعة كافة المحاذاة الأفقية للتأكد من أن جميع الحاويات والنصوص تنعكس تلقائياً بدقة عند اختيار اللغة العربية.
