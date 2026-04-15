import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
      body: const KanbanView(),
    );
  }
}

/// Corpo do kanban sem Scaffold — reutilizado pela PedidosScreen no toggle
/// Lista ↔ Kanban.
class KanbanView extends ConsumerWidget {
  const KanbanView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedidos = ref.watch(pedidosProvider);
    final wide = MediaQuery.sizeOf(context).width >= 720;

    return pedidos.when(
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

        if (!wide) {
          // Mobile: tabs por status pra não ter scroll horizontal infinito.
          return DefaultTabController(
            length: _statusOrdem.length,
            child: Column(
              children: [
                TabBar(
                  isScrollable: true,
                  tabs: [
                    for (final s in _statusOrdem)
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusInfo(context, s).icon, size: 16),
                            const SizedBox(width: 6),
                            Text('${statusInfo(context, s).label} (${porStatus[s]!.length})'),
                          ],
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      for (final s in _statusOrdem)
                        _KanbanColuna(
                          status: s,
                          pedidos: porStatus[s]!,
                          onMover: (p, ns) => _moverPedido(ref, context, p, ns),
                          mobileMode: true,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final status in _statusOrdem) ...[
                SizedBox(
                  width: 280,
                  child: _KanbanColuna(
                    status: status,
                    pedidos: porStatus[status]!,
                    onMover: (p, ns) => _moverPedido(ref, context, p, ns),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ],
          ),
        );
      },
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
  final bool mobileMode;

  const _KanbanColuna({
    required this.status,
    required this.pedidos,
    required this.onMover,
    this.mobileMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = statusInfo(context, status);
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final total = pedidos.fold<double>(0, (s, p) => s + p.valor);

    final header = mobileMode
        ? const SizedBox.shrink()
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: info.bg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(info.icon, size: 18, color: info.fg),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    info.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: info.fg,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${pedidos.length} · ${moeda.format(total)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: info.fg,
                  ),
                ),
              ],
            ),
          );

    final dropZone = DragTarget<Pedido>(
      onAcceptWithDetails: (details) => onMover(details.data, status),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          constraints: BoxConstraints(minHeight: mobileMode ? 0 : 200),
          decoration: BoxDecoration(
            color: isHovering
                ? info.bg.withValues(alpha: 0.4)
                : theme.colorScheme.surfaceContainerLow,
            borderRadius: mobileMode
                ? BorderRadius.zero
                : const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
            // Borda sempre 2px — transparente quando idle — evita "pulo" no hover.
            border: Border.all(
              color: isHovering
                  ? info.fg.withValues(alpha: 0.4)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: pedidos.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      mobileMode ? 'Nenhum pedido neste status' : 'Arraste aqui',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: !mobileMode,
                  physics: mobileMode
                      ? const AlwaysScrollableScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
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
                          width: 260,
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
    );

    if (mobileMode) return dropZone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, dropZone],
    );
  }
}
