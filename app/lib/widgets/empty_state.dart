import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String? subtitulo;
  final Widget? acao;

  const EmptyState({
    super.key,
    required this.icon,
    required this.titulo,
    this.subtitulo,
    this.acao,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 56,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              titulo,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            if (subtitulo != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitulo!,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                textAlign: TextAlign.center,
              ),
            ],
            if (acao != null) ...[
              const SizedBox(height: 20),
              acao!,
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_off, size: 48, color: theme.colorScheme.error),
            ),
            const SizedBox(height: 16),
            Text('Não consegui falar com o servidor', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar de novo'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: theme.colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: 0.3,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
