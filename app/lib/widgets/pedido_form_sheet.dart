import 'package:flutter/material.dart';

import '../screens/pedidos/pedido_form_screen.dart';

/// Abre [PedidoFormScreen] como overlay em vez de empurrar uma rota nova.
///
/// Em telas largas (≥900px) renderiza como painel lateral à direita (estilo
/// inspector). Em telas estreitas, renderiza como bottom sheet quase fullscreen.
/// Mantém [PedidoFormScreen] intocada — só hospeda dentro de um container que
/// dá tamanho. O `context.pop()` interno fecha o sheet normalmente.
class PedidoFormSheet {
  PedidoFormSheet._();

  static Future<T?> show<T>(
    BuildContext context, {
    String? pedidoId,
    Map<String, String>? initial,
  }) {
    final mq = MediaQuery.of(context);
    final isDesktop = mq.size.width >= 900;
    final theme = Theme.of(context);

    if (isDesktop) {
      return showGeneralDialog<T>(
        context: context,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, _, _) => Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: theme.colorScheme.surface,
            elevation: 16,
            child: SizedBox(
              width: 560,
              height: double.infinity,
              child: PedidoFormScreen(pedidoId: pedidoId, initial: initial),
            ),
          ),
        ),
        transitionBuilder: (_, anim, _, child) {
          final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return SlideTransition(
            position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
            child: child,
          );
        },
      );
    }

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.95,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: PedidoFormScreen(pedidoId: pedidoId, initial: initial),
        ),
      ),
    );
  }
}
