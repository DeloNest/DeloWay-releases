# DeloWay Language Coverage Audit (تقرير تغطية اللغة العربية)

> تاريخ التوليد: $(date '+%Y-%m-%d %H:%M:%S')  
> التوزيعة: Arch Linux (Rolling)  
> محرك التعريب: GNU gettext / desktop-file / environment.d / browser-flags  

---

## 1. ملخص التغطية (Localization Summary)

| الفئة | الحالة | التفاصيل |
|---|---|---|
| **شل النظام (DeloWay Shell)** | **100% عربي كامل** | دعم كامل لـ RTL والخطوط والأرقام والترجمات المدمجة |
| **مدير الملفات (Thunar)** | **مدعوم بالكامل (عربي ✔)** | مترجم بالكامل عبر `thunar.mo` و `exo.mo` مع محاذاة RTL |
| **المتصفحات (Chromium / Brave / Chrome)** | **مدعوم بالكامل (عربي ✔)** | عبر راية `--lang=ar` في ملفات flags |
| **المتصفحات (Firefox)** | **متاح بحزمة ناقصة** | يحتاج تثبيت `firefox-i18n-ar` |
| **الحزمة المكتبية (LibreOffice)** | **متاح بحزمة ناقصة** | يحتاج تثبيت `libreoffice-fresh-ar` |
| **تطبيقات GTK3 / GTK4** | **مدعوم تلقائياً (عربي ✔)** | تقرأ `LANGUAGE=ar:en` عبر gettext |
| **تطبيقات Qt6 / Qt5** | **مدعوم تلقائياً (عربي ✔)** | عبر `qt6-translations` والمتغيرات الإقليمية |

---

## 2. جدول التطبيقات المثبتة وحالة التعريب (Installed Apps Audit)

| التطبيق (Application) | الملف التنفيذي | حالة التعريب (Arabic Status) | الحزمة / الملاحظات |
|---|---|---|---|
| **Avahi Zeroconf Browser** | `avahi-discover` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **Qt D-Bus Viewer** | `qdbusviewer6` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **Add/Remove Software** | `pamac-manager` | عربي ✔ | مترجم في ملف .desktop أو النظام |
| **Celluloid** | `celluloid` | عربي ✔ | ملف ترجمة celluloid.mo |
| **Volume Control** | `pavucontrol` | عربي ✔ | ملف ترجمة pavucontrol.mo |
| **Htop** | `htop` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **Vim** | `vim` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **Mixtapes** | `muse` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **Discord** | `discord` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **Thunar File Manager** | `thunar` | عربي ✔ | مترجم بالكامل عبر thunar.mo |
| **VSCodium** | `codium` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **IPTVnator** | `iptvnator` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **Bulk Rename** | `thunar` | عربي ✔ | مترجم بالكامل عبر thunar.mo |
| **PulseAudio Volume Control** | `pavucontrol-qt` | عربي ✔ | مترجم في ملف .desktop أو النظام |
| **Qt Widgets Designer** | `designer6` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **mpv Media Player** | `mpv` | عربي ✔ | مترجم في ملف .desktop أو النظام |
| **Image Viewer** | `loupe` | عربي ✔ | ملف ترجمة loupe.mo |
| **Yazi File Manager** | `yazi` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **Qt V4L2 test Utility** | `qv4l2` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **NVIDIA X Server Settings** | `nvidia-settings` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **CMake** | `cmake-gui` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **Text Editor** | `gnome-text-editor` | عربي ✔ | ملف ترجمة gnome-text-editor.mo |
| **Steam** | `steam` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **Thunar Preferences** | `thunar-settings` | عربي ✔ | مترجم في ملف .desktop أو النظام |
| **Avahi VNC Server Browser** | `bvnc` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **Files** | `nautilus` | عربي ✔ | ملف ترجمة nautilus.mo |
| **File Roller** | `file-roller` | عربي ✔ | ملف ترجمة file-roller.mo |
| **GTK Settings** | `nwg-look` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **Advanced Network Configuration** | `nm-connection-editor` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **Spotify** | `spotify` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **kitty** | `kitty` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **SongRec** | `songrec` | عربي ✔ | ملف ترجمة songrec.mo |
| **GNOME System Monitor** | `gnome-system-monitor` | عربي ✔ | ملف ترجمة gnome-system-monitor.mo |
| **Brave** | `brave` | عربي ✔ | مدعوم عبر --lang=ar في brave-flags.conf |
| **Qt V4L2 video capture utility** | `qvidcap` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **Qt Assistant** | `assistant6` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **System Monitor** | `gnome-system-monitor` | عربي ✔ | ملف ترجمة gnome-system-monitor.mo |
| **About Xfce** | `xfce4-about` | عربي ✔ | مترجم في ملف .desktop أو النظام |
| **Hardware Locality lstopo** | `lstopo` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **Qt Linguist** | `linguist6` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **Avahi SSH Server Browser** | `bssh` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **Antigravity IDE** | `antigravity-ide` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **Antigravity 2.0** | `antigravity` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **WhatsApp Web** | `brave` | عربي ✔ | مدعوم عبر --lang=ar في brave-flags.conf |
| **Delo Store** | `pamac-manager` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **Delo Terminal** | `kitty` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **RPCS3** | `rpcs3-v0.0.42-19931-de6c1b52_linux64.appimage` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **OpenCode** | `opencode-desktop` | غير مدعوم | لا توجد ترجمة عربية مدمجة |
| **Delo Files** | `thunar` | عربي ✔ | مترجم بالكامل عبر thunar.mo |
| **LocalSend** | `localsend` | غير مدعوم | لا توجد ترجمة عربية مدمجة |

---

## 3. إرشادات وخطوات يدوية للتغطية الشاملة (Manual Enhancements)

1. **توليد locale النظام في Arch Linux**:
   ```bash
   sudo sed -i '/^#ar_SA.UTF-8 UTF-8/s/^#//' /etc/locale.gen
   sudo locale-gen
   ```

2. **تثبيت حزم التعريب والتدقيق الإملائي**:
   ```bash
   sudo pacman -S --needed hunspell-ar
   # لمتصفح فايرفوكس:
   sudo pacman -S --needed firefox-i18n-ar
   # لحزمة ليبر أوفيس:
   sudo pacman -S --needed libreoffice-fresh-ar
   ```

3. **إعدادات لوحة المفاتيح والتبديل (hyprland.conf)**:
   ```ini
   input {
       kb_layout = us,ar
       kb_options = grp:alt_shift_toggle
   }
   ```
