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
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentedButton<_Modo>(
              segments: const [
                ButtonSegment(value: _Modo.lista, label: Text('Lista'), icon: Icon(Icons.list)),
                ButtonSegment(value: _Modo.semana, label: Text('Semana'), icon: Icon(Icons.view_week)),
              ],
              selected: {_modo},
              onSelectionChanged: (s) => setState(() => _modo = s.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll(theme.textTheme.labelMedium),
              ),
            ),
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
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 76,
                              child: Text(
                                p.loteFormatado,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${p.clienteNome} — ${p.descricao}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(moeda.format(p.valor), style: theme.textTheme.labelMedium),
                          ],
                        ),
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
              final wide = constraints.maxWidth >= 720;
              if (wide) {
                return Row(
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
                        ),
                      ),
                  ],
                );
              }
              // Mobile: PageView
              return PageView.builder(
                itemCount: diasUteis.length,
                controller: PageController(initialPage: 0),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ColunaDia(
                    dia: diasUteis[i],
                    pedidos: agrupado[diasUteis[i]] ?? [],
                    limite: limite,
                    moeda: moeda,
                    diaCurto: diaCurto,
                    diaNum: diaNum,
                  ),
                ),
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

  const _ColunaDia({
    required this.dia,
    required this.pedidos,
    required this.limite,
    required this.moeda,
    required this.diaCurto,
    required this.diaNum,
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
                child: Center(
                  child: Text(
                    'Sem pedidos',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
              )
            else
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