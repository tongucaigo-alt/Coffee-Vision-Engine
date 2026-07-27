import 'dart:async';

import 'package:coffee_vision/coffee_vision.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const CoffeeVisionDemoApp());
}

class CoffeeVisionDemoApp extends StatelessWidget {
  const CoffeeVisionDemoApp({super.key, this.restoreLostData = true});

  final bool restoreLostData;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coffee Vision Density Debug',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        useMaterial3: true,
      ),
      home: DensityDebugScreen(restoreLostData: restoreLostData),
    );
  }
}

class DensityDebugScreen extends StatefulWidget {
  const DensityDebugScreen({super.key, required this.restoreLostData});

  final bool restoreLostData;

  @override
  State<DensityDebugScreen> createState() => _DensityDebugScreenState();
}

class _DensityDebugScreenState extends State<DensityDebugScreen> {
  final ImagePicker _picker = ImagePicker();
  final CoffeeVisionEngine _engine = const CoffeeVisionEngine();

  VisionSurfaceType _surfaceType = VisionSurfaceType.cup;
  Uint8List? _selectedBytes;
  String? _selectedFileName;
  String? _selectedSourceId;
  WorkingImage? _workingImage;
  List<VisionRegionDensity>? _densities;
  String? _errorMessage;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    if (widget.restoreLostData) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_recoverLostData());
      });
    }
  }

  Future<void> _recoverLostData() async {
    _setBusy(true);
    try {
      final response = await _picker.retrieveLostData();
      if (!mounted) return;
      if (response.isEmpty) {
        _setBusy(false);
        return;
      }
      if (response.exception case final exception?) {
        _showError(_describeError(exception));
        return;
      }
      final files = response.files;
      if (files == null || files.isEmpty) {
        _setBusy(false);
        return;
      }
      await _loadSelectedImage(files.first);
    } catch (error) {
      _showError(_describeError(error));
    }
  }

  Future<void> _pickImage() async {
    _setBusy(true);
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      if (!mounted) return;
      if (file == null) {
        _setBusy(false);
        return;
      }
      await _loadSelectedImage(file);
    } catch (error) {
      _showError(_describeError(error));
    }
  }

  Future<void> _loadSelectedImage(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw const FormatException('Seçilen görsel dosyası boş.');
      }
      if (!mounted) return;
      setState(() {
        _selectedBytes = bytes;
        _selectedFileName = file.name;
        _selectedSourceId = file.path;
        _workingImage = null;
        _densities = null;
        _errorMessage = null;
        _isBusy = false;
      });
    } catch (error) {
      _showError(_describeError(error));
    }
  }

  Future<void> _analyze() async {
    final bytes = _selectedBytes;
    if (bytes == null || _isBusy) return;

    setState(() {
      _isBusy = true;
      _workingImage = null;
      _densities = null;
      _errorMessage = null;
    });

    try {
      final input = VisionImageInput(
        imageBytes: bytes,
        surfaceType: _surfaceType,
        sourceId: _selectedSourceId,
      );
      final workingImage = await _engine.prepareWorkingImage(input);
      final densities = await _engine.analyzeRegionDensities(
        workingImage: workingImage,
        surfaceType: _surfaceType,
      );
      if (!mounted) return;
      setState(() {
        _workingImage = workingImage;
        _densities = densities;
        _isBusy = false;
      });
    } catch (error) {
      _showError(_describeError(error));
    }
  }

  void _changeSurface(Set<VisionSurfaceType> selection) {
    setState(() {
      _surfaceType = selection.first;
      _workingImage = null;
      _densities = null;
      _errorMessage = null;
    });
  }

  void _setBusy(bool value) {
    if (!mounted) return;
    setState(() {
      _isBusy = value;
      if (value) _errorMessage = null;
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _errorMessage = message;
    });
  }

  String _describeError(Object error) {
    if (error is FormatException) {
      return 'Görsel işlenemedi. Yalnızca geçerli PNG veya JPEG kullanın. '
          '${error.message}';
    }
    if (error is PlatformException) {
      return 'Galeri açılamadı: ${error.message ?? error.code}';
    }
    if (error is ArgumentError) {
      return 'Geçersiz görsel verisi: ${error.message}';
    }
    return 'İşlem tamamlanamadı: $error';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coffee Vision Density Debug')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<VisionSurfaceType>(
                    segments: const [
                      ButtonSegment(
                        value: VisionSurfaceType.cup,
                        icon: Icon(Icons.coffee_outlined),
                        label: Text('Fincan'),
                      ),
                      ButtonSegment(
                        value: VisionSurfaceType.saucer,
                        icon: Icon(Icons.dinner_dining_outlined),
                        label: Text('Tabak'),
                      ),
                    ],
                    selected: {_surfaceType},
                    onSelectionChanged: _isBusy ? null : _changeSurface,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isBusy ? null : _pickImage,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galeriden Seç'),
                  ),
                  const SizedBox(height: 12),
                  _buildPreview(context),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _selectedBytes == null || _isBusy
                        ? null
                        : _analyze,
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text('Analiz Et'),
                  ),
                  if (_isBusy) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                  if (_errorMessage case final message?) ...[
                    const SizedBox(height: 16),
                    _buildError(context, message),
                  ],
                  if (_workingImage case final workingImage?) ...[
                    const SizedBox(height: 16),
                    _buildResults(workingImage),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final bytes = _selectedBytes;
    if (bytes == null) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: const Text('Görsel seçilmedi'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 240,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ColoredBox(
              color: Colors.black12,
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                cacheWidth: 1024,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(child: Text('Önizleme gösterilemedi'));
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _selectedFileName ?? 'Bilinmeyen dosya',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, String message) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colors.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(WorkingImage workingImage) {
    final densityByRegion = {
      for (final result in _densities ?? const <VisionRegionDensity>[])
        result.regionId: result.density,
    };
    final contentRect = workingImage.contentRect;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Analiz sonucu',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _resultRow('Dosya', _selectedFileName ?? '-'),
            _resultRow('Yüzey', _surfaceType.name),
            _resultRow(
              'Kaynak',
              '${workingImage.sourceMetadata.format.name.toUpperCase()} '
                  '${workingImage.sourceMetadata.width}x'
                  '${workingImage.sourceMetadata.height}',
            ),
            _resultRow(
              'Working image',
              '${workingImage.workingMetadata.width}x'
                  '${workingImage.workingMetadata.height}',
            ),
            _resultRow(
              'contentRect',
              '${contentRect.left.toStringAsFixed(4)}, '
                  '${contentRect.top.toStringAsFixed(4)}, '
                  '${contentRect.right.toStringAsFixed(4)}, '
                  '${contentRect.bottom.toStringAsFixed(4)}',
            ),
            const Divider(height: 24),
            for (final regionId in VisionRegionId.values)
              _resultRow(
                regionId.name,
                (densityByRegion[regionId] ?? 0.0).toStringAsFixed(4),
              ),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
