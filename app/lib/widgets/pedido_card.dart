import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/pedido.dart';
import '../theme/spacing.dart';
import '../theme/status_colors.dart';
import 'status_pill.dart';
import 'tint_chip.dart';

/// Card de pedido rico, usado na lista, dashboard e kanban.
class PedidoCard extends StatelessWidget {
  final Pedido pedido;
  final VoidCallback onTap;
  final bool compacto;
  const PedidoCard({
    super.key,
    required this.pedido,
    required this.onTap,
    this.compacto = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dataFmt = DateFormat('dd/MM', 'pt_BR');

    final hoje = DateTime.now();
    final hojeData = DateTime(hoje.year, hoje.month, hoje.day);
    final produzHoje = pedido.dataProducao != null &&
        DateTime(pedido.dataProducao!.year, pedido.dataProducao!.month, pedido.dataProducao!.day) ==
            hojeData;

    final vencendo = pedido.dataEntregaCombinada != null &&
        !pedido.entregue &&
        pedido.dataEntregaCombinada!.difference(hoje).inDays <= 2;
    final atrasado = pedido.dataEntregaCombinada != null &&
        !pedido.entregue &&
        pedido.dataEntregaCombinada!.isBefore(hojeData);

    // Monta chips de metadata. Em compacto limita a 4 pra não estourar linhas.
    final chips = <Widget>[
      TintChip(
        icon: Icons.payments_outlined,
        label: moeda.format(pedido.valor),
        strong: true,
      ),
      if (pedido.quantidade != null)
        TintChip(icon: Icons.numbers, label: '${pedido.quantidade} pç'),
      if (pedido.tecnica != null)
        TintChip(icon: Icons.brush_outlined, label: pedido.tecnica!),
      if (pedido.arteCores != null)
        TintChip(icon: Icons.palette_outlined, label: '${pedido.arteCores}c'),
      if (produzHoje)
        TintChip(
          icon: Icons.today,
          label: 'HOJE',
          bg: theme.colorScheme.tertiaryContainer,
          fg: theme.colorScheme.onTertiaryContainer,
        ),
      if (pedido.dataProducao != null && !produzHoje)
        TintChip(
          icon: Icons.precision_manufacturing_outlined,
          label: dataFmt.format(pedido.dataProducao!),
        ),
      if (atrasado)
        TintChip(
          icon: Icons.warning_amber_rounded,
          label: 'ATRASADO',
          bg: theme.colorScheme.errorContainer,
          fg: theme.colorScheme.onErrorContainer,
        )
      else if (vencendo)
        _VencendoChip(),
    ];
    final chipsVisiveis = compacto && chips.length > 4 ? chips.sublist(0, 4) : chips;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(compacto ? AppSpacing.gapLg - 2 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      pedido.loteFormatado,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.gapSm),
                  // StatusPill no topo — sempre visível, inclusive em compacto.
                  StatusPill(status: pedido.status, small: compacto),
                  const SizedBox(width: AppSpacing.gapSm),
                  Expanded(
                    child: Text(
                      pedido.clienteNome,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              if (pedido.urgente) ...[
                const SizedBox(height: AppSpacing.gapSm),
                _UrgenteChip(),
              ],
              if (!compacto) const SizedBox(height: 10),
              if (!compacto)
                Text(
                  pedido.descricao,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              SizedBox(height: compacto ? AppSpacing.gapSm : 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: chipsVisiveis,
              ),
              if (!compacto) const SizedBox(height: AppSpacing.gapMd),
              if (!compacto)
                Row(
                  children: [
                    PagamentoPill(statusPagamento: pedido.statusPagamento),
                    const Spacer(),
                    if (pedido.clienteTelefone != null && pedido.clienteTelefone!.isNotEmpty)
                      Icon(
                        Icons.call_outlined,
                        size: 16,
                        color: theme.colorScheme.outline,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UrgenteChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.flash_on,
            size: 13,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 4),
          Text(
            'URGENTE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _VencendoChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = statusColors(context, StatusTone.warning);
    return TintChip(
      icon: Icons.access_time,
      label: 'Vencendo',
      bg: palette.bg,
      fg: palette.fg,
    );
  }
}
