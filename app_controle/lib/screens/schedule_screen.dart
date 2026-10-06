// lib/screens/schedule_screen.dart
import 'package:flutter/material.dart';
import '../models/schedule.dart';

class ScheduleScreen extends StatefulWidget {
  final Schedule? initial;
  final Function(Schedule)? onSave;

  const ScheduleScreen({super.key, this.initial, this.onSave});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final Set<int> _selectedDays = {};
  TimeOfDay _startTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 19, minute: 0);

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _selectedDays.addAll(widget.initial!.weekdays);
      _startTime = _parseTime(widget.initial!.startTime);
      _endTime = _parseTime(widget.initial!.endTime);
    }
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _save() {
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione pelo menos um dia')),
      );
      return;
    }
    final schedule = Schedule(
      weekdays: _selectedDays.toList()..sort(),
      startTime: _formatTime(_startTime),
      endTime: _formatTime(_endTime),
    );
    widget.onSave?.call(schedule); // se alguém passou callback, chama
    Navigator.of(context).pop(schedule); // e SEMPRE devolve via pop
  }

  @override
  Widget build(BuildContext context) {
    const dayNames = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    const dayValues = [1, 2, 3, 4, 5, 6, 7];

    return Scaffold(
      appBar: AppBar(title: const Text('Configurar horário')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dias permitidos',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: List.generate(7, (i) {
                final day = dayValues[i];
                final selected = _selectedDays.contains(day);
                return FilterChip(
                  label: Text(dayNames[i]),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _selectedDays.add(day);
                      } else {
                        _selectedDays.remove(day);
                      }
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 24),
            const Text(
              'Horário permitido',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(true),
                    child: Text('Início: ${_formatTime(_startTime)}'),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('até'),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(false),
                    child: Text('Fim: ${_formatTime(_endTime)}'),
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Text('Salvar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
