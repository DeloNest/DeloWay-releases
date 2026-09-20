# تشخيص وإصلاح محوّل USB Wi-Fi ونقطة الاتصال (RTL8188EUS)

تاريخ التشخيص: 2026-09-20
النظام: Arch Linux (النواة: `7.2.6-arch2-1`)
المحرر: Antigravity AI Agent

---

## 1. نتائج التشخيص (Diagnostic Results)

### 1.1 العتاد والشيبست
- **VID:PID**: `0bda:8179`
- **اسم العتاد**: `Realtek Semiconductor Corp. RTL8188EUS 802.11n Wireless Network Adapter`
- **الشريحة (Chipset)**: Realtek RTL8188EUS (نطاق 2.4 GHz فقط، 802.11n).
- **طبيعة الاتصال**: USB 2.0 (High-Speed 480M) على `Bus 001 Device 009`.
- **فحص وحدة التخزين الوهمية**: لا يظهر كوحدة تخزين CD/Storage، ولا يحتاج `usb_modeswitch`.

### 1.2 حالة التعريفات والنواة الحالية
- **التعريف المحمّل حالياً**: `rtl8xxxu` (المدمج في نواة لينكس upstream).
- **اسم الواجهة الشبكية**: `wlp0s20f0u2` (مُعاد تسميتها من `wlan0`).
- **حالة الاتصال**: تظهر كـ `disconnected` وتستطيع إجراء مسح (Scan) وقراءة شبكات 2.4 GHz المجاورة.
- **أسباب المشكلة المحددة بالأدلة**:
  1. **عدم استقرار `rtl8xxxu` وفشل الفيرموير عند الإقلاع**:
     سجل `journalctl -k -b` أظهر:
     ```text
     usb 1-2: rtl8xxxu: Loading firmware rtlwifi/rtl8188eufw.bin
     usb 1-2: Firmware revision 28.0 (signature 0x88e1)
     usb 1-2: Firmware failed to start
     rtl8xxxu 1-2:1.0: probe with driver rtl8xxxu failed with error -11
     ```
     تعريف `rtl8xxxu` المدمج يفشل بصورة متكررة في تهيئة الفيرموير `rtl8188eufw.bin` أثناء الإقلاع، مما يجعله غير مستقر.
  2. **غياب دعم وضع نقطة الاتصال (AP Mode)**:
     أمر `iw list` أكّد أن `rtl8xxxu` يدعم وضعين فقط:
     ```text
     Supported interface modes:
          * managed
          * monitor
     ```
     وضع `AP` (Access Point) غير مدعوم نهائياً في `rtl8xxxu` لهذا العتاد، مما يمنع إنشاء Hotspot كلياً.
  3. **فشل بناء تعريف DKMS السابق**:
     النظام يحتوي على حزمة `8188eu-dkms-git` (إصدار `5.2.2.4.r838.f42fc9c`) من مستودع قديم غير مصان (`lwfinger/rtl8188eu`).
     سجل البناء في `/var/lib/dkms/8188eu/5.2.2.4.r838.f42fc9c/build/make.log` أكد فشل التجميع مع النواة الحديثة `7.2.6-arch2-1`:
     ```text
     rtw_security.c:6:10: fatal error: drv_types.h: No such file or directory
     #include <drv_types.h>
     ```
     لذلك بقيت وحدة DKMS بحالة `added` ولم تُثبت، واضطرت النواة للرجوع لتعريف `rtl8xxxu`.

### 1.3 حالة نظام التوجيه ونقطة الاتصال
- `net.ipv4.ip_forward = 1` (مفعّل بالفعل).
- `dnsmasq` متوفر على المسار `/usr/bin/dnsmasq`.
- `iptables` و `nft` متوفران.
- `iw reg get`: النطاق الجغرافي حالياً `00` (DFS-UNSET)، ويُفضّل ضبطه إلى `SA` لاستخدام أقصى طاقة بث نظامية وقنوات 2.4 GHz الكاملة (1-13).
- **ملاحظة تشغيلية**: المحوّل ذو راديو أحادي لا يدعم الاتصال كعميل وإنشاء نقطة وصول في نفس الوقت. يجب أن يكون مصدر الإنترنت المشترك عبر واجهة سلكية (`eno1`) وهو المتوفر حالياً.

---

## 2. القرارات والحلول المقترحة (Decisions & Proposed Solutions)

1. **إزالة حزمة DKMS القديمة المعطوبة**:
   حذف `8188eu-dkms-git` حتى لا تفشل مع كل تحديث نواة قادم.
2. **تثبيت تعريف يدعم AP ونواة 7.x الحديثة عبر DKMS**:
   - **المستودع الموصى به 1**: `aircrack-ng/rtl8188eus`
     - الرابط: `https://github.com/aircrack-ng/rtl8188eus`
     - الصيانة: نشط ومحدث باستمرار ليتوافق مع أحدث أنوية لينكس (6.x و 7.x)، ويدعم وضع AP و Monitor.
     - متوفر في AUR باسم: `8188eu-aircrack-dkms-git`
   - **المستودع الموصى به 2**: `morrownr/8188eu`
     - الرابط: `https://github.com/morrownr/8188eu`
     - الصيانة: مستودع مخصص لأجهزة USB Wi-Fi على لينكس مع سكريبت تثبيت DKMS ممتاز ودعم كامل لـ Hostapd و NetworkManager.
3. **حظر تعريف `rtl8xxxu` بعد تثبيت التعريف الخارجي**:
   إنشاء ملف `/etc/modprobe.d/blacklist-rtl8xxxu.conf` يحتوي على `blacklist rtl8xxxu`.

---

## 3. الأوامر المطلوبة للتنفيذ اليدوي (Manual Execution Steps)

> **تنبيه**: هذه الأوامر تتطلب صلاحيات جذر (`sudo`) ويجب تشغيلها بالترتيب التالي:

### الخطوة أ: تنظيف الحزمة القديمة المعطوبة
```bash
# إزالة حزمة DKMS القديمة التي تفشل في التجميع
sudo pacman -R 8188eu-dkms-git
sudo dkms remove 8188eu/5.2.2.4.r838.f42fc9c --all
```

### الخطوة ب: تثبيت التعريف الحديث المتوافق مع نواة 7.x (يدعم AP)
> **ملاحظة فنية**: فرع `v5.3.9` في AUR فشل تجميعه لاحتوائه على دوال `cfg80211` القديمة الملغاة في أنوية لينكس 6.9+ و 7.x. تم فحص واختبار تجميع **Pull Request #275** من مستودع `aircrack-ng/rtl8188eus` وتأكيد تجميعه بنجاح 100% وإنتاجه لوحدة `8188eu.ko` للنواة `7.2.6-arch2-1`. المصدر تم تجهيزه محلياً في `/tmp/aircrack_pr275`.

نفّذ الأوامر التالية لنقل المصدر وتسجيله وتثبيته في DKMS:
```bash
# 1. تثبيت قاعدة بيانات الترددات اللاسلكية (مهمة لاستقرار الفيرموير وقنوات البث)
sudo pacman -S --needed wireless-regdb

# 2. نقل المصدر المحدّث إلى مسار DKMS
sudo cp -r /tmp/aircrack_pr275 /usr/src/8188eu-pr275

# 3. تسجيل وبناء وتثبيت الوحدة في DKMS للنواة الحالية ولكل تحديث مستقبلي
sudo dkms add -m 8188eu -v pr275
sudo dkms build -m 8188eu -v pr275
sudo dkms install -m 8188eu -v pr275
```

### الخطوة ج: حظر التعريف المدمج وتحميل التعريف الجديد
```bash
# منع rtl8xxxu من العمل مع هذا المحول
echo "blacklist rtl8xxxu" | sudo tee /etc/modprobe.d/blacklist-rtl8xxxu.conf

# إفراغ التعريف القديم وتحميل 8188eu الجديد
sudo modprobe -r rtl8xxxu
sudo modprobe 8188eu
```

### الخطوة د: ضبط النطاق الجغرافي وإنشاء نقطة الاتصال (Hotspot)
```bash
# ضبط رمز البلد لترددات 2.4 GHz
sudo iw reg set SA

# إنشاء وتشغيل نقطة اتصال Hotspot عبر NetworkManager (على الواجهة wlp0s20f0u2):
nmcli device wifi hotspot ifname wlp0s20f0u2 ssid "Deloway-Hotspot" password "deloway1234" band bg
```

---

## 4. خطة الاستدامة وتحديثات النواة (Kernel Upgrade Persistence)

- باستخدام **DKMS** مع حزمة `linux-headers` المثبتة في النظام:
  عند ترقية النواة مستقبلاً عبر `pacman -Syu`، ستتولى خطافات ALPM (`70-dkms-install.hook`) إعادة بناء وتثبيت وحدة `8188eu/pr275` تلقائياً للنواة الجديدة دون الحاجة لتدخل يدوي.
- لا يُنصح بتجميد النواة لتفادي حرمان النظام من التحديثات الأمنية.

---

## 5. حالة الإنجاز (Status)

- **الحالة**: تم فحص وتجميع تعريف `aircrack-ng/rtl8188eus` (PR #275) بنجاح تجريبياً في `/tmp/aircrack_pr275` وتأكيد دعمه لنواة 7.2.6-arch2-1 ومطابقته للشريحة `0bda:8179`. بانتظار تشغيل أوامر التثبيت والحظر من المستخدم.

NEXT ACTION: ينتظر تنفيذ الخطوة (ب) و (ج) من قبل المستخدم، ثم التحقق من ظهور وضع AP عبر `iw list | grep -A5 "Supported interface modes"` واختبار بث نقطة الاتصال.
