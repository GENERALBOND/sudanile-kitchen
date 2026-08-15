import 'dart:developer';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import '../models/community_post.dart';
import 'api_service.dart';

class CommunityService {
  final ApiService _apiService = ApiService();

  Future<List<CommunityPost>> getPosts({
    int? userId,
    String? sort,
    int page = 1,
  }) async {
    try {
      final queryParams = <String, String>{'page': page.toString()};
      if (userId != null) queryParams['user'] = userId.toString();
      if (sort != null) queryParams['sort'] = sort;

      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final response = await _apiService.get('/community/?$queryString');

      List<dynamic> results;
      if (response['results'] != null) {
        results = response['results'];
      } else if (response is List) {
        results = response;
      } else {
        results = [];
      }

      return results.map((json) => CommunityPost.fromJson(json)).toList();
    } catch (e) {
      log('❌ Error fetching community posts: $e');
      return [];
    }
  }

  /// Creates a post and returns `(post, error)` — exactly one is non-null.
  /// `post` is the serialized post returned by the server so the feed can
  /// prepend it without an extra fetch.
  Future<(CommunityPost?, String?)> createPost({
    required XFile image,
    String? caption,
    int? recipeId,
  }) async {
    try {
      final fields = <String, String>{};
      if (caption != null && caption.isNotEmpty) fields['caption'] = caption;
      if (recipeId != null) fields['recipe'] = recipeId.toString();

      final bytes = await image.readAsBytes();
      final response = await _apiService.postMultipart(
        '/community/create/',
        fields,
        fileField: 'image',
        fileBytes: bytes,
        filename: image.name,
        fileContentType: _mediaTypeFor(image),
      );
      return (CommunityPost.fromJson(response), null);
    } catch (e) {
      log('❌ Error creating community post: $e');
      return (null, _errorMessage(e));
    }
  }

  /// Toggles a like and returns the new state and like count, or null on error.
  Future<Map<String, dynamic>?> toggleLike(int postId) async {
    try {
      final response = await _apiService.post('/community/$postId/like/', {});
      return {
        'liked': response['liked'],
        'likeCount': response['like_count'],
      };
    } catch (e) {
      log('❌ Error toggling like: $e');
      return null;
    }
  }

  /// Fetches a member's public profile (used by the community profile page).
  Future<CommunityMemberProfile?> getPublicProfile(int userId) async {
    try {
      final response = await _apiService.get('/users/profile/$userId/');
      return CommunityMemberProfile.fromJson(response);
    } catch (e) {
      log('❌ Error fetching public profile: $e');
      return null;
    }
  }

  Future<List<CommunityComment>> getComments(int postId) async {
    try {
      final response = await _apiService.get('/community/$postId/comments/');
      final List<dynamic> data =
          response is List ? response : (response['results'] ?? []);
      return data.map((json) => CommunityComment.fromJson(json)).toList();
    } catch (e) {
      log('❌ Error fetching comments: $e');
      return [];
    }
  }

  /// Returns `null` on success, or a user-facing error message on failure.
  Future<String?> addComment(int postId, String comment) async {
    try {
      await _apiService.post('/community/$postId/comments/create/', {
        'comment': comment,
      });
      return null;
    } catch (e) {
      log('❌ Error adding comment: $e');
      return _errorMessage(e);
    }
  }

  Future<bool> deletePost(int postId) async {
    try {
      await _apiService.delete('/community/$postId/delete/');
      return true;
    } catch (e) {
      log('❌ Error deleting post: $e');
      return false;
    }
  }

  Future<bool> deleteComment(int commentId) async {
    try {
      await _apiService.delete('/community/comments/$commentId/delete/');
      return true;
    } catch (e) {
      log('❌ Error deleting comment: $e');
      return false;
    }
  }

  Future<bool> reportPost(int postId) async {
    try {
      await _apiService.post('/community/$postId/report/', {});
      return true;
    } catch (e) {
      log('❌ Error reporting post: $e');
      return false;
    }
  }

  String _errorMessage(Object e) {
    if (e is ApiException) return e.message;
    return e.toString().replaceFirst('Exception: ', '');
  }

  MediaType _mediaTypeFor(XFile image) {
    final mime = image.mimeType;
    if (mime != null) {
      final parts = mime.split('/');
      if (parts.length == 2) return MediaType(parts[0], parts[1]);
    }
    final name = image.name.toLowerCase();
    if (name.endsWith('.gif')) return MediaType('image', 'gif');
    if (name.endsWith('.png')) return MediaType('image', 'png');
    return MediaType('image', 'jpeg');
  }
}
