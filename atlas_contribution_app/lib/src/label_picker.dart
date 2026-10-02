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

class LabelPicker extends StatelessWidget {
  const LabelPicker({super.key});
  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(16) > 21;
    return FractionallySizedBox(
      heightFactor: .92,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Neye benziyor?',
                    style: TextStyle(
                      fontFamily: 'Literata',
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Kapat',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: contributionLabels.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: large ? 2 : 3,
                mainAxisExtent: large ? 208 : 136,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemBuilder: (context, i) {
                final item = contributionLabels.entries.elementAt(i);
                return OutlinedButton(
                  onPressed: () => Navigator.pop(context, item.key),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      LabelIcon(item.key),
                      const SizedBox(height: 8),
                      Text(
                        item.value,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, 'uncertain'),
                icon: const Icon(LucideIcons.helpCircle),
                label: const Text('Emin değilim'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
