import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../models/pedido.dart';
import '../../state/pagamentos_provider.dart';
import '../../state/pedidos_provider.dart';
import '../../state/dashboard_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_pill.dart';

class PedidoDetalheScreen extends ConsumerWidget {
  final String pedidoId;
  const PedidoDetalheScreen({super.key, required this.pedidoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedidoAsync = ref.watch(pedidoProvider(pedidoId));
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final data = DateFormat('dd/MM/yyyy', 'pt_BR');
    final dataSemana = DateFormat("EEEE', 'dd/MM/yyyy", 'pt_BR');

    return Scaffold(
      appBar: AppBar(
        title: pedidoAsync.when(
          loading: () => const Text('Pedido'),
          error: (_, __) => const Text('Pedido'),
          data: (p) => Text(p.loteFormatado),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar',
            onPressed: () => context.push('/pedidos/$pedidoId/editar'),
          ),
          pedidoAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (_) => PopupMenuButton<String>(
              onSelected: (action) => _handleMenu(context, ref, action, pedidoAsync.value!),
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'duplicar',
                  child: ListTile(
                    leading: Icon(Icons.content_copy),
                    title: Text('Duplicar'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'reagendar',
                  child: ListTile(
                    leading: Icon(Icons.event_repeat),
                    title: Text('Reagendar automaticamente'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'excluir',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error),
                    title: Text(
                      'Excluir',
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: pedidoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(pedidoProvider(pedidoId)),
        ),
        data: (pedido) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(pedidoProvider(pedidoId));
            ref.invalidate(pagamentosProvider(pedidoId));
          },
          child: LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final temArte = pedido.arteCores != null ||
                pedido.arteTamanhoCm != null ||
                (pedido.artePosicao?.isNotEmpty ?? false) ||
                (pedido.arteObservacao?.isNotEmpty ?? false);

            final cabecalho = Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusPill(status: pedido.status),
                          PagamentoPill(statusPagamento: pedido.statusPagamento),
                          if (pedido.urgente)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.flash_on, size: 14, color: Theme.of(context).colorScheme.onErrorContainer),
                                  const SizedBox(width: 4),
                                  Text(
                                    'URGENTE',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onErrorContainer,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          letterSpacing: 0.5,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        pedido.clienteNome,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(pedido.descricao, style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 12),
                      Text(
                        moeda.format(pedido.valor),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                      ),
                    ],
                  ),
                ),
              );

            final cardPeca = Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(icon: Icons.checkroom_outlined, title: 'Peça'),
                      const SizedBox(height: 12),
                      _Info('Peça', pedido.peca),
                      _Info('Técnica', pedido.tecnica),
                      _Info('Quantidade', pedido.quantidade?.toString()),
                      _Info('Cor', pedido.corPeca),
                      _Info('Tamanho', pedido.tamanhoPeca),
                      _Info('Tecido', pedido.tecido),
                    ],
                  ),
                ),
              );

            final cardArte = temArte
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(icon: Icons.palette_outlined, title: 'Arte'),
                          const SizedBox(height: 12),
                          _Info('Cores', pedido.arteCores?.toString()),
                          _Info('Tamanho', pedido.arteTamanhoCm),
                          _Info('Posição', pedido.artePosicao),
                          _Info('Observação', pedido.arteObservacao),
                        ],
                      ),
                    ),
                  )
                : null;

            final cardAgenda = Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(icon: Icons.calendar_month_outlined, title: 'Agenda'),
                      const SizedBox(height: 12),
                      _Info('Chegada', pedido.dataChegada != null ? data.format(pedido.dataChegada!) : null),
                      _Info(
                        'Produção',
                        pedido.dataProducao != null ? toBeginningOfSentenceCase(dataSemana.format(pedido.dataProducao!)) : null,
                      ),
                      _Info('Prazo', pedido.prazoDias != null ? '${pedido.prazoDias} dias' : null),
                      _Info('Entrega combinada', pedido.dataEntregaCombinada != null ? data.format(pedido.dataEntregaCombinada!) : null),
                    ],
                  ),
                ),
              );

            final cardEntrega = Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(icon: Icons.local_shipping_outlined, title: 'Entrega'),
                      const SizedBox(height: 12),
                      _Info('Forma', pedido.formaEntrega == 'entrega' ? 'Entrega' : 'Retirada'),
                      _Info('Endereço', pedido.enderecoEntrega),
                      if (pedido.entregue) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimaryContainer),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Entregue${pedido.entregueEm != null ? " em ${data.format(pedido.entregueEm!)}" : ""}${pedido.entreguePor != null ? " por ${pedido.entreguePor}" : ""}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );

            final cardPagamentos = Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        icon: Icons.payments_outlined,
                        title: 'Pagamentos',
                        subtitle: 'Restante: ${moeda.format(pedido.valorRestante)}',
                      ),
                      const SizedBox(height: 12),
                      _PagamentosList(
                        pedidoId: pedidoId,
                        valorRestante: pedido.valorRestante,
                        moeda: moeda,
                        data: data,
                      ),
                    ],
                  ),
                ),
              );

            final cardObservacao = (pedido.observacao != null && pedido.observacao!.isNotEmpty)
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(icon: Icons.note_outlined, title: 'Observação'),
                          const SizedBox(height: 8),
                          Text(pedido.observacao!, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  )
                : null;

            Widget pair(Widget? a, Widget b) {
              if (a == null) return b;
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: a),
                    const SizedBox(width: 12),
                    Expanded(child: b),
                  ],
                ),
              );
            }

            final children = <Widget>[
              cabecalho,
              const SizedBox(height: 12),
              if (wide) ...[
                pair(cardArte, cardPeca),
                const SizedBox(height: 12),
                pair(cardEntrega, cardAgenda),
                const SizedBox(height: 12),
              ] else ...[
                cardPeca,
                const SizedBox(height: 12),
                if (cardArte != null) ...[
                  cardArte,
                  const SizedBox(height: 12),
                ],
                cardAgenda,
                const SizedBox(height: 12),
                cardEntrega,
                const SizedBox(height: 12),
              ],
              cardPagamentos,
              if (cardObservacao != null) ...[
                const SizedBox(height: 12),
                cardObservacao,
              ],
            ];

            return ListView(
              padding: EdgeInsets.fromLTRB(
                wide ? 24 : 16,
                16,
                wide ? 24 : 16,
                32,
              ),
              children: children,
            );
          }),
        ),
      ),
    );
  }

  Future<void> _handleMenu(BuildContext context, WidgetRef ref, String action, Pedido pedido) async {
    if (action == 'duplicar') {
      try {
        final api = ref.read(apiClientProvider);
        final novo = await api.duplicarPedido(pedido.id);
        ref.invalidate(pedidosProvider);
        ref.invalidate(dashboardProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Duplicado como ${novo.loteFormatado}')),
          );
          context.push('/pedidos/${novo.id}/editar');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao duplicar: $e')),
          );
        }
      }
    } else if (action == 'reagendar') {
      try {
        await ref.read(apiClientProvider).agendarPedido(pedido.id);
        ref.invalidate(pedidoProvider(pedido.id));
        ref.invalidate(pedidosProvider);
        ref.invalidate(dashboardProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pedido reagendado')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao reagendar: $e')),
          );
        }
      }
    } else if (action == 'excluir') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Excluir pedido?'),
          content: Text('${pedido.loteFormatado} — ${pedido.clienteNome}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      try {
        await ref.read(apiClientProvider).deletarPedido(pedido.id);
        ref.invalidate(pedidosProvider);
        ref.invalidate(dashboardProvider);
        if (context.mounted) context.pop();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir: $e')),
          );
        }
      }
    }
  }
}

// ── Pagamentos sub-widget ──────────────────────────────────────────────────

class _PagamentosList extends ConsumerWidget {
  final String pedidoId;
  final double valorRestante;
  final NumberFormat moeda;
  final DateFormat data;
  const _PagamentosList({
    required this.pedidoId,
    required this.valorRestante,
    required this.moeda,
    required this.data,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagamentos = ref.watch(pagamentosProvider(pedidoId));
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pagamentos.when(
          loading: () => const Center(child: SizedBox(height: 48, child: CircularProgressIndicator())),
          error: (e, _) => Text('Erro ao carregar pagamentos', style: TextStyle(color: theme.colorScheme.error)),
          data: (lista) {
            if (lista.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Nenhum pagamento registrado',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                ),
              );
            }
            return Column(
              children: [
                for (final p in lista)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.check_circle, color: theme.colorScheme.primary),
                    title: Text(moeda.format(p.valor), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      '${_formaLabel(p.forma)} • ${data.format(p.quando)}${p.observacao != null && p.observacao!.isNotEmpty ? " — ${p.observacao}" : ""}',
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: theme.colorScheme.error, size: 20),
                      tooltip: 'Remover pagamento',
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Remover pagamento?'),
                            content: Text(moeda.format(p.valor)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                              FilledButton.tonal(
                                style: FilledButton.styleFrom(
                                  backgroundColor: theme.colorScheme.errorContainer,
                                ),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Remover'),
                              ),
                            ],
                          ),
                        );
                        if (ok != true) return;
                        try {
                          await ref.read(apiClientProvider).deletarPagamento(p.id);
                          ref.invalidate(pagamentosProvider(pedidoId));
                          ref.invalidate(pedidoProvider(pedidoId));
                          ref.invalidate(pedidosProvider);
                          ref.invalidate(dashboardProvider);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erro: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: () => _showRegistrarPagamento(context, ref),
            child: const Text('Registrar pagamento'),
          ),
        ),
      ],
    );
  }

  String _formaLabel(String? forma) {
    return switch (forma) {
      'dinheiro' => 'Dinheiro',
      'pix' => 'Pix',
      'cartao_credito' => 'Cartão crédito',
      'cartao_debito' => 'Cartão débito',
      'boleto' => 'Boleto',
      'transferencia' => 'Transferência',
      _ => forma ?? '—',
    };
  }

  void _showRegistrarPagamento(BuildContext context, WidgetRef ref) {
    final valorCtl = TextEditingController(text: valorRestante.toStringAsFixed(2).replaceAll('.', ','));
    String? forma = 'pix';
    final obsCtl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Registrar pagamento', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: valorCtl,
                  decoration: const InputDecoration(
                    labelText: 'Valor (R\$)',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Obrigatório';
                    final val = v.trim().replaceAll('.', '').replaceAll(',', '.');
                    if (double.tryParse(val) == null || double.parse(val) <= 0) return 'Inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: forma,
                  decoration: const InputDecoration(labelText: 'Forma'),
                  items: const [
                    DropdownMenuItem(value: 'dinheiro', child: Text('Dinheiro')),
                    DropdownMenuItem(value: 'pix', child: Text('Pix')),
                    DropdownMenuItem(value: 'cartao_credito', child: Text('Cartão crédito')),
                    DropdownMenuItem(value: 'cartao_debito', child: Text('Cartão débito')),
                    DropdownMenuItem(value: 'boleto', child: Text('Boleto')),
                    DropdownMenuItem(value: 'transferencia', child: Text('Transferência')),
                  ],
                  onChanged: (v) => forma = v,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: obsCtl,
                  decoration: const InputDecoration(
                    labelText: 'Observação',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final valor = valorCtl.text.trim().replaceAll('.', '').replaceAll(',', '.');
                      try {
                        await ref.read(apiClientProvider).registrarPagamento(pedidoId, {
                          'valor': double.parse(valor),
                          'forma': forma,
                          if (obsCtl.text.trim().isNotEmpty) 'observacao': obsCtl.text.trim(),
                        });
                        ref.invalidate(pagamentosProvider(pedidoId));
                        ref.invalidate(pedidoProvider(pedidoId));
                        ref.invalidate(pedidosProvider);
                        ref.invalidate(dashboardProvider);
                        if (context.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erro: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('Registrar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────

class _Info extends StatelessWidget {
  final String label;
  final String? valor;
  const _Info(this.label, this.valor);

  @override
  Widget build(BuildContext context) {
    if (valor == null || valor!.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(valor!, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}