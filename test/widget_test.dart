import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_booster_pro/main.dart';

void main() {
  const channel = MethodChannel('game_booster_pro/system');

  TestWidgetsFlutterBinding.ensureInitialized();
  var dnd = false;
  var permission = true;
  var failDisable = false;
  final calls = <String>[];
  final packages = <String>[];

  setUp(() {
    dnd = false;
    permission = true;
    failDisable = false;
    calls.clear();
    packages.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'listGames':
              return [
                {'name': 'Test Game', 'packageName': 'com.example.gameone'},
                {'name': 'Test Game', 'packageName': 'com.example.gametwo'},
              ];
            case 'getGameIcon':
              return base64Decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
              );
            case 'launchGame':
              packages.add((call.arguments as Map)['packageName'] as String);
              return null;
            case 'getSystemStatus':
              return {
                'totalRamMb': 8192,
                'availableRamMb': 4096,
                'totalRamBytes': 8192 * 1024 * 1024,
                'availableRamBytes': 4096 * 1024 * 1024,
                'refreshRate': 120.0,
                'dndPermission': permission,
                'dndEnabled': dnd,
                'batteryPercent': 78,
                'batteryTemperature': 32.5,
              };
            case 'cleanCache':
              return 12 * 1024 * 1024;
            case 'closeBackgroundApps':
              return {'success': true, 'message': 'App management opened.'};
            case 'toggleDnd':
              if (failDisable && (call.arguments as Map)['enabled'] == false) {
                throw PlatformException(
                  code: 'DENIED',
                  message: 'Dont Disturb permission revoked.',
                );
              }
              dnd = permission && (call.arguments as Map)['enabled'] == true;
              return {
                'enabled': dnd,
                'permission': permission,
                'message': 'Dont Disturb is active.',
              };
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  for (final throughGfx in [false, true]) {
    testWidgets('game icon and package launch through GFX: $throughGfx', (
      tester,
    ) async {
      await tester.pumpWidget(const GameBoosterProApp());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.text(throughGfx ? 'GFX Tools' : 'My games'));
      await tester.pumpAndSettle();
      if (throughGfx) {
        await tester.tap(find.widgetWithText(ListTile, 'Launch game'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Test Game'), findsNWidgets(2));
      expect(calls.where((method) => method == 'getGameIcon').length, 2);
      expect(
        find
            .byType(Image)
            .evaluate()
            .where((element) => (element.widget as Image).image is MemoryImage)
            .length,
        2,
      );
      await tester.tap(find.text('com.example.gametwo'));
      await tester.pumpAndSettle();
      expect(packages, ['com.example.gametwo']);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shows booster dashboard', (tester) async {
    await tester.pumpWidget(const GameBoosterProApp());
    await tester.pump();

    expect(find.text('Game Booster Pro'), findsOneWidget);
    expect(find.text('BOOST NOW'), findsOneWidget);
    expect(find.text('RAM'), findsNothing);
    expect(find.text('Disconnected'), findsNothing);
    expect(find.byIcon(Icons.rocket_launch), findsOneWidget);

    await tester.tap(find.text('BOOST NOW'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enable'));
    await tester.pump();
    expect(find.text('CONNECTING'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('DISCONNECT'), findsOneWidget);
    expect(calls, isNot(contains('closeBackgroundApps')));
    await tester.tap(find.text('DISCONNECT'));
    await tester.pumpAndSettle();
    expect(dnd, isFalse);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('GFX Tools'), findsOneWidget);
    await tester.tap(find.text('GFX Tools'));
    await tester.pumpAndSettle();
    expect(find.text('APPLY PROFILE'), findsNothing);
    await tester.tap(find.text('Android display settings'));
    await tester.pump();
    expect(calls, contains('openDisplaySettings'));
  });

  testWidgets('permission denial never reports a connected boost', (
    tester,
  ) async {
    permission = false;
    await tester.pumpWidget(const GameBoosterProApp());
    await tester.pump();
    await tester.tap(find.text('BOOST NOW'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enable'));
    await tester.pumpAndSettle();
    expect(find.text('DISCONNECT'), findsNothing);
    expect(calls, isNot(contains('cleanCache')));
  });

  testWidgets('failed disconnect keeps the session available for retry', (
    tester,
  ) async {
    await tester.pumpWidget(const GameBoosterProApp());
    await tester.pump();
    await tester.tap(find.text('BOOST NOW'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enable'));
    await tester.pumpAndSettle();
    failDisable = true;
    await tester.tap(find.text('DISCONNECT'));
    await tester.pumpAndSettle();
    expect(find.text('DISCONNECT'), findsOneWidget);
    expect(find.text('Dont Disturb permission revoked.'), findsOneWidget);
  });

  testWidgets('existing DND is preserved when a session ends', (tester) async {
    dnd = true;
    await tester.pumpWidget(const GameBoosterProApp());
    await tester.pump();
    await tester.tap(find.text('BOOST NOW'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DISCONNECT'));
    await tester.pumpAndSettle();
    expect(dnd, isTrue);
    expect(calls, isNot(contains('toggleDnd')));
  });

  testWidgets('disposing a running flight does not raise a ticker error', (
    tester,
  ) async {
    dnd = true;
    await tester.pumpWidget(const GameBoosterProApp());
    await tester.pump();
    await tester.tap(find.text('BOOST NOW'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('small screen reports real display telemetry', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const GameBoosterProApp());
    await tester.pump();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(find.text('120 Hz'), findsOneWidget);
    expect(find.text('120 FPS'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
