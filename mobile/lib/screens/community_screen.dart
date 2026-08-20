import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/community_post.dart';
import '../providers/community_provider.dart';
import '../services/auth_service.dart';
import '../utils/app_themes.dart';
import '../widgets/report_sheet.dart';
import 'community_post_detail_screen.dart';
import 'user_profile_screen.dart';
import 'login_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Defer until after the frame builds: loadFirstPage() notifies listeners
    // synchronously, and firing it during mount/initState trips the
    // setState-during-build assertion and crashes the app at startup
    // (HomeScreen's IndexedStack builds this tab on launch).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = Provider.of<CommunityProvider>(context, listen: false);
      if (provider.posts.isEmpty) {
        provider.loadFirstPage();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      Provider.of<CommunityProvider>(context, listen: false).loadMore();
    }
  }

  void _changeSort(String sort) {
    Provider.of<CommunityProvider>(context, listen: false)
        .loadFirstPage(sort: sort);
  }

  void _openMyPosts() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.user;
    if (user == null) {
      _showLoginRequiredDialog();
      return;
    }
    // Use a scoped provider so the pushed screen does not replace the tab
    // feed's posts in the shared provider.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => CommunityProvider(),
          child: UserProfileScreen(userId: user.id, userName: user.username),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = !Provider.of<AuthService>(context).isAuthenticated;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        actions: [
          IconButton(
            tooltip: 'My Posts',
            icon: const Icon(Icons.person_pin),
            onPressed: isGuest ? _showLoginRequiredDialog : _openMyPosts,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSortSelector(context),
          Expanded(
            child: Consumer<CommunityProvider>(
              builder: (context, provider, _) {
                return RefreshIndicator(
                  onRefresh: provider.refresh,
                  color: Colors.orange,
                  child: _buildBody(provider),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortSelector(BuildContext context) {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Consumer<CommunityProvider>(
            builder: (context, provider, _) {
              return Row(
                children: [
                  _sortButton(context, 'Latest', 'latest', provider.sort),
                  const SizedBox(width: 8),
                  _sortButton(context, 'Popular', 'popular', provider.sort),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sortButton(BuildContext context, String label, String value,
      String current) {
    final selected = current == value;
    return InkWell(
      onTap: () => _changeSort(value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Colors.orange
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(CommunityProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      );
    }

    if (provider.posts.isEmpty) {
      return _buildEmptyState();
    }

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final post = provider.posts[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildPostCard(context, provider, post),
                );
              },
              childCount: provider.posts.length,
            ),
          ),
        ),
        if (provider.isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.orange,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPostCard(
      BuildContext context, CommunityProvider provider, CommunityPost post) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAuthorRow(context, provider, post),
            GestureDetector(
              onTap: () => _openPostDetail(provider, post),
              child: _postImage(post),
            ),
            if (post.caption.isNotEmpty)
              GestureDetector(
                onTap: () => _openPostDetail(provider, post),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: Text(
                    post.caption,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
              ),
            if (post.recipeId != null)
              GestureDetector(
                onTap: () => _openPostDetail(provider, post),
                child: _buildRecipeChip(post),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Text(
                '${post.likeCount} ${post.likeCount == 1 ? 'like' : 'likes'}'
                ' · ${post.commentCount} ${post.commentCount == 1 ? 'comment' : 'comments'}',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            _buildActionRow(context, provider, post),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthorRow(
      BuildContext context, CommunityProvider provider, CommunityPost post) {
    final isOwn = Provider.of<AuthService>(context).user?.id == post.userId;
    return InkWell(
      onTap: () => _openUserPosts(post),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: context.appColors.iconCircleBg,
              backgroundImage: post.userProfilePicture != null
                  ? CachedNetworkImageProvider(post.userProfilePicture!)
                  : null,
              child: post.userProfilePicture == null
                  ? Text(
                      post.userName.isNotEmpty
                          ? post.userName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Colors.orange, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.userName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _timeAgo(post.createdAt),
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (!isOwn)
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onSelected: (value) {
                  if (value == 'report') _reportPost(post);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'report',
                    child: Text('Report post'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _reportPost(CommunityPost post) {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to report content.')),
      );
      return;
    }
    showReportSheet(
      context,
      targetType: 'post',
      targetId: post.id,
      targetLabel: 'post',
    );
  }

  Widget _buildRecipeChip(CommunityPost post) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: context.appColors.chipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.appColors.chipBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.restaurant,
                size: 14, color: context.appColors.chipFg),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                post.recipeTitle ?? 'View recipe',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.appColors.chipFg),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow(
      BuildContext context, CommunityProvider provider, CommunityPost post) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: post.isLikedByMe ? Icons.favorite : Icons.favorite_border,
              color: post.isLikedByMe
                  ? Colors.red
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              label: 'Like',
              onTap: () => provider.toggleLike(post),
            ),
          ),
          Expanded(
            child: _buildActionButton(
              icon: Icons.comment_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              label: 'Comment',
              onTap: () => _openPostDetail(provider, post),
            ),
          ),
        ],
      ),
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }

  void _openPostDetail(CommunityProvider provider, CommunityPost post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<CommunityProvider>.value(
          value: provider,
          child: CommunityPostDetailScreen(post: post),
        ),
      ),
    );
  }

  void _openUserPosts(CommunityPost post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => CommunityProvider(),
          child: UserProfileScreen(
            userId: post.userId,
            userName: post.userName,
          ),
        ),
      ),
    );
  }

  Widget _postImage(CommunityPost post) {
    final Widget image = post.imageUrl == null || post.imageUrl!.isEmpty
        ? Container(
            color: Colors.orange.shade100,
            child: const Icon(Icons.food_bank, size: 60, color: Colors.orange),
          )
        : CachedNetworkImage(
            imageUrl: post.imageUrl!,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(
              color: Colors.orange.shade100,
              child: const Icon(Icons.food_bank, size: 60, color: Colors.orange),
            ),
          );
    return AspectRatio(aspectRatio: 1, child: image);
  }

  String _timeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: constraints.maxHeight * 0.2),
            Icon(
                Icons.photo_camera_outlined,
                size: 80,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'No posts yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Be the first to share a dish you cooked!',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Required'),
        content: const Text('Please login to view your posts.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text('Login',
                style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }
}
