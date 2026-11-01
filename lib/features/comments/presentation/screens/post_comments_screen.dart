
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
  Comment? _replyingTo;

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
        throw Exception(
          'برای مشاهده گفتگوها باید وارد حساب کاربری شوید.',
        );
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
        _isLoading = false;
        _errorMessage = _readableError(error);
      });
    }
  }

  Future<void> _submitComment() async {
    final content = _controller.text.trim();

    if (_isSubmitting || content.isEmpty) return;

    if (content.length > 5000) {
      _showMessage('متن دیدگاه نمی‌تواند بیشتر از ۵۰۰۰ کاراکتر باشد.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final token = await widget.authRepository.readAccessToken();

      if (token == null || token.isEmpty) {
        throw Exception('برای ثبت دیدگاه باید وارد حساب کاربری شوید.');
      }

      final parentComment = _replyingTo;

      final createdComment = await _repository.createComment(
        postId: widget.post.id,
        content: content,
        token: token,
        parentCommentId: parentComment?.id,
      );

      if (!mounted) return;

      setState(() {
        _insertCommentInOrder(createdComment);
        _hasCreatedComment = true;
        _isSubmitting = false;
        _replyingTo = null;
        _controller.clear();
      });

      _focusNode.unfocus();
      _showMessage(
        parentComment == null
            ? 'دیدگاه شما ثبت شد.'
            : 'پاسخ شما ثبت شد.',
      );
    } catch (error) {
      if (!mounted) return;

      setState(() => _isSubmitting = false);
      _showMessage(_readableError(error));
    }
  }

  void _insertCommentInOrder(Comment comment) {
    if (!comment.isReply) {
      _comments = [..._comments, comment];
      return;
    }

    final parentId = comment.parentCommentId;
    if (parentId == null) {
      _comments = [..._comments, comment];
      return;
    }

    var insertIndex = _comments.indexWhere(
      (item) => item.id == parentId,
    );

    if (insertIndex == -1) {
      _comments = [..._comments, comment];
      return;
    }

    insertIndex++;

    while (insertIndex < _comments.length &&
        _comments[insertIndex].parentCommentId == parentId) {
      insertIndex++;
    }

    final updatedComments = [..._comments];
    updatedComments.insert(insertIndex, comment);
    _comments = updatedComments;
  }

  void _startReply(Comment comment) {
    final target = comment.isReply
        ? _findParentComment(comment)
        : comment;

    if (target == null) {
      _showMessage('دیدگاه اصلی برای پاسخ دادن پیدا نشد.');
      return;
    }

    setState(() => _replyingTo = target);
    _focusNode.requestFocus();
  }

  Comment? _findParentComment(Comment comment) {
    final parentId = comment.parentCommentId;

    if (parentId == null) return null;

    for (final item in _comments) {
      if (item.id == parentId) return item;
    }

    return null;
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
    _focusNode.unfocus();
  }

  String _readableError(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }

    return message;
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) return 'همین حالا';
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} دقیقه پیش';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} ساعت پیش';
    }
    if (difference.inDays == 1) return 'دیروز';
    if (difference.inDays < 7) {
      return '${difference.inDays} روز پیش';
    }

    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  void _handleBack() {
    Navigator.of(context).pop(_hasCreatedComment);
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
          leading: IconButton(
            onPressed: _handleBack,
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'بازگشت',
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Text(
                widget.post.content,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.8),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
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
                    onPressed: _isLoading ? null : _loadComments,
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'بارگذاری مجدد',
                  ),
                ],
              ),
            ),
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
              const Icon(Icons.cloud_off_rounded, size: 42),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loadComments,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('تلاش دوباره'),
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
                Icons.forum_outlined,
                size: 48,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                'هنوز دیدگاهی ثبت نشده است.',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'اولین دیدگاه را شما بنویسید.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final commentsById = {
      for (final comment in _comments) comment.id: comment,
    };

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: _comments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final comment = _comments[index];
        final parent = comment.parentCommentId == null
            ? null
            : commentsById[comment.parentCommentId];

        return Padding(
          padding: EdgeInsetsDirectional.only(
            start: comment.isReply ? 22 : 0,
          ),
          child: CommentCard(
            key: ValueKey(comment.id),
            comment: comment,
            timeLabel: _formatTime(comment.createdAt),
            onReply: () => _startReply(comment),
            replyToName: parent?.author.displayName,
            isReplying: _replyingTo?.id == comment.id,
          ),
        );
      },
    );
  }

  Widget _buildComposer(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final replyingTo = _replyingTo;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(color: colors.outlineVariant),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyingTo != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.reply_rounded,
                    size: 18,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'در پاسخ به ${replyingTo.author.displayName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _isSubmitting ? null : _cancelReply,
                    child: const Text('لغو'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: !_isSubmitting,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 5000,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: replyingTo == null
                          ? 'دیدگاه خود را بنویسید...'
                          : 'پاسخ خود را بنویسید...',
                      counterText: '',
                      filled: true,
                      fillColor: colors.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: colors.outlineVariant,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: colors.outlineVariant,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: colors.primary,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: IconButton.filled(
                    onPressed: _isSubmitting ? null : _submitComment,
                    tooltip: replyingTo == null
                        ? 'ثبت دیدگاه'
                        : 'ثبت پاسخ',
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
