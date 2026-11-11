import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/erp_colors.dart';
import 'core/theme/whatsapp_colors.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/home/screens/whatsapp_main_screen.dart';

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
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'WorkHub Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: ErpColors.primaryNavy,
          primary: ErpColors.primaryNavy,
        ),
        scaffoldBackgroundColor: ErpColors.scaffoldBackground,
        fontFamily: 'Roboto',
      ),
      home: authState.isAuthenticated ? const WhatsAppMainScreen() : const LoginScreen(),
    );
  }
}
