import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/cliente.dart';
import '../../state/clientes_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/shimmer_skeleton.dart';

class ClientesScreen extends ConsumerStatefulWidget {
  const ClientesScreen({super.key});

  @override
  ConsumerState<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends ConsumerState<ClientesScreen> {
  final _buscaCtl = TextEditingController();
  final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void dispose() {
    _buscaCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientes = ref.watch(clientesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: () => ref.invalidate(clientesProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/clientes/novo'),
        icon: const Icon(Icons.add),
        label: const Text('Novo cliente'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _buscaCtl,
              decoration: const InputDecoration(
                hintText: 'Buscar por nome...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => ref.read(clientesBuscaProvider.notifier).state = v,
            ),
          ),
          Expanded(
            child: clientes.when(
              loading: () => ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, __) => const _ClienteSkeleton(),
              ),
              error: (e, _) => ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(clientesProvider),
              ),
              data: (lista) {
                if (lista.isEmpty) {
                  return EmptyState(
                    icon: Icons.people_outline,
                    titulo: 'Nenhum cliente',
                    subtitulo: 'Toque em "Novo cliente" para cadastrar',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(clientesProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    itemCount: lista.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _ClienteCard(
                      cliente: lista[i],
                      moeda: moeda,
                      onTap: () => context.push('/clientes/${lista[i].id}'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cliente card ───────────────────────────────────────────────────────────

class _ClienteCard extends StatelessWidget {
  final Cliente cliente;
  final NumberFormat moeda;
  final VoidCallback onTap;

  const _ClienteCard({
    required this.cliente,
    required this.moeda,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(
                  cliente.iniciais,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cliente.nome,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (cliente.telefone != null && cliente.telefone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.call_outlined, size: 14, color: theme.colorScheme.outline),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              cliente.telefone!,
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${cliente.totalPedidos} pedido${cliente.totalPedidos == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Total ${moeda.format(cliente.totalGasto)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shimmer skeleton ───────────────────────────────────────────────────────

class _ClienteSkeleton extends StatelessWidget {
  const _ClienteSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            ShimmerSkeleton(width: 44, height: 44, borderRadius: BorderRadius.circular(22)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerSkeleton(width: 140, height: 18, borderRadius: BorderRadius.circular(4)),
                  const SizedBox(height: 6),
                  ShimmerSkeleton(width: 180, height: 14, borderRadius: BorderRadius.circular(4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}