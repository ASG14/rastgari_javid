import 'package:flutter/material.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../auth/models/auth_user.dart';
import '../../../posts/presentation/screens/post_feed_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.user,
    required this.authRepository,
    this.feedRefreshVersion = 0,
  });

  final AuthUser user;
  final AuthRepository authRepository;
  final int feedRefreshVersion;

  @override
  Widget build(BuildContext context) {
    return PostFeedScreen(
      key: ValueKey(feedRefreshVersion),
      user: user,
      authRepository: authRepository,
    );
  }
}
