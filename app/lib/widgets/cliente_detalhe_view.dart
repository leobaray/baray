import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/cliente.dart';
import '../models/cliente_fechamento.dart';
import '../models/pedido.dart';
import '../screens/clientes/fechamento_fechar_dialog.dart';
import '../screens/clientes/fechamento_estender_dialog.dart';
import '../state/cliente_fechamentos_provider.dart';
import '../state/clientes_provider.dart';
import '../state/dashboard_provider.dart';
import '../state/pedidos_provider.dart';
import '../theme/density.dart';
import '../theme/spacing.dart';
import '../util/formatters.dart';
import 'empty_state.dart';
import 'fechamento_status_badge.dart';
import 'list_skeleton.dart';
import 'pedido_form_sheet.dart';
import 'pedido_row.dart';

/// Ficha completa do cliente. Header compacto + tabs Ciclo / Pedidos / Fechamentos.
class ClienteDetalheView extends ConsumerWidget {
  final String clienteId;

  /// Quando true, renderiza um botão "Fechar" no canto superior (útil no
  /// fluxo mobile dentro de um Scaffold dedicado).
  final bool showCloseButton;

  const ClienteDetalheView({
    super.key,
    required this.clienteId,
    this.showCloseButton = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valAsync = ref.watch(clienteDetalheProvider(clienteId));
    final theme = Theme.of(context);

    return valAsync.when(
      loading: () => const DetailSkeleton(),
      error: (e, _) => ErrorState(
        message: e.toString(),
        onRetry: () => ref.invalidate(clienteDetalheProvider(clienteId)),
      ),
      data: (cliente) => DefaultTabController(
        length: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              cliente: cliente,
              clienteId: clienteId,
              showCloseButton: showCloseButton,
              onAcoes: (acao) => _handleAcao(context, ref, cliente, acao),
            ),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                border: Border(
                  bottom: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              // ShaderMask com fade na borda direita sinaliza "tem mais
              // conteúdo à direita" mesmo antes do usuário começar a scrollar.
              child: ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: [0.0, 0.9, 1.0],
                  colors: [
                    Colors.white,
                    Colors.white,
                    Color(0x00FFFFFF),
                  ],
                ).createShader(rect),
                blendMode: BlendMode.dstIn,
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                  labelStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                  tabs: const [
                    Tab(text: 'Ciclo atual', height: 36),
                    Tab(text: 'Pedidos', height: 36),
                    Tab(text: 'Fechamentos', height: 36),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _CicloAtualTab(cliente: cliente, clienteId: clienteId),
                  _PedidosTab(cliente: cliente),
                  _FechamentosTab(clienteId: clienteId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAcao(
    BuildContext context,
    WidgetRef ref,
    Cliente cliente,
    _AcaoCliente acao,
  ) async {
    switch (acao) {
      case _AcaoCliente.novoPedido:
        await PedidoFormSheet.show(
          context,
          initial: {'cliente_id': clienteId},
        );
        ref.invalidate(clienteDetalheProvider(clienteId));
        ref.invalidate(clientesProvider);
        ref.invalidate(pedidosProvider);
        ref.invalidate(dashboardProvider);
      case _AcaoCliente.editar:
        if (context.mounted) {
          await context.push('/clientes/$clienteId/editar');
          ref.invalidate(clienteDetalheProvider(clienteId));
          ref.invalidate(clientesProvider);
        }
      case _AcaoCliente.fecharCiclo:
        final f = cliente.fechamentoAtual;
        if (f == null) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => FechamentoFecharDialog(fechamento: f),
        );
        if (ok == true) {
          ref.invalidate(clienteDetalheProvider(clienteId));
          ref.invalidate(fechamentosProvider(clienteId));
          ref.invalidate(clientesProvider);
        }
      case _AcaoCliente.estenderCiclo:
        final f = cliente.fechamentoAtual;
        if (f == null) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => FechamentoEstenderDialog(
            fechamento: f,
            clienteId: clienteId,
          ),
        );
        if (ok == true) {
          ref.invalidate(clienteDetalheProvider(clienteId));
          ref.invalidate(fechamentosProvider(clienteId));
        }
    }
  }
}

enum _AcaoCliente { novoPedido, editar, fecharCiclo, estenderCiclo }

// ═══════════════════════════════════════════════════════════════════════════
//  HEADER
// ═══════════════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final Cliente cliente;
  final String clienteId;
  final bool showCloseButton;
  final ValueChanged<_AcaoCliente> onAcoes;

  const _Header({
    required this.cliente,
    required this.clienteId,
    required this.showCloseButton,
    required this.onAcoes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final moeda = AppFormatters.moedaInteira;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(
                  cliente.iniciais,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: cs.onPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.gapSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cliente.nome,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                        height: 1.1,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    _ContatoLine(cliente: cliente),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.gapSm),
              FilledButton.icon(
                onPressed: () => onAcoes(_AcaoCliente.novoPedido),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Novo pedido', style: TextStyle(fontSize: 12.5)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Editar cliente',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(
                  minWidth: AppButtons.minTouchTarget,
                  minHeight: AppButtons.minTouchTarget,
                ),
                onPressed: () => onAcoes(_AcaoCliente.editar),
              ),
              if (showCloseButton)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Fechar',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: AppButtons.minTouchTarget,
                    minHeight: AppButtons.minTouchTarget,
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _StatsStrip(cliente: cliente, moeda: moeda),
        ],
      ),
    );
  }
}

class _ContatoLine extends StatelessWidget {
  final Cliente cliente;
  const _ContatoLine({required this.cliente});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final partes = <String>[
      if (cliente.telefone != null && cliente.telefone!.isNotEmpty) cliente.telefone!,
      if (cliente.email != null && cliente.email!.isNotEmpty) cliente.email!,
      if (cliente.endereco != null && cliente.endereco!.isNotEmpty) cliente.endereco!,
    ];
    if (partes.isEmpty) {
      return Text(
        'Sem contato cadastrado',
        style: TextStyle(fontSize: AppType.caption, color: cs.onSurfaceVariant),
      );
    }
    return Text(
      partes.join('  ·  '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: AppType.caption,
        color: cs.onSurfaceVariant,
      ),
    );
  }
}

/// Linha de métricas do header — mesmo padrão `_Metric` da lista de Pedidos.
class _StatsStrip extends StatelessWidget {
  final Cliente cliente;
  final NumberFormat moeda;

  const _StatsStrip({required this.cliente, required this.moeda});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final f = cliente.fechamentoAtual;
    final temDebito = cliente.valorDevendo > 0.01;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Metric(label: 'total gasto', valor: moeda.format(cliente.totalGasto), color: cs.onSurface),
          const SizedBox(width: 16),
          _Metric(label: 'pedidos', valor: '${cliente.totalPedidos}', color: cs.onSurface),
          if (temDebito) ...[
            const SizedBox(width: 16),
            _Metric(label: 'devendo', valor: moeda.format(cliente.valorDevendo), color: cs.error),
          ],
          if (f != null) ...[
            const SizedBox(width: 16),
            _Metric(
              label: 'ciclo #${f.numero}',
              valor: moeda.format(f.valorTotal),
              color: cs.onSurface,
            ),
            const SizedBox(width: 16),
            _Metric(
              label: 'saldo ciclo',
              valor: moeda.format(f.valorPendente),
              color: f.valorPendente > 0 ? cs.error : cs.tertiary,
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
            fontSize: 14,
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

// ═══════════════════════════════════════════════════════════════════════════
//  TAB: CICLO ATUAL
// ═══════════════════════════════════════════════════════════════════════════

class _CicloAtualTab extends ConsumerWidget {
  final Cliente cliente;
  final String clienteId;
  const _CicloAtualTab({required this.cliente, required this.clienteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final moeda = AppFormatters.moeda;
    final dataFmt = DateFormat('dd/MM/yyyy');
    final f = cliente.fechamentoAtual;

    if (f == null) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        titulo: 'Sem ciclo de fechamento ativo',
        subtitulo: cliente.fechamentoAtivo
            ? 'O próximo ciclo será aberto automaticamente quando houver pedidos.'
            : 'Ative o fechamento por ciclo no cadastro do cliente.',
        acao: cliente.fechamentoAtivo
            ? null
            : TextButton.icon(
                onPressed: () => context.push('/clientes/$clienteId/editar'),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Editar cliente'),
              ),
      );
    }

    final pedidosCiclo = (cliente.pedidos ?? const <Pedido>[])
        .where((p) => p.fechamentoId == f.id)
        .toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.3),
            border: Border(bottom: BorderSide(color: cs.outlineVariant)),
          ),
          child: Row(
            children: [
              Icon(Icons.event_note_outlined, size: 16, color: cs.onSurface),
              const SizedBox(width: 7),
              Text(
                'Ciclo #${f.numero}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 10),
              FechamentoStatusBadge(status: f.status),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  '${dataFmt.format(f.dataAbertura)} → ${dataFmt.format(f.dataFechamentoPrevista)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: AppType.caption, color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _onEstender(context, ref, f),
                icon: const Icon(Icons.schedule_outlined, size: 16),
                label: const Text('Estender', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  // Mantém área >= 44 (Material 3 / WCAG 2.5.5).
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
              ),
              const SizedBox(width: 4),
              FilledButton.tonalIcon(
                onPressed: () => _onFechar(context, ref, f),
                icon: const Icon(Icons.lock_outline, size: 16),
                label: const Text('Fechar', style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: pedidosCiclo.isEmpty
              ? const _CicloVazio()
              : Column(
                  children: [
                    const PedidosHeader(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: pedidosCiclo.length,
                        itemBuilder: (_, i) => PedidoRow(
                          pedido: pedidosCiclo[i],
                          onTap: () => context.push('/pedidos/${pedidosCiclo[i].id}?from=cliente'),
                          zebra: i.isOdd,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        _ResumoCiclo(fechamento: f, moeda: moeda),
      ],
    );
  }

  Future<void> _onFechar(BuildContext context, WidgetRef ref, ClienteFechamento f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => FechamentoFecharDialog(fechamento: f),
    );
    if (ok == true) {
      ref.invalidate(clienteDetalheProvider(clienteId));
      ref.invalidate(fechamentosProvider(clienteId));
      ref.invalidate(clientesProvider);
    }
  }

  Future<void> _onEstender(BuildContext context, WidgetRef ref, ClienteFechamento f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => FechamentoEstenderDialog(fechamento: f, clienteId: clienteId),
    );
    if (ok == true) {
      ref.invalidate(clienteDetalheProvider(clienteId));
      ref.invalidate(fechamentosProvider(clienteId));
    }
  }
}

class _CicloVazio extends StatelessWidget {
  const _CicloVazio();

  @override
  Widget build(BuildContext context) {
    return const EmptyState.compact(
      icon: Icons.inbox_outlined,
      titulo: 'Nenhum pedido no ciclo atual',
    );
  }
}

class _ResumoCiclo extends StatelessWidget {
  final ClienteFechamento fechamento;
  final NumberFormat moeda;
  const _ResumoCiclo({required this.fechamento, required this.moeda});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final f = fechamento;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          _CelResumo(label: 'pedidos', valor: '${f.totalPedidos}', color: cs.onSurface),
          const SizedBox(width: 20),
          _CelResumo(label: 'total', valor: moeda.format(f.valorTotal), color: cs.onSurface),
          const SizedBox(width: 20),
          _CelResumo(label: 'pago', valor: moeda.format(f.valorPago), color: cs.tertiary),
          const SizedBox(width: 20),
          _CelResumo(
            label: 'saldo',
            valor: moeda.format(f.valorPendente),
            color: f.valorPendente > 0 ? cs.error : cs.tertiary,
            destaque: true,
          ),
        ],
      ),
    );
  }
}

class _CelResumo extends StatelessWidget {
  final String label;
  final String valor;
  final Color color;
  final bool destaque;
  const _CelResumo({
    required this.label,
    required this.valor,
    required this.color,
    this.destaque = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: TextStyle(
            fontSize: destaque ? 16 : 13.5,
            fontWeight: FontWeight.w800,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB: PEDIDOS (todos do cliente)
// ═══════════════════════════════════════════════════════════════════════════

class _PedidosTab extends StatelessWidget {
  final Cliente cliente;
  const _PedidosTab({required this.cliente});

  @override
  Widget build(BuildContext context) {
    final pedidos = cliente.pedidos ?? const <Pedido>[];
    if (pedidos.isEmpty) {
      return EmptyState(
        icon: Icons.assignment_outlined,
        titulo: 'Nenhum pedido cadastrado',
        subtitulo: 'Use "Novo pedido" no topo pra começar.',
      );
    }
    return Column(
      children: [
        _PedidosResumo(pedidos: pedidos),
        const PedidosHeader(),
        Expanded(
          child: ListView.builder(
            itemCount: pedidos.length,
            itemBuilder: (_, i) => PedidoRow(
              pedido: pedidos[i],
              onTap: () => context.push('/pedidos/${pedidos[i].id}?from=cliente'),
              zebra: i.isOdd,
            ),
          ),
        ),
      ],
    );
  }
}

class _PedidosResumo extends StatelessWidget {
  final List<Pedido> pedidos;
  const _PedidosResumo({required this.pedidos});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final moeda = AppFormatters.moedaInteira;
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _Metric(label: 'pedidos', valor: '${pedidos.length}', color: cs.onSurface),
            const SizedBox(width: 16),
            _Metric(label: 'total', valor: moeda.format(total), color: cs.onSurface),
            if (devendo > 0.01) ...[
              const SizedBox(width: 16),
              _Metric(label: 'devendo', valor: moeda.format(devendo), color: cs.error),
            ],
            if (urgentes > 0) ...[
              const SizedBox(width: 16),
              _Metric(label: 'urgentes', valor: '$urgentes', color: cs.tertiary),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB: FECHAMENTOS
// ═══════════════════════════════════════════════════════════════════════════

class _FechamentosTab extends ConsumerWidget {
  final String clienteId;
  const _FechamentosTab({required this.clienteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fechAsync = ref.watch(fechamentosProvider(clienteId));

    return fechAsync.when(
      loading: () => const ListSkeleton(items: 4),
      error: (e, _) => ErrorState(
        message: e.toString(),
        onRetry: () => ref.invalidate(fechamentosProvider(clienteId)),
      ),
      data: (lista) {
        if (lista.isEmpty) {
          return EmptyState(
            icon: Icons.folder_outlined,
            titulo: 'Sem fechamentos',
            subtitulo: 'Os ciclos do cliente vão aparecer aqui conforme forem abertos.',
          );
        }
        return LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth < 600) {
              return _listaMobile(context, lista);
            }
            return _tabelaDesktop(context, lista);
          },
        );
      },
    );
  }

  Widget _tabelaDesktop(BuildContext context, List<ClienteFechamento> lista) {
    final cs = Theme.of(context).colorScheme;
    final moeda = AppFormatters.moedaInteira;
    final dataFmt = DateFormat('dd/MM/yyyy');

    Widget header(String s, {TextAlign? align}) => Text(
          s.toUpperCase(),
          textAlign: align,
          style: TextStyle(
            fontSize: AppType.colHeader,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: cs.onSurfaceVariant,
          ),
        );

    return Column(
      children: [
        Container(
          height: kHeaderHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.padSm),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            border: Border(bottom: BorderSide(color: cs.outlineVariant)),
          ),
          child: Row(
            children: [
              SizedBox(width: 52, child: header('Ciclo')),
              const SizedBox(width: AppSpacing.gapSm),
              Expanded(child: header('Período')),
              SizedBox(width: 92, child: header('Status')),
              SizedBox(width: 52, child: header('Pçs', align: TextAlign.right)),
              const SizedBox(width: AppSpacing.gapMd),
              SizedBox(width: 92, child: header('Total', align: TextAlign.right)),
              const SizedBox(width: AppSpacing.gapSm),
              SizedBox(width: 92, child: header('Saldo', align: TextAlign.right)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: lista.length,
            itemBuilder: (_, i) {
              final f = lista[i];
              return Material(
                color: i.isOdd ? cs.surfaceContainerLow : cs.surface,
                child: InkWell(
                  onTap: () => context.push('/clientes/$clienteId/fechamentos/${f.id}'),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: kRowMinHeight),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.padSm,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 52,
                          child: Text(
                            '#${f.numero}',
                            style: TextStyle(
                              fontSize: AppType.row,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.gapSm),
                        Expanded(
                          child: Text(
                            '${dataFmt.format(f.dataAbertura)} → ${dataFmt.format(f.dataFechamentoReal ?? f.dataFechamentoPrevista)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: AppType.row, color: cs.onSurfaceVariant),
                          ),
                        ),
                        SizedBox(
                          width: 92,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FechamentoStatusBadge(status: f.status),
                          ),
                        ),
                        SizedBox(
                          width: 52,
                          child: Text(
                            '${f.totalPedidos}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: AppType.row,
                              color: cs.onSurface,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.gapMd),
                        SizedBox(
                          width: 92,
                          child: Text(
                            moeda.format(f.valorTotal),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: AppType.row,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.gapSm),
                        SizedBox(
                          width: 92,
                          child: Text(
                            moeda.format(f.valorPendente),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: AppType.row,
                              fontWeight: FontWeight.w700,
                              color: f.valorPendente > 0 ? cs.error : cs.tertiary,
                              fontFeatures: const [FontFeature.tabularFigures()],
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
        ),
      ],
    );
  }

  Widget _listaMobile(BuildContext context, List<ClienteFechamento> lista) {
    final cs = Theme.of(context).colorScheme;
    final moeda = AppFormatters.moedaInteira;
    final dataFmt = DateFormat('dd/MM/yy');

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      itemCount: lista.length,
      itemBuilder: (_, i) {
        final f = lista[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => context.push('/clientes/$clienteId/fechamentos/${f.id}'),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Ciclo #${f.numero}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 8),
                        FechamentoStatusBadge(status: f.status),
                        const Spacer(),
                        Text(
                          moeda.format(f.valorTotal),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${dataFmt.format(f.dataAbertura)} → ${dataFmt.format(f.dataFechamentoReal ?? f.dataFechamentoPrevista)} · ${f.totalPedidos} pç',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (f.valorPendente > 0.01)
                          Text(
                            'saldo ${moeda.format(f.valorPendente)}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: cs.error,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
