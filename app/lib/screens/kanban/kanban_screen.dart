import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../models/pedido.dart';
import '../../state/pedidos_provider.dart';
import '../../state/dashboard_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pedido_card.dart';
import '../../widgets/status_pill.dart';

const _statusOrdem = ['pendente', 'agendado', 'producao', 'concluido', 'entregue'];

class KanbanScreen extends ConsumerWidget {
  const KanbanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedidos = ref.watch(pedidosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kanban'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: () {
              ref.invalidate(pedidosProvider);
              ref.invalidate(dashboardProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: 'Lista',
            onPressed: () => context.go('/pedidos'),
          ),
        ],
      ),
      body: pedidos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(pedidosProvider),
        ),
        data: (lista) {
          final porStatus = <String, List<Pedido>>{
            for (final s in _statusOrdem) s: [],
          };
          for (final p in lista) {
            if (porStatus.containsKey(p.status)) {
              porStatus[p.status]!.add(p);
            } else {
              porStatus.putIfAbsent(p.status, () => []).add(p);
            }
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final status in _statusOrdem) ...[
                  SizedBox(
                    width: 320,
                    child: _KanbanColuna(
                      status: status,
                      pedidos: porStatus[status]!,
                      onMover: (pedido, novoStatus) =>
                          _moverPedido(ref, context, pedido, novoStatus),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _moverPedido(WidgetRef ref, BuildContext context, Pedido pedido, String novoStatus) async {
    if (pedido.status == novoStatus) return;
    try {
      await ref.read(apiClientProvider).atualizarPedido(pedido.id, {'status': novoStatus});
      ref.invalidate(pedidosProvider);
      ref.invalidate(dashboardProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pedido movido')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao mover: $e')),
        );
      }
    }
  }
}

// ── Kanban column ──────────────────────────────────────────────────────────

class _KanbanColuna extends StatelessWidget {
  final String status;
  final List<Pedido> pedidos;
  final Future<void> Function(Pedido, String) onMover;

  const _KanbanColuna({
    required this.status,
    required this.pedidos,
    required this.onMover,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = statusInfo(context, status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: info.bg,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Row(
            children: [
              Icon(info.icon, size: 18, color: info.fg),
              const SizedBox(width: 8),
              Text(
                info.label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: info.fg,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: info.fg.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${pedidos.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: info.fg,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Drag target zone
        DragTarget<Pedido>(
          onAcceptWithDetails: (details) => onMover(details.data, status),
          builder: (context, candidateData, rejectedData) {
            final isHovering = candidateData.isNotEmpty;
            return Container(
              constraints: const BoxConstraints(minHeight: 200),
              decoration: BoxDecoration(
                color: isHovering
                    ? info.bg.withValues(alpha: 0.4)
                    : theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                border: Border.all(
                  color: isHovering ? info.fg.withValues(alpha: 0.4) : theme.colorScheme.outlineVariant,
                  width: isHovering ? 2 : 1,
                ),
              ),
              child: pedidos.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'Arraste aqui',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(8),
                      itemCount: pedidos.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final p = pedidos[i];
                        return Draggable<Pedido>(
                          data: p,
                          feedback: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              width: 296,
                              child: Opacity(
                                opacity: 0.85,
                                child: PedidoCard(
                                  pedido: p,
                                  onTap: () {},
                                  compacto: true,
                                ),
                              ),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.3,
                            child: PedidoCard(
                              pedido: p,
                              onTap: () => context.push('/pedidos/${p.id}'),
                              compacto: true,
                            ),
                          ),
                          child: PedidoCard(
                            pedido: p,
                            onTap: () => context.push('/pedidos/${p.id}'),
                            compacto: true,
                          ),
                        );
                      },
                    ),
            );
          },
        ),
      ],
    );
  }
}