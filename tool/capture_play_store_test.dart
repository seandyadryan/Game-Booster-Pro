import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_booster_pro/main.dart';

// Capture the actual Flutter widgets. Native telemetry is left unavailable, not simulated.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('game_booster_pro/system');

  for (final desktop in [false, true]) {
    testWidgets('capture ${desktop ? 'desktop' : 'phone'} store screenshots', (
      tester,
    ) async {
      final logicalSize = desktop
          ? const Size(1280, 720)
          : const Size(432, 768);
      tester.view.physicalSize = logicalSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => null);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      final key = GlobalKey();
      final fontRoot =
          '${Platform.environment['USERPROFILE']!.replaceAll('\\', '/')}/fvm/versions/3.41.2/bin/cache/artifacts/material_fonts';
      await tester.runAsync(() async {
        final fonts = FontLoader('Roboto');
        for (final name in [
          'roboto-regular.ttf',
          'roboto-medium.ttf',
          'roboto-bold.ttf',
          'roboto-black.ttf',
        ]) {
          fonts.addFont(
            File(
              '$fontRoot/$name',
            ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          );
        }
        await fonts.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
      });
      await tester.pumpWidget(
        RepaintBoundary(key: key, child: const GameBoosterProApp()),
      );
      await tester.pumpAndSettle();
      // Give the asset decoder time to finish before capturing the rocket.
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();

      Future<void> capture(String name) async {
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: desktop ? 1.5 : 2.5);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final folder = Directory(
            '${Platform.environment['CAPTURE_OUTPUT'] ?? 'play_store'}/${desktop ? 'desktop' : 'phone'}',
          );
          await folder.create(recursive: true);
          await File(
            '${folder.path}/$name.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('01-dashboard');
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -620));
      await tester.pumpAndSettle();
      await capture('02-tools');
      {
        await tester.ensureVisible(find.text('Animation FPS'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Animation FPS'));
        await tester.pumpAndSettle();
        await capture('05-fps');
        Navigator.of(tester.element(find.text('App animation only'))).pop();
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('Display & games'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Display & games'));
      await tester.pumpAndSettle();
      await capture('03-display-game-tools');
      final context = tester.element(find.text('Android display settings'));
      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 900));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Network Latency'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Network Latency'));
      await tester.pumpAndSettle();
      await capture('04-network-latency');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
