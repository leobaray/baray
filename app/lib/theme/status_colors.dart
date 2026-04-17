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
  switch (tone) {
    case StatusTone.info:
      return dark
          ? const StatusPalette(Color(0xFF0D2137), Color(0xFF90CAF9))
          : const StatusPalette(Color(0xFFE3F2FD), Color(0xFF1976D2));
    case StatusTone.success:
      return dark
          ? const StatusPalette(Color(0xFF0D3318), Color(0xFFA5D6A7))
          : const StatusPalette(Color(0xFFE8F5E9), Color(0xFF2E7D32));
    case StatusTone.warning:
      return dark
          ? const StatusPalette(Color(0xFF3D2E00), Color(0xFFFFCA28))
          : const StatusPalette(Color(0xFFFFF3E0), Color(0xFFE65100));
    case StatusTone.danger:
      return dark
          ? const StatusPalette(Color(0xFF3D0E0E), Color(0xFFFF8A80))
          : const StatusPalette(Color(0xFFFFEBEE), Color(0xFFC62828));
    case StatusTone.neutral:
      return dark
          ? const StatusPalette(Color(0xFF3A3A38), Color(0xFFBDBDBD))
          : const StatusPalette(Color(0xFFE0E0DD), Color(0xFF616161));
  }
}
