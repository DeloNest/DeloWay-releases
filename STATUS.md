# DeloWay Shell — وثيقة المعمارية والحالة الفنية (STATUS.md)

> **الغرض من الملف**: مرجع شامل وكافٍ بذاته لأي نموذج ذكاء اصطناعي "عقل تخطيط" (مثل Claude Code أو غيره) للعمل والتخطيط وتقديم حلول وتشخيصات تقنية دقيقة ومتسقة مع الكود الحالي دون الحاجة للبحث المضني في كل ملفات المشروع على القرص.
> **قاعدة التحديث الإلزامية**: في نهاية أي مهمة برمجية معتمدة ولها commit، يتم تحديث الأقسام (6، 7، 8، 9) لتعكس واقع Git والقرص الفعلي. الأقسام (1 إلى 5) شبه ثابتة، وتُعدّل عند حدوث قرار معماري أو تعديل جذري في نظام التصميم.
> **آخر تحديث موثق**: 25 سبتمبر 2026 — جلسة إصلاحات التثبيت النظيف (القسم 7-ب). سجل Git هو المرجع النهائي عند أي تعارض.

---

## 1. نظرة عامة ورؤية المشروع (Project Overview & Vision)
- **المشروع**: DeloWay Shell (DeloOS).
- **الهدف**: بيئة سطح مكتب وقشرة نظام (Desktop Shell) عصرية ومتطورة لأنظمة لينكس مبنية على بروتوكول Wayland ومدير النوافذ Hyprland، تدمج بين أناقة macOS (مثل النوتش التفاعلي Smart Notch والكبسولة QuickSettings) وسرعة وخفة بيئة Arch Linux المستقلة، مع هندسة سطح مكتب مستوحاة من Windows 11 Fluent Design.
- **فلسفة الواجهة**: 
  - **هوية أحادية مطلقة (Strict Monochrome OLED)**: سواد نقي كفحم OLED (`#000000`) مع أسطح زجاجية خافتة وتباين ناصع (`#ffffff` في الداكن و `#0f172a` في الفاتح). لا يوجد نظام لون تمييزي (No Accent Colors) مطلقاً.
  - دعم كامل وأصيل لاتجاه الكتابة من اليمين لليسار (RTL / اللغة العربية) جنباً إلى جنب مع الإنجليزية عبر سنجلتون `I18n`.
  - تفاعل فيزيائي انسيابي يعتمد منحنيات تسارع حادة وسريعة (`OutCubic` / 120-220ms).
  - معيارية عالية وفصل صارم بين منطق الخدمات الخلفية (Services) ومكونات العرض البصري (Components).
  - خط طباعي موحد للنظام (`Cairo`) بين واجهات QML وتطبيقات النظام الخارجية (GTK3/4 و Thunar).

---

## 2. حزمة التقنيات والبيئة التشغيلية (Tech Stack & Runtime Environment)
- **محرك الواجهة الأساسي**: [Quickshell](https://quickshell.outfoxxed.me/) (مبني على Qt 6 و QML الحديث).
- **مدير النوافذ (Compositor)**: Hyprland (إصدار v0.56.2+).
- **بروتوكول العرض**: Wayland (مع استخدام `wlr_layer_shell_v1` للأسطح الممتدة، و `xdg_popup` للقوائم المنبثقة).
- **التكاملات والخدمات الخلفية**:
  - `Quickshell.Hyprland`: لمراقبة الشاشات، مساحات العمل، والنوافذ وإدارة التركيز.
  - `Quickshell.Services.SystemTray`: للتعامل مع بروتوكول StatusNotifierItem (D-Bus) لتطبيقات الخلفية مع عزل القوائم المنبثقة عبر `Loader`.
  - `Quickshell.Services.Mpris`: للتحكم في مشغلات الموسيقى والوسائط (Spotify، المتصفحات، مشغلات محلية).
  - `Quickshell.Services.Notifications`: خادم إشعارات مدمج (`NotificationServer`).
  - **بايثون / سكربتات مساعدة**:
    - `scripts/deloway-network.py`: الاتصال بالشبكات اللاسلكية وإدارة نقطة الاتصال (Hotspot) عبر NetworkManager.
    - `scripts/deloway-bluetooth.py`: فحص وإدارة أجهزة البلوتوث والاقتران عبر BlueZ.
    - `scripts/deloway-theme-apply.py`: تطبيق الثيم وتوليد ملفات GTK3/4 و Qt6ct ومزامنة الخطوط.
    - `scripts/deloway-hardware.py`: خدمة تدفقية حية لحساسات النظام (CPU, RAM, GPU, temps).
    - `system/NetworkManager/dispatcher.d/90-deloway-hotspot-forward`: يسمح بتمرير حركة الهوتسبوت عبر `DOCKER-USER` حين يوجد Docker (يثبّته `install.sh`).
- **حزم النظام المساعدة**:
  - `localsend`: يعمل كخدمة خلفية خفية (`localsend --hidden`) لتغذية كبسولة النوتش ببروتوكول Direct v2.
  - `pamac-manager`: المحرك الافتراضي لمتجر التطبيقات وإدارة الحزم.
  - `cliphist` و `wl-clipboard`: لإدارة سجل الحافظة المركزي.

---

## 3. خريطة المعمارية والملفات الرئيسية (Architecture Map & Core Files)

### أ) ملفات النواة والإطار الهيكلي (Shell Core)
1. **`shell/shell.qml` (327 سطراً)**:
   - **الغرض**: نقطة الإدخال الرئيسية للواجهة (`ShellRoot`). يقوم بتهيئة الجلسة، تسجيل الاختصارات العالمية (`GlobalShortcut`)، موزع أوامر IPC، وتوزيع الأسطح على كل شاشة متصلة.
   - **المكونات الأساسية**:
     - تسجيل اختصارات: `shellToggle`, `drawerToggle`, `settingsToggle`, `clipboardToggle`, `sidebarLeftToggle`, `sidebarRightToggle`, `smartNotchToggle`, `cheatsheetToggle`.
     - موزع أوامر IPC (`target: "deloway"`): التحكم البرمجي الكامل بالواجهة وتمرير الأوامر اللحظية.
     - حلقة `Variants` للشاشات (`Quickshell.screens`): ربط مكونات `Dock`, `Notch`, `TimeCapsule`, `QuickSettingsCapsule`, `TraditionalDesktop`, `SearchLauncher`, `AppDrawer`, `SettingsAppV2`.
   - **الاعتماديات**: `ShellState`, `Theme`, `ConfigManager`, `DesktopManager`, `LauncherIndex`.

2. **`shell/theme/Theme.qml` (382 سطراً)**:
   - **الغرض**: سنجلتون الثيم الشامل ومصدر الحقيقة لكافة الرموز البصرية (Tokens, Typography, Motion, Radii).
   - **الخصائص المحورية**:
     - `Theme.fontFamily`: يقرأ مباشرة من `ConfigManager.fontFamily` (القيمة الافتراضية: "Cairo").
     - `Theme.fontSize(baseSize)`: تحجيم ديناميكي يتبع `ConfigManager.fontSizeScale` (0.85 / 1.00 / 1.15).
     - توكنات OLED الأحادية الصارمة: `notchBackground`, `notchSurface`, `notchBorder`, `notchText` وغيرها، مع تطهير تام لأي درجات زرقة.
     - الألوان الدلالية الحصرية والمقيدة: `urgent` (`#ef4444`), `warning` (`#f59e0b`), `success` (`#10b981`).

---

### ب) أسطح العرض النشطة في الشريط العلوي (TopBar Surfaces)
3. **`shell/components/NotchFrame.qml` (124 سطراً)**:
   - **الغرض**: الحاوية الهيكلية المشتركة لكافة الكبسولات والنوتش؛ توفر الأذنين العلويتين المنحنيتين (Concave fillet ears: 18px)، الزوايا السفلية (26px)، خلفية OLED Black، والظلال المحيطية الناعمة مع دعم `LayoutMirroring` التلقائي للعربية.

4. **`shell/components/Notch.qml` (464 سطراً)**:
   - **الغرض**: النوتش الذكي في أعلى منتصف الشاشة (مستوحى من Dynamic Island / NotchNook).
   - **الميزات الفنية**:
     - أبعاد مضبوطة: `compactHeight: 44`, `expandedWidth: 600`, `baseExpandedHeight: 176 / 400`.
     - تماثل فيزيائي كامل لحركة عجلة الفأرة (Scroll wheel expand/collapse) عبر كافة مناطق النوتش.
     - تتبع العرض اللحظي وإبلاغ `ShellState.smartNotchCurrentWidth` لضبط موضع الكبسولات الجانبية بدقة متناهية.
     - تبويبات علوية متموضعة بالمنتصف الهندسي: الرئيسية (Home)، المشاركة (Share / LocalSend)، والإشعارات (Notifications).

5. **`shell/components/NotchHome.qml` (815 سطراً)**:
   - **الغرض**: المحتوى الرئيسي للنوتش في الحالتين المصغرة والموسعة.
   - **الميزات**:
     - مؤشرات مساحات العمل 1-5 المستقلة.
     - مشغل وسائط تفاعلي ذكي يدعم المشغل المفضل، مع أزرار تشغيل خاملة أنيقة تدعم روابط المتصفح والتشغيل الفوري.
     - ترتيب المشغلات زمنياً (Chronological Media Sorting) بحيث يتصدر المشغل النشط حديثاً.
     - تقويم أسبوعي مدمج وعرض تفصيلي للإشعارات وحالات الطقس.

6. **`shell/components/TimeCapsule.qml` (911 سطراً)**:
   - **الغرض**: كبسولة الوقت والتاريخ في يسار الشريط العلوي (أو اليمين بحسب الاتجاه).
   - **الوضع المصغر**: ساعة رقمية واضحة وتاريخ مختصر خفيف الاستهلاك (0% CPU).
   - **الوضع الموسع**:
     - شريط تقويم أسبوعي أفقي بـ 7 أيام (Horizontal 7-day calendar strip) متناسق مع هندسة النوتش.
     - ترويسة متكاملة: ساعة رقمية كبيرة، تاريخ ميلادي كامل، وحسابات تقويم أم القرى الهجرية بدقة فلكية.
     - قسم الهاردوير الحي (CPU, RAM, GPU) مع مخططات Sparklines حية تتوقف تلقائياً عند الإغلاق.
     - **هامش هندسي ثابت (Static Margin)**: لمنع التصاق الكبسولة بالنوتش عند تمددهما معاً.

7. **`shell/components/QuickSettingsCapsule.qml` (1211 سطراً)**:
   - **الغرض**: كبسولة الإعدادات السريعة وصينية النظام (System Tray) في الطرف المقابل للنوتش.
   - **المظهر المصغر**: مؤشرات البطارية، أيقونات تطبيقات الخلفية `SystemTrayIndicators`، الصوت، الشبكة، وشارة اللغة.
   - **المظهر الموسع**: بطاقات التحكم بالشبكة، البلوتوث، نقطة الاتصال، الإضاءة الليلية، مزلاجات الصوت والسطوع، وأزرار الطاقة.

8. **`shell/components/SystemTrayIndicators.qml` (125 سطراً)**:
   - **الغرض**: قراءة وعرض أيقونات تطبيقات الخلفية (StatusNotifierItem عبر D-Bus).
   - **الحماية والاستقرار**: عزل كامل لدورة حياة القوائم المنبثقة عبر `Loader` لتجنب كراش Quickshell عند إغلاق التطبيقات، مع قائمة سياق OLED أحادية أنيقة ومطابقة للمواصفات.

9. **`shell/components/NotchLocalSend.qml` و `LocalSendService.qml` (245 سطراً)**:
   - **الغرض**: تكامل أصيل ومباشر لبروتوكول LocalSend v2 لنقل الملفات من وإلى النوتش.
   - **الميزات**: كشف فوري للأجهزة القريبة، إرسال تدفقي للملفات مع شريط تقدم حقيقي (Real streaming progress)، ومعالجة مراحل الفشل والتنبيهات.

---

### ج) أسطح الإطلاق وسجل الحافظة (Launchers & Overlays)
10. **`shell/components/SearchLauncher.qml` (414 سطراً)**:
    - **الغرض**: نافذة بحث مركزية عائمة (Floating Spotlight Card) تفتح بمفتاح `Super + Space` (أو نقرة Super المنفردة بحسب الإعداد).
    - **المواصفات البصرية**: تصميم أحادي مركزي خفيف بدون أي تعتيم لخلفية الشاشة (Zero backdrop dimming)، حاسبة آمنة فورية، تطبيع لغوي للبحث، إطلاق التطبيقات والأوامر، واستعراض روابط الويب.

11. **`shell/components/AppDrawer.qml` (1678 سطراً)**:
    - **الغرض**: درج التطبيقات الشامل ذو الكانفاس الواسع، يفتح بـ `Super + A` أو التمرير بالماوس على الـ Dock.
    - **الميزات**: تصنيفات وظيفية للتطبيقات، تصفح كامل بالشبكة والقائمة، تحكم بإدارة النوافذ ومسارات التثبيت وإلغاء التثبيت.

12. **`shell/services/LauncherIndex.qml` (718 سطراً)**:
    - **الغرض**: سنجلتون الفهرسة المركزي المشترك بين `SearchLauncher` و `AppDrawer`.
    - **الوظائف**: فهرسة كافة ملفات `.desktop`، تسجيل التطبيقات الأكثر استخداماً، تطبيع النصوص العربية والإنجليزية، وتطبيق خوارزميات الترتيب والتقييم السريع (Scoring & Ranking).

13. **`shell/components/ClipboardManager.qml` و `ClipboardService.qml` (185 سطراً)**:
    - **الغرض**: مدير الحافظة المركزي المستدعى بـ `Super + V`. يوفر تصفية للمحتوى الحساس، وتاريخاً لآخر 100 عنصر مع حذف فوري وبحث سريع.

---

### د) سطح المكتب وشريط المهام (Desktop & Dock)
14. **`shell/components/desktop/TraditionalDesktop.qml` (325 سطراً)** و **`DesktopManager.qml` (522 سطراً)**:
    - **الغرض**: سطح مكتب عصري تفاعلي بهندسة Windows 11 Fluent Design.
    - **المواصفات البصرية**:
      - شبكة موحدة متساوية الأبعاد: **100×100 px** (أفقي ورأسي).
      - بطاقات أيقونات محسوبة: **76×84 px** مع هامش فراغ تنفسي مريح (~24px) بين العناصر المتجاورة.
      - إلغاء كبسولة النص السوداء؛ النص يعتمد على ظل ناعم (`Text.Outline` بتباين خفيف) لضمان القراءة على أي خلفية.
      - تحديد ناعم متعدد وانتقالات سلسة عند التحويم (Hover & Selection).

15. **`shell/components/Dock.qml` (434 سطراً)**:
    - **الغرض**: شريط المهام السفلي العائم.
    - **الميزات**: خيارات العرض الثلاثية (`always`, `autohide`, `disabled`)، شريط تحفيز 2px في الإخفاء التلقائي لتمدد النوافذ بالكامل (`exclusiveZone: 0`)، وقفل الإخفاء عند فتح `DockContextMenu`.

16. **`shell/components/settings/SettingsAppV2.qml` (598 سطراً)**:
    - **الغرض**: تطبيق إعدادات النظام الخماسي الشامل (المظهر، الكبسولة والشريط، النوافذ وسطح المكتب، الاتصالات والإشعارات، النظام وحول). نافذة عائمة تدعم تعدد المهام والسحب الحر واستعادة الحجم.

---

## 4. نظام التصميم والرموز البصرية المعتمدة (Design System & Visual Tokens)

### أ) لوحة الألوان الأحادية (Monochrome OLED Palette)
> **تنبيه حاسم**: النظام لا يحتوي على أي Accent Color. التدرجات حصراً بين الأسود الصرف، الرماديات المحايدة، والأبيض الناصع.

| الرمز البرمجي | الداكن (Dark OLED) | الفاتح (Light Mode) | الاستخدام |
| :--- | :--- | :--- | :--- |
| `Theme.notchBackground` | `#000000` | `#ffffff` | خلفيات النوافذ والكبسولات والـ Dock |
| `Theme.notchText` | `#ffffff` | `#0f172a` | النصوص الأساسية والأيقونات الفعالة |
| `Theme.notchTextSecondary`| `rgba(255, 255, 255, 0.70)` | `rgba(15, 23, 42, 0.70)` | التفاصيل والنصوص الفرعية |
| `Theme.notchTextTertiary` | `rgba(255, 255, 255, 0.45)` | `rgba(15, 23, 42, 0.45)` | الفواصل والتلميحات الخاملة |
| `Theme.notchSurface` | `rgba(255, 255, 255, 0.05)` | `rgba(0, 0, 0, 0.04)` | أسطح البطاقات والعناصر الافتراضية |
| `Theme.notchSurfaceHover` | `rgba(255, 255, 255, 0.12)` | `rgba(0, 0, 0, 0.08)` | تفاعل تحويم الفأرة (Hover) |
| `Theme.notchBorder` | `rgba(255, 255, 255, 0.12)` | `rgba(0, 0, 0, 0.10)` | الحدود القياسية للنوافذ والبطاقات |
| `Theme.notchBorderHighlight`| `rgba(255, 255, 255, 0.28)` | `rgba(0, 0, 0, 0.20)` | حدود التركيز والتحديد الفعال |
| `Theme.colors.urgent` | `#ef4444` | `#dc2626` | مؤشرات الخطر والحذف ($\le 8\text{px}$) |
| `Theme.colors.warning` | `#f59e0b` | `#d97706` | مؤشرات التحذير والحرارة ($\le 8\text{px}$) |
| `Theme.colors.success` | `#10b981` | `#059669` | مؤشرات الاتصال والتشغيل ($\le 8\text{px}$) |

### ب) مقاييس الخطوط والأبعاد (Typography & Sizing)
- **الخط المعتمد الموحد**: `Cairo` كخط أساسي للنظام بالكامل عبر `Theme.fontFamily` و `ConfigManager.fontFamily`.
- **معادلة التحجيم**:
  $$\text{pixelSize} = \text{Theme.fontSize}(\text{baseSize}) = \text{Math.round}(\text{baseSize} \times \text{Theme.fontScale})$$
- **المقاييس**: صغير (`0.85`)، قياسي (`1.00`)، كبير (`1.15`).

---

## 5. القواعد والمعايير المعمارية الإلزامية (Architectural Guidelines)
1. **سياسة الهوية الأحادية الصارمة (Strict Monochrome)**:
   - فحص الثيم إلزامي قبل أي commit عبر تشغيل `./scripts/check-theme.sh`. يجب أن يخرج بـ `100% Monochrome compliance` وبدون أي مخالفات ألوان.
2. **منع الـ Hot-reload وإعادة التشغيل النظيفة (Zero Hot-Reload Policy)**:
   - يُمنع حفظ الملفات والاعتماد على التحديث التلقائي لكويكشل (`qs -r`). يجب دائماً استخدام إعادة التشغيل النظيفة:
     ```bash
     killall quickshell; sleep 1.5; hyprctl dispatch exec "quickshell -p /home/waleed/Projects/Deloway/shell"
     ```
   - التأكد دائماً عبر `qs log -p ...` من خلو السجلات من أي انهيارات أو أخطاء.
3. **عزل دورة حياة القوائم المنبثقة**:
   - لا تضع `focus: true` على جذر `PopupWindow`. استخدم `Loader` مع القوائم المرتبطة بخدمات متقلبة (مثل System Tray) لمنع انهيار الواجهة عند حذف الكائنات.
4. **ثبات النوافذ وتجنب تدمير الأسطح**:
   - النوافذ التابعة لـ `PanelWindow` يجب ألا تُخفى عبر `visible: false` لأن تدمير أسطح Wayland ثم إعادة إنشائها قد يعلق أو يسبب فقداناً للتركيز. الإخفاء والتعتيم يتم عبر الشفافية `opacity` أو تحييد القناع `mask: Region`.

---

## 6. سجل التغييرات والـ Commits الأخيرة (Recent Commits & Changelog)
*(مستخرج مباشرة من واقع سجل Git — للأحدث: `git log --oneline`)*.
جلسة 23 سبتمبر (إعادة بناء الواجهة، من `1330283` إلى `2476bfd`) وجلسة 25 سبتمبر
(إصلاحات التثبيت النظيف، بعد `2476bfd`) موثقتان في رسائل الـ commits نفسها. ما يلي أقدم منهما:
* `6fdb1e1` - fix: make scroll-wheel expand/collapse symmetric across all Notch zones
* `c4eccaf` - fix: eliminate TimeCapsule sticking to Notch on expand (static right margin)
* `71c9014` - docs: remove Delo prefix from app names in documentation
* `aec81e6` - refactor(default-apps): unify pinned defaults via ConfigManager.defaultPinnedApps
* `258c796` - feat(store): register real App Store backed by pamac-manager
* `f5660d7` - feat(desktop): apply Windows 11 Fluent styling to desktop icons and grid
* `000c74f` - fix(capsules): resolve top bar collision and quicksettings font metric overflow
* `193fcd9` - feat(theme): update Thunar GTK styling for OLED monochrome + Cairo font (light/dark aware)
* `5ddcdc1` - feat(notch): wire real transfer progress and add failure stage to localsend capsule
* `86a4638` - feat(localsend): implement direct protocol v2 transfer with streaming progress
* `4d24903` - feat(hyprland): autostart localsend in hidden background mode
* `d65180d` - style: neutralize inactive border color (pure grayscale, no blue undertone)
* `2b616cf` - style: replace blue accent border with high-contrast white (monochrome identity)
* `fb86173` - fix: replace hardcoded /home/waleed path with dynamic HOME resolution in ClipboardService
* `7dd5533` - fix: add hyprpolkitagent to polkit dialog windowrules
* `cb12cac` - fix: enable hyprpolkitagent with correct binary path
* `cdb0ffb` - docs: add comprehensive system requirements and portability reference
* `e6c3c1c` - fix(capsules): polish topbar capsules, dynamic width, mutual exclusivity and motion physics
* `1139450` - fix(drawer): fix list view text-icon separation and remove card shadow/sheen
* `c53e545` - feat(drawer): redesign app drawer with spacious canvas, no backdrop dimming, and refined monochrome contrast
* `17e8a96` - fix(launcher): compact width, remove backdrop shadow, and fix name-icon proximity
* `ed5b01f` - feat(launcher): implement dedicated floating Search Launcher on Super key
* `6d65a10` - feat(time-capsule): adapt horizontal 7-day calendar strip matching Smart Notch design
* `1184ea6` - fix(media): redesign solid playback icons and enforce chronological order in compact & expanded notch
* `0f2d1e1` - fix(tray): prevent crash by isolating context menu lifecycle via Loader
* `3061644` - fix(tray): implement monochrome OLED context menu and correct positioning
* `66c1d14` - fix(screenshot): add screen freeze and single-instance toggle handling
* `3be3b97` - style(quicksettings): improve compact capsule icons and enlarge system tray apps
* `266a975` - refactor(launcher): shared index, ranking and surface components
* `8955d05` - fix(notch): hide music player and launcher in compact capsule when idle
* `c47b655` - feat(music): choose preferred player and launch target

---

## 7. حالة العمل الحالية والتعديلات غير الملتزمة (Current Working State)

### أ) المهام المنجزة المعتمدة (Phases P8..P14)
1. **P8: تكامل بروتوكول LocalSend المباشر (Direct Protocol v2)**:
   - نقل الملفات المباشر عبر السوكيت مع شريط تقدم حقيقي ومعالجة حالات الخطأ.
   - التشغيل الخفي التلقائي لـ `localsend --hidden` في الخلفية.
2. **P9: حماية واستقرار صينية النظام (System Tray Loader Isolation)**:
   - عزل قوائم D-Bus في كائنات `Loader` لتفادي انهيارات Quickshell عند تدمير العناصر.
   - تطبيق هوية OLED الأحادية على قوائم التراي وضبط تموضعها الدقيق.
3. **P10: هندسة كبسولات الشريط العلوي وحل مشاكل التصادم**:
   - تثبيت الهامش الجانبي لـ `TimeCapsule` لمنع الالتصاق والاصطدام بالنوتش الموسع.
   - توحيد تماثل عجلة الفأرة للتمدد والانكماش على كافة مناطق النوتش.
   - تحويل تقويم كبسولة الوقت إلى شريط أسبوعي أفقي 7-Day Strip.
   - ترتيب الوسائط زمنياً وإخفاء المشغلات الخاملة مع توفير أزرار إطلاق سريعة.
4. **P11: المشغل المخصص Spotlight والفهرس المشترك (`SearchLauncher` & `LauncherIndex`)**:
   - فصل شاشة البحث كبطاقة مركزية عائمة (`SearchLauncher.qml`) بدون تعتيم خلفية الشاشة.
   - توحيد الفهرسة والتطبيع والتصنيف عبر سنجلتون `LauncherIndex.qml`.
5. **P12: سطح المكتب بأسلوب Windows 11 Fluent**:
   - شبكة هندسية 100×100 px وبطاقات 76×84 px بهوامش تباعد ~24px.
   - إزالة كبسولة النص الداكنة واستبدالها بظل نص ناعم.
6. **P13: توحيد خط النظام وتطهير الحدود الأحادية**:
   - اعتماد `Cairo` كخط افتراضي للنظام عبر QML و GTK و Thunar.
   - تنظيف ألوان الحدود من أي مسحة زرقاء وجعلها بيضاء/رمادية نقية 100%.
7. **P14: متجر التطبيقات وإدارة الحزم الافتراضية**:
   - ربط متجر التطبيقات بـ `pamac-manager`.
   - توحيد التطبيقات الافتراضية المثبتة عبر `ConfigManager.defaultPinnedApps`.

### ب) جلسة 25 سبتمبر 2026: إصلاحات ما بعد التثبيت النظيف
اختُبر كل تغيير بصري في جلسة معزولة (`scripts/launch-nested.sh`: HOME مؤقت، gsettings في الذاكرة) مع لقطات grim.
- **الأيقونات**: حزمة `packaging/deloway-icon-theme` (Reversal الأسود؛ حزمة AUR لا تثبّته)، `IconResolver` يمنع لوح الشطرنج في كل مكان، وتنبيه عند غياب السمة.
- **الـ Dock**: التثبيتات الافتراضية = التطبيقات المختارة فعلياً، والمعالج يظهر عند غياب `deloway.json`.
- **الواي فاي/الهوتسبوت**: حزمة `packaging/rtl8188eus-dkms`، كشف من sysfs، dnsmasq/wireless-regdb، بلد الواي فاي، PMF، خطاف Docker.
- **الخط والحجم**: Cairo Regular للنظام كله عدا الطرفية (DejaVu Sans Mono للعربية فيها)، ومقياس النص 1.0 وكل النصوص تتبعه.
- **التطبيقات الافتراضية**: كتالوج واحد `config/default-apps.tsv` يقرؤه المثبّت والمعالج والإعدادات (`DefaultApps` + `DefaultAppChooser`).
- **RTL**: `I18n.uiLine/plural/number`، مواضع كبسولتَي الساعة والإعدادات ثابتة بكل اللغات مع خيار للتبديل، الأيقونات الاتجاهية، الترجمة الكاملة، توليد locale العربي.
- **غير ذلك**: حفظ الإعدادات ذرياً، ملفات بأسماء فيها `#`، حذف عنصر الحافظة، `update.sh` يبلّغ عن التبعيات الناقصة.

### ج) جدول اختصارات لوحة المفاتيح المعتمدة (Keybindings)
| الاختصار | الوظيفة | الوصف البرمجي |
|---|---|---|
| `Super` (نقرة منفردة) | قائمة ابدأ (App Drawer) | فتح درج التطبيقات بنمط قائمة ابدأ |
| `Super + Shift + F` | وضع الانغماس (Immersion) | إخفاء/إظهار الشريط العلوي والـ Dock |
| `Super + Space` | مشغل البحث (Search Launcher / Spotlight) | فتح بطاقة البحث المركزية والحاسبة السريعة |
| `Super + A` | درج التطبيقات (App Drawer) | فتح درج التطبيقات الشامل ذو الكانفاس الواسع |
| `Super + V` | سجل الحافظة (Clipboard) | منتقي cliphist عبر fuzzel (واجهة ClipboardManager متاحة عبر IPC فقط) |
| `Super + I` | إعدادات النظام (Settings) | فتح تطبيق إعدادات DeloWay المطور |
| `Super + M` / `Super + N` | كبسولة الإعدادات السريعة | فتح كبسولة الصوت والشبكة والإعدادات |
| `Super + Alt + N` | النوتش (Smart Notch) | فتح النوتش: الرئيسية، الإشعارات، المشاركة |
| `Super + L` | قفل الشاشة | شاشة قفل الواجهة (`ext-session-lock`)، و`hyprlock` احتياطياً |
| `Super + /` أو `Super + T`| جدول الاختصارات (CheatSheet) | عرض نافذة مساعدة الاختصارات |
| `Super + Shift + S` | لقطة الشاشة (Screenshot) | أداة التقاط وقص الشاشة مع التجميد المؤقت |

---

## 8. سجل القرارات المعمارية المحدثة (ADRs)

### أ) ADR-001 إلى ADR-016 (ملخصة)
- **ADR-001 إلى ADR-004**: فصل تطبيق الثيم، عزل باليت الألوان، استخراج نوافذ مساحات العمل برمجياً، تصحيح نقطة الفراغ.
- **ADR-005 إلى ADR-007**: خوارزمية أم القرى الفلكية في JS النقي، خدمة الهاردوير التدفقية بدون استهلاك خامل، عزل كبسولة الوقت في `PanelWindow`.
- **ADR-008 إلى ADR-012**: ترسيخ الهوية الأحادية (Monochrome OLED)، المشغل الموحد، الحافظة المدمجة، دورة حياة الـ Dock التلقائية، وتبسيط الإعدادات بالإفصاح التدريجي.
- **ADR-013 إلى ADR-016**: تطبيق الثيم الأحادي على Thunar و GTK، استقلالية الكبسولات ومنع سرقة التركيز، توحيد تعريب التطبيقات الخارجية، واختيار مشغل الموسيقى المفضل.

### ب) القرارات المعمارية الجديدة (ADR-017 إلى ADR-023)

#### ADR-017: فصل `SearchLauncher` كبطاقة Spotlight وتوحيد الفهرس مع `AppDrawer` عبر `LauncherIndex`
- **السياق**: كان البحث ودرج التطبيقات مدمجين في واجهة واحدة ضخمة تسبب بطئاً وتعتيماً لشاشة المستخدم عند الرغبة في بحث سريع.
- **القرار المعماري**:
  1. إفراد `SearchLauncher.qml` كنافذة Spotlight عائمة ومركزية تفتح في <150ms بدون تعتيم للخلفية.
  2. إفراد `AppDrawer.qml` كدرج تطبيقات متكامل ذو كانفاس واسع.
  3. بناء سنجلتون `LauncherIndex.qml` لتوحيد قراءة `.desktop`، خوارزميات الترتيب، وتطبيع النصوص العربية والإنجليزية المشتركة بينهما.

#### ADR-018: تكامل بروتوكول LocalSend Direct v2 كخدمة خلفية وتدفق مباشر في النوتش
- **السياق**: كانت مشاركة الملفات تتطلب فتح تطبيق LocalSend المستقل يدوياً والتعامل مع واجهته.
- **القرار المعماري**:
  1. تشغيل `localsend --hidden` تلقائياً عبر `hyprland.conf`.
  2. بناء `LocalSendService.qml` الذي يتخاطب مباشرة مع منفذ LocalSend عبر السوكيت (Direct Protocol v2) لكشف الأجهزة وإرسال الملفات مع شريط تقدم تدفقي حي.

#### ADR-019: عزل دورة حياة قوائم System Tray عبر `Loader`
- **السياق**: عند إغلاق أو إعادة تشغيل تطبيقات شريط النظام، كانت قوائم D-Bus القديمة تسبب كراش فوري لمحرك Quickshell لمحاولته الوصول لمؤشرات ذاكرة ميتة.
- **القرار المعماري**: عزل إنشاء وتدمير قائمة السياق داخل `Loader { active: menuOpen }`، وتطبيق واجهة أحادية OLED متناسقة بالكامل.

#### ADR-020: التماثل الفيزيائي لتمدد النوتش وتثبيت هامش كبسولة الوقت (`TimeCapsule`)
- **السياق**: كانت كبسولة الوقت تصطدم بالنوتش عند تمددهما معاً نتيجة اعتماد هامش ديناميكي مرتبط بعرض النوتش اللحظي.
- **القرار المعماري**:
  1. تثبيت الهامش الجانبي لـ `TimeCapsule` بحساب هندسي استاتيكي يضمن ثباتها في أقصى الشاشة.
  2. توحيد معامل التسارع وزمن التمدد والانكماش بعجلة الفأرة على كافة مناطق النوتش لتجربة فيزيائية متماثلة.

#### ADR-021: شبكة سطح المكتب المتساوية (100×100) وظلال النصوص الناعمة (Windows 11 Fluent)
- **السياق**: كانت أيقونات سطح المكتب متقاربة وغير متساوية الأبعاد وتحتوي على كبسولة نص سوداء غير جمالية خلف أسماء الملفات.
- **القرار المعماري**:
  1. توحيد خطوات الشبكة إلى 100×100 px وتصغير البطاقة إلى 76×84 px لتوفير هامش تباعد مريح (~24px).
  2. إزالة كبسولة النص الداكنة واستبدالها بظل نص ناعم (`Text.Outline`) عالي الوضوح على كافة الخلفيات.

#### ADR-022: توحيد خط النظام العام (Cairo) بين QML و GTK و Thunar
- **السياق**: كان النظام يستخدم خطين مختلفين (Inter في QML و Cairo في GTK)، مما أحدث تفاوتاً بصرياً بين نوافذ الشل والتطبيقات.
- **القرار المعماري**:
  1. توحيد عائلة الخط الافتراضية إلى "Cairo" في `ConfigManager.fontFamily` و `Theme.fontFamily`.
  2. تحديث `deloway-theme-apply.py` لقراءة نفس الخط من إعدادات المستخدم وتطبيقه على كافة ملفات `settings.ini` و CSS الخاصة بـ GTK3/4 و Thunar.

#### ADR-023: توحيد التطبيقات المثبتة افتراضياً وربط متجر التطبيقات بـ `pamac-manager`
- **السياق**: كانت قائمة التطبيقات المثبتة في الـ Dock مبعثرة، وكان متجر التطبيقات يفتقر للربط مع أداة حقيقية لإدارة الحزم.
- **القرار المعماري**:
  1. توحيد مصفوفة التطبيقات الافتراضية في `ConfigManager.defaultPinnedApps`.
  2. ربط زر متجر التطبيقات بـ `pamac-manager` وتوفير معالجة آمنة للتثبيت والتشغيل عبر `PackageManager.qml`.

---

## 9. خارطة الطريق والمسار القادم (Roadmap & Next Steps)
0. **(عاجل قبل Hyprland 0.57)**: Hyprland يحذّر بأن صيغة `.conf` ستُزال في 0.57 وبأن تشغيله دون `start-hyprland` غير مستحسن — يلزم ترحيل `config/hyprland.conf` و`bin/deloway-session`.
1. **استقرار وضع الانغماس (Immersion Mode / Super Key Toggle)**:
   - إنهاء ضبط إخفاء الكبسولات والـ Dock عبر مفتاح Super دون التأثير على استقرار دورة حياة أسطح Wayland.
2. **إيماءات لوحة اللمس (Touchpad Gestures)**:
   - إضافة دعم إيماءات التمرير بـ 3 و 4 أصابع لفتح المشغل وتبديل مساحات العمل بانسيابية.
3. **إدارة الشاشات المتعددة (Multi-Monitor Profiles)**:
   - حفظ واسترجاع أوضاع الكبسولات والشريط السفلي عند فصل ووصل الشاشات الخارجية.
4. **تطوير ميزات LocalSend المتقدمة**:
   - دعم استلام الملفات المباشر وتنزيلها في مجلد التنزيلات مع إشعار تفاعلي.
