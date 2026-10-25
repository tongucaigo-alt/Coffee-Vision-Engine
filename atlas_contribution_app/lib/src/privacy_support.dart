import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SupportConfiguration {
  static const draftSupportEmail = 'xxxx@atlas.com';

  const SupportConfiguration({
    this.operatorName = const String.fromEnvironment('ATLAS_OPERATOR_NAME'),
    this.privacyUrl = const String.fromEnvironment('ATLAS_PRIVACY_URL'),
    this.supportUrl = const String.fromEnvironment('ATLAS_SUPPORT_URL'),
    this.supportEmail = const String.fromEnvironment('ATLAS_SUPPORT_EMAIL'),
  });
  final String operatorName, privacyUrl, supportUrl, supportEmail;
  Uri? https(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
            uri.scheme == 'https' &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty
        ? uri
        : null;
  }

  Uri? get contact =>
      https(supportUrl) ??
      (supportEmail.toLowerCase() != draftSupportEmail &&
              RegExp(
                r'^[A-Za-z0-9.!#$%&*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$',
              ).hasMatch(supportEmail)
          ? Uri(
              scheme: 'mailto',
              path: supportEmail,
              queryParameters: {'subject': 'Atlas destek talebi'},
            )
          : null);
}

const privacySections = <(String, String)>[
  (
    'Telefonda saklanan veriler',
    'Fincan ve tabak fotoğrafları, manuel işaretler, taslaklar, incelemeler, fallar, yıldızlar ve geçmiş bağlantıları bu uygulamanın cihazdaki özel alanında saklanır. Kamera veya galeri seçimi tek başına bu fotoğrafları bir AI hizmetine göndermez.',
  ),
  (
    'Kahve yorumu oluştururken',
    'Fal oluşturmayı seçtiğinde fotoğraf yerine metinsel analiz özeti, bildirdiğin semboller ve seçtiğin konu yapılandırılmış yorum hizmetine gönderilir. Bilgilerim ekranında yaş girilmişse yaş; burcu falda kullanma seçeneği açıksa burç da gönderilebilir. Hitap adı gönderilmez. Uygun olduğunda yıldızlı eski bir falından kısa bir bölüm yeni yorum isteğine eklenebilir. Hafıza seçimi için ayrıca bir AI çağrısı yapılmaz.',
  ),
  (
    'Tarot',
    'Kart seçimi cihazda yapılır. Yorum oluştururken açılım türü, seçilen kartların kimlikleri/adları, pozisyonları, düz/ters yönleri ve o yöne ait temaları yorum hizmetine gönderilir. Seçilmeyen deste, kart görselleri ve yerel ruh hâli tercihin bu isteğe eklenmez.',
  ),
  (
    'Hizmet sağlayıcıları ve erişim',
    'Play test bağlantısı Atlas gateway üzerinden yapılandırılmış AI sağlayıcısına ulaşır. Laboratuvar sürümündeki doğrudan bağlantı seçilen sağlayıcıya gider. Adres ve erişim bilgileri bağlantı ayarlarında bulunur. AI üretimi internet bağlantısı gerektirir. Sağlayıcıların sunucu saklama koşulları cihazdan yapılan silmeyle değişmez; işletmeci gerçek sağlayıcı ve saklama bilgilerini yayımlanan politikada açıklamalıdır.',
  ),
  (
    'İçerik bildirimi',
    'Bir yorumu bildirdiğinde ayrıca onay istenir. Yalnız seçtiğin yorum metni, neden ve tekrarları ayıklamak için bir bildirim kimliği Atlas bildirim hizmetine gönderilir. Fotoğraf ve profil ayrıca eklenmez; yorum metninin kendisi kişisel ifadeler içerebilir. Gönderilemeyen metin cihazda bekler, sunucunun alındı teyidinden sonra yerel kuyruktaki metin kaldırılır. Sunucuda bildirimin metni/nedeni/kimliği ve alınma zamanı kalıcı kaydedilir; bu depoda otomatik süre dolumu uygulanmaz. Yetkili insan incelemesi ve nihai saklama süresi işletmecinin operasyonuna bağlıdır.',
  ),
  (
    'Saklama ve silme',
    'Yıldızsız kayıtlar da otomatik silinmez; yedi günlük silme kuralı uygulanmıyor. Kayıtlarım üzerinden kayıtlarını, Bilgilerim üzerinden kişisel tercihlerini silebilirsin. Yıldız kaldırmak falı silmez. Cihazdan silmek daha önce açıkça gönderdiğin bir içerik bildirimini veya sağlayıcının kayıtlarını kendiliğinden silmez. Telefon/işletim sistemi yedekleri varsa onların yönetimi ayrıca geçerlidir.',
  ),
  (
    'İzinler ve yerel kullanım',
    'Kamera izni çekim, sistem galeri seçicisi seçtiğin fotoğrafları içe aktarma içindir. Fotoğraf uygunluk ve şekil analizi yerel çalışır. Araştırma ZIP dışa aktarımı bu sürümde bulunmaz. Fotoğrafların araştırmaya gönderildiği bir akış yoktur.',
  ),
];

class PrivacySupportPage extends StatefulWidget {
  const PrivacySupportPage({
    this.support = false,
    this.configuration = const SupportConfiguration(),
    super.key,
  });
  final bool support;
  final SupportConfiguration configuration;
  @override
  State<PrivacySupportPage> createState() => _PrivacySupportPageState();
}

class _PrivacySupportPageState extends State<PrivacySupportPage> {
  static const links = MethodChannel('atlas.app/links');
  String? _error;
  Future<void> _open(Uri uri) async {
    try {
      final opened = await links.invokeMethod<bool>('open', {
        'url': uri.toString(),
      });
      if (opened != true) throw const FormatException('No handler');
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Bağlantı açılamadı. Aşağıdaki adresi kopyalayarak deneyebilirsin.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.configuration;
    final uri = widget.support
        ? config.contact
        : config.https(config.privacyUrl);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.support ? 'Destek' : 'Gizlilik Politikası'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (config.operatorName.trim().isNotEmpty)
            SelectableText('İşletmeci: ${config.operatorName}'),
          if (!widget.support) ...[
            const Text(
              'Atlas — veri kullanımı ve gizlilik',
              style: TextStyle(fontSize: 22),
            ),
            const SizedBox(height: 12),
            for (final section in privacySections) ...[
              Text(
                section.$1,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(section.$2),
              const SizedBox(height: 20),
            ],
          ] else ...[
            const Text(
              'Yardım ve geri bildirim',
              style: TextStyle(fontSize: 22),
            ),
            const SizedBox(height: 12),
            const Text(
              'Uygun bulmadığın kahve veya Tarot yorumunu, kayıtlı yorumdaki “Bu yorumu bildir” eylemiyle uygulama içinden iletebilirsin. Gönderim durumu aynı ekranda görünür. Diğer sorunlarda sürümü ve gördüğün hata mesajını paylaş; anahtarını veya özel fotoğraflarını destek talebine ekleme.',
            ),
            if (uri == null) ...[
              const SizedBox(height: 12),
              const SelectableText(
                'Taslak destek adresi: ${SupportConfiguration.draftSupportEmail} (henüz etkin değil)',
              ),
            ],
          ],
          if (uri != null) ...[
            SelectableText(uri.toString()),
            OutlinedButton(
              onPressed: () => _open(uri),
              child: Text(
                widget.support
                    ? 'Destek Kanalını Aç'
                    : 'Yayımlanan Politikayı Aç',
              ),
            ),
            TextButton(
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: uri.toString())),
              child: const Text('Adresi Kopyala'),
            ),
          ] else
            Text(
              widget.support
                  ? 'Bu derlemeye doğrulanmış destek adresi eklenmemiş. İçerik bildirimi yorum ekranından kullanılabilir; gerçek destek iletişimi yayından önce tamamlanmalıdır.'
                  : 'Bu derlemeye yayımlanmış politika adresi eklenmemiş. Yukarıdaki yerel açıklama okunabilir; işletmeci, gerçek sağlayıcı koşulları ve kamuya açık adres yayından önce tamamlanmalıdır.',
            ),
          if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
        ],
      ),
    );
  }
}
