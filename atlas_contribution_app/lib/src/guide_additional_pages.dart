import 'package:flutter/material.dart';
import 'atlas_design.dart';

/// Read-only illustrations: no profile, record, video, report or Tarot runtime.
class GuideAdditionalPage extends StatelessWidget {
  const GuideAdditionalPage({required this.kind, super.key});
  final int kind;

  Widget _text(String text, {Color color = atlasMuted}) => Text(
    text,
    textAlign: TextAlign.center,
    style: TextStyle(fontSize: 13, height: 1.5, color: color),
  );

  Widget _item(String text, IconData icon, {bool active = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      color: active ? atlasSageSurface : atlasCard,
      border: Border.all(color: atlasBorder),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: atlasSageInk, size: 22),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: atlasCoffee,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _wrap(List<Widget> items) => Wrap(
    spacing: 8,
    runSpacing: 8,
    alignment: WrapAlignment.center,
    children: items,
  );

  Widget _panel(List<Widget> items) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: atlasCard,
      border: Border.all(color: atlasBorder),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          items[i],
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _text('Örnek gösterim'),
      const SizedBox(height: 12),
      switch (kind) {
        8 => _profile(),
        9 => _resume(),
        10 => _records(),
        11 => _tarot(),
        12 => _help(),
        _ => const SizedBox.shrink(),
      },
    ],
  );

  Widget _profile() => _panel([
    const CircleAvatar(
      backgroundColor: atlasCoffee,
      child: Icon(Icons.person, color: atlasCard),
    ),
    _text('Sağ üstteki kişi simgesi → Bilgilerim', color: atlasSageInk),
    _item('Hitap adı · isteğe bağlı', Icons.person_outline),
    _item('Burç · isteğe bağlı', Icons.auto_awesome_outlined),
    _item('Yaş · isteğe bağlı', Icons.edit_outlined),
    _wrap([
      _item('Kaydet', Icons.save_outlined, active: true),
      _item('Bilgilerimi sil', Icons.delete_outline),
    ]),
    _text('Hitap adın bu cihazda kalır.'),
    _text(
      'Burç ve yaşını kaydedersen yeni yorum için hizmete gönderilir. Boş bırakabilirsin.',
    ),
  ]);

  Widget _resume() => Column(
    children: [
      _resumeExample('Kahve', Icons.coffee_outlined),
      const SizedBox(height: 16),
      _resumeExample('Tarot', Icons.style_outlined),
      const SizedBox(height: 16),
      _text(
        '▶ yalnız yarım kalan bir çalışma varsa görünür.',
        color: atlasSageInk,
      ),
      const SizedBox(height: 8),
      _text('Aynı çalışmaya dönersin; yeni çekim veya açılım başlamaz.'),
    ],
  );

  Widget _resumeExample(String name, IconData icon) => _panel([
    Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: const TextStyle(fontFamily: 'Literata', fontSize: 20),
          ),
        ),
        Semantics(
          label: '$name örneği: sağ üstteki devam simgesi',
          child: Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: atlasCream,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow_rounded, color: atlasCoffee),
          ),
        ),
      ],
    ),
    Icon(icon, size: 52, color: atlasSageInk),
    _text('Yarım kalan çalışman'),
  ]);

  Widget _records() => _panel([
    const Icon(Icons.history, size: 42, color: atlasSageInk),
    _wrap([
      _item('Kahve', Icons.coffee_outlined, active: true),
      _item('Tarot', Icons.style_outlined),
    ]),
    _text('Kahve kayıtları', color: atlasSageInk),
    _wrap([
      _item('Tümü', Icons.list),
      _item('Kayıtlı', Icons.bookmark_border),
      _item('Taslaklar', Icons.edit_outlined),
      _item('Yıldızlılar', Icons.star_border),
    ]),
    _text('Taslaklar: yarım kalan kahvene devam et.'),
    _item('Falını Oku', Icons.menu_book_outlined, active: true),
    _text('Hazır falını yeniden okuyabilirsin.'),
    _text('Yıldızsız kayıtların da saklanır.'),
  ]);

  Widget _tarot() => _panel([
    _wrap([
      _item('Günün Kartı', Icons.wb_twilight_outlined),
      _item('Üç Kart · Karıştır', Icons.style_outlined, active: true),
    ]),
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.asset(
                    'assets/tarot/KART_ARKASI.webp',
                    width: 52,
                    height: 84,
                    fit: BoxFit.cover,
                    cacheWidth: 156,
                    semanticLabel: 'Kapalı örnek kart ${i + 1}',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${i + 1}',
                  style: const TextStyle(fontSize: 13, color: atlasSageInk),
                ),
              ],
            ),
          ),
      ],
    ),
    _text('Kartlarını seç → Sırayla aç', color: atlasSageInk),
    _text('Geçmiş · Şimdi · Olası Yön'),
    _item('Ruh hâli · isteğe bağlı', Icons.sentiment_satisfied_alt),
    _item('Yorumunu Oluştur', Icons.auto_awesome, active: true),
    _text('Kart seçimi çevrimdışı; yorum için internet gerekir.'),
  ]);

  Widget _help() => Column(
    children: [
      _panel([
        _item('Ayarlar', Icons.settings_outlined, active: true),
        _item('Kullanım Rehberi', Icons.menu_book_outlined),
        _text('Rehberi buradan tekrar açabilirsin.'),
        _item('Gizlilik Politikası', Icons.privacy_tip_outlined),
        _item('Destek', Icons.help_outline),
      ]),
      const SizedBox(height: 16),
      _panel([
        _item('İçerik Bildir', Icons.flag_outlined),
        _text('Kayıtlı yorum → Bu yorumu bildir', color: atlasSageInk),
        _text('Nedeni seç → Yorumu kontrol et → Bildir'),
        _text('Gönderim için senin onayın gerekir.'),
      ]),
      const SizedBox(height: 16),
      _text('Kayıt açılamazsa “Yeniden Dene” ile tekrar kontrol edebilirsin.'),
    ],
  );
}
