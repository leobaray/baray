import 'package:flutter/material.dart';

/// Linha de resumo label/valor para cards de detalhe.
///
/// Em cards que usam `primaryContainer` (ou similar), passe `onContainer` com a
/// cor `onXxxContainer` correspondente — o label usa uma versão com alfa e o
/// valor usa a cor cheia. Em superfícies normais, omita `onContainer`.
class ResumoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final Color? onContainer;

  const ResumoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.onContainer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor = onContainer != null
        ? onContainer!.withValues(alpha: 0.7)
        : theme.colorScheme.onSurfaceVariant;
    final defaultValueColor = onContainer ?? theme.colorScheme.onSurface;
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: labelColor),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor ?? defaultValueColor,
            ),
          ),
        ),
      ],
    );
  }
}
