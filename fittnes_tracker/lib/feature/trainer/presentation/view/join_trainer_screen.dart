import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class JoinTrainerScreen extends ConsumerStatefulWidget {
  const JoinTrainerScreen({super.key});

  @override
  ConsumerState<JoinTrainerScreen> createState() => _JoinTrainerScreenState();
}

class _JoinTrainerScreenState extends ConsumerState<JoinTrainerScreen> {
  late TextEditingController _code;
  late FocusNode _focusNode;
  bool _isLoading = false;
  String? _fieldError;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(_validateCode);
  }

  @override
  void dispose() {
    _code.dispose();
    _focusNode.removeListener(_validateCode);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Join a Trainer'),
        titleTextStyle: const TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.bold,
          fontSize: 17,
          color: Colors.white,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 24),
            TextField(
              controller: _code,
              focusNode: _focusNode,
              decoration: InputDecoration(
                labelText: 'Trainer Code',
                errorText: _fieldError,
              ),
            ),
            if (_serverError != null) ...[
              SizedBox(height: 8),
              Text(
                _serverError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B3E),
                ),
                onPressed: _isLoading ? null : _submit,
                child:
                    _isLoading
                        ? CircularProgressIndicator()
                        : Text('Join Trainer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _validateCode() {
    if (!_focusNode.hasFocus) {}
  }

  _submit() {}
}
