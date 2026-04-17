import 'package:flutter/material.dart';

import '../theme/status_colors.dart';

/// Badge do status de um ciclo de fechamento (aberto/estendido/fechado).
class FechamentoStatusBadge extends StatelessWidget {
  final String status;
  const FechamentoStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (tone, label) = switch (status) {
      'aberto' => (StatusTone.success, 'Aberto'),
      'estendido' => (StatusTone.warning, 'Estendido'),
      'fechado' => (StatusTone.neutral, 'Fechado'),
      _ => (StatusTone.neutral, status),
    };
    final palette = statusColors(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: palette.bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: palette.fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
