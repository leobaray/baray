import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/pedidos_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pedido_card.dart';

class PedidosScreen extends ConsumerStatefulWidget {
  const PedidosScreen({super.key});

  @override
  ConsumerState<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends ConsumerState<PedidosScreen> {
  final _buscaCtl = TextEditingController();

  @override
  void dispose() {
    _buscaCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pedidos = ref.watch(pedidosProvider);
    final filtro = ref.watch(pedidosFiltroProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: 'Ordenar',
            onPressed: () async {
              final ordenar = await showDialog<String>(
                context: context,
                builder: (_) => SimpleDialog(
                  title: const Text('Ordenar por'),
                  children: [
                    SimpleDialogOption(child: const Text('Mais recentes'), onPressed: () => Navigator.pop(context, 'lote')),
                    SimpleDialogOption(child: const Text('Valor maior'), onPressed: () => Navigator.pop(context, 'valor')),
                    SimpleDialogOption(child: const Text('Valor menor'), onPressed: () => Navigator.pop(context, 'valor_asc')),
                    SimpleDialogOption(child: const Text('Data produção'), onPressed: () => Navigator.pop(context, 'data_producao')),
                    SimpleDialogOption(child: const Text('Prazo'), onPressed: () => Navigator.pop(context, 'prazo')),
                    SimpleDialogOption(child: const Text('Criado recente'), onPressed: () => Navigator.pop(context, 'criado')),
                  ],
                ),
              );
              if (ordenar != null) {
                ref.read(pedidosFiltroProvider.notifier).update((f) => f.copyWith(ordenar: ordenar));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: () => ref.invalidate(pedidosProvider),
          ),
          IconButton(
            icon: const Icon(Icons.view_kanban_outlined),
            tooltip: 'Kanban',
            onPressed: () => context.go('/kanban'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/pedidos/novo'),
        icon: const Icon(Icons.add),
        label: const Text('Novo pedido'),
      ),
      body: Column(
        children: [
          // Busca
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _buscaCtl,
              decoration: const InputDecoration(
                hintText: 'Buscar por cliente, descrição...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => ref.read(pedidosFiltroProvider.notifier).update(
                    (f) => f.copyWith(busca: v.isEmpty ? null : v, resetBusca: v.isEmpty),
                  ),
            ),
          ),
          // Filtros
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                FilterChip(
                  label: const Text('Urgentes'),
                  selected: filtro.urgenteOnly,
                  onSelected: (v) => ref.read(pedidosFiltroProvider.notifier).update(
                        (f) => f.copyWith(urgenteOnly: v),
                      ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Pendentes'),
                  selected: filtro.status == 'pendente',
                  onSelected: (v) => ref.read(pedidosFiltroProvider.notifier).update(
                        (f) => f.copyWith(status: v ? 'pendente' : null, resetStatus: !v),
                      ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Agendados'),
                  selected: filtro.status == 'agendado',
                  onSelected: (v) => ref.read(pedidosFiltroProvider.notifier).update(
                        (f) => f.copyWith(status: v ? 'agendado' : null, resetStatus: !v),
                      ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Em produção'),
                  selected: filtro.status == 'producao',
                  onSelected: (v) => ref.read(pedidosFiltroProvider.notifier).update(
                        (f) => f.copyWith(status: v ? 'producao' : null, resetStatus: !v),
                      ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Entregues'),
                  selected: filtro.status == 'entregue',
                  onSelected: (v) => ref.read(pedidosFiltroProvider.notifier).update(
                        (f) => f.copyWith(status: v ? 'entregue' : null, resetStatus: !v),
                      ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Devendo'),
                  selected: filtro.statusPagamento == 'devendo',
                  onSelected: (v) => ref.read(pedidosFiltroProvider.notifier).update(
                        (f) => f.copyWith(statusPagamento: v ? 'devendo' : null, resetStatusPagamento: !v),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Lista
          Expanded(
            child: pedidos.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(pedidosProvider),
              ),
              data: (lista) {
                if (lista.isEmpty) {
                  return EmptyState(
                    icon: Icons.inbox_outlined,
                    titulo: 'Nenhum pedido',
                    subtitulo: filtro.algumFiltroAtivo ? 'Tente limpar os filtros' : 'Toque em "Novo pedido" para começar',
                    acao: filtro.algumFiltroAtivo
                        ? TextButton(
                            onPressed: () => ref.read(pedidosFiltroProvider.notifier).update(
                                  (f) => const PedidosFiltro(),
                                ),
                            child: const Text('Limpar filtros'),
                          )
                        : null,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(pedidosProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    itemCount: lista.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => PedidoCard(
                      pedido: lista[i],
                      onTap: () => context.push('/pedidos/${lista[i].id}'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}