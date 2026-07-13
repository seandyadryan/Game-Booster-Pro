import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_booster_pro/main.dart';

void main() {
  const channel = MethodChannel('game_booster_pro/system');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'getSystemStatus':
              return {
                'totalRamMb': 8192,
                'availableRamMb': 4096,
                'totalRamBytes': 8192 * 1024 * 1024,
                'availableRamBytes': 4096 * 1024 * 1024,
                'refreshRate': 120.0,
                'dndPermission': true,
                'dndEnabled': false,
              };
            case 'cleanCache':
              return 12 * 1024 * 1024;
            case 'closeBackgroundApps':
              return {
                'success': true,
                'message': 'Background aplikasi diringankan.',
              };
            case 'toggleDnd':
              return {
                'enabled': true,
                'permission': true,
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
    await tester.pump();
    expect(find.text('CONNECTING'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('DISCONNECT'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('GFX Tools'), findsOneWidget);
  });
}
