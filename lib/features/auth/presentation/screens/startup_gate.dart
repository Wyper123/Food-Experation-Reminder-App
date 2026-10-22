import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_colors.dart';
import 'package:food_expiration_reminder/features/auth/presentation/controllers/session_controller.dart';
import 'package:food_expiration_reminder/features/auth/presentation/screens/login_screen.dart';
import 'package:food_expiration_reminder/features/navigation/presentation/screens/main_navigation_screen.dart';
import 'package:provider/provider.dart';

/// Root screen: shows the app when signed in and the login screen otherwise.
/// Signing in or out anywhere switches this automatically.
class StartupGate extends StatelessWidget {
  const StartupGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    if (session.isRestoring) return const _Splash();
    return session.isSignedIn
        ? const MainNavigationScreen()
        : const LoginScreen();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppColors.brandGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Icon(Icons.eco_rounded, color: Colors.white, size: 38),
        ),
      ),
    );
  }
}
