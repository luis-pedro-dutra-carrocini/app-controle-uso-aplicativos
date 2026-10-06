// lib/screens/home_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/app_rule.dart';

class HomeScreen extends StatefulWidget {
  final List<AppRule> rules;
  final bool isBlockingActive;
  final bool isLoadingApps;
  final VoidCallback onAddRule;
  final Function(int) onEditRule;
  final Function(int) onRemoveRule;
  final VoidCallback onSettings;

  const HomeScreen({
    super.key,
    required this.rules,
    required this.isBlockingActive,
    required this.isLoadingApps,
    required this.onAddRule,
    required this.onEditRule,
    required this.onRemoveRule,
    required this.onSettings,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Controle de aplicativos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: widget.onSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: ListTile(
              leading: Icon(
                widget.isBlockingActive ? Icons.block : Icons.block_flipped,
                color: widget.isBlockingActive ? Colors.green : Colors.grey,
              ),
              title: const Text('Bloqueio'),
              subtitle: Text(widget.isBlockingActive ? 'Ativo' : 'Inativo'),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Aplicativos controlados',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: widget.rules.isEmpty
                ? const Center(child: Text('Nenhum aplicativo controlado'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: widget.rules.length,
                    itemBuilder: (context, index) {
                      final rule = widget.rules[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: _buildIcon(rule),
                          title: Text(rule.appName),
                          subtitle: Text(_formatSchedule(rule)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Editar regra',
                                onPressed: () => widget.onEditRule(index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Remover regra',
                                onPressed: () => widget.onRemoveRule(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: widget.isLoadingApps
          ? null
          : FloatingActionButton(
              onPressed: widget.isLoadingApps ? null : widget.onAddRule,
              tooltip: widget.isLoadingApps
                  ? 'Carregando...'
                  : 'Adicionar regra',
              child: widget.isLoadingApps
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.add),
            ),
    );
  }

  Widget _buildIcon(AppRule rule) {
    final path = rule.iconPath;
    if (path != null && File(path).existsSync()) {
      return SizedBox(
        width: 40,
        height: 40,
        child: Image.file(
          File(path),
          width: 40,
          height: 40,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => const Icon(Icons.android, size: 40),
        ),
      );
    }
    return const Icon(Icons.android, size: 40);
  }

  String _formatSchedule(AppRule rule) {
    if (rule.schedules.isEmpty) return 'Sem horário definido';
    return rule.schedules
        .map((s) {
          final days = s.weekdays.map(_weekdayName).join('-');
          return '$days • ${s.startTime}–${s.endTime}';
        })
        .join('\n');
  }

  String _weekdayName(int day) {
    const names = ['', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    if (day < 1 || day > 7) return '?';
    return names[day];
  }
}
