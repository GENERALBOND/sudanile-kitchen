import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/community_post.dart';
import '../providers/community_provider.dart';
import '../services/auth_service.dart';
import '../services/community_service.dart';
import '../services/recipe_service.dart';
import 'recipe_detail_screen.dart';
import 'user_profile_screen.dart';

class CommunityPostDetailScreen extends StatefulWidget {
  final CommunityPost post;

  const CommunityPostDetailScreen({super.key, required this.post});

  @override
  State<CommunityPostDetailScreen> createState() =>
      _CommunityPostDetailScreenState();
}

class _CommunityPostDetailScreenState extends State<CommunityPostDetailScreen> {
  final CommunityService _communityService = CommunityService();
  final RecipeService _recipeService = RecipeService();
  final TextEditingController _commentController = TextEditingController();

  late CommunityPost _post;
  List<CommunityComment> _comments = [];
  bool _isLoadingComments = true;
  bool _isSendingComment = false;
  bool _isLiking = false;

  int? get _currentUserId {
    final authService = Provider.of<AuthService>(context, listen: false);
    return authService.user?.id;
  }

  bool get _isOwner {
    final authService = Provider.of<AuthService>(context, listen: false);
    return authService.user?.id == _post.userId || authService.isAdmin;
  }

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    final comments = await _communityService.getComments(_post.id);
    if (!mounted) return;
    setState(() {
      _comments = comments;
      _isLoadingComments = false;
    });
  }

  Future<void> _toggleLike() async {
    if (_isLiking) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) {
      _showLoginRequired();
      return;
    }
    setState(() => _isLiking = true);

    final provider = Provider.of<CommunityProvider>(context, listen: false);
    // Update the shared feed state optimistically (keeps grid + detail in sync).
    await provider.toggleLike(_post);

    final refreshed = provider.posts
        .firstWhere((p) => p.id == _post.id, orElse: () => _post);
    setState(() {
      _post = refreshed;
      _isLiking = false;
    });
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSendingComment) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) {
      _showLoginRequired();
      return;
    }

    setState(() => _isSendingComment = true);
    final error = await _communityService.addComment(_post.id, text);
    if (!mounted) return;
    setState(() => _isSendingComment = false);

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    _commentController.clear();
    Provider.of<CommunityProvider>(context, listen: false)
        .incrementComments(_post.id);
    setState(() => _post = _post.copyWith(commentCount: _post.commentCount + 1));
    FocusScope.of(context).unfocus();
    await _loadComments();
  }

  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final success = await _communityService.deletePost(_post.id);
    if (!mounted) return;
    if (success) {
      Provider.of<CommunityProvider>(context, listen: false)
          .removePost(_post.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted.')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete post.')),
      );
    }
  }

  Future<void> _reportPost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Post'),
        content: const Text(
            'Are you sure you want to report this post as inappropriate?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Report'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final success = await _communityService.reportPost(_post.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Post reported. Our team will review it.'
            : 'Failed to report post.'),
      ),
    );
  }

  void _openRecipe() async {
    final recipeId = _post.recipeId;
    if (recipeId == null) return;
    final recipe = await _recipeService.getRecipe(recipeId);
    if (!mounted) return;
    if (recipe != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipe not found.')),
      );
    }
  }

  void _openUserPosts() {
    // Scoped provider so this pushed screen does not clobber the tab feed.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => CommunityProvider(),
          child: UserProfileScreen(
            userId: _post.userId,
            userName: _post.userName,
          ),
        ),
      ),
    );
  }

  void _showLoginRequired() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please login to join the conversation.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        backgroundColor: Colors.orange,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'delete') _deletePost();
              if (value == 'report') _reportPost();
            },
            itemBuilder: (context) => [
              if (_isOwner)
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete Post'),
                )
              else
                const PopupMenuItem(
                  value: 'report',
                  child: Text('Report Post'),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      color: Colors.orange.shade100,
                      child: _post.imageUrl != null &&
                              _post.imageUrl!.isNotEmpty
                          ? Image.network(
                              _post.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.food_bank,
                                size: 60,
                                color: Colors.orange,
                              ),
                            )
                          : const Icon(Icons.food_bank,
                              size: 60, color: Colors.orange),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAuthorRow(),
                        if (_post.caption.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            _post.caption,
                            style: const TextStyle(fontSize: 15, height: 1.4),
                          ),
                        ],
                        if (_post.recipeId != null) ...[
                          const SizedBox(height: 12),
                          _buildRecipeLink(context),
                        ],
                        const SizedBox(height: 8),
                        _buildActionRow(context),
                        const SizedBox(height: 8),
                        Text(
                          _timeAgo(_post.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        Row(
                          children: [
                            const Text(
                              'Comments',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(${_post.commentCount})',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildCommentsSection(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildAuthorRow() {
    return InkWell(
      onTap: _openUserPosts,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.orange.shade100,
              backgroundImage: _post.userProfilePicture != null
                  ? NetworkImage(_post.userProfilePicture!)
                  : null,
              child: _post.userProfilePicture == null
                  ? Text(
                      _post.userName.isNotEmpty
                          ? _post.userName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontSize: 16,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _post.userName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'View posts',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeLink(BuildContext context) {
    return InkWell(
      onTap: _openRecipe,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: _post.recipeImageUrl != null &&
                        _post.recipeImageUrl!.isNotEmpty
                    ? Image.network(
                        _post.recipeImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.restaurant,
                          color: Colors.orange.shade400,
                        ),
                      )
                    : Icon(Icons.restaurant, color: Colors.orange.shade400),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cooked this recipe',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _post.recipeTitle ?? 'View recipe',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow(BuildContext context) {
    return Row(
      children: [
        _buildActionButton(
          icon: _post.isLikedByMe
              ? Icons.favorite
              : Icons.favorite_border,
          color: _post.isLikedByMe
              ? Colors.red
              : Theme.of(context).colorScheme.onSurfaceVariant,
          label: '${_post.likeCount}',
          onTap: _toggleLike,
        ),
        const SizedBox(width: 24),
        _buildActionButton(
          icon: Icons.comment_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          label: '${_post.commentCount}',
          onTap: () {
            FocusScope.of(context).requestFocus(FocusNode());
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsSection(BuildContext context) {
    if (_isLoadingComments) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
        ),
      );
    }

    if (_comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'No comments yet. Be the first to share your thoughts!',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return Column(
      children: _comments
        .map((comment) => _buildCommentTile(context, comment))
        .toList(),
    );
  }

  Widget _buildCommentTile(
      BuildContext context, CommunityComment comment) {
    final canDelete = _currentUserId == comment.userId ||
        Provider.of<AuthService>(context, listen: false).isAdmin;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.orange.shade100,
            backgroundImage: comment.userProfilePicture != null
                ? NetworkImage(comment.userProfilePicture!)
                : null,
            child: comment.userProfilePicture == null
                ? Text(
                    comment.userName.isNotEmpty
                        ? comment.userName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.orange),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment.userName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _timeAgo(comment.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(comment.comment, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
          if (canDelete)
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              onPressed: () => _deleteComment(comment),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteComment(CommunityComment comment) async {
    final success = await _communityService.deleteComment(comment.id);
    if (!mounted) return;
    if (success) {
      setState(() => _comments.removeWhere((c) => c.id == comment.id));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete comment.')),
      );
    }
  }

  Widget _buildCommentInput() {
    final authService = Provider.of<AuthService>(context);
    if (!authService.isAuthenticated) {
      return Container(
        padding: const EdgeInsets.all(12),
        color: Theme.of(context).cardColor,
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Login to join the conversation',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            TextButton(
              onPressed: _showLoginRequired,
              child: const Text('Login',
                  style: TextStyle(color: Colors.orange)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      color: Theme.of(context).cardColor,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _addComment(),
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide:
                      BorderSide(color: Theme.of(context).dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide:
                      BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: _isSendingComment
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.orange),
                  )
                : const Icon(Icons.send, color: Colors.orange),
            onPressed: _isSendingComment ? null : _addComment,
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
