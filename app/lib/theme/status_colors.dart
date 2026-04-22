import 'package:flutter/material.dart';

/// Par (background, foreground) pra um status/intenção genérico.
class StatusPalette {
  final Color bg;
  final Color fg;
  const StatusPalette(this.bg, this.fg);
}

enum StatusTone {
  info,     // neutro/informativo — azul
  success,  // concluído/pago — verde
  warning,  // vencendo/parcial — âmbar
  danger,   // atrasado/devendo — vermelho
  neutral,  // sem estado/apagado — cinza
}

/// Retorna um par de cores coerente com o tema ativo (claro/escuro) pra o
/// status/intenção informado. Use em badges, chips e pills fora do pedido
/// principal — o próprio StatusPill de pedido já tem paleta dedicada.
StatusPalette statusColors(BuildContext context, StatusTone tone) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  // Paleta dessaturada — cores transmitem estado sem competir com o conteúdo.
  switch (tone) {
    case StatusTone.info:
      return dark
          ? const StatusPalette(Color(0xFF1B2838), Color(0xFF89B4D6))
          : const StatusPalette(Color(0xFFEAF0F7), Color(0xFF3D5A80));
    case StatusTone.success:
      return dark
          ? const StatusPalette(Color(0xFF1C2E22), Color(0xFF9CBFA3))
          : const StatusPalette(Color(0xFFE6F1E9), Color(0xFF446B4E));
    case StatusTone.warning:
      return dark
          ? const StatusPalette(Color(0xFF2B2419), Color(0xFFDEB887))
          : const StatusPalette(Color(0xFFF5EDE0), Color(0xFF8B6914));
    case StatusTone.danger:
      return dark
          ? const StatusPalette(Color(0xFF2E1D1D), Color(0xFFD99999))
          : const StatusPalette(Color(0xFFF5E5E5), Color(0xFF8B4444));
    case StatusTone.neutral:
      return dark
          ? const StatusPalette(Color(0xFF2C2C2A), Color(0xFFAAAAA3))
          : const StatusPalette(Color(0xFFEEEEE9), Color(0xFF6B6B63));
  }
}
