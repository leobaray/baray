import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/cliente.dart';
import '../theme/density.dart';
import '../theme/spacing.dart';
import '../util/formatters.dart';

/// Linha densa de cliente — usada na lista master do split desktop e na
/// lista full. Mostra avatar + nome + contato + valor total + badge de débito.
class ClienteRow extends StatelessWidget {
  final Cliente cliente;
  final bool selected;
  final bool zebra;
  final VoidCallback onTap;

  const ClienteRow({
    super.key,
    required this.cliente,
    required this.onTap,
    this.selected = false,
    this.zebra = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final moeda = AppFormatters.moedaInteira;

    // Selected tem prioridade visual; senão aplica zebra.
    final Color bg;
    if (selected) {
      bg = cs.primaryContainer.withValues(alpha: 0.4);
    } else if (zebra) {
      bg = cs.surfaceContainerLow;
    } else {
      bg = cs.surface;
    }

    final temDebito = cliente.valorDevendo > 0.01;

    return Material(
      color: bg,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                width: 3,
                color: selected ? cs.primary : Colors.transparent,
              ),
              bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.padSm,
              vertical: 8,
            ),
            child: Row(
              children: [
                _Avatar(iniciais: cliente.iniciais, selected: selected),
                const SizedBox(width: AppSpacing.gapMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cliente.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppType.row,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle(cliente),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppType.caption,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.gapSm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      moeda.format(cliente.totalGasto),
                      style: TextStyle(
                        fontSize: AppType.row,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (temDebito)
                      _DebitoBadge(valor: cliente.valorDevendo, moeda: moeda)
                    else
                      Text(
                        '${cliente.totalPedidos} pç',
                        style: TextStyle(
                          fontSize: AppType.caption,
                          color: cs.onSurfaceVariant,
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
  }

  static String _subtitle(Cliente c) {
    final telefone = c.telefone?.trim();
    if (telefone != null && telefone.isNotEmpty) return telefone;
    final email = c.email?.trim();
    if (email != null && email.isNotEmpty) return email;
    return 'Sem contato';
  }
}

class _Avatar extends StatelessWidget {
  final String iniciais;
  final bool selected;
  const _Avatar({required this.iniciais, required this.selected});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: selected ? cs.primary : cs.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        iniciais,
        style: TextStyle(
          fontSize: AppType.pill,
          fontWeight: FontWeight.w800,
          color: selected ? cs.onPrimary : cs.onPrimaryContainer,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _DebitoBadge extends StatelessWidget {
  final double valor;
  final NumberFormat moeda;
  const _DebitoBadge({required this.valor, required this.moeda});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'deve ${moeda.format(valor)}',
        style: TextStyle(
          fontSize: AppType.pill,
          fontWeight: FontWeight.w700,
          color: cs.onErrorContainer,
          letterSpacing: 0.2,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
