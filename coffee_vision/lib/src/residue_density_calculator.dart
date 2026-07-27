import 'models/vision_analysis_region.dart';
import 'models/vision_region_density.dart';
import 'models/working_image.dart';
import 'residue_pixel_classifier.dart';

/// Calculates relative dark-pixel ratios without changing image data.
final class ResidueDensityCalculator {
  const ResidueDensityCalculator();

  List<VisionRegionDensity> calculate({
    required WorkingImage workingImage,
    required List<VisionAnalysisRegion> regions,
  }) {
    final classification = const ResiduePixelClassifier().classify(
      workingImage,
    );

    return List<VisionRegionDensity>.unmodifiable(
      regions.map((region) {
        return VisionRegionDensity(
          regionId: region.id,
          surfaceType: region.surfaceType,
          density: classification.densityFor(region.rect),
        );
      }),
    );
  }
}
