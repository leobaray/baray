import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/dashboard.dart';
import '../../state/dashboard_provider.dart';
import '../../state/pedidos_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/pedido_card.dart';
import '../../widgets/shimmer_skeleton.dart';

String _saudacao() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Bom dia';
  if (h < 18) return 'Boa tarde';
  return 'Boa noite';
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final theme = Theme.of(context);
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dataExtensa = DateFormat("EEEE, d 'de' MMMM 'de' y", 'pt_BR');
    final diaCurto = DateFormat('EEE d', 'pt_BR');
    final wide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!wide) ...[
              Icon(Icons.print_outlined, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 8),
            ],
            Text(
              'Serigrafia Baray',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: () => ref.invalidate(dashboardProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/pedidos/novo'),
        icon: const Icon(Icons.add),
        label: const Text('Novo pedido'),
      ),
      body: dashboard.when(
        loading: () => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _GreetingSkeleton(),
            const SizedBox(height: 20),
            Row(
              children: List.generate(4, (_) => const Expanded(child: Padding(padding: EdgeInsets.all(6), child: _KpiSkeleton()))),
            ),
            const SizedBox(height: 20),
            const _CardSkeleton(),
            const SizedBox(height: 16),
            const _CardSkeleton(),
          ],
        ),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
        data: (stats) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(dashboardProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              // Saudação
              Text(
                _saudacao(),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                toBeginningOfSentenceCase(dataExtensa.format(DateTime.now())) ?? '',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // KPI cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossCount = constraints.maxWidth >= 720 ? 4 : 2;
                  return GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 140,
                    ),
                    children: [
                      KpiCard(
                        icon: Icons.trending_up,
                        label: 'FATURAMENTO DO MÊS',
                        valor: moeda.format(stats.faturamentoMes),
                        accent: Colors.green,
                        onTap: () => context.push('/pedidos'),
                      ),
                      KpiCard(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'A RECEBER',
                        valor: moeda.format(stats.aReceber),
                        accent: Colors.orange,
                        onTap: () {
                          ref.read(pedidosFiltroProvider.notifier).update(
                                (f) => f.copyWith(statusPagamento: 'devendo'),
                              );
                          context.push('/pedidos');
                        },
                      ),
                      KpiCard(
                        icon: Icons.precision_manufacturing_outlined,
                        label: 'PRODUÇÃO HOJE',
                        valor: '${stats.emProducaoHoje.length}',
                        hint: moeda.format(stats.emProducaoHoje.fold<double>(0, (s, p) => s + p.valor)),
                        accent: theme.colorScheme.tertiary,
                        onTap: () => context.push('/agenda'),
                      ),
                      KpiCard(
                        icon: Icons.schedule,
                        label: 'VENCEM EM 7 DIAS',
                        valor: '${stats.prazosVencendo.length}',
                        accent: theme.colorScheme.error,
                        onTap: () => context.push('/pedidos'),
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: wide ? 20 : 16),

              // Conteúdo principal — empilhado no mobile, emparelhado no desktop.
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardOcupacao = _OcupacaoCard(stats: stats, moeda: moeda, diaCurto: diaCurto);
                  final cardProducao = _ProducaoHojeCard(stats: stats);
                  final cardVencendo = stats.prazosVencendo.isNotEmpty ? _VencendoCard(stats: stats) : null;
                  final cardUltimos = _UltimosMovimentosCard(stats: stats);

                  if (constraints.maxWidth >= 1100) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: cardOcupacao),
                              const SizedBox(width: 16),
                              Expanded(child: cardProducao),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (cardVencendo != null) ...[
                                Expanded(child: cardVencendo),
                                const SizedBox(width: 16),
                              ],
                              Expanded(child: cardUltimos),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  // Mobile/tablet: empilhado.
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      cardOcupacao,
                      const SizedBox(height: 16),
                      cardProducao,
                      const SizedBox(height: 16),
                      if (cardVencendo != null) ...[
                        cardVencendo,
                        const SizedBox(height: 16),
                      ],
                      cardUltimos,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OcupacaoCard extends StatelessWidget {
  final DashboardStats stats;
  final NumberFormat moeda;
  final DateFormat diaCurto;
  const _OcupacaoCard({required this.stats, required this.moeda, required this.diaCurto});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(icon: Icons.bar_chart, title: 'Ocupação da semana'),
            const SizedBox(height: 16),
            ...stats.ocupacaoSemana.map<Widget>((dia) => _OcupacaoBar(
                  dia: dia,
                  moeda: moeda,
                  diaCurto: diaCurto,
                )),
          ],
        ),
      ),
    );
  }
}

class _ProducaoHojeCard extends StatelessWidget {
  final DashboardStats stats;
  const _ProducaoHojeCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              icon: Icons.today,
              title: 'Em produção hoje',
              subtitle: '${stats.emProducaoHoje.length} pedido${stats.emProducaoHoje.length == 1 ? '' : 's'}',
            ),
            const SizedBox(height: 12),
            if (stats.emProducaoHoje.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'Nenhum pedido hoje',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              )
            else
              ...stats.emProducaoHoje.map<Widget>(
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
    );
  }
}

class _VencendoCard extends StatelessWidget {
  final DashboardStats stats;
  const _VencendoCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(icon: Icons.warning_amber_rounded, title: 'Prazos vencendo'),
            const SizedBox(height: 12),
            ...stats.prazosVencendo.map<Widget>(
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
    );
  }
}

class _UltimosMovimentosCard extends StatelessWidget {
  final DashboardStats stats;
  const _UltimosMovimentosCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(icon: Icons.history, title: 'Últimos movimentos'),
            const SizedBox(height: 12),
            ...stats.ultimosMovimentos.take(5).map<Widget>(
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
    );
  }
}

class _OcupacaoBar extends StatelessWidget {
  final DiaOcupacao dia;
  final NumberFormat moeda;
  final DateFormat diaCurto;

  const _OcupacaoBar({
    required this.dia,
    required this.moeda,
    required this.diaCurto,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = toBeginningOfSentenceCase(diaCurto.format(dia.data));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: dia.pct.clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  dia.estourado ? theme.colorScheme.error : theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              '${moeda.format(dia.ocupado)} / ${moeda.format(dia.limite)}',
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: theme.textTheme.labelSmall?.copyWith(
                color: dia.estourado ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                fontWeight: dia.estourado ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shimmer skeletons ──────────────────────────────────────────────────────

class _KpiSkeleton extends StatelessWidget {
  const _KpiSkeleton();

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
                ShimmerSkeleton(width: 36, height: 36, borderRadius: BorderRadius.circular(10)),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 14),
            const ShimmerSkeleton(width: 80, height: 12),
            const SizedBox(height: 6),
            const ShimmerSkeleton(width: 120, height: 24),
          ],
        ),
      ),
    );
  }
}

class _GreetingSkeleton extends StatelessWidget {
  const _GreetingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerSkeleton(width: 160, height: 28, borderRadius: BorderRadius.circular(6)),
        const SizedBox(height: 6),
        ShimmerSkeleton(width: 240, height: 16, borderRadius: BorderRadius.circular(4)),
      ],
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShimmerSkeleton(width: 28, height: 28, borderRadius: BorderRadius.circular(10)),
                const SizedBox(width: 12),
                const ShimmerSkeleton(width: 140, height: 16),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(3, (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ShimmerSkeleton(width: double.infinity, height: 48, borderRadius: BorderRadius.circular(12)),
            )),
          ],
        ),
      ),
    );
  }
}