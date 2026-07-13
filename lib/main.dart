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

  double _refreshRate = 0;
  double _appFps = 0;
  int _fpsFrameCount = 0;
  int _fpsMicros = 0;
  bool _boosting = false;
  bool _connected = false;
  bool _dndEnabled = false;
  bool _dndPermission = false;
  String _gfxQuality = 'Smooth';
  String _gfxResolution = 'HD';
  int _gfxFps = 60;
  bool _gfxAntiAliasing = false;
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

      setState(() {
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

    if (_connected) {
      setState(() {
        _connected = false;
        _status = 'Disconnected. Mode boost dihentikan.';
      });
      return;
    }

    setState(() {
      _boosting = true;
      _status = 'Boost berjalan...';
    });
    final flight = _flightController.forward(from: 0);

    final freed = await _cleanCache();
    await _closeBackgroundApps();
    final dndResult = _dndEnabled ? true : await _setDnd(true);
    await _loadSystemStatus(silent: true);
    await flight;

    if (!mounted) {
      return;
    }

    setState(() {
      _boosting = false;
      _connected = true;
      _status = dndResult
          ? 'Connected. Cache ${_formatStorage(freed)} dibersihkan.'
          : 'Connected. Dont Disturb menunggu izin sistem.';
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

  Future<bool> _toggleDnd() => _setDnd(!_dndEnabled);

  Future<bool> _setDnd(bool enabled) async {
    try {
      final result = await _platform.invokeMapMethod<String, dynamic>(
        'toggleDnd',
        {'enabled': enabled},
      );
      final resultEnabled = result?['enabled'] == true;
      if (mounted) {
        setState(() {
          _dndEnabled = resultEnabled;
          _dndPermission = result?['permission'] == true;
          _status =
              result?['message'] as String? ?? 'Mode Dont Disturb diproses.';
        });
      }
      return resultEnabled;
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

  Future<void> _showGfxTools() async {
    var quality = _gfxQuality;
    var resolution = _gfxResolution;
    var fps = _gfxFps;
    var antiAliasing = _gfxAntiAliasing;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF151A16),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => _GfxToolsSheet(
          quality: quality,
          resolution: resolution,
          fps: fps,
          antiAliasing: antiAliasing,
          onQualityChanged: (value) => setSheetState(() => quality = value),
          onResolutionChanged: (value) =>
              setSheetState(() => resolution = value),
          onFpsChanged: (value) => setSheetState(() => fps = value),
          onAntiAliasingChanged: (value) =>
              setSheetState(() => antiAliasing = value),
        ),
      ),
    );

    if (applied == true && mounted) {
      setState(() {
        _gfxQuality = quality;
        _gfxResolution = resolution;
        _gfxFps = fps;
        _gfxAntiAliasing = antiAliasing;
        _status = 'Profil GFX $quality, $resolution, $fps FPS diterapkan.';
      });
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

  @override
  Widget build(BuildContext context) {
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
                    sliver: SliverToBoxAdapter(child: const _Header()),
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
                        connected: _connected,
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
                      crossAxisCount: compact ? 2 : 3,
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
                              : Icons.notifications_active_outlined,
                          title: 'Dont Disturb',
                          value: _dndEnabled
                              ? 'Aktif'
                              : (_dndPermission ? 'Siap' : 'Butuh izin'),
                          color: const Color(0xFFFA5D5D),
                          onTap: _toggleDnd,
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
                        _ActionTile(
                          icon: _connected ? Icons.link : Icons.link_off,
                          title: 'Connection',
                          value: _connected ? 'Connected' : 'Disconnected',
                          color: _connected
                              ? const Color(0xFF20D38B)
                              : const Color(0xFF8B9390),
                          onTap: _runBoost,
                        ),
                        _ActionTile(
                          icon: Icons.tune,
                          title: 'GFX Tools',
                          value: '$_gfxQuality / $_gfxFps',
                          color: const Color(0xFFB788FF),
                          onTap: _showGfxTools,
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
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Game Booster Pro',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: Colors.white,
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
    required this.connected,
    required this.status,
    required this.onBoost,
  });

  final Animation<double> animation;
  final bool boosting;
  final bool connected;
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
            height: 205,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final pulse = boosting
                        ? 0.88 + math.sin(animation.value * math.pi * 6) * 0.06
                        : 0.82;
                    return Transform.scale(
                      scale: pulse,
                      child: Container(
                        width: 190,
                        height: 190,
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
                _RocketFlight(animation: animation, boosting: boosting),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: boosting ? null : onBoost,
              icon: Icon(
                boosting
                    ? Icons.bolt
                    : (connected ? Icons.link_off : Icons.rocket_launch),
              ),
              label: Text(
                boosting
                    ? 'CONNECTING'
                    : (connected ? 'DISCONNECT' : 'BOOST SEKARANG'),
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

class _RocketFlight extends StatelessWidget {
  const _RocketFlight({required this.animation, required this.boosting});

  final Animation<double> animation;
  final bool boosting;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final progress = animation.value;
        var verticalOffset = 0.0;
        var opacity = 1.0;
        var scale = 0.94;

        if (boosting && progress < 0.18) {
          final prepare = Curves.easeInOut.transform(progress / 0.18);
          verticalOffset = 12 * prepare;
          scale = 0.94 - 0.05 * prepare;
        } else if (boosting && progress < 0.70) {
          final launch = Curves.easeInCubic.transform((progress - 0.18) / 0.52);
          verticalOffset = 12 - 158 * launch;
          scale = 0.89 + 0.18 * launch;
          if (progress > 0.58) {
            opacity = (1 - (progress - 0.58) / 0.12).clamp(0, 1);
          }
        } else if (boosting) {
          final returnProgress = ((progress - 0.70) / 0.30)
              .clamp(0.0, 1.0)
              .toDouble();
          final returnCurve = Curves.easeOutBack.transform(returnProgress);
          verticalOffset = 76 * (1 - returnCurve);
          scale = 0.88 + 0.06 * returnCurve;
          opacity = returnProgress.clamp(0, 1);
        }

        final sway = boosting
            ? math.sin(progress * math.pi * 8) * (1 - progress) * 5
            : 0.0;
        final tilt = boosting ? math.sin(progress * math.pi * 6) * 0.035 : 0.0;

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (boosting)
              CustomPaint(
                size: const Size(170, 205),
                painter: _BoostTrailPainter(progress: progress),
              ),
            Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(sway, verticalOffset),
                child: Transform.rotate(
                  angle: tilt,
                  child: Transform.scale(scale: scale, child: child),
                ),
              ),
            ),
          ],
        );
      },
      child: Container(
        width: 158,
        height: 178,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5A36).withValues(alpha: 0.2),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          'assets/flying_rocket.png',
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
    );
  }
}

class _BoostTrailPainter extends CustomPainter {
  const _BoostTrailPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final intensity = progress < 0.18
        ? progress / 0.18
        : (1 - ((progress - 0.18) / 0.82)).clamp(0.18, 1.0);
    final centerX = size.width / 2;
    final startY = size.height * 0.58;
    final glow = Paint()
      ..color = const Color(0xFFFFA629).withValues(alpha: 0.25 * intensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, startY + 20),
        width: 62,
        height: 90,
      ),
      glow,
    );

    final colors = [
      const Color(0xFFFFF08A),
      const Color(0xFFFFA629),
      const Color(0xFFFF4D3D),
      const Color(0xFF22D9FF),
    ];
    for (var index = 0; index < colors.length; index++) {
      final x = centerX + (index - 1.5) * 12;
      final length = 42 + ((index + progress * 10) % 3) * 18;
      final trail = Paint()
        ..color = colors[index].withValues(alpha: 0.75 * intensity)
        ..strokeWidth = index == 1 || index == 2 ? 5 : 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(x, startY),
        Offset(
          x + math.sin(progress * math.pi * 8 + index) * 5,
          startY + length,
        ),
        trail,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BoostTrailPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _GfxToolsSheet extends StatelessWidget {
  const _GfxToolsSheet({
    required this.quality,
    required this.resolution,
    required this.fps,
    required this.antiAliasing,
    required this.onQualityChanged,
    required this.onResolutionChanged,
    required this.onFpsChanged,
    required this.onAntiAliasingChanged,
  });

  final String quality;
  final String resolution;
  final int fps;
  final bool antiAliasing;
  final ValueChanged<String> onQualityChanged;
  final ValueChanged<String> onResolutionChanged;
  final ValueChanged<int> onFpsChanged;
  final ValueChanged<bool> onAntiAliasingChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, color: Color(0xFFB788FF)),
                const SizedBox(width: 10),
                Text(
                  'GFX Tools',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _GfxLabel('Kualitas grafis'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Smooth', label: Text('Smooth')),
                ButtonSegment(value: 'Balanced', label: Text('Balanced')),
                ButtonSegment(value: 'HD', label: Text('HD')),
              ],
              selected: {quality},
              onSelectionChanged: (value) => onQualityChanged(value.first),
            ),
            const SizedBox(height: 18),
            const _GfxLabel('Resolusi'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'SD', label: Text('SD')),
                ButtonSegment(value: 'HD', label: Text('HD')),
                ButtonSegment(value: 'FHD', label: Text('FHD')),
              ],
              selected: {resolution},
              onSelectionChanged: (value) => onResolutionChanged(value.first),
            ),
            const SizedBox(height: 18),
            const _GfxLabel('Target FPS'),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 30, label: Text('30')),
                ButtonSegment(value: 60, label: Text('60')),
                ButtonSegment(value: 90, label: Text('90')),
                ButtonSegment(value: 120, label: Text('120')),
              ],
              selected: {fps},
              onSelectionChanged: (value) => onFpsChanged(value.first),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Anti-aliasing',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Menghaluskan tepian objek dalam game'),
              value: antiAliasing,
              onChanged: onAntiAliasingChanged,
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text(
                  'TERAPKAN PROFIL',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GfxLabel extends StatelessWidget {
  const _GfxLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontWeight: FontWeight.w700,
      ),
    );
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
