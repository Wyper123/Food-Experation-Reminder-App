import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_constants.dart';
import 'package:food_expiration_reminder/core/theme/app_theme.dart';

/// Shown instead of the app when startup fails, so the user sees what went
/// wrong rather than a frozen launch screen.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Builder(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return Scaffold(
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(28),
                children: [
                  const SizedBox(height: 40),
                  Icon(Icons.error_outline_rounded, size: 56, color: cs.error),
                  const SizedBox(height: 20),
                  Text(
                    '${AppConstants.appName} could not start',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Close the app and open it again. If this keeps '
                    'happening, reinstall it or send this message to the '
                    'developer:',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    '$error',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
