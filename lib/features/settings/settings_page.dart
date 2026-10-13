import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/layout/layout.dart';
import '../../ui/tokens.dart';
import '../onboarding/onboarding.dart';
import 'restart_banner.dart';
import 'setting_anchor.dart';
import 'settings_catalog.dart';
import 'settings_groups.dart';
import 'settings_scope.dart';
import 'settings_search.dart';

/// The full configuration, in four groups by purpose ([SettingsGroupId]).
/// Every control writes straight through to the live player; the
/// `AppSettings` observer records each change, so the configuration is
/// restored on the next launch.
///
/// Wide windows show the group list and the open group side by side; narrow
/// ones push the group over the list, and Android back closes it. The
/// search field finds a setting in any group by title, description and
/// keywords, and jumps to it. Settings the player reads only when it is
/// created raise the [RestartBanner].
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  SettingsGroupId? _open;
  final _focus = SettingsFocus();
  final _query = TextEditingController();
  final _searchField = FocusNode(debugLabel: 'settings search');

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    _query.dispose();
    _searchField.dispose();
    super.dispose();
  }

  void _openGroup(SettingsGroupId group) => setState(() => _open = group);

  void _close() => setState(() => _open = null);

  /// Opens [entry]'s group and reveals the row.
  void _reveal(SettingEntry entry) {
    setState(() => _open = entry.group);
    _focus.value = entry.id;
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScope.fromApp(
      context: context,
      showWelcome: showOnboarding,
      child: SettingsFocusScope(
        focus: _focus,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyF, control: true):
                _searchField.requestFocus,
            const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
                _searchField.requestFocus,
          },
          // Holds the keyboard focus when nothing inside has it, so the
          // shortcuts above work as soon as the page shows.
          child: Focus(autofocus: true, child: LayoutBuilder(builder: _layout)),
        ),
      ),
    );
  }

  Widget _layout(BuildContext context, BoxConstraints c) {
    final layout = context.layout;
    final body = c.maxWidth - layout.pagePadding.horizontal;
    final split = TwoPane.splitsAt(body.clamp(0, Breakpoints.wide));
    // Side by side, a group is always open; one at a time, the list shows
    // until the user picks one.
    final open = _open ?? (split ? SettingsGroupId.listening : null);
    final pushed = !split && open != null;
    final query = _query.text.trim();

    final list = Padding(
      padding: EdgeInsets.only(right: split ? layout.gap : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSearchField(controller: _query, focusNode: _searchField),
          const SizedBox(height: Tokens.s12),
          Expanded(
            child: query.isEmpty
                ? _GroupList(selected: split ? open : null, onOpen: _openGroup)
                : SettingsSearchResults(query: query, onOpen: _reveal),
          ),
        ],
      ),
    );

    final detail = open == null
        ? null
        : Padding(
            padding: EdgeInsets.only(left: split ? layout.gap : 0),
            child: _GroupDetail(
              key: ValueKey(open),
              group: open,
              heading: split,
            ),
          );

    return PageFrame(
      title: pushed ? open.title : 'Settings',
      onBack: pushed ? _close : null,
      scrollable: false,
      maxWidth: Breakpoints.wide,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RestartBanner(),
          Expanded(
            child: TwoPane(list: list, detail: detail, onCloseDetail: _close),
          ),
        ],
      ),
    );
  }
}

/// The four groups, each with its summary.
class _GroupList extends StatelessWidget {
  const _GroupList({required this.selected, required this.onOpen});

  /// The group shown beside the list, highlighted; null when one at a time.
  final SettingsGroupId? selected;
  final ValueChanged<SettingsGroupId> onOpen;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      child: ListView(
        padding: const EdgeInsets.only(bottom: Tokens.s24),
        children: [
          for (final g in SettingsGroupId.values)
            Padding(
              padding: const EdgeInsets.only(bottom: Tokens.s8),
              child: _GroupTile(
                group: g,
                selected: g == selected,
                pushes: selected == null,
                onTap: () => onOpen(g),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.group,
    required this.selected,
    required this.pushes,
    required this.onTap,
  });

  final SettingsGroupId group;
  final bool selected;

  /// Opening it covers the list (shows a chevron).
  final bool pushes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? Tokens.accentWash : Tokens.surface,
        shape: Tokens.squircle(Tokens.rMd),
        child: InkWell(
          onTap: onTap,
          customBorder: Tokens.squircle(Tokens.rMd),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: context.layout.minTap + 16),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Tokens.s16,
                vertical: Tokens.s12,
              ),
              child: Row(
                children: [
                  Icon(group.icon, size: 22, color: Tokens.accent),
                  const SizedBox(width: Tokens.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          group.title,
                          style: Tokens.heading.copyWith(
                            color: selected ? Tokens.accent : Tokens.fg,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          group.summary,
                          style: Tokens.label.copyWith(color: Tokens.fgDim),
                        ),
                      ],
                    ),
                  ),
                  if (pushes)
                    Icon(Icons.chevron_right_rounded, color: Tokens.fgFaint),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The section cards of one group, scrolling on their own. [heading] shows
/// the group's title on top (beside the list, where the page title says
/// "Settings").
class _GroupDetail extends StatelessWidget {
  const _GroupDetail({super.key, required this.group, required this.heading});

  final SettingsGroupId group;
  final bool heading;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: Tokens.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (heading)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Tokens.s4,
                  Tokens.s4,
                  Tokens.s4,
                  Tokens.s16,
                ),
                child: Semantics(
                  header: true,
                  child: Text(group.title, style: Tokens.heading),
                ),
              ),
            ...settingsSections(group),
          ],
        ),
      ),
    );
  }
}
