# Açılış geçişi ve geçici tuş yazıları

29 Ekim 2026. V115 sonrası kaynak çalışması tamamlandı. Sonraki telefon güncelleme talebiyle V116 üretildi ve kuruldu.

Başlangıç #201611, 500 ms yumuşak giriş. Mevcut video/posterler ve oynatma/çıkış davranışları korunuyor. Normal ana ekrana çıkış yine parşömene sönüyor.

Kalıcı tuş adları geçici: sayfa başına tamamlanan ilk ziyarette 4 saniye, sonra 300 ms sönme; uzun basma ilgili adı gösteriyor. Normal dokunma mevcut işlemi yapıyor. 14 sp EB Garamond Regular, çerçevesiz/arkaplansız. Tuş isimleri ekran okuyucuda kalıcı. Yeşil Tarot ana ekran paragrafı kaldırıldı. Ana tuş alt açıklığı 64 dp, görseller arası 40 dp; büyük yazıya uyarlanır. Üst metinlerin koordinatları V115 ile aynı.

Arayüz tercihleri: uygulama destek dizininde home-action-hints/coffee.json ve tarot.json. İş verilerinden bağımsız yeni dosyalardır. Gelecekteki kurulum veri kontrolünde bu beklenen UI tercihlerini ayrıca doğrula; eski iş dosyalarının değiştiğini varsayma.

245 senaryo başarılı; analiz temiz. 32 görünüm, görünür/gizli 64 Flutter ekranı. Teslim: C:/Users/exzau/Documents/Codex/2026-10-29/atlas-soft-start-hints-output/Onizlemeler.html ve DOGRULAMA.md.

Telefon artık V116 (1.0.0-kimi-test.116). Aynı diagnostic paket/imza ile uygulama kaldırılmadan güncellendi. 554 dosya yedeklendi ve kurulumun hemen ardından aynı olduğu doğrulandı. Açılış sonrası iş kayıtlarında değişiklik yok; iki yeni home-action-hints tercihi beklenen içerikleriyle doğrulandı. Normal Atlas paketi ve ilk kurulum tarihi korundu.

Gerçek soğuk başlatma kaydı, Kahve/Tarot ilk gösterimleri, yazıların kaybolması, uzun basma ve tekrar ziyaretler cihazda kontrol edildi. Tuş koordinatları sabit; ölümcül hata yok. Yazı ölçeği 0,9 ve yoğunluk 450 korundu. Canlı AI veya GitHub/mağaza gönderimi yapılmadı. Cihaz Kahve ana ekranında bırakıldı.

APK ve kanıtlar: aynı teslim klasöründe Atlas-V116.apk, device-v116-cold-start.mp4, V116_KURULUM_SONUCU.md/json. Onizlemeler.html gerçek telefon ekranlarıyla güncellendi.
