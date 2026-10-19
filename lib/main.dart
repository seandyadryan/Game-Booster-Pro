import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'system_tools.dart';
import 'fps_monitor.dart';

void main() {
  runApp(const GameBoosterProApp());
}

class GameBoosterProApp extends StatelessWidget {
  const GameBoosterProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('en'),
      title: 'Game Tools',
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const MethodChannel _platform = MethodChannel(
    'game_booster_pro/system',
  );

  late final AnimationController _flightController;
  Timer? _refreshTimer;

  int _battery = -1;
  double _temperature = -1;
  bool _pendingDnd = false;
  bool _dndBusy = false;
  bool _dndRequestFailed = false;
  bool _sessionOwnsDnd = false;
  bool _usageDisclosureAccepted = false;
  bool _monitorDisclosureAccepted = false;
  int? _ownCacheBytes;
  bool _cleaningCache = false;
  String? _cacheError;
  bool _cacheAccessPending = false;
  bool _cacheSheetOpen = false;
  bool _cacheLoading = false;
  List<Map<String, dynamic>> _topCachedApps = [];
  bool _boosting = false;
  bool _connected = false;
  bool _dndEnabled = false;
  bool _dndPermission = false;
  String _status = 'Ready to start your gaming session.';

  @override
  void initState() {
    super.initState();
    _flightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    WidgetsBinding.instance.addObserver(this);
    _loadSystemStatus();
    _loadOwnCacheSize();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadSystemStatus(silent: true),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _flightController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resumeStatus();
    }
  }

  Future<void> _resumeStatus() async {
    await _loadSystemStatus(silent: true);
    await _loadOwnCacheSize();
    if (mounted && _pendingDnd && _dndPermission && !_dndBusy) {
      _pendingDnd = false;
      await _setDnd(true);
    }
    if (_cacheAccessPending && mounted) {
      final granted = await _querySystemPermission('hasUsageAccess');
      if (granted) {
        _cacheAccessPending = false;
        await _loadTopCachedApps();
        if (mounted && !_cacheSheetOpen) _showTopCacheSheet();
      }
    }
  }

  Future<bool> _querySystemPermission(String method) async {
    try {
      return await _platform.invokeMethod<bool>(method) ?? false;
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() => _status = error.message ?? 'Permission check failed.');
      }
      return false;
    } on MissingPluginException {
      if (mounted) {
        setState(() => _status = 'This feature is available on Android.');
      }
      return false;
    }
  }

  Future<void> _showTopCacheApps() async {
    if (!_usageDisclosureAccepted) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Usage Access'),
          content: const Text(
            'Game Tools uses Usage Access to read cache sizes for launchable apps and rank the five largest. Android does not allow this permission to clear another app’s cache automatically. You can open each app’s Storage settings and clear it there.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
      _usageDisclosureAccepted = true;
    }

    final granted = await _querySystemPermission('hasUsageAccess');
    if (!granted) {
      _cacheAccessPending = true;
      try {
        await _platform.invokeMethod<void>('requestUsageAccess');
      } on PlatformException catch (error) {
        _cacheAccessPending = false;
        if (mounted) {
          setState(
            () => _status =
                error.message ?? 'Unable to open Usage Access settings.',
          );
        }
        return;
      } on MissingPluginException {
        _cacheAccessPending = false;
        if (mounted) {
          setState(() => _status = 'Usage Access is available on Android.');
        }
        return;
      }
      if (mounted) {
        setState(
          () => _status =
              'Grant Usage Access, then return to view the top five app caches.',
        );
      }
      return;
    }
    await _loadTopCachedApps();
    if (mounted) _showTopCacheSheet();
  }

  Future<void> _loadTopCachedApps() async {
    if (!mounted) return;
    setState(() {
      _cacheLoading = true;
      _cacheError = null;
    });
    try {
      final apps =
          await _platform.invokeListMethod<dynamic>('getTopCachedApps') ?? [];
      if (!mounted) return;
      setState(
        () => _topCachedApps = apps
            .cast<Map<dynamic, dynamic>>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(),
      );
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() {
          _cacheError = error.message ?? 'Unable to read app cache sizes.';
          _status = _cacheError!;
          _topCachedApps = [];
        });
      }
    } on MissingPluginException {
      if (mounted) {
        setState(() => _cacheError = 'App cache ranking requires Android.');
      }
    } finally {
      if (mounted) setState(() => _cacheLoading = false);
    }
  }

  void _showTopCacheSheet() {
    _cacheSheetOpen = true;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.68,
            child: Column(
              children: [
                ListTile(
                  title: const Text(
                    'Top 5 app caches',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: const Text(
                    'Open App info, then Storage, to clear its cache.',
                  ),
                  trailing: IconButton(
                    tooltip: 'Refresh',
                    onPressed: _cacheLoading
                        ? null
                        : () async {
                            setSheetState(() => _cacheLoading = true);
                            await _loadTopCachedApps();
                            if (sheetContext.mounted) setSheetState(() {});
                          },
                    icon: const Icon(Icons.refresh),
                  ),
                ),
                Expanded(
                  child: _cacheLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _cacheError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(_cacheError!),
                          ),
                        )
                      : _topCachedApps.isEmpty
                      ? const Center(
                          child: Text(
                            'No cache data is available for launchable apps.',
                          ),
                        )
                      : ListView.builder(
                          itemCount: _topCachedApps.length,
                          itemBuilder: (context, index) {
                            final app = _topCachedApps[index];
                            final packageName = app['packageName'] as String;
                            return ListTile(
                              leading: _GameIcon(packageName: packageName),
                              title: Text(app['name'] as String),
                              subtitle: Text(packageName),
                              trailing: Text(
                                _formatStorage(
                                  (app['cacheBytes'] as num).toInt(),
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              onTap: () => _systemAction(
                                'openAppStorageSettings',
                                {'packageName': packageName},
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() => _cacheSheetOpen = false);
  }

  Future<void> _prepareGameLaunch(String packageName) async {
    if (!_monitorDisclosureAccepted) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Display monitor access'),
          content: const Text(
            'Usage Access detects when the selected game is on screen. Display over other apps shows the display refresh rate in Hz. This measures the screen, not the selected game\'s rendered frame rate.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
      _monitorDisclosureAccepted = true;
    }
    final overlay = await _querySystemPermission('hasOverlayAccess');
    if (!mounted) return;
    if (!overlay) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Allow the display monitor bar?'),
          content: const Text(
            'Allow Game Tools to show the display refresh rate over the selected game. Tap the bar to remove it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Open settings'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
    }
    await _systemAction('launchGame', {'packageName': packageName});
  }

  Future<void> _systemAction(
    String method, [
    Map<String, dynamic>? args,
  ]) async {
    try {
      await _platform.invokeMethod<dynamic>(method, args);
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() => _status = error.message ?? 'Operation failed.');
      }
    } on MissingPluginException {
      if (mounted) {
        setState(() => _status = 'This feature is available on Android.');
      }
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
        _battery = (data['batteryPercent'] as num?)?.toInt() ?? -1;
        _temperature = (data['batteryTemperature'] as num?)?.toDouble() ?? -1;
        _dndEnabled = data['dndEnabled'] == true;
        _dndPermission = data['dndPermission'] == true;
        if (!silent) {
          _status = 'System status updated.';
        }
      });
    } on MissingPluginException {
      if (mounted && !silent) {
        setState(() => _status = 'System features are available on Android.');
      }
    } on PlatformException catch (error) {
      if (!mounted || silent) {
        return;
      }
      setState(
        () => _status = error.message ?? 'Unable to read system status.',
      );
    }
  }

  Future<void> _runBoost() async {
    if (_boosting || _dndBusy || _cleaningCache) {
      return;
    }

    if (_connected) {
      if (_sessionOwnsDnd) {
        await _setDnd(false);
        if (_dndRequestFailed) return;
      }
      _sessionOwnsDnd = false;
      _pendingDnd = false;
      if (!mounted) return;
      setState(() {
        _connected = false;
        _status = 'Session ended.';
      });
      return;
    }

    setState(() {
      _boosting = true;
      _status = 'Starting session...';
    });
    final flight = _flightController
        .forward(from: 0)
        .orCancel
        .then<void>(
          (_) {},
          onError: (Object error) {
            if (error is! TickerCanceled) throw error;
          },
        );
    try {
      final report = await _cleanCache();
      await _loadSystemStatus(silent: true);
      await flight;

      // Cleanup is independent of optional Dont Disturb permission and consent.
      if (mounted && _dndPermission && !_dndEnabled) {
        _sessionOwnsDnd = await _toggleDnd();
      }

      if (!mounted) {
        return;
      }

      final failedFiles = (report['failedFiles'] as num?)?.toInt() ?? 0;
      setState(() {
        _boosting = false;
        _connected = true;
        _status =
            'Session active. This app\'s cache: ${formatBytes((report['beforeBytes'] as num).toInt())} before, ${formatBytes((report['freedBytes'] as num).toInt())} cleared, ${formatBytes((report['afterBytes'] as num).toInt())} remaining.${failedFiles > 0 ? ' $failedFiles files could not be removed.' : ''}${_dndEnabled ? ' Do Not Disturb active.' : ''}';
      });
    } on TickerCanceled {
      // The dashboard was disposed while its launch animation was active.
    } on MissingPluginException {
      if (mounted) {
        setState(() => _status = 'Sessions are available on Android.');
      }
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() => _status = error.message ?? 'Unable to clear app cache.');
      }
    } finally {
      if (mounted) setState(() => _boosting = false);
    }
  }

  Future<int> _readOwnCacheSize() async {
    final stats = await _platform.invokeMapMethod<String, dynamic>(
      'getOwnCacheStats',
    );
    if (stats == null) {
      throw PlatformException(
        code: 'CACHE_ERROR',
        message: 'No app cache information was returned.',
      );
    }
    final bytes = (stats['cacheBytes'] as num).toInt();
    if (mounted) setState(() => _ownCacheBytes = bytes);
    return bytes;
  }

  Future<void> _loadOwnCacheSize() async {
    try {
      await _readOwnCacheSize();
    } on PlatformException {
      if (mounted) setState(() => _ownCacheBytes = null);
    } on MissingPluginException {
      if (mounted) setState(() => _ownCacheBytes = null);
    }
  }

  Future<Map<String, dynamic>> _cleanCache() async {
    if (_cleaningCache) {
      throw PlatformException(
        code: 'CACHE_BUSY',
        message: 'A cleanup is already running.',
      );
    }
    _cleaningCache = true;
    try {
      final report = await _platform.invokeMapMethod<String, dynamic>(
        'cleanCache',
      );
      if (report == null) {
        throw PlatformException(
          code: 'CACHE_ERROR',
          message: 'No cleanup result was returned.',
        );
      }
      if (mounted) {
        setState(() {
          _ownCacheBytes = (report['afterBytes'] as num).toInt();
          _status =
              'This app\'s cache: ${formatBytes((report['freedBytes'] as num).toInt())} cleared; ${formatBytes(_ownCacheBytes!)} remaining.';
        });
      }
      return report;
    } finally {
      _cleaningCache = false;
    }
  }

  void _showAppCache() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AppCacheSheet(
        readCache: _readOwnCacheSize,
        clearCache: _cleanCache,
        onTopApps: () {
          Navigator.pop(context);
          _showTopCacheApps();
        },
      ),
    );
  }

  void _showNetworkCheck() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const NetworkCheckSheet(channel: _platform),
    );
  }

  Future<void> _showPrivacyPolicy() async {
    final policy = await rootBundle.loadString('assets/privacy-policy.txt');
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.85,
        child: SafeArea(
          child: Column(
            children: [
              ListTile(
                title: const Text('Privacy policy'),
                trailing: IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: SelectionArea(child: Text(policy)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _closeBackgroundApps() async {
    try {
      final result = await _platform.invokeMapMethod<String, dynamic>(
        'closeBackgroundApps',
      );
      if (mounted) {
        setState(
          () => _status =
              result?['message'] as String? ?? 'App management opened.',
        );
      }
      return result?['success'] == true;
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () => _status = error.message ?? 'Unable to open app management.',
        );
      }
      return false;
    } on MissingPluginException {
      if (mounted) {
        setState(() => _status = 'App management is available on Android.');
      }
      return false;
    }
  }

  Future<bool> _toggleDnd() async {
    if (_dndBusy) return _dndEnabled;
    if (!_dndEnabled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Enable strict Do Not Disturb?'),
          content: const Text(
            'Calls and notifications will be silenced, including alarms and media. WhatsApp calls can still arrive; Do Not Disturb does not reject calls.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enable'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return false;
    }
    return _setDnd(!_dndEnabled);
  }

  Future<bool> _setDnd(bool enabled) async {
    if (_dndBusy) return _dndEnabled;
    _dndBusy = true;
    _dndRequestFailed = false;
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
          _pendingDnd = enabled && !_dndPermission;
          _status =
              result?['message'] as String? ??
              'Do Not Disturb request processed.';
        });
      }
      return resultEnabled;
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () => _status = error.message ?? 'Unable to update Do Not Disturb.',
        );
      }
      _dndRequestFailed = true;
      return false;
    } on MissingPluginException {
      _dndRequestFailed = true;
      if (mounted) {
        setState(() => _status = 'Do Not Disturb is available on Android.');
      }
      return false;
    } finally {
      _dndBusy = false;
    }
  }

  Future<void> _showGfxTools() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Display & Game Tools',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Open Android display settings or launch a game with a display refresh-rate bar. Graphics options inside a game remain controlled by that game.',
              ),
              ListTile(
                leading: const Icon(Icons.display_settings),
                title: const Text('Android display settings'),
                subtitle: const Text(
                  'Refresh rate and brightness options depend on your device',
                ),
                onTap: () => _systemAction('openDisplaySettings'),
              ),
              ListTile(
                leading: const Icon(Icons.sports_esports),
                title: const Text('Launch game with display bar'),
                onTap: () {
                  Navigator.pop(context);
                  _showGames();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showGames() async {
    try {
      final games =
          await _platform.invokeListMethod<dynamic>('listGames') ?? [];
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.6,
            child: games.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No apps identified as games were found on this device.',
                      ),
                    ),
                  )
                : ListView(
                    children: [
                      const ListTile(title: Text('My games')),
                      for (final game in games)
                        ListTile(
                          key: ValueKey(game['packageName']),
                          leading: _GameIcon(
                            packageName: game['packageName'] as String,
                          ),
                          title: Text(game['name'] as String),
                          subtitle: Text(game['packageName'] as String),
                          trailing: const Icon(Icons.play_arrow),
                          onTap: () {
                            Navigator.pop(context);
                            _prepareGameLaunch(game['packageName'] as String);
                          },
                        ),
                    ],
                  ),
          ),
        ),
      );
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() => _status = error.message ?? 'Unable to load games.');
      }
    } on MissingPluginException {
      if (mounted) {
        setState(() => _status = 'Game discovery is available on Android.');
      }
    }
  }

  String _formatStorage(int bytes) {
    return formatBytes(bytes);
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
                    sliver: SliverToBoxAdapter(
                      child: _Header(onPrivacy: _showPrivacyPolicy),
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
                      crossAxisCount: compact
                          ? 2
                          : (constraints.maxWidth >= 1100 ? 4 : 3),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: compact
                          ? 1.05
                          : (constraints.maxWidth >= 1100 ? 1.9 : 1.22),
                      children: [
                        _ActionTile(
                          icon: Icons.cleaning_services_outlined,
                          title: 'This app\'s cache',
                          value: _ownCacheBytes == null
                              ? 'View cache'
                              : formatBytes(_ownCacheBytes!),
                          color: const Color(0xFF20D38B),
                          onTap: _showAppCache,
                        ),
                        _ActionTile(
                          icon: Icons.network_check,
                          title: 'Network Latency',
                          value: 'Check latency',
                          color: const Color(0xFF46C7F4),
                          onTap: _showNetworkCheck,
                        ),
                        _ActionTile(
                          icon: Icons.layers_clear_outlined,
                          title: 'App settings',
                          value: 'Open settings',
                          color: const Color(0xFFFFB000),
                          onTap: _closeBackgroundApps,
                        ),
                        _ActionTile(
                          icon: _dndEnabled
                              ? Icons.notifications_off
                              : Icons.notifications_active_outlined,
                          title: 'Do Not Disturb',
                          value: _dndEnabled
                              ? 'Active'
                              : (_dndPermission ? 'Ready' : 'Allow access'),
                          color: const Color(0xFFFA5D5D),
                          onTap: _toggleDnd,
                        ),
                        _ActionTile(
                          icon: Icons.speed_outlined,
                          title: 'Animation FPS',
                          value: 'This app only',
                          color: const Color(0xFF46C7F4),
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => const FpsMonitorSheet(),
                          ),
                        ),
                        _ActionTile(
                          icon: _connected
                              ? Icons.pause_circle_outline
                              : Icons.play_circle_outline,
                          title: 'Session',
                          value: _connected ? 'Active' : 'Inactive',
                          color: _connected
                              ? const Color(0xFF20D38B)
                              : const Color(0xFF8B9390),
                          onTap: _runBoost,
                        ),
                        _ActionTile(
                          icon: Icons.tune,
                          title: 'Display & games',
                          value: 'Open tools',
                          color: const Color(0xFFB788FF),
                          onTap: _showGfxTools,
                        ),
                        _ActionTile(
                          icon: Icons.sports_esports,
                          title: 'My games',
                          value: 'Launch game',
                          color: const Color(0xFF20D38B),
                          onTap: _showGames,
                        ),
                        _ActionTile(
                          icon: Icons.battery_std,
                          title: 'Battery',
                          value: _battery >= 0 ? '$_battery%' : 'Unavailable',
                          color: const Color(0xFFFFB000),
                          onTap: _loadSystemStatus,
                        ),
                        _ActionTile(
                          icon: Icons.thermostat,
                          title: 'Battery temperature',
                          value: _temperature >= 0
                              ? '${_temperature.toStringAsFixed(1)} C'
                              : 'Unavailable',
                          color: const Color(0xFFFA5D5D),
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

class _GameIcon extends StatefulWidget {
  const _GameIcon({required this.packageName});

  final String packageName;

  @override
  State<_GameIcon> createState() => _GameIconState();
}

class _GameIconState extends State<_GameIcon> {
  late Future<Uint8List?> _icon;

  Future<Uint8List?> _loadIcon() async {
    try {
      return await const MethodChannel(
        'game_booster_pro/system',
      ).invokeMethod<Uint8List>('getGameIcon', {
        'packageName': widget.packageName,
      });
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _icon = _loadIcon();
  }

  @override
  void didUpdateWidget(covariant _GameIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.packageName != widget.packageName) _icon = _loadIcon();
  }

  @override
  Widget build(BuildContext context) {
    const fallback = Icon(Icons.sports_esports, size: 32);
    return SizedBox(
      width: 48,
      height: 48,
      child: FutureBuilder<Uint8List?>(
        future: _icon,
        builder: (context, snapshot) => snapshot.data == null
            ? fallback
            : Image.memory(
                snapshot.data!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) => fallback,
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onPrivacy});
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 40),
        Expanded(
          child: Text(
            'Game Tools',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: IconButton(
            tooltip: 'Privacy policy',
            onPressed: onPrivacy,
            icon: const Icon(Icons.privacy_tip_outlined, size: 20),
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
                    ? Icons.hourglass_top
                    : (connected
                          ? Icons.stop_circle_outlined
                          : Icons.play_arrow),
              ),
              label: Text(
                boosting
                    ? 'Starting Session'
                    : (connected ? 'End Session' : 'Start Session'),
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
          const Text(
            'Clears this app\'s cache. Do Not Disturb is optional.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
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
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(),
        child: Transform.scale(
          scale: 1.35,
          child: Image.asset(
            'assets/flying_rocket.png',
            fit: BoxFit.contain,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
          ),
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
