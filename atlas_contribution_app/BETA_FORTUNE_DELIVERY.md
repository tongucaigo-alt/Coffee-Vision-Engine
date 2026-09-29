# Beta fal gösterimi — 28 Eylül 2026

Kullanıcının test döneminde okunabilir falın gösterilmesi tercihi doğrultusunda,
AI Laboratuvarı açık APK'larda doğrudan sağlayıcı yanıtlarının editoryal kalite
kontrolü engelleyici olmaktan çıkarıldı. Prompt ve model talimatları korunur.
Uzunluk, paragraf, tekrar ve dil kontrolü sonucu varsa `qualityWarning` olarak
yerel AI sonucunda tutulur; araştırma ZIP'ine eklenmez.

Yanıt tamamlanmış (`stop`), en az 40 kelime ve en fazla 12.000 karakter olmalıdır.
Düşünme/rol çıktısı, boş veya kesilmiş yanıt kabul edilmez; mevcut tek düzeltme
denemesi korunur. Bağlantı hatasında hazır veya rastgele bir fal üretilmez.
Normal sürümün katı kontrolü korunur. Atlas servisinin kendi sunucu tarafı
kalite politikası bu değişiklikle değiştirilmez; mevcut Kimi doğrudan bağlantısı
yeni davranışı kullanır.

Doğrulama: 12 istemci/arayüz testi geçti; değişen Dart dosyalarının analizi temiz.
Kısa okunabilir yanıtta tek istekle sonuç alınması ve boş/kesilmiş/düşünme
yanıtlarının reddi ayrıca sınandı. Bu değişiklik anlatım kalitesi iyileşmesi
veya ağ/model arızalarında her zaman sonuç garantisi değildir.

Beta 7 aynı imzayla `adb install -r` üzerinden kuruldu; kayıtlar korundu.
28 Eylül tarihli üç fincan/üç işaret kaydıyla canlı Kimi denemesinde
“Fal telefona kaydedildi” doğrulandı ve dört bölümlü gerçek yanıt ekranda görüldü.
APK: `build/atlas-beta-v7.apk`.
