import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../widgets/app_logo.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.error, this.onRetry});

  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 120),
              const SizedBox(height: 24),
              const Text(
                AppInfo.name,
                textDirection: TextDirection.ltr,
                style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              const Text(
                'مستنداتك العربية… بصوتك أنت',
                style: TextStyle(color: Colors.white70, fontSize: 17),
              ),
              const SizedBox(height: 40),
              if (error == null)
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 3),
                )
              else ...[
                Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black),
                  onPressed: onRetry,
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
