import 'dart:io';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/feature/gym_tracking/data/csv_workout_importer.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum _ImportState { idle, importing, done }

class CsvImportScreen extends StatefulWidget {
  const CsvImportScreen({super.key});

  @override
  State<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends State<CsvImportScreen> {
  _ImportState _state = _ImportState.idle;
  String? _selectedFilePath;
  String? _selectedFileName;
  double _importProgress = 0.0;
  CsvImportResult? _result;
  String? _errorMessage;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null) return;
    setState(() {
      _selectedFilePath = result.files.single.path;
      _selectedFileName = result.files.single.name;
      _errorMessage = null;
    });
  }

  Future<void> _import() async {
    if (_selectedFilePath == null) {
      final l10n = AppLocalizations.of(context)!;
      setState(() => _errorMessage = l10n.csvPleaseSelectFile);
      return;
    }

    setState(() {
      _state = _ImportState.importing;
      _importProgress = 0.0;
      _errorMessage = null;
    });

    try {
      final csvContent = await File(_selectedFilePath!).readAsString();
      if (!mounted) return;
      final db = context.read<AppDatabase>();
      final importer = CsvWorkoutImporter(db);

      final result = await importer.importExercises(
        csvContent: csvContent,
        onProgress: (current, total) {
          if (mounted) setState(() => _importProgress = current / total);
        },
      );

      if (!mounted) return;

      if (result.isSuccess) {
        setState(() {
          _result = result;
          _state = _ImportState.done;
        });
      } else {
        setState(() {
          _state = _ImportState.idle;
          _errorMessage = result.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _ImportState.idle;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.importOptions)),
      body: switch (_state) {
        _ImportState.idle => _buildIdle(theme),
        _ImportState.importing => _buildImporting(theme),
        _ImportState.done => _buildDone(theme, l10n),
      },
    );
  }

  Widget _buildIdle(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info card
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: theme.colorScheme.onPrimaryContainer),
                      const SizedBox(width: 8),
                      Text(
                        l10n.csvFormatTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.csvFormatDescription,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // File picker
          OutlinedButton.icon(
            icon: const Icon(Icons.file_upload),
            label: Text(
              _selectedFileName ?? l10n.csvSelectFileButton,
              overflow: TextOverflow.ellipsis,
            ),
            onPressed: _pickFile,
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 24),

          FilledButton.icon(
            icon: const Icon(Icons.download_done),
            label: Text(l10n.csvImportExercisesButton),
            onPressed: _selectedFilePath != null ? _import : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImporting(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(value: _importProgress > 0 ? _importProgress : null),
            const SizedBox(height: 24),
            Text(
              l10n.csvImporting,
              style: theme.textTheme.bodyLarge,
            ),
            if (_importProgress > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${(_importProgress * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDone(ThemeData theme, AppLocalizations l10n) {
    final result = _result!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 80, color: theme.colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              l10n.importComplete,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _row(theme, Icons.add_circle_outline,
                l10n.csvExercisesAdded(result.exercisesCreated)),
            if (result.exercisesSkipped > 0)
              _row(theme, Icons.check_circle_outline,
                  l10n.csvExercisesSkipped(result.exercisesSkipped)),
            const SizedBox(height: 8),
            Text(
              l10n.csvCreateWorkoutHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                  minimumSize: const Size(200, 52)),
              child: Text(l10n.done),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(ThemeData theme, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Text(text, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
