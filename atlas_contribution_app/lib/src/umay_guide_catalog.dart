import 'package:flutter/material.dart';
import 'umay_home_tour.dart';
import 'umay_annotation_guide.dart';
import 'umay_camera_guide.dart';
import 'umay_guide_scope.dart';

class UmayGuideDefinition {
  const UmayGuideDefinition(this.id, this.title, this.steps, this.entry);
  final String id, title, entry;
  final List<UmayTourStep> steps;
}

const umayPhotoReviewSteps = [
  UmayTourStep(
    target: 'coffee-photo-image',
    message: 'Fotoğrafın burada. Oklarla diğer fotoğraflarına geçebilirsin.',
  ),
  UmayTourStep(
    target: 'coffee-add-photo',
    message:
        'Bir fincan için en fazla üç fotoğraf ekleyebilirsin. Eksik bir açı varsa bu tuştan yeni fotoğraf ekle.',
  ),
  UmayTourStep(
    target: 'coffee-replace-photo',
    message:
        'Fotoğraf içine sinmediyse Değiştir’i kullanabilirsin. Seçtiğin fotoğrafın yerine yenisini ekleriz.',
  ),
  UmayTourStep(
    target: 'coffee-add-saucer',
    message:
        'İstersen fincanının tabağını da ekleyebilirsin. Tabak fotoğrafı isteğe bağlı; onsuz da devam edebiliriz.',
  ),
  UmayTourStep(
    target: 'coffee-remove-photo',
    message:
        'Kaldır, seçili fotoğrafı bu taslaktan çıkarır. Diğer fotoğrafların ve kayıtlı falların korunur.',
  ),
  UmayTourStep(
    target: 'coffee-review-continue',
    message:
        'Fotoğrafların hazır olduğunda Bu fotoğraflarla devam et’i seç. Sonraki ekranda gördüğün şekilleri işaretleyebilirsin.',
  ),
];
const umayTarotHomeSteps = [
  UmayTourStep(
    target: 'tarot-start-daily',
    message:
        'Günün Kartı ile bugün için bir kart seçebilirsin. Kartı kendin seçip açarsın.',
  ),
  UmayTourStep(
    target: 'tarot-start-three',
    message:
        'Üç Kart ile geçmiş, şimdi ve olası yön için üç kart seçebilirsin. Önce kartlarını açar, sonra istersen falını oluşturursun.',
  ),
  UmayTourStep(
    target: 'tarot-resume',
    message:
        'Yarım kalmış bir açılımın varsa küçük devam tuşuyla aynı kartlara dönebilirsin.',
  ),
];
const umayTarotSelectionSteps = [
  UmayTourStep(
    target: 'tarot-selection-deck',
    message:
        'Desteyi yana kaydırıp istediğin kapalı karta dokun. Günün Kartı için bir, Üç Kart için üç kart seçebilirsin.',
  ),
  UmayTourStep(
    target: 'tarot-reshuffle',
    message:
        'Henüz kart seçmediysen Yeniden Karıştır ile desteyi yeniden karıştırabilirsin. Seçtiğin kartlar değiştirilmez.',
  ),
  UmayTourStep(
    target: 'tarot-selected-slots',
    message:
        'Seçtiğin kartlar üstte yerlerini alır. Seçim tamamlanınca sıradaki kapalı karta dokunarak açabilirsin.',
  ),
];
const umayTarotReadySteps = [
  UmayTourStep(
    target: 'tarot-selected-slots',
    message:
        'Kartlarının hepsi açıldı. Kartlara dokunarak adlarını ve görsellerini inceleyebilirsin.',
  ),
  UmayTourStep(
    target: 'tarot-mood-picker',
    message:
        'İstersen o anki ruh hâlini seçebilirsin. Bu seçim isteğe bağlı; yeniden dokunarak kaldırabilirsin.',
  ),
  UmayTourStep(
    target: 'tarot-generate',
    message:
        'Kartların hazırsa Yorumunu Oluştur ile falını hazırlatabilirsin. Rehber sırasında bu işlem başlatılmaz.',
  ),
];
const umayTarotReadingSteps = [
  UmayTourStep(
    target: 'tarot-reading',
    message:
        'Kartlarının hikâyesi burada. Sayfayı kaydırarak tamamını okuyabilir, Kayıtlarım’dan daha sonra yeniden açabilirsin.',
  ),
  UmayTourStep(
    target: 'tarot-star',
    message:
        'Sevdiğin falı yıldızlayabilirsin. Böylece Kayıtlarım’daki yıldızlılar arasında kolayca bulursun.',
  ),
  UmayTourStep(
    target: 'prefix:content-report-',
    message:
        'Rahatsız eden bir metin olursa Bu yorumu bildir’i kullanabilirsin. Gönderilecek içeriği ve nedeni onay ekranında görürsün.',
  ),
];
const umayRecordSteps = [
  UmayTourStep(
    target: 'history-filter-0',
    message:
        'Kahve falların, taslakların ve kayıtların burada birikir. Bir kayda dokunarak ayrıntılarını açabilirsin.',
  ),
  UmayTourStep(
    target: 'history-filter-2',
    message:
        'Taslaklar, yarım bıraktığın fincanlara dönmeni sağlar. Tamamlamadan çıktığında nerede kaldığını buradan bulabilirsin.',
  ),
  UmayTourStep(
    target: 'history-filter-3',
    message:
        'Yıldızlılar ile yıldızladığın kahve fallarını süzebilirsin. Yıldız koymadığın kayıtlar da telefonda kalır.',
  ),
  UmayTourStep(
    target: 'history-kind-tabs',
    message:
        'Kahve ve Tarot geçmişini üstteki bölümlerden ayrı ayrı görebilirsin.',
  ),
];
const umayRecordDetailSteps = [
  UmayTourStep(
    target: 'prefix:record-detail-photos-',
    message:
        'Bu kaydın fotoğrafları ve işaretleri burada. Fotoğrafları tek tek gözden geçirebilirsin.',
  ),
  UmayTourStep(
    target: 'prefix:record-read-fortune-',
    message:
        'Kayıtlı falı oku ile daha önce hazırlanmış falını açabilirsin. Yeni fal oluşturma ayrı bir işlemdir.',
  ),
  UmayTourStep(
    target: 'prefix:record-edit-',
    message:
        'İşaretleri düzenle ile bu kaydın şekillerini gözden geçirebilirsin. Açılan ekranda yaptığın değişiklikler yeni kayıt sürecine gider.',
  ),
  UmayTourStep(
    target: 'prefix:record-delete-',
    message:
        'Sil seçeneği bu kaydı kaldırır. Silmeden önce açılan onayda hangi kaydı kaldıracağını kontrol et.',
  ),
];
const umayTarotHistorySteps = [
  UmayTourStep(
    target: 'tarot-history-filter-0',
    message:
        'Tarot açılımların burada saklanır. Bir açılıma dokunarak kartlarına ve varsa hazırlanmış falına dönebilirsin.',
  ),
  UmayTourStep(
    target: 'tarot-history-filter-1',
    message:
        'Yıldızlılar, yıldızladığın Tarot açılımlarını gösterir. Diğer kayıtların da listede kalır.',
  ),
  UmayTourStep(
    target: 'prefix:tarot-history-delete-',
    message:
        'Bir açılımı silmek istersen o kaydın silme tuşunu kullan. Önce onay istenir; yalnız seçtiğin açılım kaldırılır.',
  ),
];
const umayCoffeeReadingSteps = [
  UmayTourStep(
    target: 'prefix:fortune-story-',
    message:
        'Fincanının hikâyesi burada. Sayfayı kaydırarak falının tamamını okuyabilirsin; kayıtlı falını daha sonra yeniden açabilirsin.',
  ),
  UmayTourStep(
    target: 'prefix:fortune-star-',
    message:
        'Sevdiğin falı yıldızlayarak kolayca bulabilirsin. Yıldızı kaldırmak, falı silmez.',
  ),
  UmayTourStep(
    target: 'prefix:content-report-',
    message:
        'Uygun bulmadığın bir metni Bu yorumu bildir ile iletebilirsin. Gönderim için ayrıca onay vermen gerekir.',
  ),
];
const umayProfileSteps = [
  UmayTourStep(
    target: 'profile-name',
    message:
        'Sana nasıl seslenmemi istersen buraya yazabilirsin. Bu alanı boş bırakman da mümkün.',
  ),
  UmayTourStep(
    target: 'profile-zodiac',
    message:
        'Burcunu istersen seçebilirsin. Bilmiyorum veya belirtmek istemiyorum seçeneğini de kullanabilirsin.',
  ),
  UmayTourStep(
    target: 'profile-age',
    message:
        'Yaşını yazmak isteğe bağlı. Paylaşmak istemiyorsan boş bırakabilirsin.',
  ),
  UmayTourStep(
    target: 'profile-save',
    message:
        'Değişikliklerini saklamak için Kaydet’e dokun. Bilgilerimi sil ile bu bölümde sakladığın bilgileri kaldırabilirsin.',
  ),
];
const umaySettingsSteps = [
  UmayTourStep(
    target: 'settings-guide',
    message:
        'Beni yeniden dinlemek istersen Kullanım Rehberi’ni aç. Bölümlerin anlatımını buradan tekrar seçebilirsin.',
  ),
  UmayTourStep(
    target: 'settings-connection',
    message:
        'Fal bağlantısını bu bölümden görebilirsin. Hazır bağlantını kullanıyorsan bir değişiklik yapman gerekmez.',
  ),
  UmayTourStep(
    target: 'settings-privacy',
    message:
        'Gizlilik Politikası’nda fotoğrafların ve diğer bilgilerin nasıl kullanıldığını okuyabilirsin.',
  ),
  UmayTourStep(
    target: 'settings-support',
    message:
        'Bir konuda yardıma ihtiyacın olursa Destek’e bakabilirsin. Uygun bulmadığın bir falı ise falın içindeki bildirim tuşundan iletebilirsin.',
  ),
];
const umayConnectionSteps = [
  UmayTourStep(
    target: 'prefix:connection-profile-',
    message:
        'Kullanılabilir fal bağlantıların burada görünür. Hazır bağlantı kilitli görünüyorsa onu düzenlemen gerekmez.',
  ),
  UmayTourStep(
    target: 'connection-add',
    message:
        'Yeni bir bağlantı eklemen gerekiyorsa Bağlantı ekle’yi kullanabilirsin. Adres ve erişim bilgileri sana verilen bağlantıyla eşleşmeli.',
  ),
];
const umayPrivacySteps = [
  UmayTourStep(
    target: 'privacy-heading',
    message:
        'Atlas’ın veri kullanımına ilişkin açıklamaları burada okuyabilirsin. Tamamını görmek için sayfayı kaydır.',
  ),
  UmayTourStep(
    target: 'privacy-open',
    message:
        'Yayımlanmış bir politika adresi varsa bu tuşla açabilirsin. Adresi Kopyala seçeneği de bağlantıyı kopyalar.',
  ),
];
const umayAccessSteps = [
  UmayTourStep(
    target: 'access-address',
    message:
        'Sana verilen Atlas test adresini buraya yazabilirsin. Hazır bir adres varsa değiştirmen gerekmez.',
  ),
  UmayTourStep(
    target: 'access-code',
    message:
        'Sana özel erişim kodunu bu alana yazabilirsin. Kodunu başkalarıyla paylaşma.',
  ),
  UmayTourStep(
    target: 'access-save',
    message:
        'Adresin ve kodun hazırsa Bağlantıyı Kaydet’i kullanabilirsin. Kaydettikten sonra falına kaldığın yerden dönebilirsin.',
  ),
];
const umaySupportSteps = [
  UmayTourStep(
    target: 'support-heading',
    message:
        'Yardım ve geri bildirim yollarını burada bulabilirsin. Bir sorun anlatırken gördüğün mesajı ve uygulama sürümünü belirtmen yardımcı olur.',
  ),
  UmayTourStep(
    target: 'support-open',
    message:
        'Etkin bir destek adresi varsa Destek Kanalını Aç ile ulaşabilirsin. Fal içeriği bildirimi, ilgili falın içinden yapılır.',
  ),
];
const umayReportSteps = [
  UmayTourStep(
    target: 'report-reason',
    message:
        'Bu falı neden bildirmek istediğini buradan seçebilirsin. Bildirim metnini de göndermeden önce kontrol edebilirsin.',
  ),
  UmayTourStep(
    target: 'report-confirm',
    message:
        'Bildir, ekranda gösterilen içeriği iletir. Vazgeç’i seçersen gönderim yapılmaz.',
  ),
];

const umayAppGuides = [
  UmayGuideDefinition(
    'home',
    'Ana ekran',
    umayTourSteps,
    'Kahve ana ekranında',
  ),
  UmayGuideDefinition(
    'camera',
    'Fotoğraf çekme',
    umayCameraSteps,
    'Örnek çekim ekranında',
  ),
  UmayGuideDefinition(
    'photos',
    'Fotoğrafları gözden geçirme',
    umayPhotoReviewSteps,
    'Fotoğraf ekleyip gözden geçirme ekranını açtığında',
  ),
  UmayGuideDefinition(
    'annotation',
    'Fotoğrafta şekil işaretleme',
    umayAnnotationSteps,
    'Örnek fincan fotoğrafı üzerinde',
  ),
  UmayGuideDefinition(
    'tarot',
    'Tarot’a başlama',
    umayTarotHomeSteps,
    'Tarot ana ekranında',
  ),
  UmayGuideDefinition(
    'tarot-selection',
    'Kart seçme',
    umayTarotSelectionSteps,
    'Bir Tarot açılımı seçtiğinde',
  ),
  UmayGuideDefinition(
    'tarot-ready',
    'Kartları açma ve fal hazırlama',
    umayTarotReadySteps,
    'Seçtiğin kartları açtığında',
  ),
  UmayGuideDefinition(
    'tarot-reading',
    'Tarot falını okuma',
    umayTarotReadingSteps,
    'Kayıtlı bir Tarot falını açtığında',
  ),
  UmayGuideDefinition(
    'records',
    'Kayıtlarım',
    umayRecordSteps,
    'Kayıtlarım ekranında',
  ),
  UmayGuideDefinition(
    'tarot-records',
    'Tarot kayıtları',
    umayTarotHistorySteps,
    'Kayıtlarım içindeki Tarot bölümünde',
  ),
  UmayGuideDefinition(
    'record-detail',
    'Kahve kaydının ayrıntıları',
    umayRecordDetailSteps,
    'Bir kahve kaydını açtığında',
  ),
  UmayGuideDefinition(
    'coffee-reading',
    'Kahve falını okuma',
    umayCoffeeReadingSteps,
    'Kayıtlı bir kahve falını açtığında',
  ),
  UmayGuideDefinition(
    'profile',
    'Bilgilerim',
    umayProfileSteps,
    'Bilgilerim ekranında',
  ),
  UmayGuideDefinition(
    'settings',
    'Ayarlar',
    umaySettingsSteps,
    'Ayarlar ekranında',
  ),
  UmayGuideDefinition(
    'connection',
    'Fal bağlantısı',
    umayConnectionSteps,
    'Bağlantı ekranında',
  ),
  UmayGuideDefinition(
    'privacy',
    'Gizlilik',
    umayPrivacySteps,
    'Gizlilik Politikası ekranında',
  ),
  UmayGuideDefinition(
    'support',
    'Destek',
    umaySupportSteps,
    'Destek ekranında',
  ),
  UmayGuideDefinition(
    'report',
    'Bir falı bildirme',
    umayReportSteps,
    'Bir falın bildirim onayını açtığında',
  ),
];

class UmayGuidesHub extends StatelessWidget {
  const UmayGuidesHub({required this.controller, super.key});
  final UmayGuideController controller;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Umay ile Atlas’ı tanı')),
    body: ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            key: const ValueKey('umay-guides-automatic'),
            title: const Text('İlk girişte anlat'),
            subtitle: const Text(
              'Her bölümde bir kez. Dilediğin anlatımı aşağıdan yeniden seçebilirsin.',
            ),
            value: controller.automatic,
            onChanged: (value) async {
              await controller.setAutomatic(value);
            },
          ),
          if (controller.writeFailed)
            const Text(
              'Rehber tercihi kaydedilemedi. Bu açılış için seçimin korunuyor.',
            ),
          TextButton.icon(
            key: const ValueKey('umay-guides-restart'),
            icon: const Icon(Icons.replay),
            label: const Text('Anlatımları baştan göster'),
            onPressed: () async {
              await controller.restartAll();
              if (context.mounted) Navigator.of(context).pop('home');
            },
          ),
          const Divider(),
          for (final guide in umayAppGuides)
            ListTile(
              key: ValueKey('guide-replay-${guide.id}'),
              leading: const Icon(Icons.chat_bubble_outline),
              title: Text(guide.title),
              subtitle: Text(guide.entry),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pop(guide.id),
            ),
          ListTile(
            title: const Text('Ayrıntılı kullanım rehberi'),
            leading: const Icon(Icons.menu_book_outlined),
            onTap: () => Navigator.of(context).pop('legacy'),
          ),
        ],
      ),
    ),
  );
}
