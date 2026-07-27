import 'models/vision_graph_statistics.dart';
import 'models/vision_spatial_graph.dart';

/// Reads the public spatial-graph contract and returns aggregate statistics.
///
/// This analysis does not create or mutate graphs, components, or relations.
final class GraphStatisticsAnalyzer {
  const GraphStatisticsAnalyzer();

  VisionGraphStatistics analyze(VisionSpatialGraph graph) {
    final componentCount = graph.components.length;
    final relationCount = graph.relations.length;
    if (componentCount == 0) {
      return VisionGraphStatistics(
        componentCount: 0,
        relationCount: 0,
        isolatedComponentCount: 0,
        minDegree: 0,
        maxDegree: 0,
        averageDegree: 0.0,
      );
    }

    var isolatedComponentCount = 0;
    var minDegree = componentCount;
    var maxDegree = 0;
    var degreeTotal = 0;
    for (final component in graph.components) {
      final degree = graph.degreeOf(component.id);
      if (degree == 0) isolatedComponentCount++;
      if (degree < minDegree) minDegree = degree;
      if (degree > maxDegree) maxDegree = degree;
      degreeTotal += degree;
    }

    return VisionGraphStatistics(
      componentCount: componentCount,
      relationCount: relationCount,
      isolatedComponentCount: isolatedComponentCount,
      minDegree: minDegree,
      maxDegree: maxDegree,
      averageDegree: degreeTotal / componentCount,
    );
  }
}
