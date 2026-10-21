import 'package:flutter/material.dart';
import '../local_store.dart';
import '../models.dart';
import '../photo_view.dart';

/// Read-only access while AI/receipt initialization needs recovery.
/// Deliberately has no save, delete, import, analysis or generation callbacks.
class AiRecoveryPage extends StatefulWidget {
  const AiRecoveryPage({
    required this.store,
    required this.message,
    this.onRetry,
    this.tarotPage,
    this.tarotHistoryPage,
    super.key,
  });
  final DraftStore store;
  final String message;
  final VoidCallback? onRetry;
  final Widget? tarotPage;
  final Widget? tarotHistoryPage;
  @override
  State<AiRecoveryPage> createState() => _AiRecoveryPageState();
}

class _AiRecoveryPageState extends State<AiRecoveryPage> {
  late final _snapshot = widget.store.receiptSnapshot();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Atlas · Kayıt kurtarma')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(widget.message),
        const SizedBox(height: 12),
        const Text(
          'Kayıtlı fallar şu anda açılamıyor. Veri sıfırlanmadı; kayıt değiştirme ve silme kapalı.',
        ),
        FilledButton(
          onPressed: widget.onRetry,
          child: const Text('Yeniden Dene'),
        ),
        if (widget.tarotPage != null)
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => widget.tarotPage!),
            ),
            child: const Text('Tarot'),
          ),
        if (widget.tarotHistoryPage != null)
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => widget.tarotHistoryPage!),
            ),
            child: const Text('Tarot Kayıtları'),
          ),
        const Text('Telefondaki fotoğraflar ve işaretler'),
        FutureBuilder<ReceiptSnapshot>(
          future: _snapshot,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Kayıt listesi okunamadı. Dosyalar korundu.');
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!data.writable) Text(data.warning),
                if (data.rows.isEmpty)
                  const Text(
                    'Bu listeden gösterilebilen kayıt yok. Bu, dosyaların silindiği anlamına gelmez.',
                  ),
                for (final row in data.rows) _record(row),
              ],
            );
          },
        ),
      ],
    ),
  );

  Widget _record(Map<String, dynamic> row) {
    try {
      final draft = ContributionDraft.fromJson(
        Map<String, dynamic>.from(row['document'] as Map),
      );
      return ExpansionTile(
        title: Text('Kayıt · ${draft.createdAt.split('T').first}'),
        children: [
          for (final photo in draft.photos)
            MarkedPhoto(
              photo: photo,
              image: FileImage(widget.store.file(photo.localName)),
            ),
        ],
      );
    } catch (_) {
      return const Text('Bir kayıt görüntülenemedi. Dosyaları korundu.');
    }
  }
}
