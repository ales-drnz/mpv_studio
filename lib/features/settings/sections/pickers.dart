import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

/// Asks for a folder; null when cancelled or when the platform has no
/// folder picker.
Future<String?> pickFolder() async {
  try {
    return await getDirectoryPath();
  } on Object catch (e) {
    debugPrint('Folder picker unavailable: $e');
    return null;
  }
}

/// Asks for a certificate bundle file; null when cancelled.
Future<String?> pickCertificateFile() async {
  const group = XTypeGroup(
    label: 'Certificates',
    extensions: ['pem', 'crt', 'cer'],
    uniformTypeIdentifiers: ['public.x509-certificate', 'public.data'],
  );
  try {
    final file = await openFile(acceptedTypeGroups: const [group]);
    return file?.path;
  } on Object catch (e) {
    debugPrint('File picker unavailable: $e');
    return null;
  }
}
