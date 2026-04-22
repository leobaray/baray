import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/pedido.dart';
import '../theme/density.dart';
import '../theme/spacing.dart';
import 'status_pill.dart';

/// Linha densa de pedido — usada na lista de Pedidos e Agenda.
/// Padrão: "cliente (com telefone opcional)" + "peça (com qtd inline)"
/// + valor + status + pagto. Sem colunas de Qtd e Data separadas — qtd fica
/// inline com peça ("20× camiseta") e a data completa vive no detalhe.
class PedidoRow extends StatelessWidget {
  static const double kLoteW = 64;
  static const double kValorW = 88;
  static const double kStatusW = 104;
  static const double kPagtoW = 92;
  static const int kClienteFlex = 3;
  static const int kPecaFlex = 4;

  final Pedido pedido;
  final VoidCallback onTap;
  final bool zebra;

  const PedidoRow({
    super.key,
    required this.pedido,
    required this.onTap,
    this.zebra = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);

    final hoje = DateTime.now();
    final hojeData = DateTime(hoje.year, hoje.month, hoje.day);
    final atrasado = pedido.dataEntregaCombinada != null &&
        !pedido.entregue &&
        pedido.dataEntregaCombinada!.isBefore(hojeData);

    final Color accent;
    if (atrasado) {
      accent = cs.error;
    } else if (pedido.urgente) {
      accent = cs.tertiary;
    } else {
      accent = Colors.transparent;
    }
    const double accentWidth = 4;

    return Material(
      color: zebra ? cs.surfaceContainerLow : cs.surface,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(width: accentWidth, color: accent),
              bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kRowMinHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.padSm,
                vertical: 6,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: kLoteW,
                    child: Text(
                      pedido.loteFormatado,
                      style: TextStyle(
                        fontSize: AppType.code,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.gapSm),
                  Expanded(
                    flex: kClienteFlex,
                    child: _ClienteCell(pedido: pedido),
                  ),
                  const SizedBox(width: AppSpacing.gapSm),
                  Expanded(
                    flex: kPecaFlex,
                    child: _PecaCell(pedido: pedido),
                  ),
                  const SizedBox(width: AppSpacing.gapSm),
                  SizedBox(
                    width: kValorW,
                    child: Text(
                      moeda.format(pedido.valor),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppType.row,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.gapMd),
                  SizedBox(
                    width: kStatusW,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: StatusPill(status: pedido.status, small: true),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.gapSm),
                  SizedBox(
                    width: kPagtoW,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: PagamentoPill(
                        statusPagamento: pedido.statusPagamento,
                        small: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClienteCell extends StatelessWidget {
  final Pedido pedido;
  const _ClienteCell({required this.pedido});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tel = pedido.clienteTelefone;
    final temTel = tel != null && tel.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          pedido.clienteNome,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppType.row,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
            height: 1.15,
          ),
        ),
        if (temTel)
          Text(
            tel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              color: cs.outline,
              height: 1.1,
            ),
          ),
      ],
    );
  }
}

class _PecaCell extends StatelessWidget {
  final Pedido pedido;
  const _PecaCell({required this.pedido});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final partes = <String>[
      if (pedido.quantidade != null) '${pedido.quantidade}×',
      if (pedido.peca != null && pedido.peca!.isNotEmpty) pedido.peca! else pedido.descricao,
      if (pedido.tecnica != null && pedido.tecnica!.isNotEmpty) pedido.tecnica!,
      if (pedido.arteCores != null) '${pedido.arteCores}c',
    ];
    return Text(
      partes.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: AppType.row,
        color: cs.onSurfaceVariant,
      ),
    );
  }
}

/// Cabeçalho de colunas — widths/flexes batem com [PedidoRow].
class PedidosHeader extends StatelessWidget {
  const PedidosHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: AppType.colHeader,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: cs.onSurfaceVariant,
    );

    Widget label(String s, {TextAlign? align}) =>
        Text(s.toUpperCase(), textAlign: align, style: style);

    return Container(
      height: kHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.padSm),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant),
          left: BorderSide(width: 4, color: Colors.transparent),
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: PedidoRow.kLoteW, child: label('Lote')),
          const SizedBox(width: AppSpacing.gapSm),
          Expanded(flex: PedidoRow.kClienteFlex, child: label('Cliente')),
          const SizedBox(width: AppSpacing.gapSm),
          Expanded(flex: PedidoRow.kPecaFlex, child: label('Peça / técnica')),
          const SizedBox(width: AppSpacing.gapSm),
          SizedBox(
            width: PedidoRow.kValorW,
            child: label('Valor', align: TextAlign.right),
          ),
          const SizedBox(width: AppSpacing.gapMd),
          SizedBox(width: PedidoRow.kStatusW, child: label('Status')),
          const SizedBox(width: AppSpacing.gapSm),
          SizedBox(width: PedidoRow.kPagtoW, child: label('Pagto')),
        ],
      ),
    );
  }
}

/// Card denso pra mobile (<600px) — 2 linhas, tudo visível sem scroll horizontal.
class PedidoCardMobile extends StatelessWidget {
  final Pedido pedido;
  final VoidCallback onTap;
  final bool zebra;

  const PedidoCardMobile({
    super.key,
    required this.pedido,
    required this.onTap,
    this.zebra = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);

    final hoje = DateTime.now();
    final hojeData = DateTime(hoje.year, hoje.month, hoje.day);
    final atrasado = pedido.dataEntregaCombinada != null &&
        !pedido.entregue &&
        pedido.dataEntregaCombinada!.isBefore(hojeData);

    final Color accent = atrasado
        ? cs.error
        : (pedido.urgente ? cs.tertiary : Colors.transparent);

    final peca = [
      if (pedido.quantidade != null) '${pedido.quantidade}×',
      if (pedido.peca != null && pedido.peca!.isNotEmpty)
        pedido.peca!
      else
        pedido.descricao,
      if (pedido.tecnica != null) pedido.tecnica!,
      if (pedido.arteCores != null) '${pedido.arteCores}c',
    ].join(' · ');

    return Material(
      color: zebra ? cs.surfaceContainerLow : cs.surface,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(width: 4, color: accent),
              bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      pedido.loteFormatado,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pedido.clienteNome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      moeda.format(pedido.valor),
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
                        peca,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusPill(status: pedido.status, small: true),
                    const SizedBox(width: 6),
                    PagamentoPill(statusPagamento: pedido.statusPagamento, small: true),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
