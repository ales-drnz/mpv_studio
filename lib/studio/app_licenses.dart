import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _libsmb2Notice =
    'dart_smb2 loads libsmb2, the SMB2 and SMB3 client library by Ronnie '
    'Sahlberg and its contributors (https://github.com/sahlberg/libsmb2), '
    'under the GNU Lesser General Public License, version 2.1 or later.\n\n'
    'The app ships the binary of the libsmb2-rN release of dart_smb2 '
    '(https://github.com/ales-drnz/dart_smb2/releases), which carries its '
    'license texts. libsmb2-scripts '
    '(https://github.com/ales-drnz/libsmb2-scripts), at the commit that '
    'release names, is its corresponding source.';

const _opensslNotice =
    'libsmb2 signs and encrypts through libcrypto from OpenSSL '
    '(https://www.openssl.org), linked into the libsmb2 binary and '
    'distributed under the Apache License, Version 2.0, whose text follows.';

const _robotoMonoNotice =
    'Roboto Mono, by Christian Robertson and the Roboto Mono authors '
    '(https://github.com/googlefonts/RobotoMono), is bundled under the '
    'Apache License, Version 2.0, whose text follows.';

/// Registers what no package does: Flutter's license page does not list the
/// Roboto Mono font the app bundles, nor the libsmb2 that dart_smb2
/// bundles on the native platforms, with OpenSSL's libcrypto inside it.
void registerAppLicenses() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(
      'assets/fonts/LICENSE-RobotoMono.txt',
    );
    yield LicenseEntryWithLineBreaks([
      'Roboto Mono',
    ], '$_robotoMonoNotice\n\n$text');
  });
  if (kIsWeb) return;
  LicenseRegistry.addLicense(
    () => Stream.value(
      const LicenseEntryWithLineBreaks(['libsmb2'], _libsmb2Notice),
    ),
  );
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(
      'assets/licenses/LICENSE-OpenSSL.txt',
    );
    yield LicenseEntryWithLineBreaks(['OpenSSL'], '$_opensslNotice\n\n$text');
  });
}
