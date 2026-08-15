import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/community_post.dart';
import '../providers/community_provider.dart';
import '../services/auth_service.dart';
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

    final provider = Provider.of<CommunityProvider>(context, listen: false);
    if (provider.posts.isEmpty) {
      provider.loadFirstPage();
    }
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Community'),
        backgroundColor: Colors.orange,
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
          _buildSortSelector(),
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

  Widget _buildSortSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Consumer<CommunityProvider>(
            builder: (context, provider, _) {
              return Row(
                children: [
                  _sortButton('Latest', 'latest', provider.sort),
                  const SizedBox(width: 8),
                  _sortButton('Popular', 'popular', provider.sort),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sortButton(String label, String value, String current) {
    final selected = current == value;
    return InkWell(
      onTap: () => _changeSort(value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.orange : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey.shade700,
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
          padding: const EdgeInsets.all(12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final post = provider.posts[index];
                return _buildPostCard(provider, post);
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

  Widget _buildPostCard(CommunityProvider provider, CommunityPost post) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CommunityPostDetailScreen(post: post),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: _postImage(post),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.userName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (post.caption.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        post.caption,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          post.isLikedByMe
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 14,
                          color: post.isLikedByMe
                              ? Colors.red
                              : Colors.grey,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${post.likeCount}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.comment_outlined,
                            size: 13, color: Colors.grey),
                        const SizedBox(width: 3),
                        Text(
                          '${post.commentCount}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _postImage(CommunityPost post) {
    if (post.imageUrl == null || post.imageUrl!.isEmpty) {
      return Container(
        color: Colors.orange.shade100,
        child: const Icon(Icons.food_bank, size: 50, color: Colors.orange),
      );
    }
    return Image.network(
      post.imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.orange.shade100,
        child: const Icon(Icons.food_bank, size: 50, color: Colors.orange),
      ),
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: constraints.maxHeight * 0.2),
            const Icon(Icons.photo_camera_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'No posts yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Be the first to share a dish you cooked!',
                style: TextStyle(color: Colors.grey),
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
