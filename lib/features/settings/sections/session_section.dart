import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/tokens.dart';
import '../../../ui/widgets/controls.dart';
import '../../../ui/widgets/reorder_proxy.dart';
import '../../../ui/widgets/section_body.dart';
import '../../../ui/widgets/section_header.dart';
import '../setting_anchor.dart';
import '../settings_catalog.dart';
import '../../../studio/app_settings.dart';
import '../settings_scope.dart';
import 'session_parts.dart';

/// Which controls MPV Studio advertises to the OS media session (lock
/// screen, Control Center, SMTC, MPRIS, Bluetooth). The shown set is
/// reorderable by drag; actions are added and removed with chips; the
/// skip-interval actions carry their own interval slider. How many controls
/// actually appear and where is up to each OS: the app only advertises the
/// capability set.
class SessionSection extends StatefulWidget {
  const SessionSection({super.key});

  @override
  State<SessionSection> createState() => _SessionSectionState();
}

class _SessionSectionState extends State<SessionSection> {
  // Read in didChangeDependencies, so a new scope (another player or
  // settings) is followed and the selection reloads from its settings.
  late SettingsScope _scope;
  late bool _on;
  late List<MediaAction> _shown;
  late int _ffSecs;
  late int _rwSecs;
  late InterruptionPolicy _interruption;
  AppSettings? _loadedFrom;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = SettingsScope.of(context);
    final settings = _scope.settings;
    if (identical(settings, _loadedFrom)) return;
    _loadedFrom = settings;
    _on = settings.sessionOn;
    _shown = settings.sessionActions;
    _ffSecs = settings.sessionFastForwardSecs;
    _rwSecs = settings.sessionRewindSecs;
    _interruption = settings.sessionInterruption;
  }

  // Actions the running OS's native media UI won't render (dimmed below).
  final Set<MediaAction> _unsupported = unsupportedSessionActions();
  final String _platform = sessionPlatformLabel();

  // Interruption handling is a real audio-session behaviour only on mobile.
  static final bool _interruptionSupported =
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  /// Advertised actions the running OS renders: the only ones in the
  /// reorderable "Shown controls" list (advertised order preserved).
  List<MediaAction> get _shownSupported => [
    for (final a in _shown)
      if (!_unsupported.contains(a)) a,
  ];

  /// Not yet advertised actions the OS renders: the "More actions" pool.
  List<MediaAction> get _availableSupported => [
    for (final a in MediaAction.values)
      if (!_shown.contains(a) && !_unsupported.contains(a)) a,
  ];

  /// Every action the OS won't render here, advertised or not, grouped on
  /// its own (toggling one adds it to or removes it from the set).
  List<MediaAction> get _allUnsupported => [
    for (final a in MediaAction.values)
      if (_unsupported.contains(a)) a,
  ];

  /// Applies [change] to the selection, then pushes it to the live player
  /// and persists it.
  void _edit(VoidCallback change) {
    setState(change);
    final settings = _scope.settings;
    _scope.run(
      () => _scope.player.setMediaSession(
        _on
            ? settings.composeMediaSession(
                _shown,
                fastForwardSecs: _ffSecs,
                rewindSecs: _rwSecs,
                interruptionPolicy: _interruption,
              )
            : null,
      ),
    );
    settings.recordSession(
      on: _on,
      actions: _shown,
      fastForwardSecs: _ffSecs,
      rewindSecs: _rwSecs,
      interruption: _interruption,
    );
  }

  void _enable(MediaAction a) => _edit(() => _shown = [..._shown, a]);
  void _disable(MediaAction a) => _edit(() => _shown = [..._shown]..remove(a));
  void _toggle(MediaAction a) => _shown.contains(a) ? _disable(a) : _enable(a);

  // The reorderable list shows only [_shownSupported], so its indices are
  // into that subset. Reorder them, then rebuild [_shown] as the reordered
  // supported actions followed by the (not drawn, order-irrelevant)
  // unsupported ones.
  void _reorder(int oldIndex, int newIndex) => _edit(() {
    final sup = _shownSupported;
    sup.insert(newIndex, sup.removeAt(oldIndex));
    _shown = [
      ...sup,
      for (final a in _shown)
        if (_unsupported.contains(a)) a,
    ];
  });

  Widget _caption(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(Tokens.s4, 0, Tokens.s4, Tokens.s12),
    child: Text(text, style: Tokens.caption),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          label: SettingsSections.session,
          children: [
            SettingAnchor(
              entry: SettingsCatalog.sessionPublish,
              child: SwitchRow(
                label: SettingsCatalog.sessionPublish.title,
                subtitle: SettingsCatalog.sessionPublish.description,
                value: _on,
                onChanged: (v) => _edit(() => _on = v),
              ),
            ),
            SettingAnchor(
              entry: SettingsCatalog.sessionInterruption,
              child: SettingTile(
                title: SettingsCatalog.sessionInterruption.title,
                description: _interruptionSupported
                    ? SettingsCatalog.sessionInterruption.description
                    : 'Only on iOS and Android. $_platform leaves audio '
                          'routing to the OS',
                enabled: _on,
                below: InterruptionDropdown(
                  value: _interruption,
                  enabled: _on && _interruptionSupported,
                  onChanged: (p) => _edit(() => _interruption = p),
                ),
              ),
            ),
          ],
        ),
        // Editing the set while the session is off is meaningless: dim it.
        Opacity(
          opacity: _on ? 1 : 0.4,
          child: IgnorePointer(
            ignoring: !_on,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingAnchor(
                  entry: SettingsCatalog.sessionControls,
                  child: SectionHeader(SettingsCatalog.sessionControls.title),
                ),
                _caption(
                  'Capabilities advertised to the system. Drag to reorder; '
                  'each OS decides how many to show and where.',
                ),
                _shownList(),
                if (_availableSupported.isNotEmpty) ...[
                  const SizedBox(height: Tokens.s16),
                  const SectionHeader('More actions'),
                  Wrap(
                    spacing: Tokens.s8,
                    runSpacing: Tokens.s8,
                    children: [
                      for (final a in _availableSupported)
                        SessionActionChip(
                          action: a,
                          onTap: () => _enable(a),
                          unsupported: false,
                          platform: _platform,
                        ),
                    ],
                  ),
                ],
                if (_allUnsupported.isNotEmpty) ...[
                  const SizedBox(height: Tokens.s16),
                  SectionHeader('Not shown on $_platform'),
                  _caption(
                    "$_platform's media UI won't draw these, but you can "
                    'still advertise them; they may appear on your other '
                    'devices. Tap to toggle.',
                  ),
                  Wrap(
                    spacing: Tokens.s8,
                    runSpacing: Tokens.s8,
                    children: [
                      for (final a in _allUnsupported)
                        SessionActionChip(
                          action: a,
                          onTap: () => _toggle(a),
                          unsupported: true,
                          advertised: _shown.contains(a),
                          platform: _platform,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _shownList() {
    final shown = _shownSupported;
    if (shown.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: Tokens.s24),
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: Tokens.surface3,
          shape: Tokens.shape(Tokens.rMd),
        ),
        child: Text('No controls yet. Add some below.', style: Tokens.caption),
      );
    }
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      padding: EdgeInsets.zero,
      proxyDecorator: reorderProxy(
        shape: Tokens.shape(Tokens.rMd),
        inset: const EdgeInsets.only(bottom: Tokens.s8),
      ),
      onReorderItem: _reorder,
      children: [
        for (final (i, a) in shown.indexed)
          ShownActionTile(
            key: ValueKey(a),
            index: i,
            action: a,
            onRemove: () => _disable(a),
            intervalSecs: switch (a) {
              MediaAction.fastForward => _ffSecs,
              MediaAction.rewind => _rwSecs,
              _ => null,
            },
            onInterval: switch (a) {
              MediaAction.fastForward => (s) => _edit(() => _ffSecs = s),
              MediaAction.rewind => (s) => _edit(() => _rwSecs = s),
              _ => null,
            },
          ),
      ],
    );
  }
}
