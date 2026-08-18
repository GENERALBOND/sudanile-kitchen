import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/community_post.dart';
import '../providers/community_provider.dart';
import '../services/community_service.dart';
import 'community_post_detail_screen.dart';

/// A member's profile page in the community: avatar, bio, public stats and
/// their posts. Used both for "My Posts" and when tapping another member.
class UserProfileScreen extends StatefulWidget {
  final int userId;
  final String? userName;

  const UserProfileScreen({super.key, required this.userId, this.userName});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final CommunityService _communityService = CommunityService();
  final ScrollController _scrollController = ScrollController();

  CommunityMemberProfile? _profile;
  bool _isLoadingProfile = true;
  bool _profileFailed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadProfile();
    // Defer until after the frame builds: this screen pushes its own fresh
    // ChangeNotifierProvider, and loadFirstPage() notifies listeners
    // synchronously — firing it during mount/initState trips the
    // "!__dirty is not true" assertion (setState during build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<CommunityProvider>(context, listen: false)
          .loadFirstPage(userId: widget.userId);
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

  Future<void> _loadProfile() async {
    final profile = await _communityService.getPublicProfile(widget.userId);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _isLoadingProfile = false;
      _profileFailed = profile == null;
    });
  }

  Future<void> _retryLoad() async {
    setState(() {
      _isLoadingProfile = true;
      _profileFailed = false;
    });
    final provider = Provider.of<CommunityProvider>(context, listen: false);
    await Future.wait([_loadProfile(), provider.refresh()]);
  }

  Future<void> _refresh() async {
    final provider = Provider.of<CommunityProvider>(context, listen: false);
    await Future.wait([_loadProfile(), provider.refresh()]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_profile?.username ?? widget.userName ?? 'Profile'),
        backgroundColor: Colors.orange,
      ),
      body: Consumer<CommunityProvider>(
        builder: (context, provider, _) {
          return RefreshIndicator(
            onRefresh: _refresh,
            color: Colors.orange,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildProfileHeader(context, provider)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
                    child: Text(
                      'Posts',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                if (provider.isLoading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.orange),
                      ),
                    ),
                  )
                else if (provider.posts.isEmpty)
                  SliverToBoxAdapter(child: _buildNoPosts(context))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final post = provider.posts[index];
                          return _buildPostCard(context, provider, post);
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
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, CommunityProvider provider) {
    final profile = _profile;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.orange.shade50, Colors.white],
        ),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isLoadingProfile)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: Colors.orange),
              ),
            )
          else if (_profileFailed)
            Column(
              children: [
                Icon(
                  Icons.person_off,
                  size: 50,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  'Profile unavailable',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  'Check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _retryLoad,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                  ),
                ),
              ],
            )
          else ...[
            Center(
              child: CircleAvatar(
                radius: 45,
                backgroundColor: Colors.orange.shade100,
                backgroundImage: profile!.profilePicture != null
                    ? CachedNetworkImageProvider(profile.profilePicture!)
                    : null,
                child: profile.profilePicture == null
                    ? Text(
                        profile.username.isNotEmpty
                            ? profile.username[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontSize: 36,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    profile.username,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                if (profile.isAdmin) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Admin',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.red,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Joined ${profile.createdAt.day}/${profile.createdAt.month}/${profile.createdAt.year}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (profile.bio.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                profile.bio,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat(context, '${profile.postCount}', 'Posts'),
                _buildStat(context, '${profile.likeCount}', 'Likes'),
                _buildStat(context, '${profile.commentCount}', 'Comments'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStat(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildNoPosts(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Column(
        children: [
          Icon(
            Icons.photo_camera_outlined,
            size: 70,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No posts yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This member has not shared any dishes yet.',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(
      BuildContext context, CommunityProvider provider, CommunityPost post) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider<CommunityProvider>.value(
              value: provider,
              child: CommunityPostDetailScreen(post: post),
            ),
          ),
        );
      },
      child: Container(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: _postImage(post),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post.caption.isNotEmpty) ...[
                      Text(
                        post.caption,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                    ],
                    Row(
                      children: [
                        _buildLikeButton(context, provider, post),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.comment_outlined,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${post.commentCount}',
                          style: const TextStyle(fontSize: 12),
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

  Widget _buildLikeButton(
      BuildContext context, CommunityProvider provider, CommunityPost post) {
    return InkWell(
      onTap: () => provider.toggleLike(post),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          children: [
            Icon(
              post.isLikedByMe ? Icons.favorite : Icons.favorite_border,
              size: 15,
              color: post.isLikedByMe
                  ? Colors.red
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 3),
            Text(
              '${post.likeCount}',
              style: TextStyle(
                fontSize: 12,
                color: post.isLikedByMe
                    ? Colors.red
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
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
    return CachedNetworkImage(
      imageUrl: post.imageUrl!,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => Container(
        color: Colors.orange.shade100,
        child: const Icon(Icons.food_bank, size: 50, color: Colors.orange),
      ),
    );
  }
}
