// lib/screens/app_selection_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppSelectionScreen extends StatefulWidget {
  final Set<String> excludePackages;

  const AppSelectionScreen({super.key, this.excludePackages = const {}});

  @override
  State<AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends State<AppSelectionScreen> {
  static const _channel = MethodChannel('com.example.appcontrole/app_control');

  List<_InstalledApp> _allApps = [];
  List<_InstalledApp> _filtered = [];
  bool _isLoading = true;
  String? _error;

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInstalledApps();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _select(_InstalledApp app) {
    Navigator.of(context).pop({
      'packageName': app.packageName,
      'appName': app.appName,
      'iconBytes': app.icon, // Uint8List?
    });
  }

  Future<void> _loadInstalledApps() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getInstalledApps',
      );
      final apps = (result ?? [])
          .map(
            (e) => _InstalledApp.fromMap(Map<dynamic, dynamic>.from(e as Map)),
          )
          .where((a) => !widget.excludePackages.contains(a.packageName))
          .toList();
      if (!mounted) return;
      setState(() {
        _allApps = apps;
        _filtered = apps;
        _isLoading = false;
      });
    } on PlatformException catch (e) {
      debugPrint('Erro ao obter aplicativos: ${e.message}');
      if (!mounted) return;
      setState(() {
        _error = e.message ?? 'Erro ao carregar aplicativos';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro inesperado: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Erro inesperado';
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = _allApps;
      } else {
        _filtered = _allApps
            .where(
              (a) =>
                  a.appName.toLowerCase().contains(q) ||
                  a.packageName.toLowerCase().contains(q),
            )
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Selecionar aplicativo')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar aplicativo...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Erro: $_error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }
    if (_filtered.isEmpty) {
      return const Center(child: Text('Nenhum aplicativo encontrado'));
    }
    return ListView.builder(
      itemCount: _filtered.length,
      itemBuilder: (context, index) {
        final app = _filtered[index];
        return ListTile(
          leading: SizedBox(
            width: 40,
            height: 40,
            child: app.icon != null
                ? Image.memory(
                    app.icon!,
                    width: 40,
                    height: 40,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.android, size: 40),
                  )
                : const Icon(Icons.android, size: 40),
          ),
          title: Text(app.appName),
          subtitle: Text(app.packageName, style: const TextStyle(fontSize: 11)),
          onTap: () => _select(app),
        );
      },
    );
  }
}

class _InstalledApp {
  final String appName;
  final String packageName;
  final Uint8List? icon;

  _InstalledApp({required this.appName, required this.packageName, this.icon});

  factory _InstalledApp.fromMap(Map<dynamic, dynamic> map) {
    Uint8List? iconBytes;
    final rawIcon = map['icon'];
    if (rawIcon is Uint8List) {
      iconBytes = rawIcon;
    } else if (rawIcon is List) {
      iconBytes = Uint8List.fromList(rawIcon.cast<int>());
    }
    return _InstalledApp(
      appName: map['appName']?.toString() ?? '',
      packageName: map['packageName']?.toString() ?? '',
      icon: iconBytes,
    );
  }
}
