import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../models/pedido.dart';
import '../../state/pedidos_provider.dart';
import '../../state/dashboard_provider.dart';
import '../../theme/breakpoints.dart';
import '../../util/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/list_skeleton.dart';
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
class KanbanView extends ConsumerStatefulWidget {
  const KanbanView({super.key});

  @override
  ConsumerState<KanbanView> createState() => _KanbanViewState();
}

class _KanbanViewState extends ConsumerState<KanbanView> with SingleTickerProviderStateMixin {
  // TabController persistente — não reseta o tab selecionado a cada refresh
  // do pedidosProvider (arrastar, mover, etc).
  late final TabController _tabController = TabController(length: _statusOrdem.length, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pedidos = ref.watch(pedidosProvider);
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.compact;

    return pedidos.when(
      loading: () => const ListSkeleton(itemHeight: 96),
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
          // Long-press num card abre bottom sheet com opções de status
          // (a única forma sensata de mover entre tabs em mobile).
          return Column(
            children: [
              TabBar(
                controller: _tabController,
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
                  controller: _tabController,
                  children: [
                    for (final s in _statusOrdem)
                      _KanbanColuna(
                        status: s,
                        pedidos: porStatus[s]!,
                        onMover: (p, ns) => _moverPedido(ref, context, p, ns),
                        onAbrirMenuStatus: (p) => _abrirMenuStatus(context, p),
                        mobileMode: true,
                      ),
                  ],
                ),
              ),
            ],
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
                    onAbrirMenuStatus: (p) => _abrirMenuStatus(context, p),
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

  Future<void> _abrirMenuStatus(BuildContext context, Pedido pedido) async {
    final escolha = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        final cs = Theme.of(sheetCtx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Text(
                    'Mover pedido para',
                    style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                for (final s in _statusOrdem)
                  ListTile(
                    enabled: s != pedido.status,
                    leading: Icon(statusInfo(sheetCtx, s).icon, color: statusInfo(sheetCtx, s).fg),
                    title: Text(
                      statusInfo(sheetCtx, s).label,
                      style: TextStyle(
                        fontWeight: s == pedido.status ? FontWeight.w400 : FontWeight.w600,
                      ),
                    ),
                    subtitle: s == pedido.status ? const Text('Status atual') : null,
                    trailing: s == pedido.status
                        ? Icon(Icons.check, color: cs.primary, size: 18)
                        : const Icon(Icons.arrow_forward, size: 18),
                    onTap: () => Navigator.of(sheetCtx).pop(s),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (escolha != null && context.mounted) {
      await _moverPedido(ref, context, pedido, escolha);
    }
  }

  Future<void> _moverPedido(WidgetRef ref, BuildContext context, Pedido pedido, String novoStatus) async {
    if (pedido.status == novoStatus) return;
    final statusOrigem = pedido.status;
    try {
      await ref.read(apiClientProvider).atualizarPedido(pedido.id, {'status': novoStatus});
      ref.invalidate(pedidosProvider);
      ref.invalidate(dashboardProvider);
      if (context.mounted) {
        final labelDestino = statusInfo(context, novoStatus).label;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Movido para $labelDestino'),
              action: SnackBarAction(
                label: 'Desfazer',
                onPressed: () async {
                  try {
                    await ref.read(apiClientProvider).atualizarPedido(pedido.id, {'status': statusOrigem});
                    ref.invalidate(pedidosProvider);
                    ref.invalidate(dashboardProvider);
                  } catch (_) {
                    // silencioso — o usuário verá que não voltou
                  }
                },
              ),
            ),
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
  final Future<void> Function(Pedido) onAbrirMenuStatus;
  final bool mobileMode;

  const _KanbanColuna({
    required this.status,
    required this.pedidos,
    required this.onMover,
    required this.onAbrirMenuStatus,
    this.mobileMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = statusInfo(context, status);
    final moeda = AppFormatters.moeda;
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
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final p = pedidos[i];
                    final card = PedidoCard(
                      pedido: p,
                      onTap: () => context.push('/pedidos/${p.id}?from=kanban'),
                      onLongPress: () => onAbrirMenuStatus(p),
                      compacto: true,
                      showDragHandle: !mobileMode,
                    );
                    // Mobile: drag entre tabs não faz sentido — só toque/long-press
                    // alternam status via bottom sheet. Em desktop, mantém Draggable.
                    if (mobileMode) {
                      return Semantics(
                        button: true,
                        label: 'Pedido — toque para abrir, segure para mudar status',
                        child: card,
                      );
                    }
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
                        child: card,
                      ),
                      child: Semantics(
                        button: true,
                        label: 'Pedido — toque para abrir, segure para mover',
                        child: card,
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
