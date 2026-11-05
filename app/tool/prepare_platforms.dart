// Generates the android/ and ios/ folders with `flutter create` (matching the installed
// Flutter version) and applies 4Ma5zya's configuration: app name, permissions, background
// audio service, minSdk, optional release signing and iOS Info.plist keys.
//
// Usage (from the app/ folder):  dart run tool/prepare_platforms.dart
import 'dart:io';

void main() async {
  final root = Directory.current;
  if (!File('${root.path}/pubspec.yaml').existsSync()) {
    stderr.writeln('Run this from the app/ folder (where pubspec.yaml is).');
    exit(1);
  }

  if (!Directory('android').existsSync() || !Directory('ios').existsSync()) {
    stdout.writeln('> flutter create (android, ios)');
    final r = await Process.run(
      'flutter',
      ['create', '--org', 'com.adsero', '--project-name', 'ma5zya', '--platforms', 'android,ios', '.'],
      runInShell: true,
    );
    stdout.write(r.stdout);
    stderr.write(r.stderr);
    if (r.exitCode != 0) exit(r.exitCode);
  }

  _android();
  _ios();
  stdout.writeln('Platform folders are ready.');
}

void _android() {
  File('android/app/src/main/AndroidManifest.xml')
      .writeAsStringSync(File('platform_overrides/android/AndroidManifest.xml').readAsStringSync());
  stdout.writeln('  android: AndroidManifest.xml applied');

  // The default MainActivity is replaced by AudioServiceActivity in the manifest; remove it to avoid confusion.
  for (final f in Directory('android/app/src/main').listSync(recursive: true)) {
    if (f is File && (f.path.endsWith('MainActivity.kt') || f.path.endsWith('MainActivity.java'))) {
      f.deleteSync();
    }
  }

  final kts = File('android/app/build.gradle.kts');
  final groovy = File('android/app/build.gradle');
  if (kts.existsSync()) {
    var s = kts.readAsStringSync();
    s = s.replaceAll(RegExp(r'minSdk\s*=\s*flutter\.minSdkVersion'), 'minSdk = 24');
    if (!s.contains('keystoreProperties')) {
      s = 'import java.io.FileInputStream\nimport java.util.Properties\n\n$s';
      s = s.replaceFirst(
        RegExp(r'\nandroid\s*\{'),
        '\nval keystoreProperties = Properties()\n'
            'val keystorePropertiesFile = rootProject.file("key.properties")\n'
            'if (keystorePropertiesFile.exists()) {\n'
            '    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n'
            '}\n\nandroid {',
      );
      s = s.replaceFirst(
        RegExp(r'\n(\s*)buildTypes\s*\{'),
        '\n    signingConfigs {\n'
            '        create("release") {\n'
            '            if (keystorePropertiesFile.exists()) {\n'
            '                keyAlias = keystoreProperties["keyAlias"] as String\n'
            '                keyPassword = keystoreProperties["keyPassword"] as String\n'
            '                storeFile = file(keystoreProperties["storeFile"] as String)\n'
            '                storePassword = keystoreProperties["storePassword"] as String\n'
            '            }\n'
            '        }\n'
            '    }\n\n    buildTypes {',
      );
      s = s.replaceAll(
        'signingConfig = signingConfigs.getByName("debug")',
        'signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") '
            'else signingConfigs.getByName("debug")',
      );
    }
    kts.writeAsStringSync(s);
    stdout.writeln('  android: build.gradle.kts patched (minSdk 24, release signing)');
  } else if (groovy.existsSync()) {
    var s = groovy.readAsStringSync();
    s = s.replaceAll(RegExp(r'minSdk(Version)?\s*=?\s*flutter\.minSdkVersion'), 'minSdk = 24');
    if (!s.contains('keystoreProperties')) {
      s = s.replaceFirst(
        RegExp(r'\nandroid\s*\{'),
        '\ndef keystoreProperties = new Properties()\n'
            "def keystorePropertiesFile = rootProject.file('key.properties')\n"
            'if (keystorePropertiesFile.exists()) {\n'
            '    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))\n'
            '}\n\nandroid {',
      );
      s = s.replaceFirst(
        RegExp(r'\n(\s*)buildTypes\s*\{'),
        '\n    signingConfigs {\n'
            '        release {\n'
            '            if (keystorePropertiesFile.exists()) {\n'
            "                keyAlias = keystoreProperties['keyAlias']\n"
            "                keyPassword = keystoreProperties['keyPassword']\n"
            "                storeFile = file(keystoreProperties['storeFile'])\n"
            "                storePassword = keystoreProperties['storePassword']\n"
            '            }\n'
            '        }\n'
            '    }\n\n    buildTypes {',
      );
      s = s.replaceAll(
        'signingConfig = signingConfigs.debug',
        'signingConfig = keystorePropertiesFile.exists() ? signingConfigs.release : signingConfigs.debug',
      );
    }
    groovy.writeAsStringSync(s);
    stdout.writeln('  android: build.gradle patched (minSdk 24, release signing)');
  } else {
    stderr.writeln('  android: no app build.gradle found!');
    exit(1);
  }
}

void _ios() {
  final plist = File('ios/Runner/Info.plist');
  if (!plist.existsSync()) {
    stderr.writeln('  ios: Info.plist not found, skipped');
    return;
  }
  var s = plist.readAsStringSync();
  s = s.replaceAllMapped(
    RegExp(r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)'),
    (m) => '${m[1]}4Ma5zya${m[2]}',
  );
  s = s.replaceAllMapped(
    RegExp(r'(<key>CFBundleDevelopmentRegion</key>\s*<string>)[^<]*(</string>)'),
    (m) => '${m[1]}ar${m[2]}',
  );
  if (!s.contains('NSMicrophoneUsageDescription')) {
    final additions = File('platform_overrides/ios/info_plist_additions.xml').readAsStringSync();
    final idx = s.lastIndexOf('</dict>');
    s = '${s.substring(0, idx)}$additions${s.substring(idx)}';
  }
  plist.writeAsStringSync(s);

  // Raise the iOS deployment target to 13.0 (required by some audio/PDF plugins).
  final pbx = File('ios/Runner.xcodeproj/project.pbxproj');
  if (pbx.existsSync()) {
    pbx.writeAsStringSync(pbx
        .readAsStringSync()
        .replaceAll(RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = \d+\.\d+;'), 'IPHONEOS_DEPLOYMENT_TARGET = 13.0;'));
  }
  final podfile = File('ios/Podfile');
  if (podfile.existsSync()) {
    podfile.writeAsStringSync(
        podfile.readAsStringSync().replaceAll(RegExp(r"#?\s*platform :ios, '[\d.]+'"), "platform :ios, '13.0'"));
  }
  stdout.writeln('  ios: Info.plist patched (name, microphone, background audio), target iOS 13');
}
