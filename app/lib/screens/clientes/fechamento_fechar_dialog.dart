import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../models/cliente_fechamento.dart';

class FechamentoFecharDialog extends ConsumerStatefulWidget {
  final ClienteFechamento fechamento;
  const FechamentoFecharDialog({super.key, required this.fechamento});

  @override
  ConsumerState<FechamentoFecharDialog> createState() => _FechamentoFecharDialogState();
}

class _FechamentoFecharDialogState extends ConsumerState<FechamentoFecharDialog> {
  final _obsCtl = TextEditingController();
  bool _salvando = false;

  @override
  void dispose() {
    _obsCtl.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    setState(() => _salvando = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.fecharFechamento(
        widget.fechamento.clienteId,
        widget.fechamento.id,
        observacao: _obsCtl.text.trim().isNotEmpty ? _obsCtl.text.trim() : null,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao fechar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final f = widget.fechamento;

    return AlertDialog(
      title: const Text('Fechar ciclo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deseja fechar o Ciclo #${f.numero}?',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pedidos: ${f.totalPedidos}', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text('Valor total: ${moeda.format(f.valorTotal)}', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    'Pendente: ${moeda.format(f.valorPendente)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: f.valorPendente > 0 ? theme.colorScheme.error : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'O próximo ciclo será criado automaticamente.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
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
        FilledButton(
          onPressed: _salvando ? null : _confirmar,
          child: _salvando
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Fechar ciclo'),
        ),
      ],
    );
  }
}