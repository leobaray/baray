import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/pedidos_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pedido_card.dart';
import '../kanban/kanban_screen.dart';

enum _ViewMode { lista, kanban }

const _ordenacoes = <String, String>{
  'lote': 'Mais recentes',
  'valor': 'Valor (maior)',
  'valor_asc': 'Valor (menor)',
  'data_producao': 'Data produção',
  'prazo': 'Prazo',
  'criado': 'Criado recente',
};

class PedidosScreen extends ConsumerStatefulWidget {
  const PedidosScreen({super.key});

  @override
  ConsumerState<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends ConsumerState<PedidosScreen> {
  final _buscaCtl = TextEditingController();
  _ViewMode _view = _ViewMode.lista;

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
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Ordenar',
            onSelected: (v) => ref
                .read(pedidosFiltroProvider.notifier)
                .update((f) => f.copyWith(ordenar: v)),
            itemBuilder: (context) => [
              for (final e in _ordenacoes.entries)
                PopupMenuItem(
                  value: e.key,
                  child: Row(
                    children: [
                      Icon(
                        Icons.check,
                        size: 18,
                        color: filtro.ordenar == e.key
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                      ),
                      const SizedBox(width: 8),
                      Text(e.value),
                    ],
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: () => ref.invalidate(pedidosProvider),
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
          // Toggle Lista ↔ Kanban
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<_ViewMode>(
              segments: const [
                ButtonSegment(
                  value: _ViewMode.lista,
                  label: Text('Lista'),
                  icon: Icon(Icons.view_list_outlined),
                ),
                ButtonSegment(
                  value: _ViewMode.kanban,
                  label: Text('Kanban'),
                  icon: Icon(Icons.view_kanban_outlined),
                ),
              ],
              selected: {_view},
              onSelectionChanged: (s) => setState(() => _view = s.first),
            ),
          ),
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
          const SizedBox(height: 8),
          // Status mutuamente exclusivos
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String?>(
                emptySelectionAllowed: true,
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: null, label: Text('Todos')),
                  ButtonSegment(value: 'pendente', label: Text('Pendente')),
                  ButtonSegment(value: 'agendado', label: Text('Agendado')),
                  ButtonSegment(value: 'producao', label: Text('Produção')),
                  ButtonSegment(value: 'entregue', label: Text('Entregue')),
                ],
                selected: {filtro.status},
                onSelectionChanged: (s) {
                  final v = s.isEmpty ? null : s.first;
                  ref.read(pedidosFiltroProvider.notifier).update(
                        (f) => f.copyWith(status: v, resetStatus: v == null),
                      );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Flags independentes + ordenação ativa
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                FilterChip(
                  label: const Text('Urgentes'),
                  avatar: const Icon(Icons.flash_on, size: 16),
                  selected: filtro.urgenteOnly,
                  onSelected: (v) => ref.read(pedidosFiltroProvider.notifier).update(
                        (f) => f.copyWith(urgenteOnly: v),
                      ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Devendo'),
                  avatar: const Icon(Icons.error_outline, size: 16),
                  selected: filtro.statusPagamento == 'devendo',
                  onSelected: (v) => ref.read(pedidosFiltroProvider.notifier).update(
                        (f) => f.copyWith(statusPagamento: v ? 'devendo' : null, resetStatusPagamento: !v),
                      ),
                ),
                const SizedBox(width: 12),
                InputChip(
                  avatar: const Icon(Icons.sort, size: 16),
                  label: Text(_ordenacoes[filtro.ordenar] ?? filtro.ordenar),
                  onDeleted: filtro.ordenar == 'lote'
                      ? null
                      : () => ref
                          .read(pedidosFiltroProvider.notifier)
                          .update((f) => f.copyWith(ordenar: 'lote')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Lista ou Kanban
          Expanded(
            child: _view == _ViewMode.kanban
                ? const KanbanView()
                : pedidos.when(
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
                          subtitulo: filtro.algumFiltroAtivo
                              ? 'Tente limpar os filtros'
                              : 'Toque em "Novo pedido" para começar',
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
