import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/trip_log.dart';
import '../../state/log_controller.dart';
import '../widgets/app_states.dart';
import '../widgets/status_chip.dart';

/// The local trip log: a plain, honest record of detections, hazards, voice
/// exchanges and session events. Reads from the on-device SQLite store.
class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});
  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  @override
  void initState() {
    super.initState();
    final log = context.read<LogController>();
    if (log.status != LoadStatus.ready) log.load();
  }

  Future<void> _confirmClear(LogController log) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear trip log?'),
        content: const Text('This permanently removes all recorded entries.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) log.clear();
  }

  @override
  Widget build(BuildContext context) {
    final log = context.watch<LogController>();
    final hasEntries = log.entries.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip log'),
        actions: [
          if (hasEntries)
            IconButton(
              tooltip: 'Clear log',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmClear(log),
            ),
        ],
      ),
      body: _body(context, log),
    );
  }

  Widget _body(BuildContext context, LogController log) {
    switch (log.status) {
      case LoadStatus.loading:
        return const LoadingState(message: 'Loading your trip log…');
      case LoadStatus.error:
        return ErrorState(
          message: log.error ?? 'The trip log could not be loaded.',
          onRetry: log.load,
        );
      case LoadStatus.ready:
        if (log.entries.isEmpty) {
          return const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No entries yet',
            message:
                'Detections, hazard alerts and voice questions will appear here '
                'as you use the app.',
          );
        }
        return _LogList(log: log);
    }
  }
}

class _LogList extends StatelessWidget {
  final LogController log;
  const _LogList({required this.log});
  @override
  Widget build(BuildContext context) {
    final counts = log.counts;
    final types =
        LogType.values.where((tp) => (counts[tp.name] ?? 0) > 0).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (types.isNotEmpty) ...[
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final tp in types)
              StatusChip(
                label: '${tp.label} · ${counts[tp.name]}',
                tone: _toneFor(tp),
                icon: _iconFor(tp),
              ),
          ]),
          const SizedBox(height: 16),
        ],
        for (final e in log.entries) _LogTile(entry: e),
      ],
    );
  }
}

class _LogTile extends StatelessWidget {
  final TripLogEntry entry;
  const _LogTile({required this.entry});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(_iconFor(entry.type), size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.summary, style: t.bodyLarge),
                  if (entry.detail != null) ...[
                    const SizedBox(height: 2),
                    Text(entry.detail!,
                        style: t.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ]),
          ),
          const SizedBox(width: 8),
          Text(_time(entry.time),
              style: t.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

String _time(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.hour)}:${two(dt.minute)}';
}

StatusTone _toneFor(LogType type) => switch (type) {
      LogType.hazard => StatusTone.warning,
      LogType.detection => StatusTone.info,
      LogType.voice => StatusTone.success,
      LogType.navigation => StatusTone.neutral,
      LogType.session => StatusTone.neutral,
    };

IconData _iconFor(LogType type) => switch (type) {
      LogType.hazard => Icons.warning_amber_outlined,
      LogType.detection => Icons.visibility_outlined,
      LogType.voice => Icons.mic_none_outlined,
      LogType.navigation => Icons.explore_outlined,
      LogType.session => Icons.play_circle_outline,
    };
