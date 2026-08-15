import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/community_post.dart';
import '../providers/community_provider.dart';
import '../services/community_service.dart';
import 'community_post_detail_screen.dart';

/// A member's profile page in the community: avatar, bio, stats and their
/// posts. Used both for "My Posts" and when tapping another member.
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
    Provider.of<CommunityProvider>(context, listen: false)
        .loadFirstPage(userId: widget.userId);
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

  Future<void> _refresh() async {
    final provider = Provider.of<CommunityProvider>(context, listen: false);
    await Future.wait([_loadProfile(), provider.refresh()]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
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
                SliverToBoxAdapter(child: _buildProfileHeader(provider)),
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
                  SliverToBoxAdapter(child: _buildNoPosts())
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(CommunityProvider provider) {
    final profile = _profile;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        children: [
          if (_isLoadingProfile)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: Colors.orange),
            )
          else if (_profileFailed)
            Column(
              children: [
                const Icon(Icons.person_off, size: 50, color: Colors.grey),
                const SizedBox(height: 8),
                Text(
                  'Profile unavailable',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            )
          else ...[
            CircleAvatar(
              radius: 45,
              backgroundColor: Colors.orange.shade100,
              backgroundImage: profile!.profilePicture != null
                  ? NetworkImage(profile.profilePicture!)
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
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  profile.username,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
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
            const SizedBox(height: 6),
            Text(
              'Joined ${profile.createdAt.day}/${profile.createdAt.month}/${profile.createdAt.year}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
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
                _buildStat('${profile.postCount}', 'Posts'),
                _buildStat('${profile.likeCount}', 'Likes'),
                _buildStat('${profile.commentCount}', 'Comments'),
                _buildStat('${profile.favoritesCount}', 'Saved'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
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
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildNoPosts() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Column(
        children: [
          const Icon(Icons.photo_camera_outlined, size: 70, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No posts yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[700]),
          ),
          const SizedBox(height: 6),
          Text(
            'This member has not shared any dishes yet.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
                    if (post.caption.isNotEmpty) ...[
                      Text(
                        post.caption,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                    ],
                    Row(
                      children: [
                        Icon(
                          post.isLikedByMe
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 14,
                          color: post.isLikedByMe ? Colors.red : Colors.grey,
                        ),
                        const SizedBox(width: 3),
                        Text('${post.likeCount}',
                            style: const TextStyle(fontSize: 11)),
                        const SizedBox(width: 12),
                        const Icon(Icons.comment_outlined,
                            size: 13, color: Colors.grey),
                        const SizedBox(width: 3),
                        Text('${post.commentCount}',
                            style: const TextStyle(fontSize: 11)),
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
}
