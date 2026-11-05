import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app_services.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'services/reader_audio_handler.dart';
import 'state/settings_controller.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/splash_screen.dart';

class Ma5zyaApp extends StatefulWidget {
  const Ma5zyaApp({super.key});

  @override
  State<Ma5zyaApp> createState() => _Ma5zyaAppState();
}

class _Ma5zyaAppState extends State<Ma5zyaApp> {
  late Future<AppServices> _boot = _bootstrap();

  static ReaderAudioHandler? _handler;

  static Future<AppServices> _bootstrap() async {
    final started = DateTime.now();
    if (_handler == null) {
      try {
        _handler = await AudioService.init(
          builder: ReaderAudioHandler.new,
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.adsero.ma5zya.audio',
            androidNotificationChannelName: 'القراءة الصوتية',
            androidNotificationOngoing: true,
            androidStopForegroundOnPause: true,
          ),
        );
      } catch (e) {
        // Background / lock-screen controls unavailable; in-app playback still works.
        debugPrint('AudioService.init failed: $e');
        _handler = ReaderAudioHandler();
      }
      try {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.speech());
      } catch (_) {}
    }
    final services = await AppServices.create(_handler!);
    final elapsed = DateTime.now().difference(started);
    const minSplash = Duration(milliseconds: 1200);
    if (elapsed < minSplash) await Future<void>.delayed(minSplash - elapsed);
    return services;
  }

  Widget _app({required Widget home, ThemeMode mode = ThemeMode.light}) {
    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: mode,
      home: home,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppServices>(
      future: _boot,
      builder: (context, snap) {
        final s = snap.data;
        if (s == null) {
          return _app(
            home: SplashScreen(
              error: snap.hasError ? 'تعذر تشغيل التطبيق: ${snap.error}' : null,
              onRetry: () => setState(() => _boot = _bootstrap()),
            ),
          );
        }
        return MultiProvider(
          providers: [
            Provider.value(value: s),
            ChangeNotifierProvider.value(value: s.settings),
            ChangeNotifierProvider.value(value: s.library),
            ChangeNotifierProvider.value(value: s.voices),
            ChangeNotifierProvider.value(value: s.readAloud),
          ],
          child: Consumer<SettingsController>(
            builder: (context, settings, _) => _app(home: const HomeShell(), mode: settings.themeMode),
          ),
        );
      },
    );
  }
}
