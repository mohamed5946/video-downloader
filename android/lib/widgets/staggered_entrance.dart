import 'dart:async';

import 'package:flutter/material.dart';

/// Staggered list entrance, mirroring DeliveryFlow's
/// `lib/theme/staggered_entrance.dart` (v27.30, from the reference video
/// Mohamed sent): items appear ONE BY ONE with fadeIn + slideY on
/// screen entry, and as they come into view while scrolling.
///
/// Rules (same as DeliveryFlow, adapted to SnapDL):
/// * Each item fades in and slides up from ~20% of its own height
///   ([_slideFraction]), with a stagger of [_stagger] per item.
/// * CAP: the delay is min(index, [_capIndex]) * [_stagger], so items
///   beyond the first screen never wait seconds — a long list stays
///   fast and scrolling never leaves items invisible.
/// * Entry-only: an item animates on its first mount inside a
///   [StaggeredScope] and is then marked seen, so data refreshes,
///   stream updates and scrolling back never re-trigger or flicker.
///   A fresh scope (screen/tab re-entry) replays the stagger. SnapDL
///   tabs remount through the AnimatedSwitcher in main.dart, so tab
///   switches replay automatically — no TabReplayScope needed here.
/// * Scroll-triggered: builder lists (history, log) mount items lazily
///   as they approach the viewport, so items animate in as Mohamed
///   scrolls — not only on first load.
/// * Reduce-motion: items appear immediately, no stagger.
/// * Cheap only: opacity + transform, no shader, no blur, 120fps-safe.
/// * No data/order/value/behaviour change — entrance animation only.
///
/// Timing matches SnapDL's existing 280ms AnimatedSwitcher easing.
class StaggeredScope extends StatefulWidget {
  const StaggeredScope({super.key, required this.child});

  final Widget child;

  static StaggeredScopeState? maybeOf(BuildContext context) {
    final inherited =
        context.dependOnInheritedWidgetOfExactType<_StaggeredInherited>();
    return inherited?.state;
  }

  @override
  State<StaggeredScope> createState() => StaggeredScopeState();
}

class StaggeredScopeState extends State<StaggeredScope> {
  final Set<int> _seen = {};

  bool isSeen(int index) => _seen.contains(index);

  void markSeen(int index) => _seen.add(index);

  @override
  Widget build(BuildContext context) {
    return _StaggeredInherited(state: this, child: widget.child);
  }
}

class _StaggeredInherited extends InheritedWidget {
  const _StaggeredInherited({required this.state, required super.child});

  final StaggeredScopeState state;

  @override
  bool updateShouldNotify(_StaggeredInherited old) => false;
}

/// Wrap an app's item list in this so all its items share the same
/// entrance behaviour (history, downloads, settings rows, log entries,
/// quality options).
class StaggeredList extends StatelessWidget {
  const StaggeredList({
    super.key,
    this.padding,
    required this.itemCount,
    required this.itemBuilder,
  });

  final EdgeInsetsGeometry? padding;
  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return StaggeredScope(
      child: ListView.builder(
        padding: padding,
        itemCount: itemCount,
        itemBuilder: (ctx, i) => StaggeredItem(
          index: i,
          child: itemBuilder(ctx, i) ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class StaggeredItem extends StatefulWidget {
  const StaggeredItem({super.key, required this.index, required this.child});

  /// Stagger per item, matching the video's 80ms interval.
  static const stagger = Duration(milliseconds: 80);

  /// Items at or beyond this index share the capped delay.
  static const capIndex = 7;

  /// Single-item animation length (SnapDL's 280ms easing).
  static const itemDuration = Duration(milliseconds: 280);

  /// Slide distance as a fraction of the item's own height
  /// (the video's slideY begin ~0.2).
  static const slideFraction = 0.2;

  /// Capped delay for [index] — the video's scrolling lesson.
  static Duration delayFor(int index) =>
      stagger * (index < capIndex ? index : capIndex);

  final int index;
  final Widget child;

  @override
  State<StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<StaggeredItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;
  Timer? _timer;
  bool _immediate = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: StaggeredItem.itemDuration,
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
  }

  void _play() {
    _immediate = false;
    _controller.reset();
    _timer?.cancel();
    _timer = Timer(StaggeredItem.delayFor(widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inherited lookups (MediaQuery, scope) are not allowed in
    // initState; this runs before the first build.
    if (_initialized) return;
    _initialized = true;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final scope = StaggeredScope.maybeOf(context);
    if (reduceMotion) {
      // Reduce-motion: appear immediately, never animate.
      _timer?.cancel();
      _immediate = true;
      return;
    }
    // Same scope already played this index (refresh / scroll-back):
    // appear immediately, never re-animate. A fresh scope (route
    // remount, tab re-entry) replays the entrance.
    if (scope != null && scope.isSeen(widget.index)) {
      _immediate = true;
      return;
    }
    scope?.markSeen(widget.index);
    _play();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_immediate) return widget.child;
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        final t = _progress.value;
        return Opacity(
          opacity: t,
          child: FractionalTranslation(
            translation: Offset(0, StaggeredItem.slideFraction * (1 - t)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
