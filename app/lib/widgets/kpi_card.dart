import 'package:flutter/material.dart';

class KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valor;
  final String? hint;
  final Color? accent;
  final VoidCallback? onTap;

  const KpiCard({
    super.key,
    required this.icon,
    required this.label,
    required this.valor,
    this.hint,
    this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = accent ?? theme.colorScheme.primary;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 20, color: accentColor),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    Icon(Icons.arrow_forward, size: 16, color: theme.colorScheme.outline),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                valor,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (hint != null) ...[
                const SizedBox(height: 4),
                Text(
                  hint!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
