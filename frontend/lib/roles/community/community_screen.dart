import 'package:flutter/material.dart';
import 'package:agripulse/theme/app_theme.dart';
import 'package:agripulse/shared/services/api_service.dart';
import 'package:agripulse/shared/models/post.dart';
import 'package:agripulse/shared/widgets/common.dart';

/// Shared community feed (posts, likes) used by every role.
///
/// Holds the feed in plain state (not a `FutureBuilder`) so likes can update
/// instantly without re-fetching the whole list — that re-fetch was what made
/// liking feel slow.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _api = ApiService.instance;

  List<Post> _posts = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _api.get("/community/posts");
      final posts = (raw as List).map((j) => Post.fromJson(j)).toList();
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _newPost() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _NewPostDialog(controller: controller),
    );
    if (text == null) return; // user cancelled

    try {
      final created = await _api.post("/community/posts", {"text": text});
      if (!mounted) return;
      // Show the new post immediately at the top — no full reload needed.
      setState(() => _posts = [Post.fromJson(created), ..._posts]);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Posted!")));
    } catch (e) {
      if (mounted) showResultDialog(context, "Could not post", "$e");
    }
  }

  Future<void> _like(int index) async {
    final p = _posts[index];
    // Optimistic update: bump the count now, roll back if the call fails.
    setState(() => _posts[index] = p.copyWith(likes: p.likes + 1));
    try {
      await _api.post("/community/posts/${p.id}/like");
    } catch (_) {
      if (!mounted) return;
      setState(() => _posts[index] = p); // revert
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Couldn't like — try again")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _newPost,
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _ErrorRetry(message: "$_error", onRetry: _fetch);
    }
    if (_posts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            "No posts yet.\nTap + to share something with the community.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textFaint),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView.builder(
        itemCount: _posts.length,
        itemBuilder: (_, i) {
          final p = _posts[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              title: Text(p.text),
              subtitle: Text("❤ ${p.likes}",
                  style: const TextStyle(color: AppTheme.lightGreen)),
              trailing: IconButton(
                icon: const Icon(Icons.favorite, color: AppTheme.accentYellow),
                onPressed: () => _like(i),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Compose dialog. Keeps its own state so the "Post" button can stay disabled
/// until the farmer has actually typed something — this is what stops empty,
/// "information-less" posts from being sent.
class _NewPostDialog extends StatefulWidget {
  final TextEditingController controller;
  const _NewPostDialog({required this.controller});
  @override
  State<_NewPostDialog> createState() => _NewPostDialogState();
}

class _NewPostDialogState extends State<_NewPostDialog> {
  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.trim().isNotEmpty;
    return AlertDialog(
      title: const Text("New post"),
      content: TextField(
        controller: widget.controller,
        maxLines: 4,
        autofocus: true,
        onChanged: (_) => setState(() {}), // refresh button enabled-state
        decoration: const InputDecoration(
          hintText: "Describe your crop problem or share a tip…",
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        FilledButton(
          onPressed: hasText
              ? () => Navigator.pop(context, widget.controller.text.trim())
              : null,
          child: const Text("Post"),
        ),
      ],
    );
  }
}

/// Friendly error state with a retry button (e.g. backend unreachable).
class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: AppTheme.accentYellow),
              const SizedBox(height: 12),
              Text("Couldn't load posts.\n$message",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textFaint)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
}
