
import '../models/post.dart';
import '../models/post_author.dart';

final List<Post> samplePosts = [
  Post(
    id: 'post-1',
    author: const PostAuthor(
      id: 'user-1',
      displayName: 'سارا محمدی',
      username: 'sara_m',
      isVerified: true,
    ),
    content:
        'بعضی خاطره‌ها با گذشت زمان کمرنگ نمی‌شوند؛ فقط یاد می‌گیریم با حضور آرامشان در زندگی کنار بیاییم. گاهی یک گفت‌وگوی ساده با کسی که تجربه‌ای شبیه ما دارد، می‌تواند روزمان را کمی روشن‌تر کند.',
    createdAt: DateTime.now().subtract(const Duration(minutes: 18)),
    likeCount: 24,
    commentCount: 8,
  ),
  Post(
    id: 'post-2',
    author: const PostAuthor(
      id: 'user-2',
      displayName: 'علی رضایی',
      username: 'ali_rezaei',
    ),
    content:
        'امروز برای اولین بار بعد از مدت‌ها، یکی از خاطرات خوب گذشته را با لبخند تعریف کردم. دلتنگی هنوز هست، اما فهمیدم که لبخند زدن به خاطرات، چیزی از ارزش آن‌ها کم نمی‌کند.',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    likeCount: 41,
    commentCount: 12,
  ),
  Post(
    id: 'post-3',
    author: const PostAuthor(
      id: 'user-3',
      displayName: 'مریم کریمی',
      username: 'maryam_k',
    ),
    content:
        'گاهی لازم نیست برای آرام کردن کسی، پاسخ همه‌چیز را بدانیم. همین که کنارش بمانیم، بدون قضاوت گوش بدهیم و اجازه بدهیم احساساتش را بیان کند، می‌تواند ارزشمندترین همراهی باشد.',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    likeCount: 17,
    commentCount: 5,
  ),
];
