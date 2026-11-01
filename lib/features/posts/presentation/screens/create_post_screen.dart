import 'package:flutter/material.dart';

import '../../../auth/data/auth_repository.dart';
import '../../data/posts_repository.dart';
import '../../models/post.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({
    super.key,
    required this.authRepository,
    required this.onPostCreated,
  });

  final AuthRepository authRepository;
  final ValueChanged<Post> onPostCreated;

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  final _postsRepository = PostsRepository();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    if (_isSubmitting) return;

    final content = _contentController.text.trim();

    if (content.isEmpty) {
      setState(() {
        _errorMessage = 'لطفاً متن پست را وارد کن.';
      });
      return;
    }

    if (content.length > 10000) {
      setState(() {
        _errorMessage = 'متن پست نمی‌تواند بیشتر از ۱۰۰۰۰ کاراکتر باشد.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final token = await widget.authRepository.readAccessToken();

      if (token == null || token.isEmpty) {
        throw Exception(
          'نشست کاربری معتبر نیست. لطفاً خارج شو و دوباره وارد حساب شو.',
        );
      }

      final post = await _postsRepository.createPublicPost(
        content: content,
        token: token,
      );

      if (!mounted) return;

      _contentController.clear();

      setState(() {
        _isSubmitting = false;
      });

      widget.onPostCreated(post);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
        _errorMessage = _friendlyErrorMessage(error);
      });
    }
  }

  String _friendlyErrorMessage(Object error) {
    final message = error.toString();

    if (message.contains('SocketException') ||
        message.contains('Connection refused')) {
      return 'ارتباط با سرور برقرار نشد. از روشن بودن بک‌اند مطمئن شو.';
    }

    return message;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final content = _contentController.text.trim();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  colors.primaryContainer,
                  colors.surfaceContainerHighest,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.edit_note_rounded,
                    color: colors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'حرف دلت را بنویس',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'گاهی نوشتن از احساسات و خاطره‌ها، راهی برای ارتباط و همراهی با دیگران است.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.9,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'متن نوشته',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _contentController,
            enabled: !_isSubmitting,
            autofocus: false,
            minLines: 7,
            maxLines: 14,
            maxLength: 10000,
            keyboardType: TextInputType.multiline,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.start,
            onChanged: (_) {
              setState(() {
                _errorMessage = null;
              });
            },
            decoration: InputDecoration(
              hintText:
                  'هر آنچه دوست داری با دیگران در میان بگذاری، اینجا بنویس...',
              hintMaxLines: 3,
              alignLabelWithHint: true,
              filled: true,
              fillColor: colors.surface,
              contentPadding: const EdgeInsets.all(18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: colors.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: colors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.public_rounded, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'این نوشته به‌صورت عمومی منتشر می‌شود.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: colors.onErrorContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _isSubmitting || content.isEmpty ? null : _submitPost,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _isSubmitting ? 'در حال انتشار...' : 'انتشار نوشته',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'پیش از انتشار، مطمئن شو که متن نوشته اطلاعات خصوصی دیگران را افشا نمی‌کند.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}
