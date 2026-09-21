# تقرير وتوثيق بيئة تشغيل برامج ويندوز المعزولة (Bottles / Flatpak Sandbox)

> **تاريخ التوثيق**: 21 سبتمبر 2026  
> **النظام الأساسي**: Arch Linux x86_64 (Kernel 7.2.6-arch2-1)  
> **بيئة سطح المكتب**: Hyprland (Wayland Compositor)  
> **البطاقة الرسومية**: NVIDIA GeForce RTX 4060 Ti (Driver 615.71.09)  
> **مستوى الصلاحيات المستخدم**: وضع المستخدم العادي فقط (`--user`)، بدون استخدام `sudo` إطلاقاً.

---

## 1. التشخيص الأولي وحالة النظام قبل البدء

تم إجراء فحص قراءة فقط للتحقق من جاهزية النظام والبيئة قبل تنزيل أو تكوين أي حزم:

### 1.1 أدوات العزل الأساسية (Flatpak & Bubblewrap)
- **الأمر**:
  ```bash
  pacman -Q flatpak bubblewrap
  ```
- **الناتج الفعلي**:
  ```text
  flatpak 1:1.18.2-1
  bubblewrap 0.12.0-1
  ```
- **النتيجة**: بيئة Flatpak ومحرك الحاويات Bubblewrap مثبتان بالفعل على مستوى النظام ومحدثان.

### 1.2 فحص بيئة Wine على مستوى النظام
- **الأمر**:
  ```bash
  pacman -Q wine bottles 2>&1
  ls -la ~/.wine 2>&1
  ```
- **الناتج الفعلي**:
  ```text
  error: package 'wine' was not found
  error: package 'bottles' was not found
  ls: cannot access '/home/waleed/.wine': No such file or directory
  ```
- **النتيجة**: لا توجد حزم Wine أو Bottles على نظام المضيف، ولا توجد بادئة تقليدية `~/.wine` تعرض مسارات النظام للهوست.

### 1.3 فحص تعريف الرسوميات
- **الأمر**:
  ```bash
  nvidia-smi --query-gpu=driver_version,name --format=csv,noheader
  ```
- **الناتج الفعلي**:
  ```text
  615.71.09, NVIDIA GeForce RTX 4060 Ti
  ```
- **النتيجة**: إصدار التعريف النشط هو `615.71.09`. يتطلب تشغيل تطبيقات 32-bit و 64-bit داخل الحاوية مطابقة ثنائية صارمة لمكتبات الرسوميات `org.freedesktop.Platform.GL.nvidia-615-71-09` و `GL32`.

### 1.4 فحص متغيرات بيئة سطح المكتب ($XDG_DATA_DIRS)
- **الأمر**:
  ```bash
  echo "$XDG_DATA_DIRS"
  ```
- **الناتج الفعلي**:
  ```text
  /home/waleed/.local/share:/usr/local/share:/usr/share
  ```
- **الملاحظة الفنية**: عند تثبيت تطبيقات Flatpak بوضع `--user`، تُصدّر ملفات الديسكتوب إلى `~/.local/share/flatpak/exports/share/applications/`. نظراً لأن جلسة Hyprland الحالية تم إطلاقها قبل إضافة مجلد المستخدم، لن تظهر أيقونة Bottles تلقائياً في قائمة DeloWay حتى يتم تسجيل الخروج والدخول أو عمل رابط رمزي للملف في `~/.local/share/applications/`.

---

## 2. التثبيت بوضع المستخدم والمطابقة الرسومية

تم التثبيت حصرياً عبر مستودع Flathub الرسمي بوضع `--user` دون المساس بملفات النظام الأساسي:

### 2.1 إضافة مستودع Flathub للمستخدم
- **الأمر**:
  ```bash
  flatpak --user remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  ```

### 2.2 الحزم المثبتة فعلياً
تم تثبيت الحزم التالية بواسطة Flatpak:
1. `com.usebottles.bottles` (الإصدار 67.3): بيئة إدارة حاويات وبادئات Wine المتطورة.
2. `com.github.tchx84.Flatseal` (الإصدار 2.4.1): واجهة رسومية مريحة لإدارة وتدقيق صلاحيات Flatpak.
3. الامتدادات الرسومية المتطابقة مع تعريف الهوست:
   - `org.freedesktop.Platform.GL.nvidia-615-71-09` (v1.4 - 64-bit)
   - `org.freedesktop.Platform.GL32.nvidia-615-71-09` (v1.4 - 32-bit DXVK/DirectX)
   - `org.freedesktop.Platform.VAAPI.nvidia` و `org.freedesktop.Platform.VAAPI.nvidia.i386`
4. حزم رانتايم Wine:
   - `org.winehq.Wine.gecko`
   - `org.winehq.Wine.mono`

---

## 3. تجريد الصلاحيات وتشديد العزل (Sandbox Hardening)

تأتي حزمة Bottles الافتراضية ببعض الصلاحيات التي قد تسمح بالوصول لمجلدات خارج نطاق البادئة في حال كانت الحزمة مصممة للوصول العام. تم تجريد هذه الصلاحيات بالكامل.

### 3.1 الصلاحيات الافتراضية للـ Manifest
- **الأمر**:
  ```bash
  flatpak info --show-permissions com.usebottles.bottles
  ```
- **الناتج**:
  ```ini
  [Context]
  shared=ipc;network;
  sockets=pulseaudio;wayland;x11;
  devices=all;
  features=devel;multiarch;per-app-dev-shm;
  filesystems=~/Games/umu:create;xdg-data/umu:create;

  [System Bus Policy]
  org.freedesktop.UDisks2=talk
  ```

### 3.2 تطبيق أوامر الحظر والتجريد الصارم
تم إغلاق الوصول إلى نظام الملفات في الهوست، مجلد المنزل (`home`)، وأي مجلدات ألعاب خارجية:
- **الأمر**:
  ```bash
  flatpak override --user --nofilesystem=host --nofilesystem=home --nofilesystem=~/Games/umu --nofilesystem=xdg-data/umu com.usebottles.bottles
  ```

### 3.3 التحقق من التجاوزات المفروضة (Overrides)
- **الأمر**:
  ```bash
  flatpak override --user --show com.usebottles.bottles
  ```
- **الناتج الفعلي**:
  ```ini
  [Context]
  filesystems=!home;!host;!~/Games/umu;!xdg-data/umu;
  ```

### 3.4 إثبات عملي: ما تراه الحاوية من مجلد المنزل
- **الأمر**:
  ```bash
  flatpak run --command=ls com.usebottles.bottles -la /home/waleed
  ```
- **الناتج الفعلي**:
  ```text
  total 0
  drwxr-xr-x 4 waleed waleed 80 Sep 21 04:55 .
  drwxr-xr-x 3 waleed waleed 60 Sep 21 04:55 ..
  drwxr-xr-x 3 waleed waleed 60 Sep 21 04:55 .local
  drwxr-xr-x 3 waleed waleed 60 Sep 21 04:55 .var
  ```
- **النتيجة**: لا يمكن لـ Bottles أو أي برنامج يعمل بداخلها رؤية أي ملف من ملفات المستخدم الحقيقية في الهوست (`Projects`، `Documents`، `Downloads`، ملفات `.bashrc` أو المفاتيح السرية).

---

## 4. الاختبار العملي (Canary Test) للتحقق من العزل

لإثبات فاعلية العزل بالأدلة التجريبية، تم إجراء اختبار Canary صارم.

### 4.1 إنشاء ملف الاختبار على الهوست
- **الأمر**:
  ```bash
  echo "SECRET_CANARY_TEST_12345" > ~/wine-canary-DELETE-ME.txt
  cat ~/wine-canary-DELETE-ME.txt
  ```
- **الناتج**:
  ```text
  SECRET_CANARY_TEST_12345
  ```

### 4.2 إنشاء Bottle تجريبي معزول
- **الأمر**:
  ```bash
  flatpak run --command=bottles-cli com.usebottles.bottles new --bottle-name test-canary --environment custom
  ```
- **الناتج**: اكتمل الإنشاء بنجاح، وتثبيت رانتايم `soda-11.0-10` و `sys-wine-11.0` و `WineBridge` داخل مجلد بيانات التطبيق المنفصل.

### 4.3 فحص روابط المجلدات التلقائية (Folder Bindings)
تم فحص مجلد المستخدم داخل البادئة:
- **الأمر**:
  ```bash
  file ~/.var/app/com.usebottles.bottles/data/bottles/bottles/test-canary/drive_c/users/waleed/*
  ```
- **الناتج الفعلي**:
  ```text
  .../Desktop:     directory
  .../Documents:   directory
  .../Downloads:   directory
  .../Pictures:    directory
  .../Music:       directory
  ```
- **النتيجة**: مجلدات `Desktop` و `Documents` و `Downloads` ليست روابط رمزية تشير لمجلدات الهوست كما في Wine العادي، بل هي مجلدات محلية مستقلة تماماً داخل الحاوية.

### 4.4 محاولة قراءة الملف من داخل Wine عبر محرك Z:
في بيئة Wine التقليدية، يرتبط محرك `Z:` بجذر النظام `/`.
- **الأمر**:
  ```bash
  flatpak run --command=bottles-cli com.usebottles.bottles shell -b test-canary -i 'cmd.exe /c "type Z:\home\waleed\wine-canary-DELETE-ME.txt"'
  ```
- **الناتج الفعلي**:
  ```text
  File not found.
  Failed to open 'Z:\home\waleed\wine-canary-DELETE-ME.txt'
  Command exited with status 1.
  ```

- استعراض مجلد `Z:\home\waleed`:
  ```bash
  flatpak run --command=bottles-cli com.usebottles.bottles shell -b test-canary -i 'cmd.exe /c "dir Z:\home\waleed"'
  ```
  ```text
  Volume in drive Z has no label.
  Directory of Z:\home\waleed
  0 files                        0 bytes
  2 directories     16,783,028,224 bytes free
  ```

### 4.5 محاولة قراءة الملف عبر محرك C:
- **الأمر**:
  ```bash
  flatpak run --command=bottles-cli com.usebottles.bottles shell -b test-canary -i 'cmd.exe /c "type C:\users\waleed\wine-canary-DELETE-ME.txt"'
  ```
- **الناتج الفعلي**:
  ```text
  File not found.
  Failed to open 'C:\users\waleed\wine-canary-DELETE-ME.txt'
  Command exited with status 1.
  ```

### 4.6 تنظيف الاختبار
- تم حذف ملف الاختبار:
  ```bash
  rm -f ~/wine-canary-DELETE-ME.txt
  ```
- تم حذف البادئة التجريبية:
  ```bash
  rm -rf ~/.var/app/com.usebottles.bottles/data/bottles/bottles/test-canary
  ```
- التأكد من تفريغ قائمة الزجاجات: `flatpak run --command=bottles-cli com.usebottles.bottles list bottles` أرجع 0 زجاجات.

---

## 5. عزل الشبكة (Network Isolation) وسكربت bottle-offline

تم التحقق من إمكانية قطع الاتصال بالإنترنت تماماً عن أي تطبيق يعمل داخل Wine عبر ميزة `--unshare=network`.

### 5.1 اختبار الاتصال بوجود الشبكة
- **الأمر**:
  ```bash
  flatpak run --command=bottles-cli com.usebottles.bottles shell -b test-canary -i 'cmd.exe /c "ping 1.1.1.1 -n 1"'
  ```
- **الناتج الفعلي**:
  ```text
  Reply from 1.1.1.1: bytes=32 time=16ms TTL=58
  Packets: Sent = 1, Received = 1, Lost = 0 (0% loss)
  ```

### 5.2 اختبار الاتصال مع تفعيل العزل الشبكي الصارم (--unshare=network)
- **الأمر**:
  ```bash
  flatpak run --unshare=network --command=bottles-cli com.usebottles.bottles shell -b test-canary -i 'cmd.exe /c "ping 1.1.1.1 -n 1"'
  ```
- **الناتج الفعلي**:
  ```text
  (WARNING) Connection status: offline …
  Pinging 1.1.1.1 [1.1.1.1] with 32 bytes of data:
  PING: transmit failed. General failure.
  Packets: Sent = 1, Received = 0, Lost = 1 (100% loss)
  ```
- **النتيجة**: تم عزل مكدس الشبكة بالكامل على مستوى نواة لينكس (Network Namespace)، مما يمنع البرنامج من الاتصال بأي خادم خارجي أو استقبال أي بيانات.

### 5.3 إنشاء أداة التشغيل المعزول: `~/.local/bin/bottle-offline`
تم إنشاء سكربت مساعد قابل للتنفيذ لتسهيل تشغيل أي برنامج أوفلاين دون الحاجة لكتابة أوامر Flatpak المعقدة:
- **المسار**: `~/.local/bin/bottle-offline`
- **الصلاحية**: `chmod +x`
- **المحتوى الفعلي**:
  ```bash
  #!/usr/bin/env bash
  # bottle-offline: Launch Windows applications or Wine tools inside an isolated bottle with network disconnected.
  set -euo pipefail

  if [ "$#" -lt 2 ]; then
      echo "Usage: bottle-offline <bottle-name> <exe-path | tool> [args...]"
      echo ""
      echo "Examples:"
      echo "  bottle-offline test-canary winecfg"
      echo "  bottle-offline test-canary cmd"
      echo "  bottle-offline myapp /path/to/program.exe"
      exit 1
  fi

  BOTTLE="$1"
  TARGET="$2"
  shift 2 || true

  case "$TARGET" in
      cmd|winecfg|uninstaller|regedit|taskmgr|control|explorer)
          exec flatpak run --unshare=network --command=bottles-cli com.usebottles.bottles tools -b "$BOTTLE" "$TARGET" "$@"
          ;;
      *)
          exec flatpak run --unshare=network --command=bottles-cli com.usebottles.bottles run -b "$BOTTLE" -e "$TARGET" "$@"
          ;;
  esac
  ```

---

## 6. فحص طبقة العرض (Wayland vs XWayland) والحدود الأمنية

تم تدقيق طريقة عرض نوافذ الحاوية على خادم العرض في Hyprland عبر الأمر:
```bash
hyprctl clients -j | jq '.[] | {class: .class, title: .title, xwayland: .xwayland, pid: .pid}'
```

### 6.1 النتائج التجريبية
1. **واجهة Bottles الرئيسية**:
   - `class`: `"com.usebottles.bottles"`
   - `xwayland`: `false` (تعمل مباشرة على بروتوكول Wayland الأصلي).
2. **برامج Wine الحديثة**:
   - يدمج إصدار Wine 11 بروتوكول `waylanddrv` الأصلي:
     ```text
     waylanddrv:wayland_process_init Wayland compositor doesn't support optional zwlr_data_control_manager_v1
     ```
   - عند تشغيل تطبيقات تدعم محرك Wayland، ترتبط النوافذ مباشرة بـ Wayland.

### 6.2 الحقيقة الأمنية لطبقة XWayland (شفافية تامة)
- لا تزال بعض ألعاب وتطبيقات ويندوز القديمة أو الحزم غير المتوافقة تعتمد على خادم `XWayland` (عبر مقبس `x11`).
- **المخاطرة الأمنية الفائقة لـ X11**:
  - بروتوكول X11 لا يحتوي على عزل أمني بين النوافذ. إذا عمل تطبيق خبيث تحت `XWayland`، فبإمكانه نظرياً التنصت على ضغطات لوحة المفاتيح (Keylogging) أو التقاط صور لنوافذ البرامج الأخرى التي تعمل هي أيضاً تحت `XWayland`.
  - مع ذلك، لا يمكن لتطبيق XWayland التنصت على نوافذ Wayland الأصلية (مثل متصفح Brave أو الطرفية antigravity ما دامت تعمل بـ `xwayland: false`).

---

## 7. مصفوفة الحماية الصريحة (ما يحميه وما لا يحميه هذا الإعداد)

> ⚠️ **تنويه مبدئي صارم**: هذا الإعداد **ليس "آمناً تماماً"** ولا توجد بيئة تشغيل برمجيات على مستوى نظام التشغيل المضيف توفر أماناً بنسبة 100%. الجدول التالي يوضح الحدود الدقيقة للعزل:

| النطاق | ما يحميه هذا الإعداد الفعلي | ما **لا** يحميه هذا الإعداد (المخاطر المتبقية) |
| :--- | :--- | :--- |
| **ملفات النظام الأساسي** | محمي بالكامل: جذر النظام `/` معروض كـ Read-only وغير قابل للعبث به. | لا شيء |
| **ملفات المستخدم في الهوست** | محمي: تم حجب `home` و `host`. لا يمكن قراءة أو تشفير ملفاتك في `~` أو `~/Projects`. | لا يحمي الملفات إذا قام المستخدم بفك الحظر يدوياً أو نقل ملفات للبادئة. |
| **بيئة البادئة ذاتها (Wine Prefix)** | يعزل كل زجاجة عن الأخرى؛ انهيار أو تلوث زجاجة لا يضر الزجاجات الأخرى. | **غير محمي**: لو كان البرنامج "برنامج فدية" فسيقوم بتشفير الملفات والبرامج الموجودة داخل تلك الزجاجة تحديداً. |
| **الشبكة والاتصال الخارجي** | محمي عند استخدام `bottle-offline` أو `--unshare=network` (انقطاع تام). | **غير محمي** إذا شُغّل التطبيق بالأمر الافتراضي بوجود شبكة؛ يستطيع الاتصال بخوادم القيادة والتحكم (C2). |
| **مدخلات الشاشة والفأرة (Display/Input)** | نوافذ Wayland الأصلية معزولة تماماً ضد التجسس والتقاط الشاشة. | **غير محمي تحت XWayland**: أي تطبيق يعمل تحت X11 قد يستطيع قراءة ضغطات المفاتيح لنوافذ X11 الأخرى. |
| **مستوى النواة ومحرك الرسوميات (Kernel/GPU)** | معزول عبر Bubblewrap cgroups و namespaces. | **غير محمي ضد ثغرات التعريف**: بما أن كرت الشاشة مكشوف للحاوية (`/dev/dri`, `/dev/nvidia*`)، فإن أي ثغرة Zero-Day في تعريف NVIDIA قد تؤدي لهروب من الحاوية (Escape to Host). |
| **مقبس الصوت (PulseAudio/PipeWire)** | يسمح بسماع أصوات التطبيقات والألعاب. | مقبس الصوت يسمح نظرياً للتطبيق بتسجيل الصوت من الميكروفون إذا كان مفتوحاً في الصلاحيات. |

---

## 8. سياسة الاستخدام المقترحة (Usage Policy)

بناءً على مصفوفة الحماية، نوصي باتباع السياسة التالية:

### 8.1 ما يُسمح بتشغيله داخل Bottles المعزولة:
1. **الألعاب والبرمجيات الترفيهية القديمة والحديثة** (مثل ألعاب GOG أو البرامج المحمولة الخالية من الفيروسات).
2. **أدوات الإنتاجية والتصميم الهندسية الموثوقة** من شركات معروفة التي لا تتوفر لها نسخ لينكس.
3. **التطبيقات التي تحتاج عزلاً شبكياً**: تشغيلها عبر `bottle-offline <bottle> <exe>`.

### 8.2 ما يُمنع تشغيله هنا منعاً باتاً (ويتطلب جهازاً وهمياً بالكامل VM):
1. **الكراكات، الباتشات، ومولدات السيريال (Keygens/Cracks)** المجهولة من الإنترنت: تحوي عادة برمجيات فدية أو تروجانات تحاول استغلال ثغرات الـ GPU.
2. **عينات الفيروسات والبرمجيات الخبيثة المخصصة للتحليل الجنائي (Malware Analysis)**: الـ Flatpak ليس بيئة Sandbox مخصصة للأمن السيبراني.
3. **التطبيقات التي تتعامل مع أسرار تجارية فائقة الأهمية أو مفاتيح تشفير مالية**.

---

## 9. خطة إنشاء بيئة افتراضية كاملة وعزل عتادي عبر QEMU/KVM

> ℹ️ **للتوثيق فقط (خطة مرجعية لمن يتطلب عمله عزلاً بنسبة 100%):**

عند الرغبة في عزل برامج شديدة الخطورة أو لا تتمتع بأي درجة ثقة، الحل الحقيقي الوحيد هو جهاز وهمي كامل بنظام Windows معزول عتادياً عبر تقنية KVM:

1. **المتطلبات الأساسية**:
   - تثبيت حزم المحاكاة الافتراضية:
     ```bash
     sudo pacman -S qemu-desktop virt-manager virt-viewer dnsmasq vde2 bridge-utils openbsd-netcat iptables-nft
     ```
2. **تفعيل خدمات النواة والشبكة الافتراضية**:
   ```bash
   sudo systemctl enable --now libvirtd
   sudo virsh net-autostart default
   sudo virsh net-start default
   ```
3. **إضافة المستخدم لمجموعة libvirt**:
   ```bash
   sudo usermod -aG libvirt,kvm $USER
   ```
4. **تثبيت Windows في جهاز افتراضي**:
   - تشغيل `virt-manager` وإنشاء جهاز جديد.
   - تنزيل صورة Windows الرسمية وأسطوانة تعريفات `virtio-win`.
   - استخدام أقراص بنمط `qcow2` مع أخذ لقطات فورية (Snapshots) للعودة لنقطة الصفر في حال إصابة النظام الافتراضي بأي برمجية خبيثة.
   - قطع كرت الشبكة الافتراضي من إعدادات virt-manager لتشغيل معزول تماماً عن الشبكة المحلية والإنترنت.

---

## 10. خطوات التراجع الكامل والنظيف (Full Rollback Procedure)

في حال رغبتك بحذف كل ما تم إعداده في هذه المهمة وإعادة النظام إلى وضعه السابق بنسبة 100%:

### الخطوة 1: حذف سكربت المساعدة
```bash
rm -f ~/.local/bin/bottle-offline
```

### الخطوة 2: حذف التجاوزات الأمنية لـ Bottles
```bash
flatpak override --user --reset com.usebottles.bottles
```

### الخطوة 3: حذف زجاجات وتطبيقات Bottles وبياناتها
```bash
flatpak --user uninstall --delete-data -y com.usebottles.bottles
flatpak --user uninstall --delete-data -y com.github.tchx84.Flatseal
```

### الخطوة 4: تنظيف الرانتايم والمكتبات غير المستخدمة
```bash
flatpak --user uninstall --unused -y
```

### الخطوة 5: حذف مجلدات الإعدادات والذاكرة المؤقتة من المنزل
```bash
rm -rf ~/.var/app/com.usebottles.bottles
rm -rf ~/.var/app/com.github.tchx84.Flatseal
```

### الخطوة 6: إزالة مستودع Flathub للمستخدم (إن لم تكن تستخدمه لتطبيقات أخرى)
```bash
flatpak --user remote-delete flathub
```
