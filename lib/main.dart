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
  int _totalRamMb = 0;
  int _availableRamMb = 0;
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
      final used = total <= 0 ? 0 : ((total - available) / total).clamp(0, 1);

      setState(() {
        _totalRamMb = total;
        _availableRamMb = available;
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
          : 'Boost selesai. DND menunggu izin sistem.';
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
          _status = result?['message'] as String? ?? 'Mode DND diproses.';
        });
      }
      return enabled;
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() => _status = error.message ?? 'DND belum bisa diaktifkan.');
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

  String _formatRam(int value) {
    if (value <= 0) {
      return '-';
    }
    return '${(value / 1024).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final usedRam = math.max(_totalRamMb - _availableRamMb, 0);

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
                        usedRam: _formatRam(usedRam),
                        totalRam: _formatRam(_totalRamMb),
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
                          title: 'DND',
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
    required this.totalRam,
    required this.boosting,
  });

  final double ramUsedPercent;
  final String usedRam;
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
                    '$usedRam/$totalRam',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
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

    final trailPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x0020D38B), Color(0x8820D38B), Color(0x00FFB000)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final trail = Path()
      ..moveTo(center.dx - 86, center.dy + 36)
      ..quadraticBezierTo(
        center.dx - 38,
        center.dy + 18,
        center.dx - 4,
        center.dy + 2,
      )
      ..quadraticBezierTo(
        center.dx - 42,
        center.dy + 54,
        center.dx - 106,
        center.dy + 72,
      )
      ..close();
    canvas.drawPath(trail, trailPaint);

    final capePaint = Paint()..color = const Color(0xFFFA5D5D);
    final capeShadow = Paint()..color = const Color(0xFF9F2532);
    final bodyPaint = Paint()..color = const Color(0xFF20D38B);
    final suitPaint = Paint()..color = const Color(0xFF0E271A);
    final skinPaint = Paint()..color = const Color(0xFFFFD08A);
    final bootPaint = Paint()..color = const Color(0xFFFFB000);

    final cape = Path()
      ..moveTo(center.dx - 32, center.dy + 3)
      ..cubicTo(
        center.dx - 74,
        center.dy - 8 + wave * 7,
        center.dx - 91,
        center.dy + 31,
        center.dx - 118,
        center.dy + 23 + wave * 5,
      )
      ..cubicTo(
        center.dx - 78,
        center.dy + 52,
        center.dx - 47,
        center.dy + 38,
        center.dx - 22,
        center.dy + 20,
      )
      ..close();
    canvas.drawPath(cape, capeShadow);
    canvas.drawPath(cape.shift(const Offset(3, -4)), capePaint);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.42 + wave * 0.04);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-25, -12, 68, 24),
        const Radius.circular(12),
      ),
      bodyPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-6, -10, 28, 20),
        const Radius.circular(7),
      ),
      suitPaint,
    );
    canvas.drawCircle(const Offset(49, -3), 13, skinPaint);
    final eyePaint = Paint()..color = const Color(0xFF101012);
    canvas.drawCircle(const Offset(54, -7), 3, eyePaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-48, -9, 32, 10),
        const Radius.circular(8),
      ),
      bootPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-51, 9, 34, 10),
        const Radius.circular(8),
      ),
      bootPaint,
    );
    canvas.restore();

    final sparklePaint = Paint()..color = const Color(0xFFFFF1A8);
    for (var i = 0; i < 7; i++) {
      final t = (progress + i * 0.16) % 1;
      final x = size.width - t * size.width * 0.9 - i * 4;
      final y = 28 + (i * 19) % 116 + math.sin(t * math.pi * 2) * 8;
      canvas.drawCircle(Offset(x, y), 1.7 + (i % 3), sparklePaint);
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
