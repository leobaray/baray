import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/pedido.dart';
import '../../state/configuracoes_provider.dart';
import '../../state/pedidos_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pedido_card.dart';
import '../../widgets/shimmer_skeleton.dart';

enum _Modo { lista, semana }

class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key});

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
  _Modo _modo = _Modo.lista;
  DateTime _semanaReferencia = DateTime.now();
  late final PageController _pageController = PageController(initialPage: 0);
  int _paginaAtual = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _yyyymmdd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _criarPedidoNoDia(DateTime dia) {
    context.push('/pedidos/novo?data_producao=${_yyyymmdd(dia)}&auto_agendar=false');
  }

  @override
  Widget build(BuildContext context) {
    final pedidos = ref.watch(pedidosProvider);
    final configs = ref.watch(configuracoesProvider);
    final theme = Theme.of(context);
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dataFmt = DateFormat("EEEE', 'dd/MM/yyyy", 'pt_BR');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda de produção'),
        actions: [
          IconButton(
            icon: Icon(_modo == _Modo.lista ? Icons.view_week : Icons.list),
            tooltip: _modo == _Modo.lista ? 'Modo semana' : 'Modo lista',
            onPressed: () => setState(() => _modo = _modo == _Modo.lista ? _Modo.semana : _Modo.lista),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(pedidosProvider);
              ref.invalidate(configuracoesProvider);
            },
          ),
        ],
      ),
      body: pedidos.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: 3,
          itemBuilder: (_, __) => const _AgendaCardSkeleton(),
        ),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(pedidosProvider),
        ),
        data: (lista) {
          final limite = configs.maybeWhen(
            data: (cs) => cs.firstWhere(
              (c) => c.chave == 'limite_diario',
              orElse: () => throw StateError('limite_diario ausente'),
            ).asNumber.toDouble(),
            orElse: () => 1200.0,
          );

          // Agrupar pedidos com dataProducao por dia
          final agrupado = <DateTime, List<Pedido>>{};
          for (final p in lista) {
            if (p.dataProducao == null) continue;
            final dia = DateTime(p.dataProducao!.year, p.dataProducao!.month, p.dataProducao!.day);
            agrupado.putIfAbsent(dia, () => []).add(p);
          }

          if (_modo == _Modo.lista) {
            return _modoLista(agrupado, limite, dataFmt, moeda, theme);
          } else {
            return _modoSemana(agrupado, limite, moeda, theme);
          }
        },
      ),
    );
  }

  // ── Modo Lista ───────────────────────────────────────────────────────────

  Widget _modoLista(
    Map<DateTime, List<Pedido>> agrupado,
    double limite,
    DateFormat dataFmt,
    NumberFormat moeda,
    ThemeData theme,
  ) {
    final dias = agrupado.keys.toList()..sort();

    if (dias.isEmpty) {
      return EmptyState(
        icon: Icons.event_available_outlined,
        titulo: 'Nada agendado',
        subtitulo: 'Pedidos com data de produção aparecem aqui',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(pedidosProvider),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: dias.length,
        itemBuilder: (_, i) {
          final dia = dias[i];
          final ps = agrupado[dia]!;
          final total = ps.fold<double>(0, (s, p) => s + p.valor);
          final pct = (total / limite).clamp(0.0, 1.5);
          final acima = total > limite;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            toBeginningOfSentenceCase(dataFmt.format(dia)) ?? '',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.15,
                            ),
                          ),
                        ),
                        Text(
                          '${moeda.format(total)} / ${moeda.format(limite)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: acima ? theme.colorScheme.error : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(
                          acima ? theme.colorScheme.error : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    if (acima)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Acima do limite diário em ${moeda.format(total - limite)}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                        ),
                      ),
                    const Divider(height: 24, thickness: 0.5),
                    ...ps.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: PedidoCard(
                          pedido: p,
                          onTap: () => context.push('/pedidos/${p.id}'),
                          compacto: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _criarPedidoNoDia(dia),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Adicionar pedido neste dia'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Modo Semana ──────────────────────────────────────────────────────────

  Widget _modoSemana(
    Map<DateTime, List<Pedido>> agrupado,
    double limite,
    NumberFormat moeda,
    ThemeData theme,
  ) {
    // Calcular segunda-feira da semana de referência
    final refDay = _semanaReferencia;
    final mono = refDay.subtract(Duration(days: refDay.weekday - 1));
    final friday = mono.add(const Duration(days: 4));
    final diasUteis = List.generate(5, (i) => mono.add(Duration(days: i)));

    final diaCurto = DateFormat('EEE', 'pt_BR');
    final diaNum = DateFormat('dd/MM', 'pt_BR');

    return Column(
      children: [
        // Navegação da semana
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              IconButton.outlined(
                onPressed: () => setState(() => _semanaReferencia = _semanaReferencia.subtract(const Duration(days: 7))),
                icon: const Icon(Icons.chevron_left),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Semana de ${diaNum.format(mono)} a ${diaNum.format(friday)}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                onPressed: () => setState(() => _semanaReferencia = _semanaReferencia.add(const Duration(days: 7))),
                icon: const Icon(Icons.chevron_right),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() => _semanaReferencia = DateTime.now()),
                child: const Text('Hoje'),
              ),
            ],
          ),
        ),
        // Colunas
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1200;
              if (wide) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      for (final dia in diasUteis)
                        Expanded(
                          child: _ColunaDia(
                            dia: dia,
                            pedidos: agrupado[dia] ?? [],
                            limite: limite,
                            moeda: moeda,
                            diaCurto: diaCurto,
                            diaNum: diaNum,
                            onCriarPedido: () => _criarPedidoNoDia(dia),
                          ),
                        ),
                    ],
                  ),
                );
              }
              // Tablet / mobile: scroll horizontal com colunas 280px
              if (constraints.maxWidth >= 720) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final dia in diasUteis)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: 280,
                            child: _ColunaDia(
                              dia: dia,
                              pedidos: agrupado[dia] ?? [],
                              limite: limite,
                              moeda: moeda,
                              diaCurto: diaCurto,
                              diaNum: diaNum,
                              onCriarPedido: () => _criarPedidoNoDia(dia),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }
              // Mobile: PageView com indicador
              return Column(
                children: [
                  // Chips indicadores dos dias
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: diasUteis.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final dia = diasUteis[i];
                        final sel = i == _paginaAtual;
                        return ChoiceChip(
                          selected: sel,
                          label: Text(
                            '${toBeginningOfSentenceCase(diaCurto.format(dia))} ${diaNum.format(dia)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onSelected: (_) {
                            _pageController.animateToPage(
                              i,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      itemCount: diasUteis.length,
                      controller: _pageController,
                      onPageChanged: (i) => setState(() => _paginaAtual = i),
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: _ColunaDia(
                          dia: diasUteis[i],
                          pedidos: agrupado[diasUteis[i]] ?? [],
                          limite: limite,
                          moeda: moeda,
                          diaCurto: diaCurto,
                          diaNum: diaNum,
                          onCriarPedido: () => _criarPedidoNoDia(diasUteis[i]),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Coluna de dia (modo semana) ────────────────────────────────────────────

class _ColunaDia extends StatelessWidget {
  final DateTime dia;
  final List<Pedido> pedidos;
  final double limite;
  final NumberFormat moeda;
  final DateFormat diaCurto;
  final DateFormat diaNum;
  final VoidCallback? onCriarPedido;

  const _ColunaDia({
    required this.dia,
    required this.pedidos,
    required this.limite,
    required this.moeda,
    required this.diaCurto,
    required this.diaNum,
    this.onCriarPedido,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = pedidos.fold<double>(0, (s, p) => s + p.valor);
    final pct = limite <= 0 ? 0.0 : (total / limite).clamp(0.0, 1.5);
    final acima = total > limite;
    final hoje = DateTime.now();
    final isHoje = dia.year == hoje.year && dia.month == hoje.month && dia.day == hoje.day;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                color: isHoje ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    toBeginningOfSentenceCase(diaCurto.format(dia)) ?? '',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isHoje ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    diaNum.format(dia),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isHoje ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Ocupação
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(
                        acima ? theme.colorScheme.error : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${moeda.format(total)} / ${moeda.format(limite)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: acima ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Divider(height: 16, thickness: 0.5),
            // Pedidos
            if (pedidos.isEmpty)
              Expanded(
                child: InkWell(
                  onTap: onCriarPedido,
                  borderRadius: BorderRadius.circular(10),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline, size: 28, color: theme.colorScheme.outline),
                        const SizedBox(height: 6),
                        Text(
                          'Adicionar pedido',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: pedidos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => PedidoCard(
                    pedido: pedidos[i],
                    onTap: () => context.push('/pedidos/${pedidos[i].id}'),
                    compacto: true,
                  ),
                ),
              ),
              if (onCriarPedido != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextButton.icon(
                    onPressed: onCriarPedido,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Adicionar', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Shimmer skeleton ──────────────────────────────────────────────────────

class _AgendaCardSkeleton extends StatelessWidget {
  const _AgendaCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: ShimmerSkeleton(width: 200, height: 22)),
                const SizedBox(width: 16),
                const ShimmerSkeleton(width: 120, height: 18),
              ],
            ),
            const SizedBox(height: 12),
            const ShimmerSkeleton(width: double.infinity, height: 8),
            const SizedBox(height: 16),
            const ShimmerSkeleton(width: double.infinity, height: 16),
            const SizedBox(height: 8),
            const ShimmerSkeleton(width: double.infinity, height: 16),
          ],
        ),
      ),
    );
  }
}