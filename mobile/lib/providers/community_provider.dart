import 'dart:developer';
import 'package:flutter/foundation.dart';
import '../models/community_post.dart';
import '../services/community_service.dart';

class CommunityProvider extends ChangeNotifier {
  final CommunityService _communityService = CommunityService();

  List<CommunityPost> _posts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String _sort = 'latest';
  int? _userId;

  List<CommunityPost> get posts => _posts;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String get sort => _sort;
  int? get userId => _userId;

  Future<void> loadFirstPage({
    String? sort,
    int? userId,
  }) async {
    _sort = sort ?? _sort;
    _userId = userId ?? _userId;
    _page = 1;
    _hasMore = true;
    _isLoading = true;
    notifyListeners();

    try {
      _posts = await _communityService.getPosts(
        userId: _userId,
        sort: _sort,
        page: _page,
      );
      _hasMore = _posts.length >= 20;
    } catch (e) {
      log('Error loading community feed: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = await _communityService.getPosts(
        userId: _userId,
        sort: _sort,
        page: _page + 1,
      );
      if (nextPage.isNotEmpty) {
        _posts = [..._posts, ...nextPage];
        _page += 1;
        _hasMore = nextPage.length >= 20;
      } else {
        _hasMore = false;
      }
    } catch (e) {
      log('Error loading more community posts: $e');
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  Future<void> refresh() => loadFirstPage(sort: _sort, userId: _userId);

  /// Optimistically toggles the like state; reverts if the API call fails.
  Future<void> toggleLike(CommunityPost post) async {
    final index = _posts.indexWhere((p) => p.id == post.id);
    if (index == -1) return;

    final wasLiked = _posts[index].isLikedByMe;
    _posts[index] = _posts[index].copyWith(
      isLikedByMe: !wasLiked,
      likeCount: _posts[index].likeCount + (wasLiked ? -1 : 1),
    );
    notifyListeners();

    final result = await _communityService.toggleLike(post.id);
    if (result == null && _posts.length > index) {
      // Revert on failure.
      _posts[index] = _posts[index].copyWith(
        isLikedByMe: wasLiked,
        likeCount: post.likeCount,
      );
      notifyListeners();
    }
  }

  void incrementComments(int postId) {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;
    _posts[index] = _posts[index].copyWith(commentCount: _posts[index].commentCount + 1);
    notifyListeners();
  }

  void removePost(int postId) {
    _posts.removeWhere((p) => p.id == postId);
    notifyListeners();
  }

  void prependPost(CommunityPost post) {
    _posts = [post, ..._posts];
    notifyListeners();
  }
}
