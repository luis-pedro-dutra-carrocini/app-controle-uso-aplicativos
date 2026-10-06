// lib/main.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/app_rule.dart';
import 'models/schedule.dart';
import 'screens/password_screen.dart';
import 'screens/home_screen.dart';
import 'screens/app_selection_screen.dart';
import 'screens/schedule_screen.dart';
import 'services/android_service.dart';
import 'services/icon_storage_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Controle de Aplicativos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const AppGate(),
    );
  }
}

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  bool _authenticated = false;

  List<AppRule> _rules = [];
  bool _blockingActive = false;
  bool _loadingRules = true;
  bool _loadingApps = false; // controla o FAB

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRules();
    });
  }

  // ---------------------------------------------------------------------------
  // Persistência
  // ---------------------------------------------------------------------------
  Future<void> _loadRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('rules');
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        _rules = list
            .map((e) => AppRule.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      _blockingActive = prefs.getBool('blocking_active') ?? false;
      await _pushRulesToAndroid();
    } catch (e) {
      debugPrint('_loadRules erro (ignorado): $e');
    } finally {
      if (mounted) setState(() => _loadingRules = false);
    }
  }

  Future<void> _saveRules() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_rules.map((r) => r.toJson()).toList());
    await prefs.setString('rules', raw);
    await prefs.setBool('blocking_active', _blockingActive);
    await _pushRulesToAndroid();
  }

  /// Envia as regras para o Kotlin.
  /// Só envia os campos que o AppBlockingService precisa:
  /// packageName + schedules. O ícone fica só no Flutter.
  Future<void> _pushRulesToAndroid() async {
    try {
      final rulesForAndroid = _rules
          .map(
            (r) => {
              'packageName': r.packageName,
              'schedules': r.schedules.map((s) => s.toJson()).toList(),
            },
          )
          .toList();
      await AndroidService.setRules(rulesForAndroid);
    } catch (e) {
      debugPrint('_pushRulesToAndroid erro (ignorado): $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Ações da Home
  // ---------------------------------------------------------------------------
  Future<void> _addRule() async {
    if (_loadingApps) return;
    setState(() => _loadingApps = true);

    Map<String, dynamic>? selected;
    try {
      selected = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(builder: (_) => const AppSelectionScreen()),
      );
    } finally {
      if (mounted) setState(() => _loadingApps = false);
    }

    if (selected == null) return;
    if (!mounted) return;

    final packageName = selected['packageName'] as String;

    // Verifica duplicidade
    if (_rules.any((r) => r.packageName == packageName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Já existe uma regra para ${selected['appName']}. '
            'Edite a regra existente em vez de criar uma nova.',
          ),
        ),
      );
      return;
    }

    // Salva o ícone (se houver)
    String? iconPath;
    final iconBytes = selected['iconBytes'] as Uint8List?;
    if (iconBytes != null) {
      iconPath = await IconStorageService.saveIcon(
        selected['packageName'] as String,
        iconBytes,
      );
    }

    if (!mounted) return;

    // Configura o horário
    final schedule = await Navigator.of(
      context,
    ).push<Schedule>(MaterialPageRoute(builder: (_) => const ScheduleScreen()));

    if (schedule == null) return;
    if (!mounted) return;

    final newRule = AppRule(
      packageName: selected['packageName'] as String,
      appName: selected['appName'] as String,
      iconPath: iconPath,
      schedules: [schedule],
    );

    setState(() {
      _rules = [..._rules, newRule];
      _blockingActive = true;
    });
    await _saveRules();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Regra adicionada para ${newRule.appName}')),
    );
  }

  /// Edita uma regra existente
  Future<void> _editRule(int index) async {
    final current = _rules[index];

    final schedule = await Navigator.of(context).push<Schedule>(
      MaterialPageRoute(
        builder: (_) => ScheduleScreen(
          initial: current.schedules.isNotEmpty
              ? current.schedules.first
              : null,
        ),
      ),
    );

    if (schedule == null) return;
    if (!mounted) return;

    setState(() {
      _rules = [..._rules];
      _rules[index] = current.copyWith(schedules: [schedule]);
    });
    await _saveRules();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Regra de ${current.appName} atualizada')),
    );
  }

  Future<void> _removeRule(int index) async {
    final removed = _rules[index];
    setState(() {
      _rules = [..._rules]..removeAt(index);
      if (_rules.isEmpty) _blockingActive = false;
    });
    await IconStorageService.deleteIcon(removed.iconPath);
    await _saveRules();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Regra de ${removed.appName} removida')),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const _SettingsPage()));
    if (!mounted) return;
    setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (!_authenticated) {
      return PasswordScreen(
        onAuthenticated: () => setState(() => _authenticated = true),
      );
    }

    if (_loadingRules) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return HomeScreen(
      rules: _rules,
      isBlockingActive: _blockingActive,
      isLoadingApps: _loadingApps,
      onAddRule: _addRule,
      onEditRule: _editRule,
      onRemoveRule: _removeRule,
      onSettings: _openSettings,
    );
  }
}

// -----------------------------------------------------------------------------
// Configurações / permissões
// -----------------------------------------------------------------------------
class _SettingsPage extends StatefulWidget {
  const _SettingsPage();

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  bool? _accessibilityOk;
  bool? _overlayOk;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final a = await AndroidService.checkAccessibilityPermission();
      final o = await AndroidService.checkOverlayPermission();
      if (!mounted) return;
      setState(() {
        _accessibilityOk = a;
        _overlayOk = o;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _accessibilityOk = false;
        _overlayOk = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(
              _accessibilityOk == true ? Icons.check_circle : Icons.error,
              color: _accessibilityOk == true ? Colors.green : Colors.red,
            ),
            title: const Text('Serviço de acessibilidade'),
            subtitle: Text(
              _accessibilityOk == true ? 'Concedido' : 'Não concedido',
            ),
            trailing: const Icon(Icons.open_in_new),
            onTap: () async {
              await AndroidService.openAccessibilitySettings();
            },
          ),
          ListTile(
            leading: Icon(
              _overlayOk == true ? Icons.check_circle : Icons.error,
              color: _overlayOk == true ? Colors.green : Colors.red,
            ),
            title: const Text('Sobrepor outros aplicativos'),
            subtitle: Text(_overlayOk == true ? 'Concedido' : 'Não concedido'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () async {
              await AndroidService.openOverlaySettings();
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.tonal(
              onPressed: _refresh,
              child: const Text('Atualizar status'),
            ),
          ),
        ],
      ),
    );
  }
}
