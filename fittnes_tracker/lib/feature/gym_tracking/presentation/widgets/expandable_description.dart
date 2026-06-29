import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class ExpandableDescription extends StatefulWidget {
  final String description;
  final TextStyle? style;
  final TextAlign textAlign;
  final int threshold;

  const ExpandableDescription({
    super.key,
    required this.description,
    this.style,
    this.textAlign = TextAlign.start,
    this.threshold = 100,
  });

  @override
  State<ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<ExpandableDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLong = widget.description.length > widget.threshold;
    final displayText = isLong && !_expanded
        ? '${widget.description.substring(0, widget.threshold)}…'
        : widget.description;

    return Column(
      crossAxisAlignment: widget.textAlign == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          displayText,
          style: widget.style,
          textAlign: widget.textAlign,
        ),
        if (isLong)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded
                  ? AppLocalizations.of(context)!.showLess
                  : AppLocalizations.of(context)!.showMore,
              style: theme.textTheme.bodySmall?.copyWith(
                color: widget.style?.color ?? theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: widget.style?.color ?? theme.colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }
}
