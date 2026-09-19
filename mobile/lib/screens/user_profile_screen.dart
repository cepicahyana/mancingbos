import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/app_states.dart';
import '../widgets/level_badge.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.userId, this.userName = ''});

  final int userId;
  final String userName;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  UserProfile? _profile;
  List<FeedPost> _posts = [];
  bool _loading = true;
  bool _followBusy = false;
  String? _error;

  ApiClient get _api => context.read<AuthState>().api;

  String _mediaUrl(String path) {
    if (path.startsWith('http')) return path;
    return '${AppConfig.apiBaseUrl}$path';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profileRes = await _api.get('/api/profiles/${widget.userId}');
      final postsRes = await _api.get('/api/profiles/${widget.userId}/posts', query: {'per_page': '30'});
      if (!mounted) return;
      setState(() {
        _profile = UserProfile.fromJson(profileRes['data'] as Map<String, dynamic>);
        _posts = asObjectList(postsRes['data']).map(FeedPost.fromJson).toList();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.firstError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final p = _profile;
    if (p == null || p.isMe || _followBusy) return;
    setState(() => _followBusy = true);
    final wasFollowing = p.followedByMe;
    setState(() {
      _profile = p.copyWith(
        followedByMe: !wasFollowing,
        followersCount: p.followersCount + (wasFollowing ? -1 : 1),
      );
    });
    try {
      final res = wasFollowing
          ? await _api.delete('/api/users/${widget.userId}/follow')
          : await _api.post('/api/users/${widget.userId}/follow');
      if (!mounted) return;
      setState(() => _profile = UserProfile.fromJson(res['data'] as Map<String, dynamic>));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _profile = p);
      showAppError(context, e.firstError);
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    final title = p?.name.isNotEmpty == true ? p!.name : (widget.userName.isNotEmpty ? widget.userName : 'Profil');

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: _load,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _header(p!)),
                      if (_posts.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text('Belum ada postingan', style: TextStyle(color: AppTheme.secondary)),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 4,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (_, i) {
                                final post = _posts[i];
                                final url = _mediaUrl(post.mediaUrls.isNotEmpty ? post.mediaUrls.first : post.imageUrl);
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      color: const Color(0xFFEEF3F0),
                                      child: const Icon(Icons.broken_image_outlined, color: AppTheme.secondary),
                                    ),
                                  ),
                                );
                              },
                              childCount: _posts.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _header(UserProfile p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFF1FA86A), AppTheme.header]),
                ),
                alignment: Alignment.center,
                child: Text(
                  p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 28),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _stat('${p.postsCount}', 'Postingan'),
                    _stat('${p.followersCount}', 'Pengikut'),
                    _stat('${p.followingCount}', 'Mengikuti'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          const SizedBox(height: 10),
          LevelBadge(
            level: p.level,
            tierName: p.tierName,
            points: p.points,
            pointsToNext: p.pointsToNext,
          ),
          if (!p.isMe) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _followBusy ? null : _toggleFollow,
                style: FilledButton.styleFrom(
                  backgroundColor: p.followedByMe ? const Color(0xFFEEF3F0) : AppTheme.primary,
                  foregroundColor: p.followedByMe ? AppTheme.ink : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  p.followedByMe ? 'Mengikuti' : 'Ikuti',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppTheme.secondary, fontSize: 11)),
      ],
    );
  }
}
