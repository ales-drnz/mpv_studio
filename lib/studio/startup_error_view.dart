import 'package:flutter/material.dart';

import '../ui/layout/layout.dart';
import '../ui/tokens.dart';
import 'playback_issues.dart';

/// What shows when the player could not start (at launch or on a restart):
/// the reason in plain words and a way to try again. A browser that cannot
/// run the engine ([unsupported]) gets its reason and where the app runs
/// instead, without a retry that could only fail the same way.
class StartupErrorView extends StatelessWidget {
  const StartupErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.unsupported = false,
  });

  final Object error;

  /// Tries again; null where trying again cannot help.
  final VoidCallback? onRetry;

  /// Whether [error] is the browser's reason it cannot run the engine.
  final bool unsupported;

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
                    unsupported
                        ? Icons.web_asset_off_rounded
                        : Icons.error_outline_rounded,
                    size: Tokens.s40,
                    color: Tokens.red,
                  ),
                  const SizedBox(height: Tokens.s16),
                  Semantics(
                    header: true,
                    child: Text(
                      unsupported
                          ? 'This browser cannot run the audio engine'
                          : 'The audio engine did not start',
                      style: Tokens.title,
                    ),
                  ),
                  const SizedBox(height: Tokens.s8),
                  Text(
                    unsupported ? '$error' : describeCallError(error),
                    style: Tokens.body,
                  ),
                  if (unsupported) ...[
                    const SizedBox(height: Tokens.s8),
                    Text(
                      'MPV Studio runs libmpv as WebAssembly on its own '
                      'threads. Open it in a recent Chrome, Edge or Firefox.',
                      style: Tokens.body.copyWith(color: Tokens.fgDim),
                    ),
                  ],
                  if (onRetry case final retry?) ...[
                    const SizedBox(height: Tokens.s24),
                    FilledButton.icon(
                      onPressed: retry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
