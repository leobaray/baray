import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../models/pedido.dart';
import '../../state/pagamentos_provider.dart';
import '../../state/pedidos_provider.dart';
import '../../state/dashboard_provider.dart';
import '../../theme/breakpoints.dart';
import '../../theme/spacing.dart';
import '../../util/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/list_skeleton.dart';
import '../../widgets/status_pill.dart';

class PedidoDetalheScreen extends ConsumerWidget {
  final String pedidoId;

  /// Chave da tela de origem (`agenda`, `pedidos`, `dashboard`, `kanban`,
  /// `cliente`, `fechamento`). Mostra um breadcrumb "← X" abaixo do título.
  /// Quando `null`, breadcrumb fica oculto (deep link / abertura externa).
  final String? from;
  const PedidoDetalheScreen({super.key, required this.pedidoId, this.from});

  String? _fromLabel(String? key) => switch (key) {
        'agenda' => 'Agenda',
        'pedidos' => 'Pedidos',
        'dashboard' => 'Início',
        'kanban' => 'Kanban',
        'cliente' => 'Cliente',
        'fechamento' => 'Fechamento',
        _ => null,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedidoAsync = ref.watch(pedidoProvider(pedidoId));
    final moeda = AppFormatters.moeda;
    final data = AppFormatters.data;
    final dataSemana = DateFormat("EEEE', 'dd/MM/yyyy", 'pt_BR');
    final breadcrumb = _fromLabel(from);

    return Scaffold(
      appBar: AppBar(
        title: pedidoAsync.when(
          loading: () => const Text('Pedido'),
          error: (_, _) => const Text('Pedido'),
          data: (p) => Text(p.loteFormatado),
        ),
        bottom: breadcrumb == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: _Breadcrumb(label: breadcrumb, onTap: () {
                  if (context.canPop()) context.pop();
                }),
              ),
        actions: [
          pedidoAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (p) => IconButton(
              icon: const Icon(Icons.swap_horiz_outlined),
              tooltip: 'Mudar status',
              onPressed: () => _abrirMenuStatus(context, ref, p),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar',
            onPressed: () => context.push('/pedidos/$pedidoId/editar'),
          ),
          pedidoAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (_) => PopupMenuButton<String>(
              onSelected: (action) => _handleMenu(context, ref, action, pedidoAsync.value!),
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'duplicar',
                  child: ListTile(
                    leading: Icon(Icons.content_copy),
                    title: Text('Duplicar'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'reagendar',
                  child: ListTile(
                    leading: Icon(Icons.event_repeat),
                    title: Text('Reagendar automaticamente'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'excluir',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error),
                    title: Text(
                      'Excluir',
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: pedidoAsync.when(
        loading: () => const DetailSkeleton(),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(pedidoProvider(pedidoId)),
        ),
        data: (pedido) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(pedidoProvider(pedidoId));
            ref.invalidate(pagamentosProvider(pedidoId));
          },
          child: LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= AppBreakpoints.medium;
            final temArte = pedido.arteCores != null ||
                pedido.arteTamanhoCm != null ||
                (pedido.artePosicao?.isNotEmpty ?? false) ||
                (pedido.arteObservacao?.isNotEmpty ?? false);

            final cabecalho = Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.padLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusPill(status: pedido.status),
                          PagamentoPill(statusPagamento: pedido.statusPagamento),
                          if (pedido.urgente)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.flash_on, size: 14, color: Theme.of(context).colorScheme.onErrorContainer),
                                  const SizedBox(width: 4),
                                  Text(
                                    'URGENTE',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onErrorContainer,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          letterSpacing: 0.5,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        pedido.clienteNome,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(pedido.descricao, style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 12),
                      Text(
                        moeda.format(pedido.valor),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                      ),
                    ],
                  ),
                ),
              );

            final cardPeca = Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.padLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(icon: Icons.checkroom_outlined, title: 'Peça'),
                      const SizedBox(height: 12),
                      _Info('Peça', pedido.peca),
                      _Info('Técnica', pedido.tecnica),
                      _Info('Quantidade', pedido.quantidade?.toString()),
                      _Info('Cor', pedido.corPeca),
                      _Info('Tamanho', pedido.tamanhoPeca),
                      _Info('Tecido', pedido.tecido),
                    ],
                  ),
                ),
              );

            final cardArte = temArte
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.padLg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(icon: Icons.palette_outlined, title: 'Arte'),
                          const SizedBox(height: 12),
                          _Info('Cores', pedido.arteCores?.toString()),
                          _Info('Tamanho', pedido.arteTamanhoCm),
                          _Info('Posição', pedido.artePosicao),
                          _Info('Observação', pedido.arteObservacao),
                        ],
                      ),
                    ),
                  )
                : null;

            final cardAgenda = Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.padLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(icon: Icons.calendar_month_outlined, title: 'Agenda'),
                      const SizedBox(height: 12),
                      _Info('Chegada', pedido.dataChegada != null ? data.format(pedido.dataChegada!) : null),
                      _Info(
                        'Produção',
                        pedido.dataProducao != null ? toBeginningOfSentenceCase(dataSemana.format(pedido.dataProducao!)) : null,
                      ),
                      _Info('Prazo', pedido.prazoDias != null ? '${pedido.prazoDias} dias' : null),
                      _Info('Entrega combinada', pedido.dataEntregaCombinada != null ? data.format(pedido.dataEntregaCombinada!) : null),
                    ],
                  ),
                ),
              );

            final cardEntrega = Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.padLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(icon: Icons.local_shipping_outlined, title: 'Entrega'),
                      const SizedBox(height: 12),
                      _Info('Forma', pedido.formaEntrega == 'entrega' ? 'Entrega' : 'Retirada'),
                      _Info('Endereço', pedido.enderecoEntrega),
                      if (pedido.entregue) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimaryContainer),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Entregue${pedido.entregueEm != null ? " em ${data.format(pedido.entregueEm!)}" : ""}${pedido.entreguePor != null ? " por ${pedido.entreguePor}" : ""}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );

            final cardPagamentos = Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.padLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        icon: Icons.payments_outlined,
                        title: 'Pagamentos',
                        subtitle: 'Restante: ${moeda.format(pedido.valorRestante)}',
                      ),
                      const SizedBox(height: 12),
                      _PagamentosList(
                        pedidoId: pedidoId,
                        valorRestante: pedido.valorRestante,
                        moeda: moeda,
                        data: data,
                      ),
                    ],
                  ),
                ),
              );

            final cardObservacao = (pedido.observacao != null && pedido.observacao!.isNotEmpty)
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.padLg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(icon: Icons.note_outlined, title: 'Observação'),
                          const SizedBox(height: 8),
                          Text(pedido.observacao!, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  )
                : null;

            Widget pair(Widget? a, Widget b) {
              if (a == null) return b;
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: a),
                    const SizedBox(width: 12),
                    Expanded(child: b),
                  ],
                ),
              );
            }

            final children = <Widget>[
              cabecalho,
              const SizedBox(height: 12),
              if (wide) ...[
                pair(cardArte, cardPeca),
                const SizedBox(height: 12),
                pair(cardEntrega, cardAgenda),
                const SizedBox(height: 12),
              ] else ...[
                cardPeca,
                const SizedBox(height: 12),
                if (cardArte != null) ...[
                  cardArte,
                  const SizedBox(height: 12),
                ],
                cardAgenda,
                const SizedBox(height: 12),
                cardEntrega,
                const SizedBox(height: 12),
              ],
              cardPagamentos,
              if (cardObservacao != null) ...[
                const SizedBox(height: 12),
                cardObservacao,
              ],
            ];

            return ListView(
              padding: EdgeInsets.fromLTRB(
                wide ? 24 : 16,
                16,
                wide ? 24 : 16,
                32,
              ),
              children: children,
            );
          }),
        ),
      ),
    );
  }

  static const _statusOrdem = ['pendente', 'agendado', 'producao', 'concluido', 'entregue'];

  Future<void> _abrirMenuStatus(BuildContext context, WidgetRef ref, Pedido pedido) async {
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
                    'Mudar status para',
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
                    trailing: s == pedido.status ? Icon(Icons.check, color: cs.primary, size: 18) : null,
                    onTap: () => Navigator.of(sheetCtx).pop(s),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (escolha == null || escolha == pedido.status || !context.mounted) return;
    final statusOrigem = pedido.status;
    try {
      await ref.read(apiClientProvider).atualizarPedido(pedido.id, {'status': escolha});
      ref.invalidate(pedidoProvider(pedido.id));
      ref.invalidate(pedidosProvider);
      ref.invalidate(dashboardProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Status: ${statusInfo(context, escolha).label}'),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Desfazer',
                onPressed: () async {
                  try {
                    await ref.read(apiClientProvider).atualizarPedido(pedido.id, {'status': statusOrigem});
                    ref.invalidate(pedidoProvider(pedido.id));
                    ref.invalidate(pedidosProvider);
                    ref.invalidate(dashboardProvider);
                  } catch (_) {}
                },
              ),
            ),
          );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao mudar status: $e')),
        );
      }
    }
  }

  Future<void> _handleMenu(BuildContext context, WidgetRef ref, String action, Pedido pedido) async {
    if (action == 'duplicar') {
      try {
        final api = ref.read(apiClientProvider);
        final novo = await api.duplicarPedido(pedido.id);
        ref.invalidate(pedidosProvider);
        ref.invalidate(dashboardProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Duplicado como ${novo.loteFormatado}')),
          );
          context.push('/pedidos/${novo.id}/editar');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao duplicar: $e')),
          );
        }
      }
    } else if (action == 'reagendar') {
      try {
        final atualizado = await ref.read(apiClientProvider).agendarPedido(pedido.id);
        ref.invalidate(pedidoProvider(pedido.id));
        ref.invalidate(pedidosProvider);
        ref.invalidate(dashboardProvider);
        if (context.mounted) {
          final nova = atualizado.dataProducao;
          final dia = nova == null
              ? null
              : '${nova.year.toString().padLeft(4, '0')}-${nova.month.toString().padLeft(2, '0')}-${nova.day.toString().padLeft(2, '0')}';
          final msg = nova == null
              ? 'Pedido reagendado'
              : 'Reagendado para ${AppFormatters.data.format(nova)}';
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(msg),
                behavior: SnackBarBehavior.floating,
                action: dia == null
                    ? null
                    : SnackBarAction(
                        label: 'Ver agenda',
                        onPressed: () => context.go('/agenda?dia=$dia'),
                      ),
              ),
            );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao reagendar: $e')),
          );
        }
      }
    } else if (action == 'excluir') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Excluir pedido?'),
          content: Text('${pedido.loteFormatado} — ${pedido.clienteNome}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogCtx).colorScheme.errorContainer,
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Excluir'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      try {
        await ref.read(apiClientProvider).deletarPedido(pedido.id);
        ref.invalidate(pedidosProvider);
        ref.invalidate(dashboardProvider);
        if (context.mounted) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Pedido ${pedido.loteFormatado} excluído')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir: $e')),
          );
        }
      }
    }
  }
}

// ── Pagamentos sub-widget ──────────────────────────────────────────────────

class _PagamentosList extends ConsumerWidget {
  final String pedidoId;
  final double valorRestante;
  final NumberFormat moeda;
  final DateFormat data;
  const _PagamentosList({
    required this.pedidoId,
    required this.valorRestante,
    required this.moeda,
    required this.data,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagamentos = ref.watch(pagamentosProvider(pedidoId));
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pagamentos.when(
          loading: () => const Center(child: SizedBox(height: 48, child: CircularProgressIndicator())),
          error: (e, _) => Text('Erro ao carregar pagamentos', style: TextStyle(color: theme.colorScheme.error)),
          data: (lista) {
            if (lista.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Nenhum pagamento registrado',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                ),
              );
            }
            return Column(
              children: [
                for (final p in lista)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.check_circle, color: theme.colorScheme.primary),
                    title: Text(moeda.format(p.valor), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      '${_formaLabel(p.forma)} • ${data.format(p.quando)}${p.observacao != null && p.observacao!.isNotEmpty ? " — ${p.observacao}" : ""}',
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: theme.colorScheme.error, size: 20),
                      tooltip: 'Remover pagamento',
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (dialogCtx) => AlertDialog(
                            title: const Text('Remover pagamento?'),
                            content: Text(moeda.format(p.valor)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogCtx, false),
                                child: const Text('Cancelar'),
                              ),
                              FilledButton.tonal(
                                style: FilledButton.styleFrom(
                                  backgroundColor: theme.colorScheme.errorContainer,
                                ),
                                onPressed: () => Navigator.pop(dialogCtx, true),
                                child: const Text('Remover'),
                              ),
                            ],
                          ),
                        );
                        if (ok != true) return;
                        try {
                          await ref.read(apiClientProvider).deletarPagamento(p.id);
                          ref.invalidate(pagamentosProvider(pedidoId));
                          ref.invalidate(pedidoProvider(pedidoId));
                          ref.invalidate(pedidosProvider);
                          ref.invalidate(dashboardProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Pagamento removido')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erro: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: () => _showRegistrarPagamento(context, ref),
            child: const Text('Registrar pagamento'),
          ),
        ),
      ],
    );
  }

  String _formaLabel(String? forma) {
    return switch (forma) {
      'dinheiro' => 'Dinheiro',
      'pix' => 'Pix',
      'cartao_credito' => 'Cartão crédito',
      'cartao_debito' => 'Cartão débito',
      'boleto' => 'Boleto',
      'transferencia' => 'Transferência',
      _ => forma ?? '—',
    };
  }

  void _showRegistrarPagamento(BuildContext context, WidgetRef ref) {
    final valorCtl = TextEditingController(text: formatValorBR(valorRestante));
    String? forma = 'pix';
    final obsCtl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Registrar pagamento', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: valorCtl,
                  decoration: const InputDecoration(
                    labelText: 'Valor (R\$)',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: const [BrlInputFormatter()],
                  validator: (v) {
                    final val = parseValorBR(v ?? '');
                    if (val == null || val <= 0) return 'Inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: forma,
                  decoration: const InputDecoration(labelText: 'Forma'),
                  items: const [
                    DropdownMenuItem(value: 'dinheiro', child: Text('Dinheiro')),
                    DropdownMenuItem(value: 'pix', child: Text('Pix')),
                    DropdownMenuItem(value: 'cartao_credito', child: Text('Cartão crédito')),
                    DropdownMenuItem(value: 'cartao_debito', child: Text('Cartão débito')),
                    DropdownMenuItem(value: 'boleto', child: Text('Boleto')),
                    DropdownMenuItem(value: 'transferencia', child: Text('Transferência')),
                  ],
                  onChanged: (v) => forma = v,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: obsCtl,
                  decoration: const InputDecoration(
                    labelText: 'Observação',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final valor = parseValorBR(valorCtl.text);
                      if (valor == null) return;
                      try {
                        await ref.read(apiClientProvider).registrarPagamento(pedidoId, {
                          'valor': valor,
                          'forma': forma,
                          if (obsCtl.text.trim().isNotEmpty) 'observacao': obsCtl.text.trim(),
                        });
                        ref.invalidate(pagamentosProvider(pedidoId));
                        ref.invalidate(pedidoProvider(pedidoId));
                        ref.invalidate(pedidosProvider);
                        ref.invalidate(dashboardProvider);
                        if (context.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erro: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('Registrar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Breadcrumb (abaixo do título da AppBar) ───────────────────────────────

class _Breadcrumb extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Breadcrumb({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 28,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 16, 4),
          child: Row(
            children: [
              Icon(Icons.arrow_back, size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────

class _Info extends StatelessWidget {
  final String label;
  final String? valor;
  const _Info(this.label, this.valor);

  @override
  Widget build(BuildContext context) {
    if (valor == null || valor!.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(valor!, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}