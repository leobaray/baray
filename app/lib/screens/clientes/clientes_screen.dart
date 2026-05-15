import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/cliente.dart';
import '../../state/clientes_provider.dart';
import '../../theme/breakpoints.dart';
import '../../util/formatters.dart';
import '../../widgets/cliente_detalhe_view.dart';
import '../../widgets/cliente_row.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/list_skeleton.dart';

const _ordenacoes = <String, String>{
  'nome': 'Nome (A-Z)',
  'gasto': 'Maior gasto',
  'devendo': 'Maior débito',
  'pedidos': 'Mais pedidos',
  'recente': 'Mais recentes',
};

class ClientesScreen extends ConsumerStatefulWidget {
  const ClientesScreen({super.key});

  @override
  ConsumerState<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends ConsumerState<ClientesScreen> {
  final _buscaCtl = TextEditingController();
  final _buscaFocus = FocusNode();
  String? _selecionadoId;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Restaura o texto do campo se o provider já tinha uma busca.
    final buscaAtual = ref.read(clientesFiltroProvider).busca;
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
      ref.read(clientesFiltroProvider.notifier).update(
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
    ref
        .read(clientesFiltroProvider.notifier)
        .update((f) => f.copyWith(resetBusca: true));
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.medium;
    final clientes = ref.watch(clientesProvider);
    final filtro = ref.watch(clientesFiltroProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: [
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/clientes/novo'),
        icon: const Icon(Icons.add),
        label: const Text('Novo cliente'),
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
            child: wide
                ? _buildSplit(context, clientes, filtro)
                : _buildList(context, clientes, filtro, fullWidth: true),
          ),
        ],
      ),
    );
  }

  Widget _buildSplit(BuildContext context, AsyncValue<List<Cliente>> clientes, ClientesFiltro filtro) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 340,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: cs.outlineVariant)),
            ),
            child: _buildList(context, clientes, filtro, fullWidth: false),
          ),
        ),
        Expanded(
          child: _selecionadoId == null
              ? _buildEmptyDetail(context)
              : ClienteDetalheView(
                  key: ValueKey(_selecionadoId),
                  clienteId: _selecionadoId!,
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyDetail(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      child: EmptyState(
        icon: Icons.touch_app_outlined,
        titulo: 'Selecione um cliente',
        subtitulo: 'A ficha completa aparece aqui — pedidos, ciclos e fechamentos.',
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    AsyncValue<List<Cliente>> clientes,
    ClientesFiltro filtro, {
    required bool fullWidth,
  }) {
    return clientes.when(
      loading: () => const ListSkeleton(itemHeight: 72),
      error: (e, _) => ErrorState(
        message: e.toString(),
        onRetry: () => ref.invalidate(clientesProvider),
      ),
      data: (lista) {
        if (lista.isEmpty) {
          return EmptyState(
            icon: filtro.algumFiltroAtivo ? Icons.filter_alt_off_outlined : Icons.people_outline,
            titulo: filtro.algumFiltroAtivo ? 'Nenhum cliente encontrado' : 'Nenhum cliente ainda',
            subtitulo: filtro.algumFiltroAtivo
                ? 'Tente mudar a busca ou limpar filtros.'
                : 'Cadastre o primeiro cliente pra começar.',
            acao: filtro.algumFiltroAtivo
                ? TextButton.icon(
                    onPressed: () => ref
                        .read(clientesFiltroProvider.notifier)
                        .update((f) => const ClientesFiltro()),
                    icon: const Icon(Icons.close),
                    label: const Text('Limpar filtros'),
                  )
                : FilledButton.icon(
                    onPressed: () => context.push('/clientes/novo'),
                    icon: const Icon(Icons.add),
                    label: const Text('Novo cliente'),
                  ),
          );
        }

        return Column(
          children: [
            _ResumoBanner(clientes: lista),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(clientesProvider),
                child: ListView.builder(
                  padding: EdgeInsets.only(bottom: fullWidth ? 96 : 12),
                  itemCount: lista.length,
                  itemBuilder: (_, i) {
                    final c = lista[i];
                    return ClienteRow(
                      cliente: c,
                      selected: !fullWidth && _selecionadoId == c.id,
                      zebra: i.isOdd,
                      onTap: () {
                        if (fullWidth) {
                          context.push('/clientes/${c.id}');
                        } else {
                          setState(() => _selecionadoId = c.id);
                        }
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  HEADER DE FILTROS
// ═══════════════════════════════════════════════════════════════════════════

class _FiltrosHeader extends ConsumerWidget {
  final TextEditingController buscaCtl;
  final FocusNode buscaFocus;
  final ClientesFiltro filtro;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: buscaCtl,
            focusNode: buscaFocus,
            decoration: InputDecoration(
              labelText: 'Buscar',
              hintText: 'nome ou telefone',
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              suffixIcon: buscaCtl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: onLimparBusca,
                      tooltip: 'Limpar',
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    )
                  : null,
            ),
            textInputAction: TextInputAction.search,
            onChanged: onBuscaChanged,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                FilterChip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: const Text('Com débito', style: TextStyle(fontSize: 11.5)),
                  avatar: const Icon(Icons.error_outline, size: 14),
                  selected: filtro.comDebito,
                  onSelected: (v) => ref
                      .read(clientesFiltroProvider.notifier)
                      .update((f) => f.copyWith(comDebito: v)),
                ),
                const SizedBox(width: 10),
                _OrdenarChip(filtro: filtro),
                if (filtro.algumFiltroAtivo) ...[
                  const SizedBox(width: 10),
                  TextButton.icon(
                    onPressed: () => ref
                        .read(clientesFiltroProvider.notifier)
                        .update((f) => const ClientesFiltro()),
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
          ),
        ],
      ),
    );
  }
}

class _OrdenarChip extends ConsumerWidget {
  final ClientesFiltro filtro;
  const _OrdenarChip({required this.filtro});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final label = _ordenacoes[filtro.ordenar] ?? filtro.ordenar;
    return PopupMenuButton<String>(
      tooltip: 'Ordenar',
      onSelected: (v) => ref
          .read(clientesFiltroProvider.notifier)
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
                  color: filtro.ordenar == e.key ? cs.primary : Colors.transparent,
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
//  BANNER RESUMO
// ═══════════════════════════════════════════════════════════════════════════

class _ResumoBanner extends StatelessWidget {
  final List<Cliente> clientes;
  const _ResumoBanner({required this.clientes});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final moeda = AppFormatters.moedaInteira;
    final comDebito = clientes.where((c) => c.valorDevendo > 0.01).length;
    final totalDebito = clientes.fold<double>(0, (s, c) => s + c.valorDevendo);

    final resumoTexto = [
      '${clientes.length} clientes',
      if (comDebito > 0) '$comDebito com débito (${moeda.format(totalDebito)})',
    ].join(', ');

    return Semantics(
      liveRegion: true,
      label: 'Resumo: $resumoTexto',
      container: true,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
        ),
        padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _Metric(label: 'clientes', valor: '${clientes.length}', color: cs.onSurface),
              if (comDebito > 0) ...[
                const SizedBox(width: 16),
                _Metric(label: 'com débito', valor: '$comDebito', color: cs.error),
                const SizedBox(width: 16),
                _Metric(label: 'em aberto', valor: moeda.format(totalDebito), color: cs.error),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String valor;
  final Color color;

  const _Metric({required this.label, required this.valor, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
