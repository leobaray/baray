import 'package:flutter/material.dart';

import '../theme/density.dart';

/// Chip tintado pequeno com ícone + label. Usado em cards de pedido, cliente
/// e dashboard pra mostrar metadados sem roubar atenção do conteúdo principal.
class TintChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool strong;
  final Color? bg;
  final Color? fg;

  const TintChip({
    super.key,
    required this.icon,
    required this.label,
    this.strong = false,
    this.bg,
    this.fg,
  });

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
              fontSize: AppType.pill,
            ),
          ),
        ],
      ),
    );
  }
}
