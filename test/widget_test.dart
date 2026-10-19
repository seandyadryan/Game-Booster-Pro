import 'dart:convert';
import 'dart:ui' show FrameTiming;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_booster_pro/main.dart';
import 'package:game_booster_pro/system_tools.dart';
import 'package:game_booster_pro/fps_monitor.dart';

void main() {
  const channel = MethodChannel('game_booster_pro/system');

  TestWidgetsFlutterBinding.ensureInitialized();
  var dnd = false;
  var permission = true;
  var failDisable = false;
  var failCache = false;
  var ownBytes = 12 * 1024 * 1024;
  var failNetwork = false;
  final calls = <String>[];
  final packages = <String>[];

  setUp(() {
    dnd = false;
    permission = true;
    failDisable = false;
    failCache = false;
    ownBytes = 12 * 1024 * 1024;
    failNetwork = false;
    calls.clear();
    packages.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'hasUsageAccess':
            case 'hasOverlayAccess':
              return true;
            case 'getOwnCacheStats':
              return {'cacheBytes': ownBytes};
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
              return {'success': true, 'message': 'App management opened.'};
            case 'toggleDnd':
              if (failDisable && (call.arguments as Map)['enabled'] == false) {
                throw PlatformException(
                  code: 'DENIED',
                  message: 'Do Not Disturb permission revoked.',
                );
              }
              dnd = permission && (call.arguments as Map)['enabled'] == true;
              return {
                'enabled': dnd,
                'permission': permission,
                'message': 'Do Not Disturb is active.',
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
      await tester.tap(find.text(throughGfx ? 'Display & games' : 'My games'));
      await tester.pumpAndSettle();
      if (throughGfx) {
        await tester.tap(
          find.widgetWithText(ListTile, 'Launch game with display bar'),
        );
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
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(packages, ['com.example.gametwo']);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shows booster dashboard', (tester) async {
    await tester.pumpWidget(const GameBoosterProApp());
    await tester.pump();

    expect(find.text('Game Tools'), findsOneWidget);
    expect(find.text('Start Session'), findsOneWidget);
    expect(find.text('RAM'), findsNothing);
    expect(find.text('Disconnected'), findsNothing);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    await tester.tap(find.text('Start Session'));
    await tester.pumpAndSettle();
    expect(find.text('Starting Session'), findsOneWidget);
    await tester.tap(find.text('Enable'));
    await tester.pumpAndSettle();
    expect(find.text('End Session'), findsOneWidget);
    expect(calls, isNot(contains('closeBackgroundApps')));
    await tester.tap(find.text('End Session'));
    await tester.pumpAndSettle();
    expect(dnd, isFalse);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Display & games'), findsOneWidget);
    await tester.tap(find.text('Display & games'));
    await tester.pumpAndSettle();
    expect(find.text('APPLY PROFILE'), findsNothing);
    await tester.tap(find.text('Android display settings'));
    await tester.pump();
    expect(calls, contains('openDisplaySettings'));
  });

  testWidgets('Boost cleans cache even without Do Not Disturb access', (
    tester,
  ) async {
    permission = false;
    await tester.pumpWidget(const GameBoosterProApp());
    await tester.pump();
    await tester.tap(find.text('Start Session'));
    await tester.pumpAndSettle();
    expect(find.text('End Session'), findsOneWidget);
    expect(calls, contains('cleanCache'));
    expect(calls, isNot(contains('toggleDnd')));
    expect(
      find.textContaining('12.0 MB before, 12.0 MB cleared, 0 B remaining'),
      findsOneWidget,
    );
  });

  testWidgets('failed disconnect keeps the session available for retry', (
    tester,
  ) async {
    await tester.pumpWidget(const GameBoosterProApp());
    await tester.pump();
    await tester.tap(find.text('Start Session'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enable'));
    await tester.pumpAndSettle();
    failDisable = true;
    await tester.tap(find.text('End Session'));
    await tester.pumpAndSettle();
    expect(find.text('End Session'), findsOneWidget);
    expect(find.text('Do Not Disturb permission revoked.'), findsOneWidget);
  });

  testWidgets('existing DND is preserved when a session ends', (tester) async {
    dnd = true;
    await tester.pumpWidget(const GameBoosterProApp());
    await tester.pump();
    await tester.tap(find.text('Start Session'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End Session'));
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
    await tester.tap(find.text('Start Session'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('FPS menu does not relabel screen refresh rate', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const GameBoosterProApp());
    await tester.pump();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(find.text('Animation FPS'), findsOneWidget);
    expect(find.text('This app only'), findsOneWidget);
    expect(find.text('FPS'), findsNothing);
    expect(find.text('Refresh rate'), findsNothing);
    expect(find.text('120 Hz'), findsNothing);
    expect(find.text('120 FPS'), findsNothing);
    await tester.tap(find.text('Animation FPS'));
    await tester.pumpAndSettle();
    expect(find.text('App animation only'), findsOneWidget);
    expect(find.textContaining('Game FPS is unavailable.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard restores original rocket artwork', (tester) async {
    await tester.pumpWidget(const GameBoosterProApp());
    await tester.pump();
    final images = tester.widgetList<Image>(find.byType(Image));
    expect(
      images.any(
        (image) =>
            image.image is AssetImage &&
            (image.image as AssetImage).assetName == 'assets/flying_rocket.png',
      ),
      isTrue,
    );
    expect(
      images.any(
        (image) =>
            image.image is AssetImage &&
            (image.image as AssetImage).assetName == 'assets/app_icon.png',
      ),
      isFalse,
    );
  });

  testWidgets(
    'store presentation describes settings and avoids rejected claims',
    (tester) async {
      await tester.pumpWidget(const GameBoosterProApp());
      await tester.pump();
      for (final rejectedLabel in [
        'Game Booster Pro',
        'BOOST NOW',
        'AI Network',
        'GFX Tools',
        'Clear recent apps',
        'Background',
        'FPS',
      ]) {
        expect(find.text(rejectedLabel), findsNothing);
      }
      expect(find.text('Network Latency'), findsOneWidget);
      await tester.ensureVisible(find.text('App settings'));
      await tester.pumpAndSettle();
      expect(find.text('Open settings'), findsOneWidget);
      await tester.tap(find.text('App settings'));
      await tester.pumpAndSettle();
      expect(
        calls.where((method) => method == 'closeBackgroundApps').length,
        1,
      );
    },
  );

  test(
    'frame cadence uses actual frame intervals and includes slow frames',
    () {
      final window = FrameRateWindow();
      expect(window.add(0), isNull);
      double? fps;
      for (var index = 1; index <= 60; index++) {
        fps = window.add((index * 1000000 / 60).round()) ?? fps;
      }
      expect(fps, closeTo(60, 0.01));
      expect(window.add(5000000), closeTo(0.25, 0.001));
      expect(window.add(5000000), isNull);
      expect(window.add(4000000), isNull);
      window.reset();
      expect(window.add(0), isNull);
      for (var index = 1; index <= 30; index++) {
        fps = window.add((index * 1000000 / 30).round()) ?? fps;
      }
      expect(fps, closeTo(30, 0.01));
    },
  );

  testWidgets('FPS sampling stops on pause and disposes safely', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FpsMonitorSheet())),
    );
    await tester.pumpAndSettle();
    expect(find.text('-- FPS'), findsOneWidget);
    await tester.tap(find.text('Start measurement'));
    await tester.pump();
    expect(find.text('Measuring...'), findsOneWidget);
    tester.binding.platformDispatcher.onReportTimings!([
      for (var index = 0; index <= 60; index++)
        FrameTiming(
          vsyncStart: (index * 1000000 / 60).round(),
          buildStart: (index * 1000000 / 60).round() + 100,
          buildFinish: (index * 1000000 / 60).round() + 200,
          rasterStart: (index * 1000000 / 60).round() + 300,
          rasterFinish: (index * 1000000 / 60).round() + 400,
          rasterFinishWallTime: (index * 1000000 / 60).round() + 400,
        ),
    ]);
    await tester.pump();
    expect(find.text('60.0 FPS'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.text('-- FPS'), findsOneWidget);
    expect(find.text('Start measurement'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.tap(find.text('Start measurement'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty cache reports zero instead of invented freed space', (
    tester,
  ) async {
    ownBytes = 0;
    permission = false;
    await tester.pumpWidget(const GameBoosterProApp());
    await tester.pump();
    await tester.tap(find.text('Start Session'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('0 B before, 0 B cleared, 0 B remaining'),
      findsOneWidget,
    );
  });

  testWidgets('failed cleanup does not start a boost session', (tester) async {
    failCache = true;
    await tester.pumpWidget(const GameBoosterProApp());
    await tester.pump();
    await tester.tap(find.text('Start Session'));
    await tester.pumpAndSettle();
    expect(find.text('Cache cleanup failed.'), findsOneWidget);
    expect(find.text('End Session'), findsNothing);
  });

  testWidgets('cache sheet clears cache and shows before and after', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppCacheSheet(
            readCache: () async => ownBytes,
            clearCache: () async {
              final before = ownBytes;
              ownBytes = 0;
              return {
                'beforeBytes': before,
                'afterBytes': 0,
                'freedBytes': before,
                'failedFiles': 0,
              };
            },
            onTopApps: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('12.0 MB'), findsOneWidget);
    await tester.tap(find.text('Clear This App\'s Cache'));
    await tester.pumpAndSettle();
    expect(find.text('Cleared'), findsOneWidget);
    expect(find.text('Remaining'), findsOneWidget);
    expect(find.text('0 B'), findsNWidgets(2));
  });

  testWidgets(
    'Network Latency renders measured values and failures and retries',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: NetworkCheckSheet(channel: channel)),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, isNot(contains('checkNetworkLatency')));
      await tester.tap(find.text('Check now'));
      await tester.pumpAndSettle();
      expect(find.text('Wi-Fi'), findsOneWidget);
      expect(find.text('1 / 5'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('0.0 ms'), findsNothing);
      expect(find.text('16.0 ms'), findsNWidgets(3));
      failNetwork = true;
      await tester.ensureVisible(find.text('Check again'));
      await tester.tap(find.text('Check again'));
      await tester.pumpAndSettle();
      expect(find.text('No active network.'), findsOneWidget);
      expect(find.text('16.0 ms'), findsNothing);
      expect(find.text('Check now'), findsOneWidget);
    },
  );
}
