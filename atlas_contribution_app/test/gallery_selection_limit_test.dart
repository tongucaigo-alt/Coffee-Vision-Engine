import 'dart:io';
import 'dart:typed_data';

import 'package:atlas_contribution_app/src/gallery_import.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'photo_set_test.dart' show SetPicker, setDraft, setImage;

class _File extends XFile {
  _File() : super('not-read-from-disk.png');
  int reads = 0;
  @override
  Future<Uint8List> readAsBytes() async {
    reads++;
    return Uint8List.fromList([1, 2, 3]);
  }
}

class _NativePicker extends ImagePicker {
  List<_File> files = [];
  int? limit;
  int singleCalls = 0;
  int multipleCalls = 0;
  bool? metadata;
  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    multipleCalls++;
    this.limit = limit;
    metadata = requestFullMetadata;
    return files;
  }

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    expect(source, ImageSource.gallery);
    singleCalls++;
    return files.firstOrNull;
  }

  @override
  Future<LostDataResponse> retrieveLostData() async =>
      LostDataResponse(files: files, type: RetrieveType.image);
}

class _Store extends DraftStore {
  _Store(super.directory);
  int imports = 0;
  @override
  Future<ContributionPhoto> importGallery(Uint8List input) {
    imports++;
    return super.importGallery(input);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final capError = isA<GallerySelectionLimit>();

  for (final limit in [3, 2]) {
    test('native picker receives cap $limit before reading images', () async {
      final native = _NativePicker()
        ..files = [for (var i = 0; i < limit; i++) _File()];
      final selected = await AndroidGalleryPicker(
        imagePicker: native,
      ).pickMany(limit: limit);
      expect(native.limit, limit);
      expect(native.metadata, false);
      expect(selected, hasLength(limit));
      expect(native.files.every((f) => f.reads == 1), true);
    });
  }

  test('one remaining cup and saucer use a single-image picker', () async {
    final native = _NativePicker()..files = [_File()];
    final picker = AndroidGalleryPicker(imagePicker: native);
    expect(await picker.pickMany(limit: 1), hasLength(1));
    expect(await picker.pick(), isNotNull);
    expect(native.singleCalls, 2);
    expect(native.multipleCalls, 0);
  });

  for (final count in [4, 7]) {
    for (final recovery in [false, true]) {
      test('rejects $count files before reads, recovery=$recovery', () async {
        final native = _NativePicker()
          ..files = [for (var i = 0; i < count; i++) _File()];
        final picker = AndroidGalleryPicker(imagePicker: native);
        await expectLater(
          recovery ? picker.recoverMany() : picker.pickMany(),
          throwsA(capError),
        );
        expect(native.files.every((f) => f.reads == 0), true);
      });
    }
  }

  test(
    'recovered saucer or replacement rejects multiple images before reads',
    () async {
      final native = _NativePicker()..files = [_File(), _File()];
      await expectLater(
        AndroidGalleryPicker(imagePicker: native).recover(),
        throwsA(capError),
      );
      expect(native.files.every((f) => f.reads == 0), true);
    },
  );

  late Directory root;
  late _Store store;
  late SetPicker picker;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('atlas-gallery-cap-');
    store = _Store(root);
    await store.initialize();
    picker = SetPicker();
  });
  tearDown(() => root.delete(recursive: true));

  test(
    'existing cups reduce the cap and a full set never opens the picker',
    () async {
      final importer = PhotoSetGallery(store, picker);
      var draft = setDraft();
      await store.save(draft);
      picker.items = [setImage(0)];
      draft = (await importer.select(draft))!;
      expect(picker.requestedLimit, 3);
      picker.items = [setImage(1)];
      draft = (await importer.select(draft))!;
      expect(picker.requestedLimit, 2);
      picker.items = [setImage(2)];
      draft = (await importer.select(draft))!;
      expect(picker.singleCalls, 1);
      expect(picker.multipleCalls, 2);
      expect(draft.cups, hasLength(3));
      await expectLater(importer.select(draft), throwsA(capError));
      expect(picker.singleCalls + picker.multipleCalls, 3);
      expect((await store.load())!.toJson(), draft.toJson());

      // Saucer has its own slot even after all three cup slots have been used.
      picker.items = [setImage(3)];
      draft = (await importer.select(draft, surface: PhotoSurface.saucer))!;
      expect(draft.cups, hasLength(3));
      expect(draft.saucers, hasLength(1));
      expect(picker.singleCalls, 2);
      await expectLater(
        importer.select(draft, surface: PhotoSurface.saucer),
        throwsA(capError),
      );
      // Replacement keeps that single slot and uses the same single-image picker.
      picker.items = [setImage(4)];
      final replaced = (await importer.select(
        draft,
        surface: PhotoSurface.saucer,
        replaceId: draft.saucers.single.id,
      ))!;
      expect(replaced.saucers.single.id, draft.saucers.single.id);
      expect(
        replaced.cups.map((p) => p.toJson()),
        draft.cups.map((p) => p.toJson()),
      );
      expect(picker.singleCalls, 3);
    },
  );

  for (final count in [4, 7]) {
    for (final recovery in [false, true]) {
      test(
        'oversized batch $count preserves draft/files, recovery=$recovery',
        () async {
          var draft = setDraft();
          await store.save(draft);
          picker.items = [setImage(0)];
          draft = (await PhotoSetGallery(store, picker).select(draft))!;
          final original = await store
              .file(draft.cups.single.localName)
              .readAsBytes();
          final names = root.listSync().map((f) => f.path).toSet();
          store.imports = 0;
          // Deliberately invalid images prove that count is checked before decoding.
          picker.items = [for (var i = 0; i < count; i++) Uint8List(1)];
          if (recovery) {
            await store.saveSetGalleryPending({
              'operation': 'photoSet',
              'draft': draft.toJson(),
              'surface': 'cup',
              'replaceId': null,
            });
          }
          await expectLater(
            recovery
                ? GalleryImport(store, picker).recover()
                : PhotoSetGallery(store, picker).select(draft),
            throwsA(capError),
          );
          expect(store.imports, 0);
          expect((await store.load())!.toJson(), draft.toJson());
          expect(
            await store.file(draft.cups.single.localName).readAsBytes(),
            original,
          );
          expect(root.listSync().map((f) => f.path).toSet(), names);
          expect((await store.galleryPending())?['draft'], isNull);
        },
      );
    }
  }
}
