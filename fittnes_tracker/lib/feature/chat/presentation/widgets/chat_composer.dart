import 'package:flutter/material.dart';

import 'package:ForgeForm/core/design_tokens.dart';

/// The message input: attachment affordance, pill field, circular orange send.
///
/// Owns its own [TextEditingController] because the draft is screen state, not
/// shared client data — a half-typed message has no business in ChatProvider.
class ChatComposer extends StatefulWidget {
  final ValueChanged<String> onSend;

  const ChatComposer({super.key, required this.onSend});

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    // Cleared before the send is awaited: the message is already durable in the
    // outbox by then, so holding the text hostage to the network would only make
    // a slow connection feel like a broken button.
    _controller.clear();
    widget.onSend(text);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Present but inert: there is no upload endpoint yet (see the
            // roadmap's out-of-scope list). Disabled rather than absent so the
            // layout doesn't shift when it starts working.
            Tooltip(
              message: 'Attachments are not available yet',
              child: IconButton(
                onPressed: null,
                icon: const Icon(Icons.add_rounded),
                iconSize: 22,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: const TextStyle(fontFamily: 'Exo 2', fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'Message',
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  filled: true,
                  fillColor: colors.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Send message',
              child: Semantics(
                button: true,
                label: 'Send message',
                excludeSemantics: true,
                child: Material(
                  color: ForgeColors.forgeOrange,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _send,
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.send_rounded,
                        size: 19,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
