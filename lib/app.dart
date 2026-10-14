import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/onboarding/onboarding.dart';
import 'shell/router.dart';
import 'studio/mpv_studio.dart';
import 'studio/player_scope.dart';
import 'studio/startup_error_view.dart';
import 'studio/studio_host.dart';
import 'studio/uncaught_errors.dart';
import 'ui/layout/layout.dart';
import 'ui/theme.dart';
import 'ui/theme_host.dart';
import 'ui/tokens.dart';

/// Root widget. Renders the running [MpvStudio]: exposes it to the tree via
/// [PlayerScope], applies the persisted theme ([StudioThemeHost]) and the
/// responsive layout ([LayoutScope], [DebugViewport]), swaps it for a new
/// one on an in-app player restart ([StudioHost]), opens the welcome
/// screen on the first launch, and shuts the studio down on process exit.
class MpvStudioApp extends StatefulWidget {
  final MpvStudio studio;

  /// The uncaught error handlers, pointed at each new studio.
  final UncaughtErrors? errors;

  const MpvStudioApp({super.key, required this.studio, this.errors});

  @override
  State<MpvStudioApp> createState() => _MpvStudioAppState();
}

class _MpvStudioAppState extends State<MpvStudioApp> {
  late MpvStudio _studio = widget.studio;
  GoRouter _router = createAppRouter();

  late final _theme = ThemeController(
    initial: widget.studio.settings.themeMode,
    onChanged: (mode) => _studio.settings.recordThemeMode(mode),
  );

  // Dock-Quit / ⌘Q call NSApplication terminate: without unwinding the widget
  // tree, so State.dispose never runs before the engine tears down.
  // onExitRequested is the hook that does fire there: kick the player shutdown
  // off best-effort and allow the exit immediately (see _onExitRequested).
  late final AppLifecycleListener _exitGate;

  @override
  void initState() {
    super.initState();
    _exitGate = AppLifecycleListener(
      onExitRequested: _onExitRequested,
      onDetach: () => unawaited(_teardown()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _welcome());
  }

  /// Opens the welcome screen on the first launch.
  void _welcome() {
    if (!mounted) return;
    final context = _router.routerDelegate.navigatorKey.currentContext;
    if (context == null) return;
    unawaited(
      welcomeOnFirstLaunch(
        context,
        _studio.settings,
        OnboardingActions.of(context),
      ),
    );
  }

  // Bounded so a wedged shutdown can never itself block quit. Repeat
  // lifecycle signals share the studio's single shutdown.
  Future<void> _teardown() =>
      _studio.shutdown().timeout(const Duration(seconds: 3), onTimeout: () {});

  // onExitRequested is a DECISION point, not a teardown hook: return
  // AppExitResponse.exit promptly so the engine answers the OS quit Apple
  // Event with .exit instead of NSTerminateCancel-then-re-terminate. Awaiting
  // the teardown is what holds this Future pending and trips macOS's "App is
  // preventing your computer from shutting down" panel: the mpv core and
  // CoreAudio device are pure resource reclamation the OS frees on process
  // exit, so the teardown runs best-effort (also fired from onDetach).
  Future<AppExitResponse> _onExitRequested() async {
    unawaited(_teardown());
    return AppExitResponse.exit;
  }

  /// A new studio replaced the old one: a fresh router on the same page
  /// (its navigators belong to the old tree), and the error handlers
  /// pointed at the new studio.
  void _onStudio(MpvStudio studio) {
    final location = _router.routerDelegate.currentConfiguration.uri;
    final old = _router;
    setState(() {
      _studio = studio;
      _router = createAppRouter()..go(location.toString());
    });
    widget.errors?.target = studio;
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  @override
  void dispose() {
    _exitGate.dispose();
    _theme.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StudioThemeHost(
      controller: _theme,
      builder: (context, palette) => StudioHost<MpvStudio>(
        initial: widget.studio,
        restart: (studio) => studio.restart(),
        launch: MpvStudio.launch,
        onChanged: _onStudio,
        // The old studio's tree is taken down before it shuts down, so
        // this screen, which reads no studio, stands in meanwhile.
        busyBuilder: (context) => MaterialApp(
          title: 'MPV Studio',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.of(palette, input: InputMode.platformDefault),
          builder: (context, child) => LayoutScope(child: child!),
          home: const _RestartingView(),
        ),
        errorBuilder: (context, error, retry) => MaterialApp(
          title: 'MPV Studio',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.of(palette, input: InputMode.platformDefault),
          builder: (context, child) => LayoutScope(child: child!),
          home: StartupErrorView(error: error, onRetry: retry),
        ),
        // PlayerScope sits ABOVE MaterialApp so the routed pages (which live
        // under MaterialApp's Navigator) can still read the studio's
        // services.
        builder: (context, studio, restart) => PlayerScope(
          studio: studio,
          onRestart: restart.run,
          child: MaterialApp.router(
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
      ),
    );
  }
}

/// Stands in for the app while the player restarts: the old player's
/// tree is gone and the new one is not built yet.
class _RestartingView extends StatelessWidget {
  const _RestartingView();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Tokens.bg,
      child: Center(
        child: Semantics(
          liveRegion: true,
          child: Material(
            color: Tokens.surface2,
            shape: Tokens.shape(Tokens.rMd),
            child: Padding(
              padding: const EdgeInsets.all(Tokens.s24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Tokens.accent,
                    ),
                  ),
                  const SizedBox(width: Tokens.s12),
                  Text('Restarting the player', style: Tokens.body),
                ],
              ),
            ),
          ),
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
