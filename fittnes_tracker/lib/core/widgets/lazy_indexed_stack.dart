import 'package:flutter/material.dart';

/// An [IndexedStack] that builds a child only once its index has been
/// selected, and keeps it alive from then on.
///
/// A plain IndexedStack builds *every* child immediately, so the five tabs of
/// the trainee app all mounted and fired their database loads on the first
/// frame — including the Progress tab's history-wide aggregate query, for a
/// screen nobody was looking at. They contended with the dashboard's own
/// queries on drift's single background isolate and delayed first paint.
///
/// Children still stay mounted after the first visit, so switching tabs is
/// instant and screens that expose a `GlobalKey` for cross-tab refreshes keep
/// working. A key whose tab has never been opened simply resolves to null —
/// that screen loads current data when it is first mounted anyway.
class LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<WidgetBuilder> builders;

  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.builders,
  });

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  late final Set<int> _built = {widget.index};

  @override
  void didUpdateWidget(LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _built.add(widget.index);
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.builders.length; i++)
          _built.contains(i)
              ? widget.builders[i](context)
              : const SizedBox.shrink(),
      ],
    );
  }
}
