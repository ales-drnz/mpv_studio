import 'package:flutter/material.dart';

import '../ui/layout/layout.dart';
import '../ui/tokens.dart';
import 'playback_issues.dart';

/// What shows when the player could not start (at launch or on a restart):
/// the reason in plain words and a way to try again.
class StartupErrorView extends StatelessWidget {
  const StartupErrorView({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tokens.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: context.layout.pagePadding,
            child: ReadableWidth(
              maxWidth: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 40,
                    color: Tokens.red,
                  ),
                  const SizedBox(height: Tokens.s16),
                  Semantics(
                    header: true,
                    child: Text(
                      'The audio engine did not start',
                      style: Tokens.title,
                    ),
                  ),
                  const SizedBox(height: Tokens.s8),
                  Text(describeCallError(error), style: Tokens.body),
                  const SizedBox(height: Tokens.s24),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
