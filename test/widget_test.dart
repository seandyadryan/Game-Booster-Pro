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

  setUp(() {
    dnd = false;
    permission = true;
    failDisable = false;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          switch (call.method) {
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
              return {
                'success': true,
                'message': 'Background aplikasi diringankan.',
              };
            case 'toggleDnd':
              if (failDisable && (call.arguments as Map)['enabled'] == false) {
                throw PlatformException(
                  code: 'DENIED',
                  message: 'Izin DND dicabut.',
                );
              }
              dnd = permission && (call.arguments as Map)['enabled'] == true;
              return {
                'enabled': dnd,
                'permission': permission,
                'message': 'Mode Dont Disturb aktif.',
              };
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('shows booster dashboard', (tester) async {
    await tester.pumpWidget(const GameBoosterProApp());
    await tester.pump();

    expect(find.text('Game Booster Pro'), findsOneWidget);
    expect(find.text('BOOST SEKARANG'), findsOneWidget);
    expect(find.text('RAM'), findsNothing);
    expect(find.text('Disconnected'), findsNothing);
    expect(find.byIcon(Icons.rocket_launch), findsOneWidget);

    await tester.tap(find.text('BOOST SEKARANG'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aktifkan'));
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
    expect(find.text('TERAPKAN PROFIL'), findsNothing);
    await tester.tap(find.text('Pengaturan layar Android'));
    await tester.pump();
    expect(calls, contains('openDisplaySettings'));
  });

  testWidgets('permission denial never reports a connected boost', (
    tester,
  ) async {
    permission = false;
    await tester.pumpWidget(const GameBoosterProApp());
    await tester.pump();
    await tester.tap(find.text('BOOST SEKARANG'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aktifkan'));
    await tester.pumpAndSettle();
    expect(find.text('DISCONNECT'), findsNothing);
    expect(calls, isNot(contains('cleanCache')));
  });

  testWidgets('failed disconnect keeps the session available for retry', (
    tester,
  ) async {
    await tester.pumpWidget(const GameBoosterProApp());
    await tester.pump();
    await tester.tap(find.text('BOOST SEKARANG'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aktifkan'));
    await tester.pumpAndSettle();
    failDisable = true;
    await tester.tap(find.text('DISCONNECT'));
    await tester.pumpAndSettle();
    expect(find.text('DISCONNECT'), findsOneWidget);
    expect(find.text('Izin DND dicabut.'), findsOneWidget);
  });

  testWidgets('existing DND is preserved when a session ends', (tester) async {
    dnd = true;
    await tester.pumpWidget(const GameBoosterProApp());
    await tester.pump();
    await tester.tap(find.text('BOOST SEKARANG'));
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
    await tester.tap(find.text('BOOST SEKARANG'));
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
