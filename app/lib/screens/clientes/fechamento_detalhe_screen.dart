import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../models/cliente_fechamento.dart';
import '../../models/pedido.dart';
import '../../state/cliente_fechamentos_provider.dart';
import '../../widgets/pedido_card.dart';
import 'fechamento_fechar_dialog.dart';
import 'fechamento_estender_dialog.dart';

class FechamentoDetalheScreen extends ConsumerStatefulWidget {
  final String clienteId;
  final String fechamentoId;
  const FechamentoDetalheScreen({
    super.key,
    required this.clienteId,
    required this.fechamentoId,
  });

  @override
  ConsumerState<FechamentoDetalheScreen> createState() => _FechamentoDetalheScreenState();
}

class _FechamentoDetalheScreenState extends ConsumerState<FechamentoDetalheScreen> {
  ClienteFechamento? _fechamento;
  List<Pedido>? _pedidos;
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final api = ref.read(apiClientProvider);
      final result = await api.buscarFechamento(widget.clienteId, widget.fechamentoId);
      // A API retorna o fechamento + pedidos no campo 'pedidos'
      if (!mounted) return;
      // Como buscarFechamento retorna ClienteFechamento, e a API inclui pedidos no JSON,
      // precisamos extrair os pedidos separadamente
      final dio = api.dio;
      final r = await dio.get('/clientes/${widget.clienteId}/fechamentos/${widget.fechamentoId}');
      final data = r.data as Map<String, dynamic>;
      final pedidosJson = data['pedidos'] as List?;
      setState(() {
        _fechamento = result;
        _pedidos = pedidosJson?.map((p) => Pedido.fromJson(p as Map<String, dynamic>)).toList() ?? [];
        _carregando = false;
      });
    } catch (e) {
      if (mounted) setState(() { _erro = e.toString(); _carregando = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dataFmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: _fechamento != null
            ? Text('Ciclo #${_fechamento!.numero}')
            : const Text('Fechamento'),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
              ? Center(child: Text(_erro!, style: TextStyle(color: theme.colorScheme.error)))
              : _buildContent(theme, moeda, dataFmt),
    );
  }

  Widget _buildContent(ThemeData theme, NumberFormat moeda, DateFormat dataFmt) {
    final f = _fechamento!;

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          // Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Ciclo #${f.numero}',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      _StatusBadge(status: f.status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ResumoRow(label: 'Abertura', value: dataFmt.format(f.dataAbertura)),
                  const SizedBox(height: 8),
                  _ResumoRow(
                    label: 'Previsto',
                    value: dataFmt.format(f.dataFechamentoPrevista),
                  ),
                  if (f.dataFechamentoReal != null) ...[
                    const SizedBox(height: 8),
                    _ResumoRow(
                      label: 'Fechado em',
                      value: dataFmt.format(f.dataFechamentoReal!),
                    ),
                  ],
                  const Divider(height: 24),
                  _ResumoRow(label: 'Pedidos', value: '${f.totalPedidos}'),
                  const SizedBox(height: 8),
                  _ResumoRow(label: 'Valor total', value: moeda.format(f.valorTotal)),
                  const SizedBox(height: 8),
                  _ResumoRow(
                    label: 'Valor pago',
                    value: moeda.format(f.valorPago),
                    valueColor: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  _ResumoRow(
                    label: 'Pendente',
                    value: moeda.format(f.valorPendente),
                    valueColor: f.valorPendente > 0 ? theme.colorScheme.error : theme.colorScheme.primary,
                  ),
                  if (f.aberto) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _fechar(),
                            icon: const Icon(Icons.lock_outline, size: 18),
                            label: const Text('Fechar agora'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () => _estender(),
                            icon: const Icon(Icons.schedule_outlined, size: 18),
                            label: const Text('Estender'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Pedidos
          const SizedBox(height: 16),
          Text(
            'Pedidos do período',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (_pedidos == null || _pedidos!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Nenhum pedido neste ciclo',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ..._pedidos!.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PedidoCard(
                  pedido: p,
                  onTap: () {}, // Navegação futura
                  compacto: true,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _fechar() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => FechamentoFecharDialog(fechamento: _fechamento!),
    );
    if (result == true) {
      _carregar();
      ref.invalidate(fechamentosProvider(widget.clienteId));
    }
  }

  Future<void> _estender() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => FechamentoEstenderDialog(
        fechamento: _fechamento!,
        clienteId: widget.clienteId,
      ),
    );
    if (result == true) {
      _carregar();
      ref.invalidate(fechamentosProvider(widget.clienteId));
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, fgColor, label) = switch (status) {
      'aberto' => (Colors.green.shade100, Colors.green.shade900, 'Aberto'),
      'estendido' => (Colors.orange.shade100, Colors.orange.shade900, 'Estendido'),
      'fechado' => (Colors.grey.shade200, Colors.grey.shade700, 'Fechado'),
      _ => (Colors.grey.shade200, Colors.grey.shade700, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: fgColor, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ResumoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _ResumoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          )),
        ),
        Expanded(
          child: Text(value, style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
          )),
        ),
      ],
    );
  }
}