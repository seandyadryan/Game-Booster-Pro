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
            case 'enableDnd':
              return {
                'enabled': true,
                'permission': true,
                'message': 'Mode DND aktif.',
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
    expect(find.byIcon(Icons.rocket_launch), findsOneWidget);
  });
}
