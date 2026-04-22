import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/pedido.dart';
import '../../state/pedidos_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pedido_form_sheet.dart';
import '../../widgets/pedido_row.dart';
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

String _periodoLabel(String? de, String? ate) {
  String fmt(String yyyymmdd) {
    final p = yyyymmdd.split('-');
    if (p.length != 3) return yyyymmdd;
    return '${p[2]}/${p[1]}';
  }
  if (de != null && ate != null) return '${fmt(de)} → ${fmt(ate)}';
  if (de != null) return 'a partir de ${fmt(de)}';
  if (ate != null) return 'até ${fmt(ate)}';
  return '';
}

class PedidosScreen extends ConsumerStatefulWidget {
  const PedidosScreen({super.key});

  @override
  ConsumerState<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends ConsumerState<PedidosScreen> {
  final _buscaCtl = TextEditingController();
  final _buscaFocus = FocusNode();
  _ViewMode _view = _ViewMode.lista;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Preenche o controller com a busca persistida no provider (caso o usuário
    // saia e volte — o estado do Riverpod sobrevive a rebuild da tela).
    final buscaAtual = ref.read(pedidosFiltroProvider).busca;
    if (buscaAtual != null) _buscaCtl.text = buscaAtual;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _buscaCtl.dispose();
    _buscaFocus.dispose();
    super.dispose();
  }

  void _onBuscaChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(pedidosFiltroProvider.notifier).update(
            (f) => f.copyWith(
              busca: v.trim().isEmpty ? null : v.trim(),
              resetBusca: v.trim().isEmpty,
            ),
          );
    });
  }

  void _limparBusca() {
    _debounce?.cancel();
    _buscaCtl.clear();
    ref.read(pedidosFiltroProvider.notifier).update(
          (f) => f.copyWith(resetBusca: true),
        );
  }

  @override
  Widget build(BuildContext context) {
    final pedidos = ref.watch(pedidosProvider);
    final filtro = ref.watch(pedidosFiltroProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos'),
        actions: [
          // Toggle Lista/Kanban no AppBar — economiza espaço vertical.
          IconButton(
            icon: Icon(_view == _ViewMode.lista
                ? Icons.view_kanban_outlined
                : Icons.view_list_outlined),
            tooltip: _view == _ViewMode.lista ? 'Kanban' : 'Lista',
            onPressed: () => setState(() => _view = _view == _ViewMode.lista
                ? _ViewMode.kanban
                : _ViewMode.lista),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: () => ref.invalidate(pedidosProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => PedidoFormSheet.show(context),
        icon: const Icon(Icons.add),
        label: const Text('Novo pedido'),
      ),
      body: Column(
        children: [
          _FiltrosHeader(
            buscaCtl: _buscaCtl,
            buscaFocus: _buscaFocus,
            filtro: filtro,
            onBuscaChanged: _onBuscaChanged,
            onLimparBusca: _limparBusca,
          ),
          Expanded(
            child: _view == _ViewMode.kanban
                ? const KanbanView()
                : _ListaView(async: pedidos, filtro: filtro),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  HEADER DE FILTROS — compacto, 2 linhas no máximo
// ═══════════════════════════════════════════════════════════════════════════

class _FiltrosHeader extends ConsumerWidget {
  final TextEditingController buscaCtl;
  final FocusNode buscaFocus;
  final PedidosFiltro filtro;
  final ValueChanged<String> onBuscaChanged;
  final VoidCallback onLimparBusca;

  const _FiltrosHeader({
    required this.buscaCtl,
    required this.buscaFocus,
    required this.filtro,
    required this.onBuscaChanged,
    required this.onLimparBusca,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: LayoutBuilder(
        builder: (context, c) {
          final estreito = c.maxWidth < 720;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Linha 1: busca + status (em wide) ou só busca (estreito)
              if (estreito) ...[
                _buildBusca(context),
                const SizedBox(height: 8),
                _buildStatusSelector(context, ref),
              ] else
                Row(
                  children: [
                    SizedBox(width: 320, child: _buildBusca(context)),
                    const SizedBox(width: 12),
                    Expanded(child: Center(child: _buildStatusSelector(context, ref))),
                  ],
                ),
              const SizedBox(height: 8),
              // Linha 2: chips de flags + ordem + período
              _buildChipsRow(context, ref),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBusca(BuildContext context) {
    return TextField(
      controller: buscaCtl,
      focusNode: buscaFocus,
      decoration: InputDecoration(
        hintText: 'Buscar por cliente, descrição, lote...',
        prefixIcon: const Icon(Icons.search, size: 18),
        isDense: true,
        suffixIcon: buscaCtl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: onLimparBusca,
                visualDensity: VisualDensity.compact,
                splashRadius: 16,
                tooltip: 'Limpar',
              )
            : null,
      ),
      textInputAction: TextInputAction.search,
      onChanged: onBuscaChanged,
    );
  }

  Widget _buildStatusSelector(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<String?>(
        style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
        emptySelectionAllowed: true,
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 'pendente', label: Text('Pendente')),
          ButtonSegment(value: 'agendado', label: Text('Agendado')),
          ButtonSegment(value: 'producao', label: Text('Produção')),
          ButtonSegment(value: 'entregue', label: Text('Entregue')),
        ],
        selected: filtro.status == null ? <String?>{} : {filtro.status},
        onSelectionChanged: (s) {
          final v = s.isEmpty ? null : s.first;
          ref.read(pedidosFiltroProvider.notifier).update(
                (f) => f.copyWith(status: v, resetStatus: v == null),
              );
        },
      ),
    );
  }

  Widget _buildChipsRow(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          FilterChip(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            label: const Text('Urgentes', style: TextStyle(fontSize: 11.5)),
            avatar: const Icon(Icons.local_fire_department, size: 14),
            selected: filtro.urgenteOnly,
            onSelected: (v) => ref.read(pedidosFiltroProvider.notifier).update(
                  (f) => f.copyWith(urgenteOnly: v),
                ),
          ),
          const SizedBox(width: 6),
          FilterChip(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            label: const Text('Devendo', style: TextStyle(fontSize: 11.5)),
            avatar: const Icon(Icons.error_outline, size: 14),
            selected: filtro.statusPagamento == 'devendo',
            onSelected: (v) => ref.read(pedidosFiltroProvider.notifier).update(
                  (f) => f.copyWith(
                    statusPagamento: v ? 'devendo' : null,
                    resetStatusPagamento: !v,
                  ),
                ),
          ),
          const SizedBox(width: 10),
          // Ordenação: PopupMenu ancorado num chip (uma interação só).
          _OrdenarChip(filtro: filtro),
          if (filtro.de != null || filtro.ate != null) ...[
            const SizedBox(width: 6),
            InputChip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              avatar: const Icon(Icons.event, size: 14),
              label: Text(_periodoLabel(filtro.de, filtro.ate),
                  style: const TextStyle(fontSize: 11.5)),
              onDeleted: () => ref
                  .read(pedidosFiltroProvider.notifier)
                  .update((f) => f.copyWith(resetPeriodo: true)),
            ),
          ],
          if (filtro.algumFiltroAtivo) ...[
            const SizedBox(width: 10),
            TextButton.icon(
              onPressed: () => ref.read(pedidosFiltroProvider.notifier).update(
                    (f) => const PedidosFiltro(),
                  ),
              icon: const Icon(Icons.close, size: 14),
              label: const Text('Limpar', style: TextStyle(fontSize: 11.5)),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrdenarChip extends ConsumerWidget {
  final PedidosFiltro filtro;
  const _OrdenarChip({required this.filtro});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final label = _ordenacoes[filtro.ordenar] ?? filtro.ordenar;
    return PopupMenuButton<String>(
      tooltip: 'Ordenar',
      onSelected: (v) => ref
          .read(pedidosFiltroProvider.notifier)
          .update((f) => f.copyWith(ordenar: v)),
      itemBuilder: (ctx) => [
        for (final e in _ordenacoes.entries)
          PopupMenuItem(
            value: e.key,
            height: 36,
            child: Row(
              children: [
                Icon(
                  Icons.check,
                  size: 16,
                  color: filtro.ordenar == e.key
                      ? cs.primary
                      : Colors.transparent,
                ),
                const SizedBox(width: 8),
                Text(e.value, style: const TextStyle(fontSize: 12.5)),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 16, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  LISTA — tabela em wide, cards em mobile
// ═══════════════════════════════════════════════════════════════════════════

class _ListaView extends ConsumerWidget {
  final AsyncValue<List<Pedido>> async;
  final PedidosFiltro filtro;

  const _ListaView({required this.async, required this.filtro});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorState(
        message: e.toString(),
        onRetry: () => ref.invalidate(pedidosProvider),
      ),
      data: (lista) {
        if (lista.isEmpty) {
          return EmptyState(
            icon: filtro.algumFiltroAtivo ? Icons.filter_alt_off_outlined : Icons.inbox_outlined,
            titulo: filtro.algumFiltroAtivo ? 'Nenhum pedido encontrado' : 'Nenhum pedido ainda',
            subtitulo: filtro.algumFiltroAtivo
                ? 'Tente limpar os filtros ou mudar a busca.'
                : 'Crie o primeiro pedido pra começar.',
            acao: filtro.algumFiltroAtivo
                ? TextButton.icon(
                    onPressed: () => ref
                        .read(pedidosFiltroProvider.notifier)
                        .update((f) => const PedidosFiltro()),
                    icon: const Icon(Icons.close),
                    label: const Text('Limpar filtros'),
                  )
                : FilledButton.icon(
                    onPressed: () => PedidoFormSheet.show(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Novo pedido'),
                  ),
          );
        }
        return Column(
          children: [
            _ResumoBanner(pedidos: lista),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(pedidosProvider),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 600) {
                      return _buildMobileCards(context, lista);
                    }
                    return _buildTabela(context, lista, constraints);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMobileCards(BuildContext context, List<Pedido> lista) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: lista.length,
      itemBuilder: (_, i) => PedidoCardMobile(
        pedido: lista[i],
        onTap: () => context.push('/pedidos/${lista[i].id}'),
        zebra: i.isOdd,
      ),
    );
  }

  Widget _buildTabela(BuildContext context, List<Pedido> lista, BoxConstraints constraints) {
    const minTableWidth = 720.0;
    final tableWidth = constraints.maxWidth >= minTableWidth
        ? constraints.maxWidth
        : minTableWidth;
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: tableWidth,
          height: constraints.maxHeight,
          child: Column(
            children: [
              const PedidosHeader(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: lista.length,
                  itemBuilder: (_, i) => PedidoRow(
                    pedido: lista[i],
                    onTap: () => context.push('/pedidos/${lista[i].id}'),
                    zebra: i.isOdd,
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

/// Banner compacto no topo da lista com contagens e totais agregados.
class _ResumoBanner extends StatelessWidget {
  final List<Pedido> pedidos;
  const _ResumoBanner({required this.pedidos});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);

    final total = pedidos.fold<double>(0, (s, p) => s + p.valor);
    final devendo = pedidos
        .where((p) => p.statusPagamento != 'pago')
        .fold<double>(0, (s, p) => s + p.valorRestante);
    final urgentes = pedidos.where((p) => p.urgente).length;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
      ),
      padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
      child: Row(
        children: [
          _Metric(
            label: 'pedidos',
            valor: '${pedidos.length}',
            color: cs.onSurface,
          ),
          const SizedBox(width: 16),
          _Metric(
            label: 'total',
            valor: moeda.format(total),
            color: cs.onSurface,
          ),
          if (devendo > 0.01) ...[
            const SizedBox(width: 16),
            _Metric(
              label: 'devendo',
              valor: moeda.format(devendo),
              color: cs.error,
            ),
          ],
          if (urgentes > 0) ...[
            const SizedBox(width: 16),
            _Metric(
              label: 'urgentes',
              valor: '$urgentes',
              color: cs.tertiary,
              icon: Icons.local_fire_department,
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String valor;
  final Color color;
  final IconData? icon;

  const _Metric({
    required this.label,
    required this.valor,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
        ],
        Text(
          valor,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
