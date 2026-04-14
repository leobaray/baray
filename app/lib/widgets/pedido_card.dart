import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/pedido.dart';
import 'status_pill.dart';

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

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(compacto ? 14 : 18),
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      pedido.clienteNome,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (pedido.urgente)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.flash_on,
                              size: 11,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'URGENTE',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                                fontWeight: FontWeight.w800,
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              if (!compacto) const SizedBox(height: 10),
              if (!compacto)
                Text(
                  pedido.descricao,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              SizedBox(height: compacto ? 8 : 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Chip(
                    icon: Icons.payments_outlined,
                    label: moeda.format(pedido.valor),
                    strong: true,
                  ),
                  if (pedido.quantidade != null)
                    _Chip(
                      icon: Icons.numbers,
                      label: '${pedido.quantidade} pç',
                    ),
                  if (pedido.tecnica != null)
                    _Chip(icon: Icons.brush_outlined, label: pedido.tecnica!),
                  if (pedido.arteCores != null)
                    _Chip(icon: Icons.palette_outlined, label: '${pedido.arteCores}c'),
                  if (produzHoje)
                    _Chip(
                      icon: Icons.today,
                      label: 'HOJE',
                      bg: theme.colorScheme.tertiaryContainer,
                      fg: theme.colorScheme.onTertiaryContainer,
                    ),
                  if (pedido.dataProducao != null && !produzHoje)
                    _Chip(
                      icon: Icons.precision_manufacturing_outlined,
                      label: dataFmt.format(pedido.dataProducao!),
                    ),
                  if (atrasado)
                    _Chip(
                      icon: Icons.warning_amber_rounded,
                      label: 'ATRASADO',
                      bg: theme.colorScheme.errorContainer,
                      fg: theme.colorScheme.onErrorContainer,
                    )
                  else if (vencendo)
                    _Chip(
                      icon: Icons.access_time,
                      label: 'Vencendo',
                      bg: const Color(0xFFFFE0B2),
                      fg: const Color(0xFFE65100),
                    ),
                ],
              ),
              if (!compacto) const SizedBox(height: 12),
              if (!compacto)
                Row(
                  children: [
                    StatusPill(status: pedido.status),
                    const SizedBox(width: 8),
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

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool strong;
  final Color? bg;
  final Color? fg;
  const _Chip({required this.icon, required this.label, this.strong = false, this.bg, this.fg});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = bg ?? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
    final fgColor = fg ?? theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fgColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fgColor,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
