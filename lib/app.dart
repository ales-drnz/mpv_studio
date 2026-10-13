import 'dart:async';
import 'dart:ui' show AppExitResponse;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

import 'shell/router.dart';
import 'studio/mpv_studio.dart';
import 'studio/player_scope.dart';
import 'ui/layout/layout.dart';
import 'ui/theme.dart';
import 'ui/theme_host.dart';

/// Root widget. Renders the running [MpvStudio]: exposes it to the tree via
/// [PlayerScope], applies the persisted theme ([StudioThemeHost]) and the
/// responsive layout ([LayoutScope], [DebugViewport]), and shuts the
/// studio down on process exit.
class MpvStudioApp extends StatefulWidget {
  final MpvStudio studio;
  const MpvStudioApp({super.key, required this.studio});

  @override
  State<MpvStudioApp> createState() => _MpvStudioAppState();
}

class _MpvStudioAppState extends State<MpvStudioApp> {
  late final _router = createAppRouter();
  late final _theme = ThemeController(
    initial: widget.studio.settings.themeMode,
    onChanged: widget.studio.settings.recordThemeMode,
  );

  // Dock-Quit / ⌘Q call NSApplication terminate: without unwinding the widget
  // tree, so State.dispose never runs before the engine tears down.
  // onExitRequested is the hook that does fire there: kick the player shutdown
  // off best-effort and allow the exit immediately (see _onExitRequested).
  late final AppLifecycleListener _exitGate;
  Future<void>? _inFlight;

  @override
  void initState() {
    super.initState();
    _exitGate = AppLifecycleListener(
      onExitRequested: _onExitRequested,
      onDetach: () => unawaited(_teardown()),
    );
  }

  // Single cached teardown future so repeat lifecycle signals all await the
  // same shutdown; bounded so a wedged shutdown can never itself block quit.
  Future<void> _teardown() => _inFlight ??= widget.studio.shutdown().timeout(
    const Duration(seconds: 3),
    onTimeout: () {},
  );

  // onExitRequested is a DECISION point, not a teardown hook: return
  // AppExitResponse.exit promptly so the engine answers the OS quit Apple
  // Event with .exit instead of NSTerminateCancel-then-re-terminate. Awaiting
  // the teardown is what holds this Future pending and trips macOS's "App is
  // preventing your computer from shutting down" panel — the mpv core +
  // CoreAudio device are pure resource reclamation the OS frees on process
  // exit, so the teardown runs best-effort (also fired from onDetach).
  Future<AppExitResponse> _onExitRequested() async {
    unawaited(_teardown());
    return AppExitResponse.exit;
  }

  @override
  void dispose() {
    _exitGate.dispose();
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // PlayerScope sits ABOVE MaterialApp so the routed pages (which live
    // under MaterialApp's Navigator) can still read the studio's services.
    return PlayerScope(
      studio: widget.studio,
      child: StudioThemeHost(
        controller: _theme,
        builder: (context, palette) => MaterialApp.router(
          title: 'MPV Studio',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.of(palette, input: InputMode.platformDefault),
          // The palette switches at once everywhere else, so the Material
          // theme must not cross-fade behind it.
          themeAnimationDuration: Duration.zero,
          // Let the mouse click-and-drag to scroll on desktop, like touch
          // does: Flutter leaves the mouse out of the default drag devices.
          scrollBehavior: const _DragScrollBehavior(),
          routerConfig: _router,
          // Above the navigator, so pages, dialogs and sheets all share the
          // layout (and the debug viewport, when one is defined).
          builder: (context, child) =>
              DebugViewport(child: LayoutScope(child: child!)),
        ),
      ),
    );
  }
}

/// Adds the mouse (and the rest) to the scroll drag devices so lists scroll on
/// click-drag on desktop, not just with the wheel/trackpad.
class _DragScrollBehavior extends MaterialScrollBehavior {
  const _DragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.unknown,
  };
}
