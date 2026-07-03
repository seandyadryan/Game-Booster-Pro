import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';

void main() {
  runApp(const GameBoosterProApp());
}

class GameBoosterProApp extends StatelessWidget {
  const GameBoosterProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Game Booster Pro',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF20D38B),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0F0C),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const BoosterDashboard(),
    );
  }
}

class BoosterDashboard extends StatefulWidget {
  const BoosterDashboard({super.key});

  @override
  State<BoosterDashboard> createState() => _BoosterDashboardState();
}

class _BoosterDashboardState extends State<BoosterDashboard>
    with SingleTickerProviderStateMixin {
  static const MethodChannel _platform = MethodChannel(
    'game_booster_pro/system',
  );

  late final AnimationController _flightController;
  Timer? _refreshTimer;

  double _ramUsedPercent = 0;
  int _totalRamBytes = 0;
  int _availableRamBytes = 0;
  double _refreshRate = 0;
  double _appFps = 0;
  int _fpsFrameCount = 0;
  int _fpsMicros = 0;
  bool _boosting = false;
  bool _dndEnabled = false;
  bool _dndPermission = false;
  String _status = 'Siap mengoptimalkan sesi game.';

  @override
  void initState() {
    super.initState();
    _flightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    SchedulerBinding.instance.addTimingsCallback(_handleFrameTimings);
    _loadSystemStatus();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadSystemStatus(silent: true),
    );
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_handleFrameTimings);
    _refreshTimer?.cancel();
    _flightController.dispose();
    super.dispose();
  }

  void _handleFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _fpsFrameCount++;
      _fpsMicros += timing.totalSpan.inMicroseconds;
    }

    if (_fpsMicros >= Duration.microsecondsPerSecond && mounted) {
      setState(() {
        _appFps = _fpsFrameCount * Duration.microsecondsPerSecond / _fpsMicros;
        _fpsFrameCount = 0;
        _fpsMicros = 0;
      });
    }
  }

  Future<void> _loadSystemStatus({bool silent = false}) async {
    try {
      final data = await _platform.invokeMapMethod<String, dynamic>(
        'getSystemStatus',
      );
      if (!mounted || data == null) {
        return;
      }

      final total = (data['totalRamMb'] as num?)?.toInt() ?? 0;
      final available = (data['availableRamMb'] as num?)?.toInt() ?? 0;
      final totalBytes =
          (data['totalRamBytes'] as num?)?.toInt() ?? total * 1024 * 1024;
      final availableBytes =
          (data['availableRamBytes'] as num?)?.toInt() ??
          available * 1024 * 1024;
      final used = totalBytes <= 0
          ? 0
          : ((totalBytes - availableBytes) / totalBytes).clamp(0, 1);

      setState(() {
        _totalRamBytes = totalBytes;
        _availableRamBytes = availableBytes;
        _ramUsedPercent = used.toDouble();
        _refreshRate = (data['refreshRate'] as num?)?.toDouble() ?? 0;
        _dndEnabled = data['dndEnabled'] == true;
        _dndPermission = data['dndPermission'] == true;
        if (!silent) {
          _status = 'Status sistem diperbarui.';
        }
      });
    } on PlatformException catch (error) {
      if (!mounted || silent) {
        return;
      }
      setState(() => _status = error.message ?? 'Gagal membaca sistem.');
    }
  }

  Future<void> _runBoost() async {
    if (_boosting) {
      return;
    }

    setState(() {
      _boosting = true;
      _status = 'Boost berjalan...';
    });
    _flightController.forward(from: 0);

    final freed = await _cleanCache();
    await _closeBackgroundApps();
    final dndResult = await _enableDnd();
    await _loadSystemStatus(silent: true);

    if (!mounted) {
      return;
    }

    setState(() {
      _boosting = false;
      _status = dndResult
          ? 'Boost selesai. Cache ${_formatStorage(freed)} dibersihkan.'
          : 'Boost selesai. Dont Disturb menunggu izin sistem.';
    });
  }

  Future<int> _cleanCache() async {
    try {
      final freed = await _platform.invokeMethod<int>('cleanCache') ?? 0;
      if (mounted) {
        setState(() => _status = 'Cache ${_formatStorage(freed)} dibersihkan.');
      }
      return freed;
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () => _status = error.message ?? 'Cache belum bisa dibersihkan.',
        );
      }
      return 0;
    }
  }

  Future<bool> _closeBackgroundApps() async {
    try {
      final result = await _platform.invokeMapMethod<String, dynamic>(
        'closeBackgroundApps',
      );
      if (mounted) {
        setState(
          () =>
              _status = result?['message'] as String? ?? 'Memori diringankan.',
        );
      }
      return result?['success'] == true;
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () => _status = error.message ?? 'Background belum bisa ditutup.',
        );
      }
      return false;
    }
  }

  Future<bool> _enableDnd() async {
    try {
      final result = await _platform.invokeMapMethod<String, dynamic>(
        'enableDnd',
      );
      final enabled = result?['enabled'] == true;
      if (mounted) {
        setState(() {
          _dndEnabled = enabled;
          _dndPermission = result?['permission'] == true;
          _status =
              result?['message'] as String? ?? 'Mode Dont Disturb diproses.';
        });
      }
      return enabled;
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () =>
              _status = error.message ?? 'Dont Disturb belum bisa diaktifkan.',
        );
      }
      return false;
    }
  }

  String _formatStorage(int bytes) {
    if (bytes <= 0) {
      return '0 MB';
    }
    final mb = bytes / (1024 * 1024);
    if (mb < 1024) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    return '${(mb / 1024).toStringAsFixed(2)} GB';
  }

  String _formatMemory(int bytes) {
    if (bytes <= 0) {
      return '-';
    }
    final gb = bytes / (1024 * 1024 * 1024);
    if (gb >= 1) {
      return '${gb.toStringAsFixed(1)} GB';
    }
    return '${(bytes / (1024 * 1024)).round()} MB';
  }

  @override
  Widget build(BuildContext context) {
    final usedRamBytes = math.max(_totalRamBytes - _availableRamBytes, 0);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;

            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0B0F0C),
                    Color(0xFF162016),
                    Color(0xFF101012),
                  ],
                ),
              ),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 18 : 28,
                      20,
                      compact ? 18 : 28,
                      12,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _Header(
                        ramUsedPercent: _ramUsedPercent,
                        usedRam: _formatMemory(usedRamBytes),
                        availableRam: _formatMemory(_availableRamBytes),
                        totalRam: _formatMemory(_totalRamBytes),
                        boosting: _boosting,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 18 : 28,
                      vertical: 8,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _BoosterCore(
                        animation: _flightController,
                        boosting: _boosting,
                        status: _status,
                        onBoost: _runBoost,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 18 : 28,
                      12,
                      compact ? 18 : 28,
                      28,
                    ),
                    sliver: SliverGrid.count(
                      crossAxisCount: compact ? 2 : 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: compact ? 1.05 : 1.22,
                      children: [
                        _ActionTile(
                          icon: Icons.cleaning_services_outlined,
                          title: 'Cache',
                          value: 'Bersihkan',
                          color: const Color(0xFF20D38B),
                          onTap: _cleanCache,
                        ),
                        _ActionTile(
                          icon: Icons.layers_clear_outlined,
                          title: 'Background',
                          value: 'Ringankan',
                          color: const Color(0xFFFFB000),
                          onTap: _closeBackgroundApps,
                        ),
                        _ActionTile(
                          icon: _dndEnabled
                              ? Icons.notifications_off
                              : Icons.notifications_paused_outlined,
                          title: 'Dont Disturb',
                          value: _dndEnabled
                              ? 'Aktif'
                              : (_dndPermission ? 'Siap' : 'Butuh izin'),
                          color: const Color(0xFFFA5D5D),
                          onTap: _enableDnd,
                        ),
                        _ActionTile(
                          icon: Icons.speed_outlined,
                          title: 'FPS',
                          value: _appFps > 0
                              ? '${_appFps.round()} FPS'
                              : (_refreshRate > 0
                                    ? '${_refreshRate.round()} Hz'
                                    : 'Menunggu'),
                          color: const Color(0xFF46C7F4),
                          onTap: _loadSystemStatus,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.ramUsedPercent,
    required this.usedRam,
    required this.availableRam,
    required this.totalRam,
    required this.boosting,
  });

  final double ramUsedPercent;
  final String usedRam;
  final String availableRam;
  final String totalRam;
  final bool boosting;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Game Booster Pro',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                boosting ? 'Mode turbo sedang aktif' : 'Dashboard performa',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 86,
          height: 86,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: ramUsedPercent == 0 ? null : ramUsedPercent,
                strokeWidth: 8,
                backgroundColor: Colors.white12,
                color: const Color(0xFF20D38B),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(ramUsedPercent * 100).round()}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    'Sisa $availableRam',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Terpakai $usedRam dari $totalRam',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BoosterCore extends StatelessWidget {
  const _BoosterCore({
    required this.animation,
    required this.boosting,
    required this.status,
    required this.onBoost,
  });

  final Animation<double> animation;
  final bool boosting;
  final String status;
  final VoidCallback onBoost;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF151A16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final pulse = boosting
                        ? 0.85 + math.sin(animation.value * math.pi * 6) * 0.08
                        : 0.76;
                    return Transform.scale(
                      scale: pulse,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            width: 2,
                            color: const Color(
                              0xFF20D38B,
                            ).withValues(alpha: 0.55),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF20D38B,
                              ).withValues(alpha: 0.18),
                              blurRadius: 36,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                FlyingHero(animation: animation),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: boosting ? null : onBoost,
              icon: Icon(boosting ? Icons.bolt : Icons.rocket_launch),
              label: Text(
                boosting ? 'BOOSTING' : 'BOOST SEKARANG',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF20D38B),
                foregroundColor: const Color(0xFF06100B),
                disabledBackgroundColor: const Color(
                  0xFF20D38B,
                ).withValues(alpha: 0.6),
                disabledForegroundColor: const Color(0xFF06100B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            status,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class FlyingHero extends StatelessWidget {
  const FlyingHero({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _FlyingHeroPainter(progress: animation.value),
          size: const Size(240, 170),
        );
      },
    );
  }
}

class _FlyingHeroPainter extends CustomPainter {
  _FlyingHeroPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final wave = math.sin(progress * math.pi * 2);
    final dx = -42 + progress * 86;
    final dy = 18 - math.sin(progress * math.pi) * 64 + wave * 5;
    final center = Offset(size.width / 2 + dx, size.height / 2 + dy);

    final trailRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final glowPaint = Paint()
      ..color = const Color(0xFF22D9FF).withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(center + const Offset(10, 2), 42, glowPaint);

    for (var i = 0; i < 5; i++) {
      final lane = Path()
        ..moveTo(center.dx - 42 - i * 24, center.dy - 29 + i * 13)
        ..lineTo(center.dx - 124 - i * 20, center.dy - 21 + i * 13)
        ..lineTo(center.dx - 112 - i * 20, center.dy - 13 + i * 13)
        ..lineTo(center.dx - 36 - i * 24, center.dy - 21 + i * 13)
        ..close();
      final trailPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0x0009E8FF),
            const Color(0xFF09E8FF).withValues(alpha: 0.7 - i * 0.08),
            const Color(0xFFFF3156).withValues(alpha: 0.16),
          ],
        ).createShader(trailRect);
      canvas.drawPath(lane, trailPaint);
    }

    final capeBack = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF5D0B78), Color(0xFFFE3157), Color(0xFFFFB000)],
      ).createShader(trailRect);
    final capeGlow = Paint()
      ..color = const Color(0xFFFF3156).withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    final cape = Path()
      ..moveTo(center.dx - 26, center.dy - 7)
      ..cubicTo(
        center.dx - 74,
        center.dy - 44 + wave * 8,
        center.dx - 116,
        center.dy - 16,
        center.dx - 132,
        center.dy + 18 + wave * 5,
      )
      ..cubicTo(
        center.dx - 93,
        center.dy + 48,
        center.dx - 55,
        center.dy + 45 + wave * 4,
        center.dx - 24,
        center.dy + 18,
      )
      ..close();
    canvas.drawPath(cape, capeGlow);
    canvas.drawPath(cape, capeBack);

    final capeFold = Path()
      ..moveTo(center.dx - 31, center.dy + 2)
      ..cubicTo(
        center.dx - 65,
        center.dy + 4 + wave * 8,
        center.dx - 90,
        center.dy + 25,
        center.dx - 118,
        center.dy + 19,
      );
    canvas.drawPath(
      capeFold,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.48 + wave * 0.04);

    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1DF3D5), Color(0xFF1478FF), Color(0xFF102B67)],
      ).createShader(const Rect.fromLTWH(-50, -34, 104, 72));
    final darkSuitPaint = Paint()..color = const Color(0xFF07131F);
    final trimPaint = Paint()
      ..color = const Color(0xFF10F3FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    final bootPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFF08A), Color(0xFFFFA000), Color(0xFFFF3156)],
      ).createShader(const Rect.fromLTWH(-70, -20, 90, 40));

    final rearArm = Paint()
      ..color = const Color(0xFF0A6DDE)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-21, -4), const Offset(17, 23), rearArm);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-28, -18, 62, 35),
        const Radius.circular(18),
      ),
      bodyPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-10, -14, 29, 29),
        const Radius.circular(9),
      ),
      darkSuitPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-4, -12)
        ..lineTo(8, 4)
        ..lineTo(-2, 15),
      trimPaint,
    );

    final frontArm = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF1DF3D5), Color(0xFF22D9FF)],
      ).createShader(const Rect.fromLTWH(14, -24, 60, 26))
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(22, -8), const Offset(61, -24), frontArm);
    canvas.drawCircle(const Offset(65, -26), 8, bootPaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-58, -18, 34, 12),
        const Radius.circular(8),
      ),
      bootPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-60, 11, 35, 12),
        const Radius.circular(8),
      ),
      bootPaint,
    );

    final helmetPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFFFFF), Color(0xFF32E7FF), Color(0xFF0A1F47)],
      ).createShader(const Rect.fromLTWH(28, -35, 46, 42));
    canvas.drawOval(const Rect.fromLTWH(31, -29, 34, 30), helmetPaint);
    canvas.drawPath(
      Path()
        ..moveTo(39, -20)
        ..quadraticBezierTo(51, -28, 64, -19)
        ..lineTo(61, -12)
        ..quadraticBezierTo(49, -16, 37, -11)
        ..close(),
      Paint()..color = const Color(0xFF07131F),
    );
    canvas.drawPath(
      Path()
        ..moveTo(41, -18)
        ..quadraticBezierTo(51, -24, 61, -18),
      Paint()
        ..color = const Color(0xFFFF3156)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();

    final sparklePaint = Paint()..color = const Color(0xFFFFF1A8);
    final starPaint = Paint()
      ..color = const Color(0xFF22D9FF).withValues(alpha: 0.9)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final t = (progress + i * 0.13) % 1;
      final x = size.width - t * size.width * 0.92 - i * 5;
      final y = 25 + (i * 18) % 120 + math.sin(t * math.pi * 2) * 9;
      canvas.drawCircle(Offset(x, y), 1.5 + (i % 3), sparklePaint);
      if (i.isEven) {
        canvas.drawLine(Offset(x - 5, y), Offset(x + 5, y), starPaint);
        canvas.drawLine(Offset(x, y - 5), Offset(x, y + 5), starPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FlyingHeroPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final FutureOr<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF151A16),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => onTap(),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
