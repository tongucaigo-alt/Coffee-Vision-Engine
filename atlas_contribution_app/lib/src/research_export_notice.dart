import 'package:flutter/material.dart';
import 'research_export.dart';

Future<void> showResearchExportFailure(
  BuildContext context,
  Object error, {
  Future<void> Function()? openPermissions,
}) async {
  final noPermission =
      error is ExportFailure && error.code == ExportFailureCode.noPermission;
  final open = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Paket kaydedilemedi'),
      content: Text(
        '${exportFailureMessage(error)}\n\n${noPermission ? 'Paylaşmak istediğin incelemeyi açıp araştırma iznini kontrol edebilirsin. Bu izin fal oluşturmak için gerekli değildir.' : 'Mevcut fotoğrafların ve kayıtların telefonda korunuyor.'}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Kapat'),
        ),
        if (noPermission && openPermissions != null)
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kayıt izinlerini aç'),
          ),
      ],
    ),
  );
  if (open == true && context.mounted) await openPermissions?.call();
}
