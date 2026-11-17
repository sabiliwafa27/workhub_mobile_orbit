import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/navigation/home_navigation.dart';
import 'core/services/fcm_notification_service.dart';
import 'core/theme/orbit_backdrop.dart';
import 'core/theme/orbit_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/home/screens/orbit_main_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: WorkHubApp(),
    ),
  );
}

class WorkHubApp extends ConsumerWidget {
  const WorkHubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Automatically trigger FCM token synchronization upon successful user authentication
    ref.listen<AuthState>(authProvider, (previous, next) {
      if ((previous == null || !previous.isAuthenticated) &&
          next.isAuthenticated) {
        ref.read(fcmNotificationServiceProvider).initialize();
      }
    });

    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Orbit WorkHub',
      debugShowCheckedModeBanner: false,
      theme: OrbitTheme.lightTheme,
      navigatorObservers: [homeNavigationObserver],
      builder: (context, child) =>
          OrbitBackdrop(child: child ?? const SizedBox.shrink()),
      home: authState.isAuthenticated
          ? const OrbitMainShell()
          : const LoginScreen(),
    );
  }
}
