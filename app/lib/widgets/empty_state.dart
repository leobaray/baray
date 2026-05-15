import 'package:flutter/material.dart';

/// Empty state canônico — três variantes pra cobrir todos os casos do app.
///
/// **full** (default): ícone grande circular + título + subtítulo + ação.
///   Para empty da tela inteira.
/// **compact**: ícone médio + texto + CTA opcional. Para empty dentro de cards
///   ou abas (Dashboard destaques, Cliente ciclo, etc.).
/// **inline**: ícone pequeno + texto inline + tap action. Para empty em linhas
///   compactas (dia vazio na agenda).
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String? subtitulo;
  final Widget? acao;
  final _EmptyVariant _variant;

  /// Ação inline (usada só pela variante `inline` — toda a linha vira tappable).
  final VoidCallback? _onTapInline;

  /// CTA da variante `compact` — TextButton com seta. Use `acao` se quiser
  /// passar um widget customizado.
  final String? _compactCtaLabel;
  final VoidCallback? _compactCtaOnTap;

  const EmptyState({
    super.key,
    required this.icon,
    required this.titulo,
    this.subtitulo,
    this.acao,
  })  : _variant = _EmptyVariant.full,
        _onTapInline = null,
        _compactCtaLabel = null,
        _compactCtaOnTap = null;

  /// Empty state para sub-seção (cards, tabs, painéis laterais).
  const EmptyState.compact({
    super.key,
    required this.icon,
    required this.titulo,
    this.subtitulo,
    String? ctaLabel,
    VoidCallback? onCta,
  })  : _variant = _EmptyVariant.compact,
        acao = null,
        _onTapInline = null,
        _compactCtaLabel = ctaLabel,
        _compactCtaOnTap = onCta;

  /// Empty state inline — linha curta tappable com ícone e texto lado a lado.
  const EmptyState.inline({
    super.key,
    required this.icon,
    required this.titulo,
    VoidCallback? onTap,
  })  : _variant = _EmptyVariant.inline,
        subtitulo = null,
        acao = null,
        _onTapInline = onTap,
        _compactCtaLabel = null,
        _compactCtaOnTap = null;

  @override
  Widget build(BuildContext context) {
    return switch (_variant) {
      _EmptyVariant.full => _buildFull(context),
      _EmptyVariant.compact => _buildCompact(context),
      _EmptyVariant.inline => _buildInline(context),
    };
  }

  Widget _buildFull(BuildContext context) {
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
              child: Icon(icon, size: 56, color: theme.colorScheme.primary),
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
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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

  Widget _buildCompact(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: cs.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitulo != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitulo!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            if (_compactCtaLabel != null && _compactCtaOnTap != null) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _compactCtaOnTap,
                icon: const Icon(Icons.arrow_forward, size: 14),
                label: Text(_compactCtaLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInline(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final inner = Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              titulo,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (_onTapInline == null) return inner;
    return InkWell(onTap: _onTapInline, child: inner);
  }
}

enum _EmptyVariant { full, compact, inline }

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
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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

/// Section header com ícone em primaryContainer + título + subtítulo opcional.
///
/// Use em cards prominentes (Pedido detalhe, Configurações). Para o header
/// "uppercase label primary" em cards densos, use [BlockHeader].
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
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Header denso pra blocos dentro de cards — ícone primário pequeno + label
/// uppercase com letter-spacing. Versão compacta do [SectionHeader].
///
/// Use em cards densos onde o `SectionHeader` (com primaryContainer box) ocupa
/// espaço demais. Padronizado em fontSize 12 / w800 / letterSpacing 0.9 / icon 14.
class BlockHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;

  const BlockHeader({
    super.key,
    required this.icon,
    required this.label,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 14, color: cs.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: cs.primary,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
