import 'package:coffee_vision/coffee_vision.dart';

const regionalSummaryVersion = 'atlas-regional-summary-v1';

/// A projection of physical engine output, never a symbol detector.
Map<String, dynamic> summarizeRegions(VisionFeatureSet features) {
  final content = features.imageProvenance.contentRect;
  final candidates =
      features.componentFeatures
          .where((c) => !c.touchesBorder && c.residueShare >= .01)
          .toList()
        ..sort((a, b) {
          final size = b.pixelCount.compareTo(a.pixelCount);
          return size == 0 ? a.componentId.compareTo(b.componentId) : size;
        });
  final selected = candidates.take(3).toList();
  final indices = {
    for (var i = 0; i < selected.length; i++) selected[i].componentId: i + 1,
  };
  return {
    'version': regionalSummaryVersion,
    'bands': [
      for (final r in features.regionFeatures)
        {'position': r.regionId.name, 'density': r.residueDensity},
    ],
    'components': [
      for (var i = 0; i < selected.length; i++)
        {
          'number': i + 1,
          'x': ((selected[i].centroid.x - content.left) / content.width).clamp(
            0.0,
            1.0,
          ),
          'y': ((selected[i].centroid.y - content.top) / content.height).clamp(
            0.0,
            1.0,
          ),
          'residueShare': selected[i].residueShare,
          'aspectRatio': selected[i].aspectRatio,
        },
    ],
    'relations': [
      for (final r in features.spatialRelationFeatures)
        if (r.selected &&
            indices.containsKey(r.sourceComponentId) &&
            indices.containsKey(r.targetComponentId))
          {
            'from': indices[r.sourceComponentId],
            'to': indices[r.targetComponentId],
            'distance': r.centroidDistance,
          },
    ],
  };
}

/// Strict allowlist used both at persistence and at the outgoing boundary.
void validateRegionalSummary(Object? value) {
  if (value == null) return;
  void keys(Map m, List<String> allowed) {
    if (m.length != allowed.length || m.keys.any((k) => !allowed.contains(k))) {
      throw const FormatException('Invalid regional fields');
    }
  }

  bool number(Object? n, [double? max]) =>
      n is num && n.isFinite && n >= 0 && (max == null || n <= max);
  if (value is! Map) throw const FormatException('Invalid regional summary');
  keys(value, ['version', 'bands', 'components', 'relations']);
  if (value['version'] != regionalSummaryVersion ||
      value['bands'] is! List ||
      value['components'] is! List ||
      value['relations'] is! List) {
    throw const FormatException('Invalid regional version');
  }
  final positions = <String>{};
  for (final b in value['bands'] as List) {
    if (b is! Map) throw const FormatException('Invalid band');
    keys(b, ['position', 'density']);
    if (![
          'top',
          'middle',
          'bottom',
          'left',
          'center',
          'right',
        ].contains(b['position']) ||
        !positions.add(b['position'] as String) ||
        !number(b['density'], 1)) {
      throw const FormatException('Invalid band');
    }
  }
  final components = value['components'] as List;
  if (components.length > 3) throw const FormatException('Too many regions');
  for (var i = 0; i < components.length; i++) {
    final c = components[i];
    if (c is! Map) throw const FormatException('Invalid component');
    keys(c, ['number', 'x', 'y', 'residueShare', 'aspectRatio']);
    if (c['number'] != i + 1 ||
        !number(c['x'], 1) ||
        !number(c['y'], 1) ||
        !number(c['residueShare'], 1) ||
        (c['residueShare'] as num) < .01 ||
        !number(c['aspectRatio']) ||
        c['aspectRatio'] == 0) {
      throw const FormatException('Invalid component');
    }
  }
  final pairs = <String>{};
  for (final r in value['relations'] as List) {
    if (r is! Map) throw const FormatException('Invalid relation');
    keys(r, ['from', 'to', 'distance']);
    if (r['from'] is! int ||
        r['to'] is! int ||
        (r['from'] as int) < 1 ||
        (r['from'] as int) > components.length ||
        (r['to'] as int) < 1 ||
        (r['to'] as int) > components.length ||
        r['from'] == r['to'] ||
        !number(r['distance']) ||
        !pairs.add('${r['from']}:${r['to']}')) {
      throw const FormatException('Invalid relation');
    }
  }
}
