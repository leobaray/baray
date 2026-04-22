import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/cliente_detalhe_view.dart';

/// Shell de rota — usa [ClienteDetalheView] dentro de Scaffold.
/// Quando navegamos via push (`/clientes/:id`), esse shell é o container.
/// No master-detail desktop, a `ClienteDetalheView` é embutida diretamente
/// sem este shell.
class ClienteDetalheScreen extends ConsumerWidget {
  final String clienteId;
  const ClienteDetalheScreen({super.key, required this.clienteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cliente'),
      ),
      body: ClienteDetalheView(clienteId: clienteId),
    );
  }
}
