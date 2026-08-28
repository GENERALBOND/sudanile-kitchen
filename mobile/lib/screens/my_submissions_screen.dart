import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/recipe_submission.dart';
import '../services/recipe_service.dart';
import '../utils/app_themes.dart';

/// Lists the signed-in user's recipe submissions together with their review
/// status (pending / approved / rejected) and any admin feedback.
class MySubmissionsScreen extends StatefulWidget {
  const MySubmissionsScreen({super.key});

  @override
  State<MySubmissionsScreen> createState() => _MySubmissionsScreenState();
}

class _MySubmissionsScreenState extends State<MySubmissionsScreen> {
  final RecipeService _recipeService = RecipeService();
  List<RecipeSubmission> _submissions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() => _isLoading = true);
    final submissions = await _recipeService.getMySubmissions();
    if (!mounted) return;
    setState(() {
      _submissions = submissions;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Submissions'),
        backgroundColor: Colors.orange,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _submissions.isEmpty
              ? _buildEmpty(context)
              : RefreshIndicator(
                  onRefresh: _loadSubmissions,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _submissions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _buildSubmissionCard(context, _submissions[index]),
                  ),
                ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            const Text(
              'No submissions yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Recipes you submit will appear here so you can track their review status.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionCard(BuildContext context, RecipeSubmission s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: s.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: s.imageUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _imageFallback(),
                            placeholder: (_, __) => _imageFallback(),
                          )
                        : _imageFallback(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${s.categoryName} • ${s.totalTimeDisplay}',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusBadge(s),
              ],
            ),
            if (s.adminNotes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.appColors.chipBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Reviewer note: ${s.adminNotes}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appColors.chipFg,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color: context.appColors.iconCircleBg,
      child: Icon(
        Icons.restaurant,
        color: context.appColors.iconCircleFg,
      ),
    );
  }

  Widget _statusBadge(RecipeSubmission s) {
    final (color, label) = switch (s.status) {
      'approved' => (Colors.green, 'Approved'),
      'rejected' => (Colors.red, 'Rejected'),
      _ => (Colors.orange, 'Pending'),
    };
    return Chip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
    );
  }
}
