import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../generated/filter_catalog.dart';
import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/round_icon_button.dart';
import '../../../ui/widgets/section_header.dart';
import '../rack_catalog.dart';
import '../rack_controller.dart';

/// The featured effects as pill chips, one tap from their editor: wrapped
/// over as many lines as they need on wide windows, a scrolling row on
/// compact ones or with [singleRow], faded at the edge that has more and
/// with arrows on pointer while some chips are out of view.
/// A chip is filled while the chain has that effect switched on.
class QuickEditors extends StatelessWidget {
  final RackController rack;

  /// Opens the first stage of the filter, adding one when there is none.
  final ValueChanged<AudioFilter> onOpen;

  /// Keeps the chips on one scrolling line at any width, to leave the
  /// height to an editor below.
  final bool singleRow;

  const QuickEditors({
    super.key,
    required this.rack,
    required this.onOpen,
    this.singleRow = false,
  });

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final chips = [
      for (final d in kFeaturedCatalog)
        _QuickChip(
          d: d,
          active: rack.chain.stages.any(
            (s) => s.effect.filter == d.filter && s.effect.enabled,
          ),
          onTap: () => onOpen(d.filter),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Quick editors'),
        if (layout.isCompact || singleRow)
          _ScrollingRow(height: layout.minTap, children: chips)
        else
          Wrap(spacing: Tokens.s8, runSpacing: Tokens.s8, children: chips),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  final FilterDescriptor d;
  final bool active;
  final VoidCallback onTap;
  const _QuickChip({
    required this.d,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? Tokens.onAccentContainer : Tokens.fg;
    return Tooltip(
      message: kFeaturedSubtitles[d.filter] ?? d.title,
      child: Semantics(
        button: true,
        toggled: active,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: ValueKey('quick-${d.name}'),
            onTap: onTap,
            customBorder: Tokens.pill,
            child: Ink(
              height: context.layout.minTap,
              padding: const EdgeInsets.fromLTRB(Tokens.s12, 0, Tokens.s16, 0),
              decoration: ShapeDecoration(
                color: active ? Tokens.accentContainer : Tokens.surface,
                shape: Tokens.pill,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(d.icon, size: 18, color: fg),
                  const SizedBox(width: Tokens.s8),
                  Text(
                    d.title,
                    style: Tokens.label.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                    ),
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

/// A horizontal row that scrolls, fading out at the edge where more chips
/// wait, with arrow buttons at the edges when a pointer drives it.
class _ScrollingRow extends StatefulWidget {
  final double height;
  final List<Widget> children;
  const _ScrollingRow({required this.height, required this.children});

  @override
  State<_ScrollingRow> createState() => _ScrollingRowState();
}

class _ScrollingRowState extends State<_ScrollingRow> {
  final _scroll = ScrollController();
  bool _more = true;
  bool _less = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_sync);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  void _sync() {
    if (!mounted || !_scroll.hasClients) return;
    final p = _scroll.position;
    final more = p.pixels < p.maxScrollExtent - 1;
    final less = p.pixels > 1;
    if (more != _more || less != _less) {
      setState(() {
        _more = more;
        _less = less;
      });
    }
  }

  void _page(int direction) {
    final p = _scroll.position;
    _scroll.animateTo(
      (p.pixels + direction * p.viewportDimension * 0.7).clamp(
        0,
        p.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pointer = context.layout.isPointer;
    final row = SizedBox(
      height: widget.height,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => LinearGradient(
          colors: [
            _less ? Colors.transparent : Colors.black,
            Colors.black,
            Colors.black,
            _more ? Colors.transparent : Colors.black,
          ],
          stops: const [0, 0.08, 0.92, 1],
        ).createShader(rect),
        // A resize or rotation changes what is hidden without a scroll.
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: (_) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
            return false;
          },
          child: ListView.separated(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            itemCount: widget.children.length,
            separatorBuilder: (_, _) => const SizedBox(width: Tokens.s8),
            itemBuilder: (_, i) => widget.children[i],
          ),
        ),
      ),
    );
    // Every chip in view: no arrows to offer.
    if (!pointer || (!_less && !_more)) return row;
    Widget arrow(IconData icon, String tip, int direction, bool shown) =>
        // Dimmed at the end it cannot go past, keeping its place.
        Opacity(
          opacity: shown ? 1 : 0.4,
          child: ExcludeSemantics(
            excluding: !shown,
            child: RoundIconButton(
              icon: icon,
              size: 20,
              tooltip: tip,
              onTap: shown ? () => _page(direction) : null,
            ),
          ),
        );
    return Row(
      // Both arrows after the chips, so the row starts under its label.
      children: [
        Expanded(child: row),
        const SizedBox(width: Tokens.s4),
        arrow(Icons.chevron_left_rounded, 'Scroll back', -1, _less),
        arrow(Icons.chevron_right_rounded, 'More quick editors', 1, _more),
      ],
    );
  }
}
