import 'dart:convert';
import 'dart:io';

import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Preview data computed from a parsed CSV before the actual import runs.
class _PreviewData {
  final String csvContent;
  final int sessions;
  final String? firstDate;
  final String? lastDate;
  final List<_ExercisePreview> exercises;
  final int totalSets;

  _PreviewData({
    required this.csvContent,
    required this.sessions,
    required this.firstDate,
    required this.lastDate,
    required this.exercises,
    required this.totalSets,
  });

  int get newExerciseCount => exercises.where((e) => e.isNew).length;
}

class _ExercisePreview {
  final String name;
  final String category;
  final bool isNew; // true if not yet in the database

  _ExercisePreview({
    required this.name,
    required this.category,
    required this.isNew,
  });
}

enum _ImportState { idle, loadingPreview, preview, importing, done }

class FitNotesImportView extends StatefulWidget {
  const FitNotesImportView({super.key});

  @override
  State<FitNotesImportView> createState() => _FitNotesImportViewState();
}

class _FitNotesImportViewState extends State<FitNotesImportView> {
  _ImportState _state = _ImportState.idle;
  _PreviewData? _preview;
  FitNotesImportResult? _result;
  String? _errorMessage;

  Future<void> _pickAndPreview() async {
    setState(() {
      _state = _ImportState.loadingPreview;
      _errorMessage = null;
    });

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (picked == null || !mounted) {
        setState(() => _state = _ImportState.idle);
        return;
      }

      final file = picked.files.single;
      String content;
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        throw Exception('Cannot read selected file');
      }

      final preview = await _buildPreview(content);
      if (!mounted) return;

      if (preview.sessions == 0) {
        setState(() {
          _state = _ImportState.idle;
          _errorMessage = AppLocalizations.of(context)!.noValidDataInFile;
        });
        return;
      }

      setState(() {
        _preview = preview;
        _state = _ImportState.preview;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _ImportState.idle;
        _errorMessage = e.toString();
      });
    }
  }

  Future<_PreviewData> _buildPreview(String csvContent) async {
    // Parse CSV manually (split by newline, then comma)
    final lines = csvContent.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 2) {
      return _PreviewData(
        csvContent: csvContent,
        sessions: 0,
        firstDate: null,
        lastDate: null,
        exercises: [],
        totalSets: 0,
      );
    }

    // Collect unique dates, exercise names, categories
    final dates = <String>{};
    final exerciseByName = <String, String>{}; // name → category
    int totalSets = 0;

    for (final line in lines.skip(1)) {
      final cols = line.split(',');
      if (cols.length < 6) continue;
      final date = cols[0].trim();
      final exercise = cols[1].trim();
      final category = cols[2].trim();
      if (date.isEmpty || exercise.isEmpty) continue;
      dates.add(date);
      exerciseByName[exercise] = category;
      totalSets++;
    }

    if (dates.isEmpty) {
      return _PreviewData(
        csvContent: csvContent,
        sessions: 0,
        firstDate: null,
        lastDate: null,
        exercises: [],
        totalSets: 0,
      );
    }

    final sortedDates = dates.toList()..sort();

    // Check which exercises already exist in the DB
    final db = context.read<AppDatabase>();
    final existingExercises = await db.select(db.exerciseTable).get();
    final existingNames = existingExercises.map((e) => e.name).toSet();

    final exercisePreviews = exerciseByName.entries
        .map((e) => _ExercisePreview(
              name: e.key,
              category: e.value,
              isNew: !existingNames.contains(e.key),
            ))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return _PreviewData(
      csvContent: csvContent,
      sessions: dates.length,
      firstDate: sortedDates.first,
      lastDate: sortedDates.last,
      exercises: exercisePreviews,
      totalSets: totalSets,
    );
  }

  Future<void> _startImport() async {
    if (_preview == null) return;
    setState(() => _state = _ImportState.importing);

    try {
      final db = context.read<AppDatabase>();
      final result = await db.workoutDao.importFitNotesCsv(_preview!.csvContent);
      if (!mounted) return;
      setState(() {
        _result = result;
        _state = _ImportState.done;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _ImportState.preview;
        _errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.importFailed(e)),
          backgroundColor: ForgeColors.statusBadFor(Theme.of(context).brightness),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.importFitNotes)),
      body: switch (_state) {
        _ImportState.idle || _ImportState.loadingPreview => _buildIdleBody(l10n, theme),
        _ImportState.preview => _buildPreviewBody(l10n, theme),
        _ImportState.importing => _buildImportingBody(l10n),
        _ImportState.done => _buildDoneBody(l10n, theme),
      },
    );
  }

  Widget _buildIdleBody(AppLocalizations l10n, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.upload_file,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.importFitNotes,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.importFitNotesHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ],
            const SizedBox(height: 32),
            _state == _ImportState.loadingPreview
                ? const CircularProgressIndicator()
                : FilledButton.icon(
                    onPressed: _pickAndPreview,
                    icon: const Icon(Icons.folder_open),
                    label: Text(l10n.selectCsvFile),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(220, 52),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewBody(AppLocalizations l10n, ThemeData theme) {
    final preview = _preview!;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.readyToImport,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (preview.firstDate != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${preview.firstDate} → ${preview.lastDate}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Stats row
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      theme,
                      Icons.calendar_today,
                      l10n.sessionsCount(preview.sessions),
                      null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statCard(
                      theme,
                      Icons.fitness_center,
                      '${preview.exercises.length}',
                      l10n.uniqueExercisesLabel,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statCard(
                      theme,
                      Icons.format_list_numbered,
                      l10n.setsCount(preview.totalSets),
                      null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // New exercises notice
              if (preview.newExerciseCount > 0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline,
                          color: theme.colorScheme.onTertiaryContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.newExercisesWillBeCreated(
                              preview.newExerciseCount),
                          style: TextStyle(
                              color: theme.colorScheme.onTertiaryContainer),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Exercise list
              Text(
                l10n.exercises,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...preview.exercises.map(
                (ex) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.circle,
                    size: 10,
                    color: ex.isNew
                        ? theme.colorScheme.tertiary
                        : theme.colorScheme.outline,
                  ),
                  title: Text(ex.name),
                  subtitle: Text(ex.category),
                  trailing: ex.isNew
                      ? Chip(
                          label: Text(l10n.setLabel,
                              style: const TextStyle(fontSize: 11)),
                          backgroundColor: theme.colorScheme.tertiaryContainer,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),

        // Import button
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                FilledButton.icon(
                  onPressed: _startImport,
                  icon: const Icon(Icons.download_done),
                  label: Text(l10n.importButton),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() {
                    _state = _ImportState.idle;
                    _preview = null;
                    _errorMessage = null;
                  }),
                  child: Text(l10n.cancel),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImportingBody(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(l10n.importingWorkoutHistory),
        ],
      ),
    );
  }

  Widget _buildDoneBody(AppLocalizations l10n, ThemeData theme) {
    final result = _result!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle,
                size: 80, color: theme.colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              l10n.importComplete,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _resultRow(theme, Icons.calendar_today,
                l10n.importedSessions(result.sessions)),
            _resultRow(
                theme, Icons.format_list_numbered, l10n.importedSets(result.setsImported)),
            if (result.newExercises.isNotEmpty)
              _resultRow(theme, Icons.add_circle_outline,
                  l10n.createdExercises(result.newExercises.length)),
            _resultRow(theme, Icons.fitness_center,
                l10n.importedWorkoutsCreated(result.workoutsCreated)),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                minimumSize: const Size(200, 52),
              ),
              child: Text(l10n.done),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(
      ThemeData theme, IconData icon, String value, String? label) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 4),
            Text(value,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            if (label != null)
              Text(label,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(ThemeData theme, IconData icon, String text) {
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
