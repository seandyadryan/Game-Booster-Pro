import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

String formatBytes(int bytes) {
  if (bytes < 1024) return '${bytes.clamp(0, 1023)} B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

class AppCacheSheet extends StatefulWidget {
  const AppCacheSheet({
    super.key,
    required this.readCache,
    required this.clearCache,
    required this.onTopApps,
  });

  final Future<int> Function() readCache;
  final Future<Map<String, dynamic>> Function() clearCache;
  final VoidCallback onTopApps;

  @override
  State<AppCacheSheet> createState() => _AppCacheSheetState();
}

class _AppCacheSheetState extends State<AppCacheSheet> {
  int? _bytes;
  Map<String, dynamic>? _report;
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await widget.readCache();
      if (mounted) setState(() => _bytes = bytes);
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final report = await widget.clearCache();
      if (mounted) {
        setState(() {
          _report = report;
          _bytes = (report['afterBytes'] as num).toInt();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.cleaning_services_outlined,
                  color: Color(0xFF20D38B),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'This app\'s cache',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh cache size',
                  onPressed: _busy ? null : _read,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Game Tools cache'),
            const SizedBox(height: 8),
            Text(
              _bytes == null ? '--' : formatBytes(_bytes!),
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text(
              'Remove this app\'s temporary files. Your preferences and game data are kept.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFFF9595)),
                ),
              ),
            if (_report != null) ...[
              _MetricRow(
                'Before cleanup',
                formatBytes((_report!['beforeBytes'] as num).toInt()),
              ),
              _MetricRow(
                'Cleared',
                formatBytes((_report!['freedBytes'] as num).toInt()),
              ),
              _MetricRow(
                'Remaining',
                formatBytes((_report!['afterBytes'] as num).toInt()),
              ),
              if ((_report!['failedFiles'] as num?)?.toInt()
                  case final int failed when failed > 0)
                Text(
                  '$failed files could not be removed. Try again when the app is idle.',
                ),
              if ((_report!['beforeBytes'] as num).toInt() == 0)
                const Text(
                  'No temporary cache files were found.',
                  style: TextStyle(color: Colors.white70),
                ),
              const SizedBox(height: 16),
            ],
            FilledButton.icon(
              onPressed: _busy ? null : _clear,
              icon: const Icon(Icons.cleaning_services_outlined),
              label: Text(_busy ? 'Working...' : 'Clear This App\'s Cache'),
            ),
            const Divider(height: 40),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.storage_outlined),
              title: const Text('Top 5 app caches'),
              subtitle: const Text(
                'Usage Access is required to read other apps\' cache sizes. Clear them manually in Android settings.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy ? null : widget.onTopApps,
            ),
          ],
        ),
      ),
    );
  }
}

class NetworkCheckSheet extends StatefulWidget {
  const NetworkCheckSheet({super.key, required this.channel});
  final MethodChannel channel;

  @override
  State<NetworkCheckSheet> createState() => _NetworkCheckSheetState();
}

class _NetworkCheckSheetState extends State<NetworkCheckSheet> {
  bool _busy = false;
  Map<String, dynamic>? _result;
  String? _error;

  Future<void> _check() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await widget.channel.invokeMapMethod<String, dynamic>(
        'checkNetworkLatency',
      );
      if (result == null) {
        throw StateError('No network result was returned. Try again.');
      }
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _ms(dynamic value) =>
      value is num ? '${value.toStringAsFixed(1)} ms' : 'Unavailable';

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.network_check, color: Color(0xFF46C7F4)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Network Latency',
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
            const SizedBox(height: 24),
            const Text(
              'Average latency',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              result == null ? '-- ms' : _ms(result['averageMs']),
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              _busy
                  ? 'Checking 5 probes on your active network...'
                  : 'Check your current Wi-Fi, mobile data, Ethernet, or VPN connection.',
            ),
            const SizedBox(height: 20),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFFF9595)),
                ),
              ),
            if (result != null) ...[
              _MetricRow('Network', result['networkType'] as String),
              _MetricRow('Minimum', _ms(result['minMs'])),
              _MetricRow('Maximum', _ms(result['maxMs'])),
              _MetricRow('Jitter', _ms(result['jitterMs'])),
              _MetricRow(
                'Failed probes',
                '${result['failedProbes']} / ${result['totalProbes']}',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final sample in result['samplesMs'] as List)
                    Chip(label: Text(sample == null ? 'Failed' : _ms(sample))),
                ],
              ),
              if (result['averageMs'] == null)
                const Text(
                  'No probe connected. The endpoint may be blocked or your connection may be offline.',
                ),
              const SizedBox(height: 16),
            ],
            FilledButton.icon(
              onPressed: _busy ? null : _check,
              icon: const Icon(Icons.network_check),
              label: Text(
                _busy
                    ? 'Checking...'
                    : (result == null ? 'Check now' : 'Check again'),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '5 TCP connection probes to Cloudflare 1.1.1.1:443. This measures connection latency, not game-server ping or an Internet speed test. A failed probe is not a measurement of packet loss.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            const Text(
              'This check connects to a third-party endpoint, which can receive your public IP address. Results stay on your device.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

String _errorMessage(Object error) {
  if (error is PlatformException) {
    return error.message ?? 'The operation failed. Try again.';
  }
  if (error is MissingPluginException) return 'This feature requires Android.';
  return 'The operation failed. Try again.';
}

class _MetricRow extends StatelessWidget {
  const _MetricRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.white70)),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
