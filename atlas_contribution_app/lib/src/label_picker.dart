import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'models.dart';

const labelIcons = <String, IconData>{
  'bird': LucideIcons.bird,
  'heart': LucideIcons.heart,
  'fish': LucideIcons.fish,
  'snake': LucideIcons.waves,
  'dog': LucideIcons.dog,
  'butterfly': LucideIcons.flower,
  'tree': LucideIcons.treeDeciduous,
  'horse': LucideIcons.footprints,
  'eye': LucideIcons.eye,
  'crown': LucideIcons.crown,
  'ring': LucideIcons.circle,
  'road': LucideIcons.moveUpRight,
  'mountain': LucideIcons.mountain,
  'moon': LucideIcons.moon,
  'sun': LucideIcons.sun,
  'anchor': LucideIcons.anchor,
  'house': LucideIcons.home,
  'humanFigure': LucideIcons.personStanding,
  'airplane': LucideIcons.plane,
  'flower': LucideIcons.flower2,
  'cat': LucideIcons.cat,
  'star': LucideIcons.star,
  'key': LucideIcons.keyRound,
  'boat': LucideIcons.ship,
  'turtle': LucideIcons.turtle,
  'rabbit': LucideIcons.rabbit,
  'lion': Icons.pets,
  'book': LucideIcons.bookOpen,
  'ladder': Icons.stairs,
  'bridge': Icons.architecture,
  'cloud': LucideIcons.cloud,
  'elephant': Icons.pets,
};

class LabelIcon extends StatelessWidget {
  const LabelIcon(this.label, {this.size = 28, super.key});
  final String? label;
  final double size;
  @override
  Widget build(BuildContext context) {
    final asset = switch (label) {
      'snake' => 'snake',
      'butterfly' => 'butterfly',
      'horse' => 'horse',
      'ring' => 'ring',
      'road' => 'road-horizon',
      'lion' => 'lion',
      'elephant' => 'elephant',
      'bridge' => 'bridge',
      'ladder' => 'ladder',
      _ => null,
    };
    return asset == null
        ? Icon(labelIcons[label] ?? LucideIcons.helpCircle, size: size)
        : SvgPicture.asset(
            'assets/labels/$asset.svg',
            width: size,
            height: size,
            colorFilter: ColorFilter.mode(
              Theme.of(context).colorScheme.primary,
              BlendMode.srcIn,
            ),
          );
  }
}

Future<String?> pickContributionLabel(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const LabelPicker(),
    );

const labelCategories = <String, List<String>>{
  'Öne çıkan': ['bird', 'heart', 'humanFigure', 'tree', 'fish', 'road'],
  'Hayvanlar': [
    'bird',
    'fish',
    'snake',
    'dog',
    'butterfly',
    'horse',
    'cat',
    'turtle',
    'rabbit',
    'lion',
    'elephant',
  ],
  'Doğa': ['tree', 'mountain', 'moon', 'sun', 'flower', 'star', 'cloud'],
  'İnsan ve nesneler': [
    'heart',
    'eye',
    'crown',
    'ring',
    'anchor',
    'house',
    'humanFigure',
    'airplane',
    'key',
    'boat',
    'book',
    'ladder',
    'bridge',
    'road',
  ],
};

String _searchText(String text) => text
    .replaceAll('İ', 'i')
    .replaceAll('I', 'ı')
    .toLowerCase()
    .replaceAll('ı', 'i')
    .replaceAll('ş', 's')
    .replaceAll('ğ', 'g')
    .replaceAll('ü', 'u')
    .replaceAll('ö', 'o')
    .replaceAll('ç', 'c');

class LabelPicker extends StatefulWidget {
  const LabelPicker({super.key});
  @override
  State<LabelPicker> createState() => _LabelPickerState();
}

class _LabelPickerState extends State<LabelPicker> {
  final _search = TextEditingController();
  String _query = '', _category = 'Öne çıkan';
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final items = contributionLabels.entries
        .where(
          (e) => _query.isNotEmpty
              ? _searchText(e.value).contains(_searchText(_query))
              : _category == 'Tümü' ||
                    labelCategories[_category]!.contains(e.key),
        )
        .toList();
    final columns = MediaQuery.sizeOf(context).width < 380 || scale > 1.3
        ? 2
        : 3;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              (MediaQuery.sizeOf(context).height -
                  MediaQuery.viewInsetsOf(context).bottom) *
              .92,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                'Neye benziyor?',
                style: TextStyle(
                  fontFamily: 'Literata',
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  labelText: 'Şekil ara',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  for (final category in ['Tümü', ...labelCategories.keys])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: _category == category,
                        onSelected: (_) => setState(() {
                          _category = category;
                          _query = '';
                          _search.clear();
                        }),
                      ),
                    ),
                ],
              ),
            ),
            items.isEmpty
                ? const Center(child: Text('Bu adla şekil bulunamadı.'))
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: items.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: 84 + 88 * (scale - 1).clamp(0, 2),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemBuilder: (context, i) => OutlinedButton(
                      onPressed: () => Navigator.pop(context, items[i].key),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          LabelIcon(items[i].key, size: 20),
                          const SizedBox(height: 4),
                          Text(
                            items[i].value,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'uncertain'),
                    child: const Text('Emin değilim'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Vazgeç'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
