import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'label_picker.dart';
import 'models.dart';
import 'service.dart';
import 'theme.dart';

class AdminWorkspace extends StatefulWidget {
  const AdminWorkspace({required this.service, this.onExport, super.key});
  final ContributionService service;
  final void Function(String text, String name)? onExport;
  @override
  State<AdminWorkspace> createState() => _AdminWorkspaceState();
}

class _AdminWorkspaceState extends State<AdminWorkspace> {
  List<Map<String, dynamic>> rows = [], reviews = [];
  Map<String, dynamic>? selected;
  Map<String, String> urls = {};
  final Map<String, String?> corrections = {};
  final Map<String, GlobalKey> regionKeys = {};
  String? active, error;
  String outcome = 'uncertain';
  bool busy = false;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> action(Future<void> Function() fn) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await fn();
    } catch (e) {
      error = e is ContributionFailure ? e.message : 'İşlem tamamlanamadı.';
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> refresh() => action(() async {
    final data = await widget.service.call('adminList');
    rows = (data['rows'] as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    reviews = (data['reviews'] as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (selected != null && !rows.any((r) => r['id'] == selected!['id'])) {
      selected = null;
      urls = {};
    }
  });
  Future<void> select(Map<String, dynamic> row) => action(() async {
    final data = await widget.service.call('adminPhotoUrls', {'id': row['id']});
    urls = Map<String, String>.from(data['urls']);
    selected = row;
    active = null;
    corrections.clear();
    regionKeys.clear();
    outcome = 'uncertain';
    final previous = reviews
        .where((r) => r['revision_id'] == row['id'])
        .lastOrNull;
    if (previous != null) {
      outcome = previous['outcome'] as String;
      for (final c in previous['corrections'] as List) {
        corrections[c['regionId'] as String] = c['label'] as String?;
      }
    }
  });
  Future<void> save() => action(() async {
    await widget.service.call('review', {
      'id': selected!['id'],
      'outcome': outcome,
      'corrections': corrections.entries
          .map((e) => {'regionId': e.key, 'label': e.value})
          .toList(),
    });
    if (mounted) {
      showNotice(
        context,
        'İnceleme kaydedildi. Özgün kullanıcı işaretleri korundu.',
      );
    }
  });
  void focus(String id, {bool scroll = false}) {
    setState(() => active = id);
    final c = regionKeys[id]?.currentContext;
    if (scroll && c != null) {
      Scrollable.ensureVisible(
        c,
        duration: const Duration(milliseconds: 220),
        alignment: .4,
      );
    }
  }

  Widget summary() {
    final counts = <String, int>{}, groups = <String, Set<String>>{};
    var undecided = 0;
    final checksums = <String, int>{};
    for (final row in rows) {
      for (final p in (row['document'] as Map)['photos'] as List) {
        checksums.update(
          p['checksum'] as String,
          (n) => n + 1,
          ifAbsent: () => 1,
        );
        if (p['decision'] != 'marked') undecided++;
        for (final r in p['regions'] as List) {
          final label = r['label'] as String?;
          if (label == null) {
            undecided++;
            continue;
          }
          counts.update(label, (n) => n + 1, ifAbsent: () => 1);
          (groups[label] ??= {}).add(row['group_id'] as String);
        }
      }
    }
    return ExpansionTile(
      title: Text(
        '${rows.length} katkı · ${rows.map((r) => r['group_id']).toSet().length} bildirilen fincan grubu',
      ),
      childrenPadding: const EdgeInsets.all(16),
      children: [
        Text(
          '$undecided belirsiz/işaretsiz fotoğraf veya bölge · ${checksums.values.where((n) => n > 1).length} tekrar eden fotoğraf checksum’u',
        ),
        const Text(
          'Grup sayıları katılımcı beyanıdır; bağımsızlık doğrulaması değildir.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            for (final e in contributionLabels.entries)
              Text(
                '${e.value}: ${counts[e.key] ?? 0} işaret / ${groups[e.key]?.length ?? 0} grup',
              ),
          ],
        ),
      ],
    );
  }

  Widget photo(ContributionPhoto p) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(p.title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      AspectRatio(
        aspectRatio: p.width / p.height,
        child: LayoutBuilder(
          builder: (_, c) => Stack(
            children: [
              Positioned.fill(
                child: Image.network(
                  urls[p.fileKey]!,
                  fit: BoxFit.fill,
                  errorBuilder: (_, _, _) => Center(
                    child: TextButton(
                      onPressed: busy ? null : () => select(selected!),
                      child: const Text('Fotoğraf bağlantısını yenile'),
                    ),
                  ),
                ),
              ),
              for (final r in p.regions)
                Positioned(
                  left: r.box.x * c.maxWidth,
                  top: r.box.y * c.maxHeight,
                  width: r.box.width * c.maxWidth,
                  height: r.box.height * c.maxHeight,
                  child: MouseRegion(
                    onEnter: (_) => focus(r.id),
                    child: GestureDetector(
                      onTap: () => focus(r.id, scroll: true),
                      child: Semantics(
                        button: true,
                        label: r.title,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: active == r.id
                                  ? const Color(0xffffb000)
                                  : const Color(0xff13745e),
                              width: active == r.id ? 5 : 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      SelectableText(
        'SHA-256: ${p.checksum.substring(7)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      if (p.regions.isEmpty)
        Text(switch (p.decision) {
          PhotoDecision.notSeen => 'Kullanıcı şekil seçemedi',
          PhotoDecision.skipped => 'Kullanıcı geçti',
          _ => 'Kullanıcı emin değil',
        }),
      for (final r in p.regions)
        MouseRegion(
          onEnter: (_) => focus(r.id),
          child: ListTile(
            key: regionKeys.putIfAbsent(r.id, GlobalKey.new),
            selected: active == r.id,
            selectedTileColor: const Color(0xffffedc5),
            onTap: () => focus(r.id),
            leading: LabelIcon(r.label),
            title: Text(r.title),
            subtitle: corrections.containsKey(r.id)
                ? Text(
                    'İnceleyen: ${contributionLabels[corrections[r.id]] ?? 'Belirsiz'}',
                  )
                : null,
            trailing: IconButton(
              tooltip: 'İnceleyen etiketini seç',
              onPressed: busy
                  ? null
                  : () async {
                      final label = await pickContributionLabel(context);
                      if (label != null && mounted) {
                        setState(
                          () => corrections[r.id] = label == 'uncertain'
                              ? null
                              : label,
                        );
                      }
                    },
              icon: const Icon(LucideIcons.pencil),
            ),
          ),
        ),
      const Divider(height: 32),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final doc = selected == null
        ? null
        : ContributionDraft.fromJson(
            Map<String, dynamic>.from(selected!['document']),
          );
    final menu = ListView(
      children: [
        for (var i = 0; i < rows.length; i++)
          ListTile(
            selected: selected?['id'] == rows[i]['id'],
            title: Text(
              'Fincan ${rows.length - i} · rev ${rows[i]['revision']}',
            ),
            subtitle: Text(
              (rows[i]['submitted_at'] as String).split('T').first,
            ),
            onTap: busy ? null : () => select(rows[i]),
          ),
      ],
    );
    final detail = doc == null
        ? const Center(child: Text('İncelemek için bir katkı seç.'))
        : ListView(
            key: const ValueKey('admin-detail'),
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Katkı incelemesi',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SelectableText('Fincan grubu: ${doc.groupId}'),
              const SizedBox(height: 16),
              for (final p in doc.photos) photo(p),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in const {
                    'suitable': 'Uygun',
                    'uncertain': 'Belirsiz',
                    'unsuitable': 'Uygun değil',
                  }.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: outcome == e.key,
                      onSelected: busy
                          ? null
                          : (_) => setState(() => outcome = e.key),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : save,
                child: const Text('İncelemeyi kaydet'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bu karar yalnız incelenmiş araştırma adayıdır; canonical kabul veya eğitim kararı değildir.',
              ),
            ],
          );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Atlas Katkı · İnceleme'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: busy ? null : refresh,
            icon: const Icon(LucideIcons.refreshCw),
          ),
          IconButton(
            tooltip: 'Güncel araştırma kayıtlarını dışa aktar',
            onPressed: busy
                ? null
                : () => action(() async {
                    final data = await widget.service.call('export');
                    widget.onExport?.call(
                      jsonEncode(data),
                      'atlas-research-export.json',
                    );
                  }),
            icon: const Icon(LucideIcons.download),
          ),
          IconButton(
            tooltip: 'Çıkış',
            onPressed: () => widget.service.client.auth.signOut(),
            icon: const Icon(LucideIcons.logOut),
          ),
        ],
      ),
      body: Column(
        children: [
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: SingleChildScrollView(child: summary()),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (_, c) => c.maxWidth >= 800
                  ? Row(
                      children: [
                        SizedBox(width: 260, child: menu),
                        const VerticalDivider(width: 1),
                        Expanded(child: detail),
                      ],
                    )
                  : Column(
                      children: [
                        SizedBox(height: 140, child: menu),
                        const Divider(height: 1),
                        Expanded(child: detail),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
