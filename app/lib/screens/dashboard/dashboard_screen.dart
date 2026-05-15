import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/dashboard.dart';
import '../../models/pedido.dart';
import '../../state/dashboard_provider.dart';
import '../../state/pedidos_provider.dart';
import '../../theme/density.dart';
import '../../theme/spacing.dart';
import '../../theme/status_colors.dart';
import '../../util/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pedido_form_sheet.dart';
import '../../widgets/pedido_row.dart';
import '../../widgets/shimmer_skeleton.dart';

const double _kWide = 1100;

String _saudacao(int hora) {
  if (hora < 12) return 'Bom dia';
  if (hora < 18) return 'Boa tarde';
  return 'Boa noite';
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.print_outlined, color: Theme.of(context).colorScheme.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              'Serigrafia Baray',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => PedidoFormSheet.show(context),
        icon: const Icon(Icons.add),
        label: const Text('Novo pedido'),
      ),
      body: dashboard.when(
        loading: () => const _LoadingState(),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
        data: (stats) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(dashboardProvider),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= _kWide;
              return wide ? _buildWide(context, ref, stats) : _buildNarrow(context, ref, stats);
            },
          ),
        ),
      ),
    );
  }

  // ── Desktop ≥1100 — 2 colunas ────────────────────────────────────────────
  Widget _buildWide(BuildContext context, WidgetRef ref, DashboardStats stats) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SaudacaoBanner(stats: stats),
          const SizedBox(height: 14),
          _KpisRow(stats: stats),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _DestaquesCard(stats: stats),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: _OcupacaoCard(stats: stats),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Mobile/tablet — coluna ────────────────────────────────────────────────
  Widget _buildNarrow(BuildContext context, WidgetRef ref, DashboardStats stats) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 96),
      children: [
        _SaudacaoBanner(stats: stats),
        const SizedBox(height: 12),
        _KpisRow(stats: stats),
        const SizedBox(height: 12),
        _DestaquesCard(stats: stats),
        const SizedBox(height: 12),
        _OcupacaoCard(stats: stats),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BANNER DE SAUDAÇÃO
// ─────────────────────────────────────────────────────────────────────────────

class _SaudacaoBanner extends StatelessWidget {
  final DashboardStats stats;
  const _SaudacaoBanner({required this.stats});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hora = DateTime.now().hour;
    final dataExtensa = DateFormat("EEEE, d 'de' MMMM", 'pt_BR');
    final data = toBeginningOfSentenceCase(dataExtensa.format(DateTime.now()));

    final emProducao = stats.emProducaoHoje.length;
    final urgentes = stats.urgentes.length;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            cs.primaryContainer.withValues(alpha: 0.35),
            cs.primaryContainer.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.22)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
      child: LayoutBuilder(
        builder: (context, c) {
          final estreito = c.maxWidth < 520;
          final highlight = _HighlightBadge(
            emProducao: emProducao,
            urgentes: urgentes,
          );
          final texto = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _saudacao(hora),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.05,
                      color: cs.onSurface,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                data,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          );

          if (estreito) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                texto,
                const SizedBox(height: 10),
                highlight,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: texto),
              const SizedBox(width: 16),
              highlight,
            ],
          );
        },
      ),
    );
  }
}

class _HighlightBadge extends StatelessWidget {
  final int emProducao;
  final int urgentes;
  const _HighlightBadge({required this.emProducao, required this.urgentes});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (emProducao == 0 && urgentes == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 16, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              'Nenhum pedido urgente hoje',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emProducao > 0) ...[
            _HighlightMetric(
              label: 'Hoje',
              valor: '$emProducao',
              icon: Icons.precision_manufacturing_outlined,
              color: cs.primary,
            ),
          ],
          if (emProducao > 0 && urgentes > 0) ...[
            const SizedBox(width: 14),
            Container(width: 1, height: 24, color: cs.outlineVariant),
            const SizedBox(width: 14),
          ],
          if (urgentes > 0)
            _HighlightMetric(
              label: 'Urgentes',
              valor: '$urgentes',
              icon: Icons.local_fire_department,
              color: cs.error,
            ),
        ],
      ),
    );
  }
}

class _HighlightMetric extends StatelessWidget {
  final String label;
  final String valor;
  final IconData icon;
  final Color color;
  const _HighlightMetric({
    required this.label,
    required this.valor,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          valor,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
            letterSpacing: -0.3,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: cs.onSurfaceVariant,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  KPIs (linha de 4)
// ─────────────────────────────────────────────────────────────────────────────

class _KpisRow extends ConsumerWidget {
  final DashboardStats stats;
  const _KpisRow({required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moeda = AppFormatters.moedaInteira;
    final cs = Theme.of(context).colorScheme;
    final warning = statusColors(context, StatusTone.warning).fg;

    void irParaPedidosDoMes() {
      ref.read(pedidosFiltroProvider.notifier).update(
            (f) => f.copyWith(de: stats.inicioMes, ate: stats.fimMes),
          );
      context.go('/pedidos');
    }

    void irParaDevendo() {
      ref.read(pedidosFiltroProvider.notifier).update(
            (f) => f.copyWith(statusPagamento: 'devendo', resetPeriodo: true),
          );
      context.go('/pedidos');
    }

    return LayoutBuilder(
      builder: (context, c) {
        final colunas = c.maxWidth >= 720 ? 4 : 2;
        final largura = (c.maxWidth - 10 * (colunas - 1)) / colunas;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: largura,
              child: _KpiTile(
                label: 'VENDAS DO MÊS',
                valor: moeda.format(stats.vendasMes),
                hint: 'recebido ${moeda.format(stats.recebidoMes)}',
                icon: Icons.trending_up,
                accent: cs.primary,
                onTap: irParaPedidosDoMes,
              ),
            ),
            SizedBox(
              width: largura,
              child: _KpiTile(
                label: 'A RECEBER',
                valor: moeda.format(stats.aReceber),
                icon: Icons.account_balance_wallet_outlined,
                accent: warning,
                onTap: irParaDevendo,
              ),
            ),
            SizedBox(
              width: largura,
              child: _KpiTile(
                label: 'CONCLUÍDOS NO MÊS',
                valor: '${stats.concluidosMes}',
                hint: 'de ${stats.pedidosMes} criados',
                icon: Icons.check_circle_outline,
                accent: cs.tertiary,
                onTap: irParaPedidosDoMes,
              ),
            ),
            SizedBox(
              width: largura,
              child: _KpiTile(
                label: 'TICKET MÉDIO',
                valor: moeda.format(stats.ticketMedio),
                hint: 'pedido do mês',
                icon: Icons.local_offer_outlined,
                accent: cs.secondary,
                onTap: irParaPedidosDoMes,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String valor;
  final String? hint;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  const _KpiTile({
    required this.label,
    required this.valor,
    required this.icon,
    required this.accent,
    this.hint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, size: 14, color: accent),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    Icon(Icons.arrow_forward, size: 12, color: cs.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: cs.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  valor,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    color: cs.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (hint != null) ...[
                const SizedBox(height: 2),
                Text(
                  hint!,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CARD DE DESTAQUES (tabs Hoje / Urgentes / Vencendo)
// ─────────────────────────────────────────────────────────────────────────────

class _DestaquesCard extends StatelessWidget {
  final DashboardStats stats;
  const _DestaquesCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.all(AppSpacing.padMd),
      child: DefaultTabController(
        length: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BlockHeader(icon: Icons.star_outline, label: 'Próximos destaques'),
            const SizedBox(height: 8),
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              tabs: [
                _destaqueTab(context, Icons.today, 'Hoje', stats.emProducaoHoje.length),
                _destaqueTab(context, Icons.local_fire_department, 'Urgentes', stats.urgentes.length),
                _destaqueTab(context, Icons.schedule, 'Vencendo', stats.prazosVencendo.length),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 340,
              child: TabBarView(
                children: [
                  _DestaqueLista(
                    pedidos: stats.emProducaoHoje,
                    emptyIcon: Icons.event_available_outlined,
                    emptyTitle: 'Nenhum pedido em produção hoje',
                    emptyCta: 'Ver agenda',
                    onEmptyCta: () => context.go('/agenda'),
                  ),
                  _DestaqueLista(
                    pedidos: stats.urgentes,
                    emptyIcon: Icons.check_circle_outline,
                    emptyTitle: 'Nenhum pedido urgente aberto',
                  ),
                  _DestaqueLista(
                    pedidos: stats.prazosVencendo,
                    emptyIcon: Icons.check_circle_outline,
                    emptyTitle: 'Nenhum pedido vencendo em 7 dias',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _destaqueTab(BuildContext context, IconData icon, String label, int count) {
    final cs = Theme.of(context).colorScheme;
    return Tab(
      height: 34,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(label),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: count > 0 ? cs.primaryContainer : cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: count > 0 ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lista densa de pedidos usando PedidoRow — sem header (o tab já identifica).
class _DestaqueLista extends StatelessWidget {
  final List<Pedido> pedidos;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptyCta;
  final VoidCallback? onEmptyCta;

  const _DestaqueLista({
    required this.pedidos,
    required this.emptyIcon,
    required this.emptyTitle,
    this.emptyCta,
    this.onEmptyCta,
  });

  @override
  Widget build(BuildContext context) {
    if (pedidos.isEmpty) {
      return EmptyState.compact(
        icon: emptyIcon,
        titulo: emptyTitle,
        ctaLabel: emptyCta,
        onCta: onEmptyCta,
      );
    }
    return Column(
      children: [
        const PedidosHeader(),
        Expanded(
          child: ListView.builder(
            itemCount: pedidos.length,
            itemBuilder: (_, i) => PedidoRow(
              pedido: pedidos[i],
              onTap: () => context.push('/pedidos/${pedidos[i].id}?from=dashboard'),
              zebra: i.isOdd,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  OCUPAÇÃO DA SEMANA (com destaque do dia atual)
// ─────────────────────────────────────────────────────────────────────────────

class _OcupacaoCard extends ConsumerWidget {
  final DashboardStats stats;
  const _OcupacaoCard({required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final moeda = AppFormatters.moedaInteira;
    final diaCurto = DateFormat('EEE d', 'pt_BR');

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.all(AppSpacing.padMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BlockHeader(
            icon: Icons.bar_chart,
            label: 'Ocupação da semana',
            trailing: InkWell(
              onTap: () => context.go('/agenda'),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'agenda',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                    Icon(Icons.arrow_forward, size: 12, color: cs.primary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final dia in stats.ocupacaoSemana)
            _OcupacaoBar(
              dia: dia,
              moeda: moeda,
              diaCurto: diaCurto,
              hojeStr: stats.hoje,
            ),
        ],
      ),
    );
  }
}

class _OcupacaoBar extends StatelessWidget {
  final DiaOcupacao dia;
  final NumberFormat moeda;
  final DateFormat diaCurto;
  final String hojeStr;

  const _OcupacaoBar({
    required this.dia,
    required this.moeda,
    required this.diaCurto,
    required this.hojeStr,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = toBeginningOfSentenceCase(diaCurto.format(dia.data));
    final isHoje = _dataStr(dia.data) == hojeStr;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Row(
              children: [
                if (isHoje)
                  Container(
                    width: 3,
                    height: 14,
                    margin: const EdgeInsets.only(right: 5),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppType.caption,
                      fontWeight: isHoje ? FontWeight.w800 : FontWeight.w600,
                      color: isHoje ? cs.primary : cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: dia.pct.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  dia.estourado
                      ? cs.error
                      : (isHoje ? cs.primary : cs.primary.withValues(alpha: 0.65)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 114,
            child: Text(
              '${moeda.format(dia.ocupado)} / ${moeda.format(dia.limite)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                color: dia.estourado ? cs.error : cs.onSurfaceVariant,
                fontWeight: dia.estourado ? FontWeight.w800 : FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _dataStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
//  LOADING STATE (compacto)
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      children: [
        ShimmerSkeleton(width: double.infinity, height: 90, borderRadius: BorderRadius.circular(14)),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              Expanded(child: ShimmerSkeleton(width: double.infinity, height: 100, borderRadius: BorderRadius.circular(10))),
              if (i < 3) const SizedBox(width: 10),
            ],
          ],
        ),
        const SizedBox(height: 12),
        ShimmerSkeleton(width: double.infinity, height: 340, borderRadius: BorderRadius.circular(10)),
        const SizedBox(height: 12),
        ShimmerSkeleton(width: double.infinity, height: 220, borderRadius: BorderRadius.circular(10)),
      ],
    );
  }
}

