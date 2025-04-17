import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flame/flame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await initWindowManager();

  await dotenv.load(fileName: ".env");
  await Flame.device.fullScreen();
  await Flame.device.setPortrait();

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await MobileAds.instance.initialize();
  }

  runApp(const ProviderScope(
    child: PaletteMasterApp(),
  ));
}

Future<void> initWindowManager() async {
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
    return;
  }

  const size = Size(600, 1000);
  await windowManager.ensureInitialized();
  final windowOptions = WindowOptions(
    maximumSize: size,
    minimumSize: size,
    size: size,
    center: true,
    backgroundColor: const Color.fromARGB(255, 255, 255, 255),
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'Palette Master',
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
