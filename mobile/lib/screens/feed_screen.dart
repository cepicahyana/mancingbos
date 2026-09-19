import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../core/time_ago.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/app_states.dart';
import 'create_post_screen.dart';
import 'user_profile_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, this.mineOnly = false, this.title});

  /// Jika true, hanya postingan milik user (galeri lapak pelapak).
  final bool mineOnly;
  final String? title;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<FeedPost> _posts = [];
  bool _loading = true;
  String? _error;

  AuthState get _auth => context.read<AuthState>();
  ApiClient get _api => _auth.api;

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
      final Map<String, dynamic> res;
      if (widget.mineOnly) {
        final uid = _auth.user!.id;
        res = await _api.get('/api/profiles/$uid/posts', query: {'per_page': '30'});
      } else {
        res = await _api.get('/api/posts', query: {'per_page': '30'});
      }
      _posts = asObjectList(res['data']).map(FeedPost.fromJson).toList();
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CreatePostScreen(forPelapak: widget.mineOnly)),
    );
    if (ok == true) _load();
  }

  Future<void> _toggleLike(FeedPost post) async {
    final i = _posts.indexWhere((p) => p.id == post.id);
    if (i < 0) return;
    final liked = post.likedByMe;
    setState(() {
      _posts[i] = post.copyWith(
        likedByMe: !liked,
        likesCount: liked ? (post.likesCount - 1).clamp(0, 1 << 30) : post.likesCount + 1,
      );
    });
    try {
      final res = liked ? await _api.delete('/api/posts/${post.id}/like') : await _api.post('/api/posts/${post.id}/like');
      final updated = FeedPost.fromJson(res['data'] as Map<String, dynamic>);
      if (!mounted) return;
      setState(() {
        final j = _posts.indexWhere((p) => p.id == post.id);
        if (j >= 0) _posts[j] = updated;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        final j = _posts.indexWhere((p) => p.id == post.id);
        if (j >= 0) _posts[j] = post;
      });
      showAppError(context, e.firstError);
    }
  }

  Future<void> _deletePost(FeedPost post) async {
    try {
      await _api.delete('/api/posts/${post.id}');
      _load();
    } on ApiException catch (e) {
      if (mounted) showAppError(context, e.firstError);
    }
  }

  Future<void> _openComments(FeedPost post) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => _CommentsSheet(post: post, onChanged: _load),
    );
    _load();
  }

  String _mediaUrl(String path) {
    if (path.startsWith('http')) return path;
    return '${AppConfig.apiBaseUrl}$path';
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthState>().user!;
    final top = MediaQuery.paddingOf(context).top;
    final isGaleri = widget.mineOnly;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: Icon(isGaleri ? Icons.add_photo_alternate_rounded : Icons.add_a_photo_rounded),
        label: Text(isGaleri ? 'Upload lapak' : 'Posting'),
      ),
      body: Column(
        children: [
          _FeedHeader(
            topInset: top,
            name: me.name.split(' ').first,
            postCount: _posts.length,
            onRefresh: _load,
            onCreate: _create,
            title: widget.title ?? (isGaleri ? 'Galeri Lapak' : 'Komunitas IndoFish'),
            subtitle: isGaleri
                ? 'Foto & video spot / fasilitas lapakmu'
                : 'Hai ${me.name.split(' ').first}, bagikan hasil tangkapanmu',
            createLabel: isGaleri ? 'Upload' : null,
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _error != null
                    ? ErrorView(message: _error!, onRetry: _load)
                    : _posts.isEmpty
                        ? EmptyView(
                            icon: isGaleri ? Icons.storefront_outlined : Icons.photo_camera_front_outlined,
                            title: isGaleri ? 'Galeri masih kosong' : 'Belum ada postingan',
                            subtitle: isGaleri
                                ? 'Upload foto/video lapak agar pemancing tertarik.'
                                : 'Bagikan momen mancing pertama kamu.',
                          )
                        : RefreshIndicator(
                            color: AppTheme.primary,
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
                              itemCount: _posts.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 14),
                              itemBuilder: (_, i) {
                                final post = _posts[i];
                                return _PostCard(
                                  post: post,
                                  imageUrls: post.mediaUrls.map(_mediaUrl).toList(),
                                  canDelete: post.userId == me.id || me.isAdmin,
                                  onLike: () => _toggleLike(post),
                                  onComment: () => _openComments(post),
                                  onDelete: () => _deletePost(post),
                                  onOpenProfile: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => UserProfileScreen(userId: post.userId, userName: post.userName),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _FeedHeader extends StatelessWidget {
  const _FeedHeader({
    required this.topInset,
    required this.name,
    required this.postCount,
    required this.onRefresh,
    required this.onCreate,
    this.title = 'Komunitas IndoFish',
    this.subtitle,
    this.createLabel,
  });

  final double topInset;
  final String name;
  final int postCount;
  final VoidCallback onRefresh;
  final VoidCallback onCreate;
  final String title;
  final String? subtitle;
  final String? createLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topInset + 12, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.header, Color(0xFF0E5A45)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [AppTheme.accent.withValues(alpha: 0.9), const Color(0xFF1FA86A)]),
                ),
                child: const Icon(Icons.groups_rounded, color: AppTheme.ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                    Text(
                      subtitle ?? 'Hai $name, bagikan hasil tangkapanmu',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              _circleBtn(Icons.refresh_rounded, onRefresh),
              const SizedBox(width: 8),
              _circleBtn(Icons.add_a_photo_rounded, onCreate),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '$postCount postingan',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 40, height: 40, child: Icon(icon, color: Colors.white, size: 20)),
      ),
    );
  }
}

class _PostCard extends StatefulWidget {
  const _PostCard({
    required this.post,
    required this.imageUrls,
    required this.canDelete,
    required this.onLike,
    required this.onComment,
    required this.onDelete,
    required this.onOpenProfile,
  });

  final FeedPost post;
  final List<String> imageUrls;
  final bool canDelete;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onDelete;
  final VoidCallback onOpenProfile;

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> with SingleTickerProviderStateMixin {
  late final AnimationController _heartCtrl;
  bool _showHeart = false;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _heartCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  Future<void> _doubleTapLike() async {
    widget.onLike();
    setState(() => _showHeart = true);
    await _heartCtrl.forward(from: 0);
    if (mounted) setState(() => _showHeart = false);
  }

  String get _timeLabel => formatPostTime(widget.post.createdAt);

  Future<void> _openMaps() async {
    final post = widget.post;
    final Uri uri;
    if (post.latitude != null && post.longitude != null) {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${post.latitude},${post.longitude}');
    } else if (post.location.trim().isNotEmpty) {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(post.location.trim())}');
    } else {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openViewer(int index) async {
    final urls = widget.imageUrls;
    if (urls.isEmpty || urls.first.isEmpty) return;
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, _, _) => _PhotoViewer(urls: urls, initialIndex: index),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final urls = widget.imageUrls.isEmpty ? const [''] : widget.imageUrls;
    final hasLoc = post.location.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: AppTheme.header.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 10)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onOpenProfile,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [Color(0xFF1FA86A), AppTheme.header]),
                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.55), width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      post.userName.isEmpty ? '?' : post.userName[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: widget.onOpenProfile,
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.userName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.2)),
                        const SizedBox(height: 2),
                        Text(_timeLabel, style: const TextStyle(color: AppTheme.secondary, fontSize: 11.5, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
                if (widget.canDelete)
                  IconButton(onPressed: widget.onDelete, icon: const Icon(Icons.more_horiz_rounded, color: AppTheme.secondary)),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  itemCount: urls.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openViewer(i),
                    onDoubleTap: _doubleTapLike,
                    child: Image.network(
                      urls[i],
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: const Color(0xFFEEF3F0),
                        child: const Center(child: Icon(Icons.broken_image_outlined, size: 42, color: AppTheme.secondary)),
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const ColoredBox(
                          color: Color(0xFFEEF3F0),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
                        );
                      },
                    ),
                  ),
                ),
                const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.transparent, Color(0x33000000)],
                        stops: [0, 0.7, 1],
                      ),
                    ),
                  ),
                ),
                if (hasLoc)
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _openMaps,
                        borderRadius: BorderRadius.circular(999),
                        child: Ink(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10)],
                          ),
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 260),
                            padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(color: AppTheme.header, shape: BoxShape.circle),
                                  child: const Icon(Icons.place_rounded, size: 13, color: AppTheme.accent),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    post.location.trim(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: AppTheme.ink),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (urls.length > 1)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(999)),
                        child: Text(
                          '${_page + 1}/${urls.length}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                if (urls.length > 1)
                  Positioned(
                    bottom: hasLoc ? 48 : 12,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(urls.length, (i) {
                          final active = i == _page;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: active ? 16 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: active ? AppTheme.accent : Colors.white70,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                if (_showHeart)
                  Center(
                    child: IgnorePointer(
                      child: ScaleTransition(
                        scale: Tween(begin: 0.4, end: 1.2).animate(CurvedAnimation(parent: _heartCtrl, curve: Curves.elasticOut)),
                        child: FadeTransition(
                          opacity: Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _heartCtrl, curve: const Interval(0.55, 1))),
                          child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 84, shadows: [Shadow(blurRadius: 18, color: Colors.black45)]),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
            child: Row(
              children: [
                _ActionChip(
                  icon: post.likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  label: '${post.likesCount}',
                  active: post.likedByMe,
                  activeColor: const Color(0xFFE11D48),
                  onTap: widget.onLike,
                ),
                const SizedBox(width: 6),
                _ActionChip(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '${post.commentsCount}',
                  onTap: widget.onComment,
                ),
                const Spacer(),
                TextButton(
                  onPressed: widget.onComment,
                  style: TextButton.styleFrom(foregroundColor: AppTheme.primaryDark),
                  child: const Text('Komentar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                ),
              ],
            ),
          ),
          if (post.likesCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
              child: Text(
                post.likesCount == 1 ? 'Disukai 1 orang' : 'Disukai ${post.likesCount} orang',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink, fontSize: 12.5),
              ),
            ),
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: AppTheme.ink, height: 1.4, fontSize: 13.5),
                  children: [
                    TextSpan(text: '${post.userName} ', style: const TextStyle(fontWeight: FontWeight.w800)),
                    TextSpan(text: post.caption),
                  ],
                ),
              ),
            )
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.urls, required this.initialIndex});

  final List<String> urls;
  final int initialIndex;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _ctrl = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _ctrl,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  widget.urls[i],
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 56),
                ),
              ),
            ),
          ),
          Positioned(
            top: top + 8,
            left: 8,
            right: 8,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(backgroundColor: Colors.white12),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
                const Spacer(),
                if (widget.urls.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(999)),
                    child: Text(
                      '${_index + 1} / ${widget.urls.length}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.urls.length > 1)
            Positioned(
              bottom: MediaQuery.paddingOf(context).bottom + 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.urls.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: active ? AppTheme.accent : Colors.white38,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.activeColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final color = active ? (activeColor ?? AppTheme.primary) : AppTheme.ink;
    return Material(
      color: active ? color.withValues(alpha: 0.1) : AppTheme.bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.post, required this.onChanged});

  final FeedPost post;
  final VoidCallback onChanged;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  static const _emojis = ['❤️', '🙌', '🔥', '👏', '😢', '😍', '😮', '😂'];

  final _body = TextEditingController();
  final _focus = FocusNode();
  List<PostComment> _items = [];
  final Set<int> _expanded = {};
  bool _loading = true;
  bool _sending = false;
  PostComment? _replyTo;

  AuthState get _auth => context.read<AuthState>();
  ApiClient get _api => _auth.api;

  @override
  void initState() {
    super.initState();
    _body.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _body.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<PostComment> _repliesOf(int rootId) =>
      _items.where((c) => c.isReply && c.parentId == rootId).toList();

  List<PostComment> get _roots => _items.where((c) => !c.isReply).toList();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/api/posts/${widget.post.id}/comments');
      _items = asObjectList(res['data']).map(PostComment.fromJson).toList();
    } on ApiException catch (e) {
      if (mounted) showAppError(context, e.firstError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startReply(PostComment c) {
    setState(() => _replyTo = c);
    _focus.requestFocus();
  }

  void _cancelReply() => setState(() => _replyTo = null);

  void _insertEmoji(String emoji) {
    final t = _body.text;
    final sel = _body.selection;
    final start = sel.isValid ? sel.start : t.length;
    final end = sel.isValid ? sel.end : t.length;
    final next = t.replaceRange(start, end, emoji);
    _body.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    _focus.requestFocus();
  }

  Future<void> _send() async {
    final text = _body.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final payload = <String, dynamic>{'body': text};
      if (_replyTo != null) {
        payload['parent_id'] = _replyTo!.id;
        if (_replyTo!.isReply && _replyTo!.parentId != null) {
          _expanded.add(_replyTo!.parentId!);
        } else {
          _expanded.add(_replyTo!.id);
        }
      }
      await _api.post('/api/posts/${widget.post.id}/comments', payload);
      _body.clear();
      _replyTo = null;
      widget.onChanged();
      await _load();
    } on ApiException catch (e) {
      if (mounted) showAppError(context, e.firstError);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(PostComment c) async {
    try {
      await _api.delete('/api/comments/${c.id}');
      widget.onChanged();
      await _load();
    } on ApiException catch (e) {
      if (mounted) showAppError(context, e.firstError);
    }
  }

  Future<void> _toggleLike(PostComment c) async {
    final i = _items.indexWhere((e) => e.id == c.id);
    if (i < 0) return;
    final nextLiked = !c.likedByMe;
    final nextCount = c.likesCount + (nextLiked ? 1 : -1);
    setState(() => _items[i] = c.copyWith(likedByMe: nextLiked, likesCount: nextCount < 0 ? 0 : nextCount));
    try {
      final res = nextLiked
          ? await _api.post('/api/comments/${c.id}/like')
          : await _api.delete('/api/comments/${c.id}/like');
      final updated = PostComment.fromJson(res['data'] as Map<String, dynamic>);
      if (!mounted) return;
      final j = _items.indexWhere((e) => e.id == updated.id);
      if (j >= 0) setState(() => _items[j] = updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _items[i] = c);
      showAppError(context, e.firstError);
    }
  }

  InlineSpan _bodySpans(String body, {String replyToName = ''}) {
    var text = body;
    if (replyToName.isNotEmpty) {
      final prefix = '@$replyToName';
      if (text.startsWith(prefix)) {
        text = text.substring(prefix.length).trimLeft();
      }
    }
    final mention = RegExp(r'@(\S+)').allMatches(text);
    if (mention.isEmpty) return TextSpan(text: text);
    final children = <InlineSpan>[];
    var cursor = 0;
    for (final m in mention) {
      if (m.start > cursor) children.add(TextSpan(text: text.substring(cursor, m.start)));
      children.add(TextSpan(
        text: m.group(0),
        style: const TextStyle(color: Color(0xFF055C9D), fontWeight: FontWeight.w600),
      ));
      cursor = m.end;
    }
    if (cursor < text.length) children.add(TextSpan(text: text.substring(cursor)));
    return TextSpan(children: children);
  }

  Widget _avatar(String name, {double size = 32}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1FA86A), AppTheme.header],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.34),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = _auth.user!;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final roots = _roots;
    final hasText = _body.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(width: 36, height: 3.5, decoration: BoxDecoration(color: const Color(0xFFDBDBDB), borderRadius: BorderRadius.circular(99))),
              const SizedBox(
                height: 44,
                child: Center(
                  child: Text('Komentar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.ink)),
                ),
              ),
              const Divider(height: 1, thickness: 0.5, color: Color(0xFFEFEFEF)),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                    : roots.isEmpty
                        ? const Center(
                            child: Text(
                              'Belum ada komentar.\nJadi yang pertama.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.secondary, fontSize: 13, height: 1.4),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                            itemCount: roots.length,
                            itemBuilder: (_, i) {
                              final root = roots[i];
                              final replies = _repliesOf(root.id);
                              final expanded = _expanded.contains(root.id);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _IgCommentRow(
                                    comment: root,
                                    timeLabel: formatCommentTime(root.createdAt),
                                    bodySpan: _bodySpans(root.body),
                                    avatar: _avatar(root.userName, size: 32),
                                    canDelete: root.userId == me.id || me.isAdmin,
                                    onReply: () => _startReply(root),
                                    onDelete: () => _delete(root),
                                    onLike: () => _toggleLike(root),
                                  ),
                                  if (replies.isNotEmpty && !expanded)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 44, top: 2, bottom: 8),
                                      child: InkWell(
                                        onTap: () => setState(() => _expanded.add(root.id)),
                                        child: Row(
                                          children: [
                                            Container(width: 24, height: 1, color: const Color(0xFFDBDBDB)),
                                            const SizedBox(width: 10),
                                            Text(
                                              'Lihat ${replies.length} balasan lainnya',
                                              style: const TextStyle(
                                                color: AppTheme.secondary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (replies.isNotEmpty && expanded) ...[
                                    for (final r in replies)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 40),
                                        child: _IgCommentRow(
                                          comment: r,
                                          timeLabel: formatCommentTime(r.createdAt),
                                          bodySpan: _bodySpans(r.body, replyToName: r.replyToName),
                                          avatar: _avatar(r.userName, size: 24),
                                          canDelete: r.userId == me.id || me.isAdmin,
                                          onReply: () => _startReply(r),
                                          onDelete: () => _delete(r),
                                          onLike: () => _toggleLike(r),
                                          compact: true,
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 44, bottom: 6),
                                      child: InkWell(
                                        onTap: () => setState(() => _expanded.remove(root.id)),
                                        child: const Text(
                                          'Sembunyikan balasan',
                                          style: TextStyle(color: AppTheme.secondary, fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
              ),
              if (_replyTo != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  color: const Color(0xFFF7F7F7),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Membalas @${_replyTo!.userName}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.secondary, fontWeight: FontWeight.w600),
                        ),
                      ),
                      GestureDetector(
                        onTap: _cancelReply,
                        child: const Icon(Icons.close, size: 16, color: AppTheme.secondary),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 1, thickness: 0.5, color: Color(0xFFEFEFEF)),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  itemCount: _emojis.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 4),
                  itemBuilder: (_, i) => InkWell(
                    onTap: () => _insertEmoji(_emojis[i]),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(_emojis[i], style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      _avatar(me.name, size: 32),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.only(left: 14, right: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0xFFDBDBDB)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _body,
                                  focusNode: _focus,
                                  minLines: 1,
                                  maxLines: 3,
                                  style: const TextStyle(fontSize: 13, color: AppTheme.ink),
                                  decoration: InputDecoration(
                                    hintText: _replyTo == null
                                        ? 'Gabung dengan percakapan...'
                                        : 'Balas @${_replyTo!.userName}...',
                                    hintStyle: const TextStyle(fontSize: 13, color: AppTheme.secondary),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _send(),
                                ),
                              ),
                              if (hasText)
                                TextButton(
                                  onPressed: _sending ? null : _send,
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    _sending ? '...' : 'Kirim',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                )
                              else
                                IconButton(
                                  onPressed: () => _insertEmoji('😊'),
                                  icon: const Icon(Icons.sentiment_satisfied_alt_outlined, size: 22, color: AppTheme.secondary),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IgCommentRow extends StatelessWidget {
  const _IgCommentRow({
    required this.comment,
    required this.timeLabel,
    required this.bodySpan,
    required this.avatar,
    required this.canDelete,
    required this.onReply,
    required this.onDelete,
    required this.onLike,
    this.compact = false,
  });

  final PostComment comment;
  final String timeLabel;
  final InlineSpan bodySpan;
  final Widget avatar;
  final bool canDelete;
  final VoidCallback onReply;
  final VoidCallback onDelete;
  final VoidCallback onLike;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 10 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          avatar,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: compact ? 12.5 : 13, height: 1.25, color: AppTheme.ink),
                    children: [
                      TextSpan(text: comment.userName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (timeLabel.isNotEmpty)
                        TextSpan(
                          text: '  $timeLabel',
                          style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.w400, fontSize: 11.5),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: compact ? 12.5 : 13, height: 1.35, color: AppTheme.ink, fontWeight: FontWeight.w400),
                    children: [bodySpan],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onReply,
                      child: const Text(
                        'Balas',
                        style: TextStyle(color: AppTheme.secondary, fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (canDelete) ...[
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: onDelete,
                        child: const Text(
                          'Hapus',
                          style: TextStyle(color: AppTheme.secondary, fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: onLike,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 6, 8),
              child: Column(
                children: [
                  Icon(
                    comment.likedByMe ? Icons.favorite : Icons.favorite_border,
                    size: 14,
                    color: comment.likedByMe ? const Color(0xFFE11D48) : AppTheme.secondary,
                  ),
                  if (comment.likesCount > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${comment.likesCount}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: comment.likedByMe ? const Color(0xFFE11D48) : AppTheme.secondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
