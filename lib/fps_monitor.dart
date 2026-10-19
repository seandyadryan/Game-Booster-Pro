import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Estimates this Flutter renderer's frame cadence, never another app's FPS.
class FrameRateWindow {
  int? _first;
  int? _last;
  int _intervals = 0;

  void reset() {
    _first = _last = null;
    _intervals = 0;
  }

  double? add(int timestampMicros) {
    if (_last != null && timestampMicros <= _last!) return null;
    if (_last == null) {
      _first = _last = timestampMicros;
      _intervals = 0;
      return null;
    }
    _last = timestampMicros;
    _intervals++;
    final elapsed = timestampMicros - _first!;
    if (elapsed < 1000000) return null;
    final fps = _intervals * 1000000 / elapsed;
    _first = timestampMicros;
    _intervals = 0;
    return fps;
  }
}

class FpsMonitorSheet extends StatefulWidget {
  const FpsMonitorSheet({super.key});

  @override
  State<FpsMonitorSheet> createState() => _FpsMonitorSheetState();
}

class _FpsMonitorSheetState extends State<FpsMonitorSheet>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _animation;
  final _window = FrameRateWindow();
  bool _running = false;
  double? _fps;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    WidgetsBinding.instance.addObserver(this);
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!mounted || !_running) return;
    double? latest;
    for (final timing in timings) {
      latest =
          _window.add(timing.timestampInMicroseconds(FramePhase.vsyncStart)) ??
          latest;
    }
    if (latest != null) setState(() => _fps = latest);
  }

  void _stop() {
    if (!_running) return;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _animation.stop();
    _window.reset();
    setState(() {
      _running = false;
      _fps = null;
    });
  }

  void _start() {
    if (_running) return;
    _window.reset();
    setState(() {
      _running = true;
      _fps = null;
    });
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _animation.repeat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_running) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    }
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Animation FPS',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Text(
              'App animation only',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Measures the frame cadence of this app\'s test animation, not your game. '
              'Game FPS is unavailable. Screen refresh rate (Hz) is a different measurement.',
            ),
            const SizedBox(height: 16),
            Text(
              _fps == null
                  ? (_running ? 'Measuring...' : '-- FPS')
                  : '${_fps!.toStringAsFixed(1)} FPS',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            SizedBox(
              height: 140,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) => Align(
                  alignment: Alignment(-0.85 + _animation.value * 1.7, 0),
                  child: child,
                ),
                child: Image.asset(
                  'assets/flying_rocket.png',
                  width: 90,
                  height: 130,
                ),
              ),
            ),
            const Text(
              'Results depend on device load and build mode. No game FPS overlay is enabled.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _running ? _stop : _start,
              icon: Icon(_running ? Icons.stop : Icons.play_arrow),
              label: Text(_running ? 'Stop measurement' : 'Start measurement'),
            ),
          ],
        ),
      ),
    );
  }
}
