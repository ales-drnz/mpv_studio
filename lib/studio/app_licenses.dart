import 'package:flutter/foundation.dart';

const _libsmb2Notice =
    'dart_smb2 loads libsmb2, the SMB2 and SMB3 client library by Ronnie '
    'Sahlberg and its contributors (https://github.com/sahlberg/libsmb2), '
    'under the GNU Lesser General Public License, version 2.1 or later.\n\n'
    'The app ships the binary of the libsmb2-rN release of dart_smb2 '
    '(https://github.com/ales-drnz/dart_smb2/releases), which carries its '
    'license texts. libsmb2-scripts '
    '(https://github.com/ales-drnz/libsmb2-scripts), at the commit that '
    'release names, is its corresponding source.';

/// Registers what no package does: Flutter's license page does not list the
/// libsmb2 that dart_smb2 bundles on the native platforms.
void registerAppLicenses() {
  if (kIsWeb) return;
  LicenseRegistry.addLicense(
    () => Stream.value(
      const LicenseEntryWithLineBreaks(['libsmb2'], _libsmb2Notice),
    ),
  );
}
