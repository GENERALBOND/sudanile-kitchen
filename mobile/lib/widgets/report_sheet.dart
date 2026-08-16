import 'package:flutter/material.dart';
import '../services/community_service.dart';

/// Opens the report bottom sheet for a community post or comment.
///
/// `targetType` is `'post'` or `'comment'`. The reporter is never revealed
/// to the content author; the sheet only shows a generic confirmation.
Future<void> showReportSheet(
  BuildContext context, {
  required String targetType,
  required int targetId,
  required String targetLabel,
}) async {
  final reported = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReportSheet(
      targetType: targetType,
      targetId: targetId,
      targetLabel: targetLabel,
    ),
  );

  if (!context.mounted) return;
  if (reported != true) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Thanks — we'll review this.")),
  );
}

class _ReportSheet extends StatefulWidget {
  final String targetType;
  final int targetId;
  final String targetLabel;

  const _ReportSheet({
    required this.targetType,
    required this.targetId,
    required this.targetLabel,
  });

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final CommunityService _communityService = CommunityService();
  final TextEditingController _detailsController = TextEditingController();

  static const _reasons = [
    ('spam', 'Spam or scam'),
    ('harassment', 'Harassment or bullying'),
    ('misinformation', 'Misinformation'),
    ('inappropriate', 'Inappropriate content'),
    ('other', 'Other'),
  ];

  String? _selectedReason;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _selectedReason;
    if (reason == null || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    final error = await _communityService.report(
      targetType: widget.targetType,
      targetId: widget.targetId,
      reason: reason,
      details: _detailsController.text.trim(),
    );
    if (!mounted) return;

    if (error != null) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Report ${widget.targetLabel}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Why are you reporting this? Your identity stays private.',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _reasons.map((r) {
              final selected = _selectedReason == r.$1;
              return ChoiceChip(
                label: Text(r.$2),
                selected: selected,
                onSelected: (value) {
                  setState(() => _selectedReason = value ? r.$1 : null);
                },
                selectedColor: Colors.orange.shade100,
                labelStyle: TextStyle(
                  fontSize: 13,
                  color: selected ? Colors.orange.shade900 : null,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _detailsController,
            maxLines: 2,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'Add details (optional)',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedReason == null || _isSubmitting
                  ? null
                  : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
                disabledForegroundColor: theme.colorScheme.onSurfaceVariant,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit report'),
            ),
          ),
        ],
      ),
    );
  }
}