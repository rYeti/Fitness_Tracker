import 'dart:async';
import 'package:flutter/material.dart';

/// A countdown timer widget for rest periods between sets
class RestTimerWidget extends StatefulWidget {
  final int defaultSeconds;
  final VoidCallback? onTimerComplete;
  const RestTimerWidget({
    super.key,
    this.defaultSeconds = 90,
    this.onTimerComplete,
  });
  @override
  State<RestTimerWidget> createState() => _RestTimerWidgetState();
}

class _RestTimerWidgetState extends State<RestTimerWidget> {
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isRunning = false;
  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.defaultSeconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _stopTimer();
        widget.onTimerComplete?.call();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = widget.defaultSeconds;
      _isRunning = false;
    });
  }

  void _addTime(int seconds) {
    setState(() {
      _remainingSeconds += seconds;
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _remainingSeconds / widget.defaultSeconds;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Rest Timer',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16), // Circular progress indicator with time
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: theme.colorScheme.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _remainingSeconds <= 10
                          ? Colors.red
                          : theme.colorScheme.primary,
                    ),
                  ),
                ),
                Text(
                  _formatTime(_remainingSeconds),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _remainingSeconds <= 10 ? Colors.red : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16), // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isRunning) ...[
                ElevatedButton.icon(
                  onPressed: _startTimer,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _resetTimer,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: _stopTimer,
                  icon: const Icon(Icons.pause),
                  label: const Text('Pause'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    _stopTimer();
                    _resetTimer();
                  },
                  child: const Text('Stop'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12), // Quick time adjust buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTimeButton('-30s', () => _addTime(-30)),
              const SizedBox(width: 8),
              _buildTimeButton('-15s', () => _addTime(-15)),
              const SizedBox(width: 8),
              _buildTimeButton('+15s', () => _addTime(15)),
              const SizedBox(width: 8),
              _buildTimeButton('+30s', () => _addTime(30)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeButton(String label, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(60, 36),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

/// Show rest timer as a bottom sheet
void showRestTimer(BuildContext context, {int defaultSeconds = 90}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder:
        (context) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: RestTimerWidget(
            defaultSeconds: defaultSeconds,
            onTimerComplete: () {
              // Optional: Play a sound or vibration
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Rest time complete! 💪'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ),
  );
}
