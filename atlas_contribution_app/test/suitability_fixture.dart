import 'dart:io';
import 'dart:convert';
import 'package:atlas_contribution_app/src/photo_suitability.dart';
import 'package:atlas_contribution_app/src/photo_crop.dart';
import 'package:atlas_contribution_app/src/models.dart';

class SupportedSuitability extends PhotoSuitability {
  SupportedSuitability() : super(Directory.systemTemp);
  @override
  Future<Map<String, dynamic>> assess(
    File file,
    ContributionPhoto p, {
    bool retry = false,
  }) async => {
    'version': suitabilityVersion,
    'checksum': p.checksum,
    'surface': p.surface.name,
    'cropKey': jsonEncode((p.displayCrop ?? PhotoCrop.full).toJson()),
    'status': 'supported',
  };
}
