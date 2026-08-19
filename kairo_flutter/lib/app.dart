import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/providers/social_summary_provider.dart';
import 'core/providers/theme_provider.dart';
import 'features/auth/services/auth_notifier.dart';
import 'features/auth/services/auth_service.dart';
import 'features/auth/views/signin_view.dart';
import 'features/auth/views/signup_view.dart';
import 'features/chat/views/chat_thread_view.dart';
import 'features/chat/views/chat_view.dart';
import 'features/admin/views/church_requests_admin_view.dart';
import 'features/events/providers/church_admin_provider.dart';
import 'features/events/providers/events_provider.dart';
import 'features/events/views/events_view.dart';
import 'features/feed/views/create_post_view.dart';
import 'features/feed/views/feed_view.dart';
import 'features/home/views/home_view.dart';
import 'features/notifications/views/notifications_view.dart';
import 'features/posts/providers/posts_provider.dart';
import 'features/profile/views/profile_view.dart';
import 'features/settings/views/settings_view.dart';
import 'features/videos/views/videos_view.dart';

class KairoApp extends StatefulWidget {
  const KairoApp({super.key});

  @override
  State<KairoApp> createState() => _KairoAppState();
}

class _KairoAppState extends State<KairoApp> {
  late final AuthNotifier _authNotifier;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authNotifier = AuthNotifier();
    _router = GoRouter(
      refreshListenable: _authNotifier,
      initialLocation: '/',
      redirect: (context, state) {
        final loggedIn = AuthService().isSignedIn;
        final path = state.matchedLocation;
        final isAuth = path.startsWith('/auth');
        final isPublic = path == '/' || path == '/feed' || path == '/videos' || path == '/events' || path.startsWith('/profile');

        if (path == '/feed/create' && !loggedIn) return '/auth/signin';
        if (path == '/notifications' && !loggedIn) return '/auth/signin';
        if (path == '/settings' && !loggedIn) return '/auth/signin';
        if (path == '/admin/churches' && !loggedIn) return '/auth/signin';
        if (path.startsWith('/chat/') && path != '/chat' && !loggedIn) return '/auth/signin';
        if (loggedIn && isAuth) return '/feed';
        if (!loggedIn && !isAuth && !isPublic) return '/auth/signin';
        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HomeView()),
        GoRoute(
          path: '/auth/signin',
          builder: (context, state) {
            final registered = state.uri.queryParameters['registered'] == 'true';
            return SignInView(registeredSuccess: registered);
          },
        ),
        GoRoute(path: '/auth/signup', builder: (_, __) => const SignUpView()),
        GoRoute(path: '/feed', builder: (_, __) => const FeedView()),
        GoRoute(path: '/feed/create', builder: (_, __) => const CreatePostView()),
        GoRoute(path: '/videos', builder: (_, __) => const VideosView()),
        GoRoute(path: '/chat', builder: (_, __) => const ChatView()),
        GoRoute(
          path: '/chat/:userId',
          builder: (context, state) => ChatThreadView(
            otherUserId: state.pathParameters['userId']!,
            otherUserName: Uri.decodeComponent(state.uri.queryParameters['name'] ?? 'Chat'),
          ),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => ProfileView(userId: state.uri.queryParameters['userId']),
        ),
        GoRoute(path: '/notifications', builder: (_, __) => const NotificationsView()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsView()),
        GoRoute(path: '/events', builder: (_, __) => const EventsView()),
        GoRoute(path: '/admin/churches', builder: (_, __) => const ChurchRequestsAdminView()),
      ],
    );
  }

  @override
  void dispose() {
    _authNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PostsProvider()),
        ChangeNotifierProvider(create: (_) => EventsProvider()),
        ChangeNotifierProvider(create: (_) => ChurchAdminProvider()),
        ChangeNotifierProvider(create: (_) => SocialSummaryProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp.router(
          title: 'KAIRO',
          debugShowCheckedModeBanner: false,
          theme: theme.theme,
          routerConfig: _router,
        ),
      ),
    );
  }
}
