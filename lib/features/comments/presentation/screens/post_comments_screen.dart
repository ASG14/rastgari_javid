import 'package:flutter/material.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../posts/models/post.dart';
import '../../data/comments_repository.dart';
import '../../models/comment.dart';
import '../widgets/comment_card.dart';

class PostCommentsScreen extends StatefulWidget {
  const PostCommentsScreen({
    super.key,
    required this.post,
    required this.authRepository,
  });

  final Post post;
  final AuthRepository authRepository;

  @override
  State<PostCommentsScreen> createState() => _PostCommentsScreenState();
}

class _PostCommentsScreenState extends State<PostCommentsScreen> {
  final CommentsRepository _repository = CommentsRepository();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Comment> _comments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _hasCreatedComment = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await widget.authRepository.readAccessToken();

      if (token == null || token.isEmpty) {
        throw Exception('برای مشاهده گفتگوها باید وارد حساب کاربری شوید.');
      }

      final comments = await _repository.getPostComments(
        postId: widget.post.id,
        token: token,
      );

      if (!mounted) return;

      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _submitComment() async {
    final content = _controller.text.trim();

    if (_isSubmitting || content.isEmpty) return;

    if (content.length > 5000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('متن دیدگاه نمی‌تواند بیشتر از ۵۰۰۰ کاراکتر باشد.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final token = await widget.authRepository.readAccessToken();

      if (token == null || token.isEmpty) {
        throw Exception('برای ثبت دیدگاه باید وارد حساب کاربری شوید.');
      }

      final comment = await _repository.createComment(
        postId: widget.post.id,
        content: content,
        token: token,
      );

      if (!mounted) return;

      setState(() {
        _comments = [..._comments, comment];
        _hasCreatedComment = true;
        _isSubmitting = false;
      });

      _controller.clear();
      _focusNode.unfocus();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('دیدگاه شما با موفقیت ثبت شد.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ثبت دیدگاه ناموفق بود: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatTime(DateTime date) {
    final difference = DateTime.now().difference(date);

    if (difference.inSeconds < 60) return 'همین حالا';
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} دقیقه پیش';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} ساعت پیش';
    }
    if (difference.inDays == 1) return 'دیروز';
    if (difference.inDays < 7) return '${difference.inDays} روز پیش';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<bool> _handleBack() async {
    Navigator.of(context).pop(_hasCreatedComment);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('گفتگوها'),
          centerTitle: false,
          leading: IconButton(
            tooltip: 'بازگشت',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _handleBack,
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'گفتگو درباره نوشته',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.post.content,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.8),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Text(
                    'دیدگاه‌ها',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_comments.length}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'بارگذاری مجدد',
                    onPressed: _isLoading ? null : _loadComments,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(child: _buildCommentsBody(context)),
            _buildComposer(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsBody(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 42, color: colors.error),
              const SizedBox(height: 12),
              Text(
                'دریافت دیدگاه‌ها ناموفق بود',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadComments,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('تلاش مجدد'),
              ),
            ],
          ),
        ),
      );
    }

    if (_comments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 46,
                color: colors.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'هنوز دیدگاهی ثبت نشده است',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'می‌توانی اولین نفری باشی که به این نوشته پاسخ می‌دهد.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.8,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: _comments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final comment = _comments[index];

        return CommentCard(
          key: ValueKey(comment.id),
          comment: comment,
          timeLabel: _formatTime(comment.createdAt),
        );
      },
    );
  }

  Widget _buildComposer(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                minLines: 1,
                maxLines: 5,
                maxLength: 5000,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'دیدگاه خود را بنویس...',
                  counterText: '',
                  filled: true,
                  fillColor: colors.surfaceContainerHighest.withValues(
                    alpha: 0.55,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 48,
              height: 48,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submitComment,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
