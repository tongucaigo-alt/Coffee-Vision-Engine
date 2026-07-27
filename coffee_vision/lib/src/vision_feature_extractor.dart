import 'models/vision_edge_selection_profile.dart';
import 'models/vision_analysis_region.dart';
import 'models/vision_component_feature.dart';
import 'models/vision_feature_image_provenance.dart';
import 'models/vision_feature_set.dart';
import 'models/vision_global_features.dart';
import 'models/vision_geometry.dart';
import 'models/vision_image_input.dart';
import 'models/vision_pipeline_result.dart';
import 'models/vision_region_density.dart';
import 'models/vision_region_feature.dart';
import 'models/vision_spatial_relation_feature.dart';

typedef VisionPipelineRunner =
    Future<VisionPipelineResult> Function(
      VisionImageInput input,
      VisionEdgeSelectionProfile edgeSelectionProfile,
    );

/// Internal M7 feature boundary over the existing detailed pipeline.
///
/// This type is deliberately absent from the public barrel. It runs the
/// supplied pipeline exactly once and projects only the physical values
/// approved through M7D.
final class VisionFeatureExtractor {
  const VisionFeatureExtractor();

  Future<VisionFeatureSet> analyze({
    required VisionImageInput input,
    required VisionEdgeSelectionProfile edgeSelectionProfile,
    required VisionPipelineRunner pipelineRunner,
  }) async {
    final pipelineResult = await pipelineRunner(input, edgeSelectionProfile);
    return extract(pipelineResult);
  }

  VisionFeatureSet extract(VisionPipelineResult pipelineResult) {
    final workingImage = pipelineResult.workingImage;
    final sourceMetadata = workingImage.sourceMetadata;
    final workingMetadata = workingImage.workingMetadata;
    final residueMask = pipelineResult.residueMask;
    final componentResult = pipelineResult.componentResult;
    final relationResult = pipelineResult.relationResult;
    final edgeSelectionResult = pipelineResult.edgeSelectionResult;

    if (residueMask.residuePixelCount != componentResult.totalResiduePixels) {
      throw StateError(
        'Pipeline residue and component pixel totals must match.',
      );
    }
    if (componentResult.componentCount != componentResult.components.length) {
      throw StateError('Pipeline component count must match its collection.');
    }
    if (edgeSelectionResult.decisionRecords.length !=
        relationResult.relations.length) {
      throw StateError(
        'Pipeline edge decisions must cover every candidate relation.',
      );
    }
    if (edgeSelectionResult.selectedRelations.length >
        edgeSelectionResult.decisionRecords.length) {
      throw StateError(
        'Selected relation count must not exceed candidate relation count.',
      );
    }

    final globalFeatures = VisionGlobalFeatures(
      residuePixelCount: residueMask.residuePixelCount,
      contentResidueRatio: residueMask.residueRatio,
      componentCount: componentResult.componentCount,
      candidateRelationCount: edgeSelectionResult.decisionRecords.length,
      selectedRelationCount: edgeSelectionResult.selectedRelations.length,
    );

    return VisionFeatureSet.withSpatialAndConnectivityFeatures(
      surfaceType: pipelineResult.surfaceType,
      sourceId: pipelineResult.sourceId,
      imageProvenance: VisionFeatureImageProvenance(
        sourceFormat: sourceMetadata.format,
        sourceWidth: sourceMetadata.width,
        sourceHeight: sourceMetadata.height,
        workingFormat: workingMetadata.format,
        workingWidth: workingMetadata.width,
        workingHeight: workingMetadata.height,
        workingResolution: workingImage.resolution,
        contentRect: workingImage.contentRect,
      ),
      globalFeatures: globalFeatures,
      regionFeatures: _projectRegionFeatures(pipelineResult),
      componentFeatures: _projectComponentFeatures(
        pipelineResult,
        globalFeatures,
      ),
      edgeSelectionProfile: edgeSelectionResult.profile,
      spatialRelationFeatures: _projectSpatialRelationFeatures(pipelineResult),
      graphStatistics: pipelineResult.graphStatistics,
      connectedStructureResult: pipelineResult.connectedStructureResult,
    );
  }

  List<VisionSpatialRelationFeature> _projectSpatialRelationFeatures(
    VisionPipelineResult pipelineResult,
  ) {
    return List<VisionSpatialRelationFeature>.unmodifiable(
      pipelineResult.edgeSelectionResult.decisionRecords.map(
        VisionSpatialRelationFeature.fromDecision,
      ),
    );
  }

  List<VisionComponentFeature> _projectComponentFeatures(
    VisionPipelineResult pipelineResult,
    VisionGlobalFeatures globalFeatures,
  ) {
    final components = pipelineResult.componentResult.components.toList()
      ..sort((first, second) => first.id.compareTo(second.id));
    final componentIds = <int>{};
    for (final component in components) {
      if (!componentIds.add(component.id)) {
        throw StateError('Pipeline component IDs must be unique.');
      }
    }

    final nearestById =
        pipelineResult.relationResult.nearestNeighborByComponentId;
    if (nearestById.length != componentIds.length ||
        !componentIds.every(nearestById.containsKey) ||
        !nearestById.keys.every(componentIds.contains)) {
      throw StateError(
        'Nearest-neighbor keys must match canonical component IDs.',
      );
    }

    if (components.isEmpty) {
      if (globalFeatures.residuePixelCount != 0) {
        throw StateError('Residue pixels require at least one component.');
      }
      return const <VisionComponentFeature>[];
    }
    if (globalFeatures.residuePixelCount <= 0) {
      throw StateError('Component residue share requires residue pixels.');
    }

    return List<VisionComponentFeature>.unmodifiable(
      components.map((component) {
        final nearestId = nearestById[component.id];
        if (components.length == 1) {
          if (nearestId != null) {
            throw StateError(
              'A single component must have no nearest neighbor.',
            );
          }
        } else if (nearestId == null || !componentIds.contains(nearestId)) {
          throw StateError(
            'Each component must reference an existing nearest neighbor.',
          );
        }

        late final double fillRatio;
        late final bool touchesBorder;
        try {
          fillRatio = component.fillRatio;
          touchesBorder = component.touchesBorder;
        } on StateError catch (error) {
          throw StateError(
            'Pipeline component ${component.id} is missing detection '
            'metadata: ${error.message}',
          );
        }

        return VisionComponentFeature(
          componentId: component.id,
          pixelCount: component.pixelCount,
          boundingBox: component.boundingBox,
          centroid: component.centroid,
          width: component.width,
          height: component.height,
          aspectRatio: component.aspectRatio,
          areaRatio: component.areaRatio,
          fillRatio: fillRatio,
          touchesBorder: touchesBorder,
          residueShare: component.pixelCount / globalFeatures.residuePixelCount,
          nearestNeighborComponentId: nearestId,
        );
      }),
    );
  }

  List<VisionRegionFeature> _projectRegionFeatures(
    VisionPipelineResult pipelineResult,
  ) {
    final regionsById = <VisionRegionId, VisionAnalysisRegion>{};
    for (final region in pipelineResult.analysisRegions) {
      if (region.surfaceType != pipelineResult.surfaceType) {
        throw StateError('Analysis region surface type must match the result.');
      }
      if (regionsById.containsKey(region.id)) {
        throw StateError('Analysis region IDs must be unique.');
      }
      if (!_containsRect(
        outer: pipelineResult.workingImage.contentRect,
        inner: region.rect,
      )) {
        throw StateError('Analysis regions must stay inside contentRect.');
      }
      regionsById[region.id] = region;
    }

    final densitiesById = <VisionRegionId, VisionRegionDensity>{};
    for (final density in pipelineResult.regionDensities) {
      if (density.surfaceType != pipelineResult.surfaceType) {
        throw StateError('Region density surface type must match the result.');
      }
      if (densitiesById.containsKey(density.regionId)) {
        throw StateError('Region density IDs must be unique.');
      }
      densitiesById[density.regionId] = density;
    }

    if (regionsById.length != VisionRegionId.values.length ||
        densitiesById.length != VisionRegionId.values.length) {
      throw StateError(
        'Pipeline result must contain all six canonical regions and densities.',
      );
    }

    return List<VisionRegionFeature>.unmodifiable(
      VisionRegionId.values.map((id) {
        final region = regionsById[id];
        final density = densitiesById[id];
        if (region == null || density == null) {
          throw StateError('Region geometry and density IDs must match.');
        }
        return VisionRegionFeature(
          regionId: id,
          rect: region.rect,
          residueDensity: density.density,
        );
      }),
    );
  }

  bool _containsRect({required VisionRect outer, required VisionRect inner}) {
    return inner.left >= outer.left &&
        inner.top >= outer.top &&
        inner.right <= outer.right &&
        inner.bottom <= outer.bottom;
  }
}
