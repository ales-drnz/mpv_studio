import 'package:flutter/material.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/controls.dart';

/// Who the page is signed in to, as a labelled button beside the search:
/// it opens a menu with [action] (sign out, disconnect), instead of a bare
/// logout icon where a filter would be expected.
class AccountButton extends StatelessWidget {
  const AccountButton({
    super.key,
    required this.label,
    required this.action,
    required this.onAction,
    this.icon = Icons.account_circle_outlined,
  });

  /// What the session is with: a server, a share.
  final String label;

  /// The menu item that ends the session.
  final String action;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$label account',
      child: Builder(
        builder: (context) => OutlinedButton.icon(
          onPressed: onAction == null
              ? null
              : () async {
                  final box = context.findRenderObject() as RenderBox?;
                  final picked = await showStudioMenu<bool>(
                    context,
                    position: box?.localToGlobal(
                      box.size.bottomLeft(Offset.zero),
                    ),
                    title: label,
                    items: [
                      StudioMenuItem(
                        value: true,
                        label: action,
                        icon: Icons.logout_rounded,
                        destructive: true,
                      ),
                    ],
                  );
                  if (picked == true) onAction?.call();
                },
          icon: Icon(icon),
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          style: OutlinedButton.styleFrom(
            minimumSize: Size(0, controlHeightOf(context)),
            padding: const EdgeInsets.symmetric(horizontal: Tokens.s16),
          ),
        ),
      ),
    );
  }
}
