import 'package:flutter/material.dart';

import '../models/health_record.dart';
import 'athena_resource_detail_page.dart';

class HealthEventDetailsScreen extends StatelessWidget {
  final HealthRecord record;

  const HealthEventDetailsScreen({
    super.key,
    required this.record,
  });

  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// The page with the full stored record, for EHR records the app can
  /// address. The shown version's own source serves it.
  static Widget? _fullRecordPage(HealthRecord record) {
    final type = record.resourceType;
    if (type == null || record.id.isEmpty) return null;
    // Epic's record page is the Ask AI citation target and names its source,
    // so Health Data doesn't link to it.
    return record.primarySource == RecordSource.athena
        ? AthenaResourceDetailPage(resourceType: type, resourceId: record.id)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Event Details'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 900,
              ),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.type.label.toUpperCase(),
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  // The light theme's primary is 2.85:1 on white.
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Theme.of(context).colorScheme.primary
                                      : const Color(0xFF006B80),
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            record.title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          if (record.status != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              record.status!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                          if (record.date != null) ...[
                            const SizedBox(height: 24),
                            Text(
                              'Date',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(record.date!),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                          // Where a record came from is never shown: only
                          // "not connected" messages name a source.
                          if (record.details.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 16),
                            ...record.details.map(
                              (detail) => Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      detail.label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      detail.value,
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if (_fullRecordPage(record) case final page?) ...[
                            const SizedBox(height: 8),
                            TextButton.icon(
                              // The light theme's primary is 2.85:1 on white.
                              style: TextButton.styleFrom(
                                foregroundColor: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Theme.of(context).colorScheme.primary
                                    : const Color(0xFF006B80),
                                minimumSize: const Size(48, 48),
                              ),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(builder: (_) => page),
                              ),
                              icon: const Icon(Icons.description_outlined),
                              label: const Text('View full record'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
