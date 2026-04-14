import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../models/cliente_fechamento.dart';

class FechamentoEstenderDialog extends ConsumerStatefulWidget {
  final ClienteFechamento fechamento;
  final String clienteId;
  const FechamentoEstenderDialog({
    super.key,
    required this.fechamento,
    required this.clienteId,
  });

  @override
  ConsumerState<FechamentoEstenderDialog> createState() => _FechamentoEstenderDialogState();
}

class _FechamentoEstenderDialogState extends ConsumerState<FechamentoEstenderDialog> {
  final _obsCtl = TextEditingController();
  DateTime? _novaData;
  bool _salvando = false;

  @override
  void dispose() {
    _obsCtl.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final data = await showDatePicker(
      context: context,
      initialDate: _novaData ?? widget.fechamento.dataFechamentoPrevista.add(const Duration(days: 7)),
      firstDate: widget.fechamento.dataFechamentoPrevista.add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('pt', 'BR'),
    );
    if (data != null) {
      setState(() => _novaData = data);
    }
  }

  Future<void> _confirmar() async {
    if (_novaData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a nova data')),
      );
      return;
    }

    setState(() => _salvando = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.estenderFechamento(
        widget.clienteId,
        widget.fechamento.id,
        _novaData!,
        observacao: _obsCtl.text.trim().isNotEmpty ? _obsCtl.text.trim() : null,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao estender: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dataFmt = DateFormat('dd/MM/yyyy');
    final f = widget.fechamento;

    return AlertDialog(
      title: const Text('Estender ciclo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Postergar o prazo do Ciclo #${f.numero}',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Data prevista atual: ${dataFmt.format(f.dataFechamentoPrevista)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selecionarData,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Nova data de fechamento *',
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  suffixIcon: _novaData != null
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                ),
                child: Text(
                  _novaData != null
                      ? dataFmt.format(_novaData!)
                      : 'Selecionar data',
                  style: _novaData != null
                      ? theme.textTheme.bodyLarge
                      : theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _obsCtl,
              decoration: const InputDecoration(
                labelText: 'Observação (opcional)',
                alignLabelWithHint: true,
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton.tonal(
          onPressed: _salvando ? null : _confirmar,
          child: _salvando
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Estender'),
        ),
      ],
    );
  }
}