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
  var failCache = false;
  var ownBytes = 12 * 1024 * 1024;
  var failNetwork = false;
  var emptyGames = false;
  var failLaunch = false;
  final calls = <String>[];
  final launches = <Map<dynamic, dynamic>>[];

  setUp(() {
    dnd = false;
    permission = true;
    failDisable = failCache = failNetwork = emptyGames = failLaunch = false;
    ownBytes = 12 * 1024 * 1024;
    calls.clear();
    launches.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'hasUsageAccess':
            case 'hasOverlayAccess':
              return true;
            case 'getOwnCacheStats':
              return {'cacheBytes': ownBytes};
            case 'getSystemStatus':
              return {
                'refreshRate': 120.0,
                'dndPermission': permission,
                'dndEnabled': dnd,
                'batteryPercent': 78,
                'batteryTemperature': 32.5,
              };
            case 'listGames':
              return emptyGames
                  ? []
                  : [
                      {
                        'name': 'Test Game',
                        'packageName': 'com.example.gameone',
                      },
                      {
                        'name': 'Test Game',
                        'packageName': 'com.example.gametwo',
                      },
                    ];
            case 'getGameIcon':
              return base64Decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
              );
            case 'launchGame':
              if (failLaunch) {
                throw PlatformException(
                  code: 'SYSTEM_ERROR',
                  message: 'Game is no longer installed.',
                );
              }
              launches.add(Map<dynamic, dynamic>.from(call.arguments as Map));
              return {'launched': true};
            case 'cleanCache':
              if (failCache) {
                throw PlatformException(
                  code: 'CACHE_ERROR',
                  message: 'Cache cleanup failed.',
                );
              }
              final before = ownBytes;
              ownBytes = 0;
              return {
                'beforeBytes': before,
                'afterBytes': 0,
                'freedBytes': before,
                'failedFiles': 0,
              };
            case 'closeBackgroundApps':
              return {
                'success': true,
                'message':
                    'Android app settings opened. No apps have been closed or changed.',
              };
            case 'toggleDnd':
              final enabled = (call.arguments as Map)['enabled'] == true;
              if (failDisable && !enabled) {
                throw PlatformException(
                  code: 'DENIED',
                  message: 'Do Not Disturb permission revoked.',
                );
              }
              dnd = permission && enabled;
              return {
                'enabled': dnd,
                'permission': permission,
                'message': 'Do Not Disturb request processed.',
              };
            case 'checkNetworkLatency':
              if (failNetwork) {
                throw PlatformException(
                  code: 'NETWORK_ERROR',
                  message: 'No active network.',
                );
              }
              return {
                'networkType': 'Wi-Fi',
                'endpoint': '1.1.1.1:443',
                'samplesMs': [12.0, null, 16.0, 20.0, 16.0],
                'averageMs': 16.0,
                'minMs': 12.0,
                'maxMs': 20.0,
                'jitterMs': 4.0,
                'failedProbes': 1,
                'totalProbes': 5,
              };
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> openTile(WidgetTester tester, String title) async {
    await tester.scrollUntilVisible(
      find.text(title),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  for (final displayBar in [false, true]) {
    testWidgets(
      'launch correct package with explicit display bar: $displayBar',
      (tester) async {
        await tester.pumpWidget(const GameBoosterProApp());
        await tester.pump();
        if (displayBar) {
          await openTile(tester, 'Display & games');
          await tester.tap(
            find.widgetWithText(ListTile, 'Launch game with display bar'),
          );
          await tester.pumpAndSettle();
        } else {
          await tester.tap(find.text('Open game library'));
          await tester.pumpAndSettle();
        }
        expect(find.text('Test Game'), findsNWidgets(2));
        expect(calls.where((method) => method == 'getGameIcon').length, 2);
        expect(
          tester
              .widgetList<Image>(find.byType(Image))
              .where((image) => image.image is MemoryImage)
              .length,
          2,
        );
        await tester.tap(find.text('com.example.gametwo'));
        await tester.pumpAndSettle();
        if (displayBar) {
          await tester.tap(find.text('Continue'));
          await tester.pumpAndSettle();
        }
        expect(launches, [
          {'packageName': 'com.example.gametwo', 'showDisplayBar': displayBar},
        ]);
        if (!displayBar) {
          expect(calls, isNot(contains('hasOverlayAccess')));
          expect(calls, isNot(contains('hasUsageAccess')));
        }
        for (final sideEffect in [
          'cleanCache',
          'toggleDnd',
          'closeBackgroundApps',
        ]) {
          expect(calls, isNot(contains(sideEffect)));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'canceling overlay disclosure does not launch or request access',
    (tester) async {
      await tester.pumpWidget(const GameBoosterProApp());
      await tester.pump();
      await openTile(tester, 'Display & games');
      await tester.tap(find.text('Launch game with display bar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('com.example.gameone'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(launches, isEmpty);
      expect(calls, isNot(contains('hasOverlayAccess')));
    },
  );

  testWidgets('no games shows an honest empty state', (tester) async {
    emptyGames = true;
    await tester.pumpWidget(const GameBoosterProApp());
    await tester.pump();
    await tester.tap(find.text('Open game library'));
    await tester.pumpAndSettle();
    expect(
      find.text('No apps identified as games were found on this device.'),
      findsOneWidget,
    );
    expect(launches, isEmpty);
  });

  testWidgets('launch failure is reported without success or optimization', (
    tester,
  ) async {
    failLaunch = true;
    await tester.pumpWidget(const GameBoosterProApp());
    await tester.pump();
    await tester.tap(find.text('Open game library'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('com.example.gameone'));
    await tester.pumpAndSettle();
    expect(find.text('Game is no longer installed.'), findsOneWidget);
    expect(launches, isEmpty);
  });

  testWidgets('DND is explicit, consented and reversible', (tester) async {
    await tester.pumpWidget(const GameBoosterProApp());
    await tester.pump();
    await openTile(tester, 'Do Not Disturb');
    expect(calls, isNot(contains('toggleDnd')));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(dnd, isFalse);
    await openTile(tester, 'Do Not Disturb');
    await tester.tap(find.text('Enable'));
    await tester.pumpAndSettle();
    expect(dnd, isTrue);
    await openTile(tester, 'Do Not Disturb');
    expect(dnd, isFalse);
  });

  testWidgets('DND disable failure preserves the active state for retry', (
    tester,
  ) async {
    dnd = true;
    failDisable = true;
    await tester.pumpWidget(const GameBoosterProApp());
    await tester.pump();
    await openTile(tester, 'Do Not Disturb');
    expect(dnd, isTrue);
    expect(find.text('Active'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 900));
    await tester.pumpAndSettle();
    expect(find.text('Do Not Disturb permission revoked.'), findsOneWidget);
  });

  testWidgets('opening the library preserves existing DND', (tester) async {
    dnd = true;
    await tester.pumpWidget(const GameBoosterProApp());
    await tester.pump();
    await tester.tap(find.text('Open game library'));
    await tester.pumpAndSettle();
    expect(dnd, isTrue);
    expect(calls, isNot(contains('toggleDnd')));
  });

  testWidgets('disposing decorative flight does not raise a ticker error', (
    tester,
  ) async {
    await tester.pumpWidget(const GameBoosterProApp());
    await tester.pump();
    await tester.tap(find.text('Open game library'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('small screen reports Hz, never game FPS or a fake session', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const GameBoosterProApp());
    await tester.pump();
    expect(find.text('Game Tools'), findsOneWidget);
    expect(find.text('Open game library'), findsOneWidget);
    await tester.ensureVisible(find.text('Screen refresh rate'));
    await tester.pumpAndSettle();
    expect(find.text('120 Hz'), findsOneWidget);
    for (final label in [
      'Game Booster Pro',
      'BOOST NOW',
      'AI Network',
      'GFX Tools',
      'Background',
      'FPS',
      'Animation FPS',
      'Start Session',
      'Session',
      'Connected',
      'Clear recent apps',
    ]) {
      expect(find.text(label), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('original rocket asset is preserved', (tester) async {
    await tester.pumpWidget(const GameBoosterProApp());
    await tester.pump();
    expect(
      tester
          .widgetList<Image>(find.byType(Image))
          .any(
            (image) =>
                image.image is AssetImage &&
                (image.image as AssetImage).assetName ==
                    'assets/flying_rocket.png',
          ),
      isTrue,
    );
  });

  testWidgets('app settings only invokes the settings shortcut', (
    tester,
  ) async {
    await tester.pumpWidget(const GameBoosterProApp());
    await tester.pump();
    await openTile(tester, 'App settings');
    expect(calls.where((method) => method == 'closeBackgroundApps').length, 1);
    expect(calls, isNot(contains('cleanCache')));
  });

  for (final empty in [false, true]) {
    testWidgets('own-cache cleanup uses actual byte counts, empty: $empty', (
      tester,
    ) async {
      if (empty) ownBytes = 0;
      await tester.pumpWidget(const GameBoosterProApp());
      await tester.pump();
      await openTile(tester, 'This app\'s cache');
      await tester.tap(find.text('Clear This App\'s Cache'));
      await tester.pumpAndSettle();
      expect(calls, contains('cleanCache'));
      expect(ownBytes, 0);
      expect(find.text('Before cleanup'), findsOneWidget);
      expect(find.text('Cleared'), findsOneWidget);
      expect(find.text('Remaining'), findsOneWidget);
      if (empty) {
        expect(
          find.text('No temporary cache files were found.'),
          findsOneWidget,
        );
      } else {
        expect(find.text('12.0 MB'), findsNWidgets(2));
      }
      expect(calls, isNot(contains('toggleDnd')));
    });
  }

  testWidgets('cache errors do not invent successful cleanup', (tester) async {
    failCache = true;
    await tester.pumpWidget(const GameBoosterProApp());
    await tester.pump();
    await openTile(tester, 'This app\'s cache');
    await tester.tap(find.text('Clear This App\'s Cache'));
    await tester.pumpAndSettle();
    expect(find.text('Cache cleanup failed.'), findsOneWidget);
    expect(find.text('Cleared'), findsNothing);
  });

  testWidgets(
    'network check runs on request and clears stale results on failure',
    (tester) async {
      await tester.pumpWidget(const GameBoosterProApp());
      await tester.pump();
      await openTile(tester, 'Network Latency');
      expect(calls, isNot(contains('checkNetworkLatency')));
      await tester.tap(find.text('Check now'));
      await tester.pumpAndSettle();
      expect(find.text('Wi-Fi'), findsOneWidget);
      expect(find.text('1 / 5'), findsOneWidget);
      expect(find.text('16.0 ms'), findsNWidgets(3));
      expect(find.text('0.0 ms'), findsNothing);
      failNetwork = true;
      await tester.ensureVisible(find.text('Check again'));
      await tester.tap(find.text('Check again'));
      await tester.pumpAndSettle();
      expect(find.text('No active network.'), findsOneWidget);
      expect(find.text('16.0 ms'), findsNothing);
    },
  );
}
