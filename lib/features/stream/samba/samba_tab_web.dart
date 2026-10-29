import 'package:flutter/material.dart';

import '../stream_actions.dart';
import '../widgets/stream_states.dart';

/// The Samba tab in the browser, which cannot open a TCP connection to an
/// SMB server: a message in place of the sign-in form. The native tab
/// (samba_tab.dart) links dart_smb2, which needs dart:ffi.
class SambaTab extends StatelessWidget {
  const SambaTab({super.key, required this.actions});

  final StreamActions actions;

  @override
  Widget build(BuildContext context) {
    return const StreamMessage(
      icon: Icons.lan_outlined,
      title: 'Samba is not available in the browser',
      message:
          'A web page cannot connect to an SMB share. Open the files from '
          'the share through your system instead, with Add files.',
    );
  }
}
