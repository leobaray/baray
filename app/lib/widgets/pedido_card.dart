import 'package:flutter/material.dart';

import '../models/pedido.dart';
import '../theme/spacing.dart';
import '../theme/status_colors.dart';
import '../util/formatters.dart';
import 'status_pill.dart';
import 'tint_chip.dart';

/// Card de pedido rico, usado na lista, dashboard e kanban.
class PedidoCard extends StatelessWidget {
  final Pedido pedido;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool compacto;
  final bool showDragHandle;
  const PedidoCard({
    super.key,
    required this.pedido,
    required this.onTap,
    this.onLongPress,
    this.compacto = false,
    this.showDragHandle = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moeda = AppFormatters.moeda;
    final dataFmt = AppFormatters.dataCurta;

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
    // Em compacto, limita visíveis a 4 e adiciona um indicador "+N" pra não
    // esconder informação silenciosamente.
    final chipsVisiveis = compacto && chips.length > 4
        ? [
            ...chips.sublist(0, 4),
            TintChip(
              icon: Icons.more_horiz,
              label: '+${chips.length - 4}',
            ),
          ]
        : chips;

    return Card(
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(compacto ? 14 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (showDragHandle) ...[
                    Icon(
                      Icons.drag_indicator,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      semanticLabel: 'Arrastar',
                    ),
                    const SizedBox(width: 4),
                  ],
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.call_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            pedido.clienteTelefone!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
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
              fontSize: 12,
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
