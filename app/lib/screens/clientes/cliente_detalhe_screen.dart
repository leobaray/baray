import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/cliente_fechamento.dart';
import '../../state/cliente_fechamentos_provider.dart';
import '../../state/clientes_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/fechamento_status_badge.dart';
import '../../widgets/pedido_card.dart';
import '../../widgets/resumo_row.dart';
import '../../widgets/tint_chip.dart';
import 'fechamento_fechar_dialog.dart';
import 'fechamento_estender_dialog.dart';

class ClienteDetalheScreen extends ConsumerWidget {
  final String clienteId;
  const ClienteDetalheScreen({super.key, required this.clienteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valAsync = ref.watch(clienteDetalheProvider(clienteId));
    final theme = Theme.of(context);
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dataFmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: valAsync.when(
          loading: () => const Text('Cliente'),
          error: (_, __) => const Text('Cliente'),
          data: (c) => Text(c.nome),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar',
            onPressed: () => context.push('/clientes/$clienteId/editar'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/pedidos/novo?cliente_id=$clienteId'),
        icon: const Icon(Icons.add),
        label: const Text('Novo pedido'),
      ),
      body: valAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(clienteDetalheProvider(clienteId)),
        ),
        data: (cliente) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(clienteDetalheProvider(clienteId));
            ref.invalidate(fechamentosProvider(clienteId));
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              // Header card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(27),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              cliente.iniciais,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cliente.nome,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (cliente.telefone != null && cliente.telefone!.isNotEmpty)
                        _InfoRow(icon: Icons.call_outlined, text: cliente.telefone!, theme: theme),
                      if (cliente.email != null && cliente.email!.isNotEmpty)
                        _InfoRow(icon: Icons.mail_outline, text: cliente.email!, theme: theme),
                      if (cliente.endereco != null && cliente.endereco!.isNotEmpty)
                        _InfoRow(icon: Icons.home_outlined, text: cliente.endereco!, theme: theme),
                      if (cliente.observacao != null && cliente.observacao!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            cliente.observacao!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TintChip(
                            icon: Icons.assignment_outlined,
                            label: '${cliente.totalPedidos} pedido${cliente.totalPedidos == 1 ? '' : 's'}',
                          ),
                          TintChip(
                            icon: Icons.payments_outlined,
                            label: moeda.format(cliente.totalGasto),
                            strong: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Fechamento Atual ────────────────────────────────────────
              if (cliente.fechamentoAtivo && cliente.fechamentoAtual != null) ...[
                const SizedBox(height: 16),
                _FechamentoAtualCard(
                  fechamento: cliente.fechamentoAtual!,
                  clienteId: clienteId,
                  moeda: moeda,
                  dataFmt: dataFmt,
                ),
              ],

              // ── Histórico de Fechamentos ────────────────────────────────
              if (cliente.fechamentoAtivo) ...[
                const SizedBox(height: 16),
                _HistoricoFechamentos(clienteId: clienteId),
              ],

              // ── Histórico de pedidos ───────────────────────────────────
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(icon: Icons.history, title: 'Histórico de pedidos'),
                      const SizedBox(height: 12),
                      if (cliente.pedidos == null || cliente.pedidos!.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Nenhum pedido ainda',
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                          ),
                        )
                      else
                        ...cliente.pedidos!.map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: PedidoCard(
                              pedido: p,
                              onTap: () => context.push('/pedidos/${p.id}'),
                              compacto: true,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Fechamento Atual Card ────────────────────────────────────────────────

class _FechamentoAtualCard extends ConsumerWidget {
  final ClienteFechamento fechamento;
  final String clienteId;
  final NumberFormat moeda;
  final DateFormat dataFmt;

  const _FechamentoAtualCard({
    required this.fechamento,
    required this.clienteId,
    required this.moeda,
    required this.dataFmt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final f = fechamento;
    final onContainer = theme.colorScheme.onPrimaryContainer;

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: onContainer, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ciclo #${f.numero} — ${f.statusLabel}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: onContainer,
                    ),
                  ),
                ),
                FechamentoStatusBadge(status: f.status),
              ],
            ),
            const SizedBox(height: 16),
            ResumoRow(
              label: 'Período',
              value: '${dataFmt.format(f.dataAbertura)} — ${dataFmt.format(f.dataFechamentoPrevista)}',
              onContainer: onContainer,
            ),
            const SizedBox(height: 8),
            ResumoRow(label: 'Pedidos', value: '${f.totalPedidos}', onContainer: onContainer),
            const SizedBox(height: 8),
            ResumoRow(label: 'Valor total', value: moeda.format(f.valorTotal), onContainer: onContainer),
            const SizedBox(height: 8),
            ResumoRow(
              label: 'Valor pago',
              value: moeda.format(f.valorPago),
              valueColor: theme.colorScheme.primary,
              onContainer: onContainer,
            ),
            const SizedBox(height: 8),
            ResumoRow(
              label: 'Pendente',
              value: moeda.format(f.valorPendente),
              valueColor: f.valorPendente > 0 ? theme.colorScheme.error : theme.colorScheme.primary,
              onContainer: onContainer,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _fechar(context, ref),
                    icon: const Icon(Icons.lock_outline, size: 18),
                    label: const Text('Fechar agora'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _estender(context, ref),
                    icon: const Icon(Icons.schedule_outlined, size: 18),
                    label: const Text('Estender'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fechar(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => FechamentoFecharDialog(fechamento: fechamento),
    );
    if (result == true) {
      ref.invalidate(clienteDetalheProvider(clienteId));
      ref.invalidate(fechamentosProvider(clienteId));
    }
  }

  Future<void> _estender(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => FechamentoEstenderDialog(
        fechamento: fechamento,
        clienteId: clienteId,
      ),
    );
    if (result == true) {
      ref.invalidate(clienteDetalheProvider(clienteId));
      ref.invalidate(fechamentosProvider(clienteId));
    }
  }
}

// ── Histórico de Fechamentos ─────────────────────────────────────────────

class _HistoricoFechamentos extends ConsumerWidget {
  final String clienteId;
  const _HistoricoFechamentos({required this.clienteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fechAsync = ref.watch(fechamentosProvider(clienteId));
    final theme = Theme.of(context);
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dataFmt = DateFormat('dd/MM/yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(icon: Icons.folder_outlined, title: 'Histórico de fechamentos'),
        const SizedBox(height: 8),
        fechAsync.when(
          loading: () => const Center(child: SizedBox(height: 32, width: 32, child: CircularProgressIndicator(strokeWidth: 2))),
          error: (e, _) => Text('Erro: $e', style: TextStyle(color: theme.colorScheme.error)),
          data: (fechamentos) {
            final fechados = fechamentos.where((f) => f.fechado).toList();
            if (fechados.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Nenhum fechamento concluído ainda',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final f in fechados)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: InkWell(
                        onTap: () => context.push('/clientes/$clienteId/fechamentos/${f.id}'),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.folder_outlined, color: theme.colorScheme.onSurfaceVariant, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Ciclo #${f.numero}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${dataFmt.format(f.dataAbertura)} — ${dataFmt.format(f.dataFechamentoReal ?? f.dataFechamentoPrevista)}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    moeda.format(f.valorTotal),
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${f.totalPedidos} pedido${f.totalPedidos == 1 ? '' : 's'}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final ThemeData theme;
  const _InfoRow({required this.icon, required this.text, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Flexible(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

