import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../models/orcamento.dart';
import '../../state/orcamento_provider.dart';
import '../../widgets/empty_state.dart';

class OrcamentoScreen extends ConsumerStatefulWidget {
  const OrcamentoScreen({super.key});

  @override
  ConsumerState<OrcamentoScreen> createState() => _OrcamentoScreenState();
}

class _OrcamentoScreenState extends ConsumerState<OrcamentoScreen> {
  String? _tecnica;
  String _regiao = 'FRENTE/COSTAS';
  int _quantidade = 25;
  int _cores = 1;
  bool _urgente = false;
  String? _tipoPeca;

  OrcamentoResultado? _resultado;
  bool _calculando = false;
  String? _erro;

  final _quantidadeCtl = TextEditingController(text: '25');
  final _coresCtl = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _quantidadeCtl.addListener(() {
      final v = int.tryParse(_quantidadeCtl.text);
      if (v != null && v > 0) setState(() => _quantidade = v);
    });
    _coresCtl.addListener(() {
      final v = int.tryParse(_coresCtl.text);
      if (v != null && v > 0) setState(() => _cores = v);
    });
  }

  @override
  void dispose() {
    _quantidadeCtl.dispose();
    _coresCtl.dispose();
    super.dispose();
  }

  Future<void> _calcular() async {
    if (_tecnica == null) {
      setState(() => _erro = 'Selecione uma técnica');
      return;
    }
    if (_quantidade <= 0) {
      setState(() => _erro = 'Quantidade deve ser maior que 0');
      return;
    }
    setState(() {
      _calculando = true;
      _erro = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final resultado = await api.calcularOrcamento({
        'tecnica': _tecnica,
        'regiao': _regiao,
        'quantidade': _quantidade,
        'cores': _cores,
        'urgente': _urgente,
        'tipo_peca': _tipoPeca,
      });
      setState(() => _resultado = resultado);
    } catch (e) {
      setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _calculando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final tecnicas = ref.watch(tecnicasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Calculadora de orçamento')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          // Técnica
          SectionHeader(icon: Icons.brush_outlined, title: 'Técnica'),
          const SizedBox(height: 8),
          tecnicas.when(
            loading: () => const SizedBox(
              height: 48,
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
            error: (e, _) => Text('Erro ao carregar técnicas', style: TextStyle(color: theme.colorScheme.error)),
            data: (lista) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in lista)
                  ChoiceChip(
                    label: Text(t),
                    selected: _tecnica == t,
                    onSelected: (_) => setState(() => _tecnica = t),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Região
          SectionHeader(icon: Icons.place_outlined, title: 'Região'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Frente/Costas'),
                selected: _regiao == 'FRENTE/COSTAS',
                onSelected: (_) => setState(() => _regiao = 'FRENTE/COSTAS'),
              ),
              ChoiceChip(
                label: const Text('Bottom/Nuca'),
                selected: _regiao == 'BOTTOM/NUCA',
                onSelected: (_) => setState(() => _regiao = 'BOTTOM/NUCA'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Quantidade
          SectionHeader(icon: Icons.numbers, title: 'Quantidade'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _quantidadeCtl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              hintText: '25',
              prefixIcon: Icon(Icons.numbers),
            ),
          ),
          const SizedBox(height: 20),

          // Nº de cores
          SectionHeader(icon: Icons.palette_outlined, title: 'Número de cores'),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: _cores <= 1
                    ? null
                    : () {
                        _cores--;
                        _coresCtl.text = _cores.toString();
                      },
                icon: const Icon(Icons.remove),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 72,
                child: TextFormField(
                  controller: _coresCtl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(isDense: true),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                onPressed: () {
                  _cores++;
                  _coresCtl.text = _cores.toString();
                },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Urgente
          SwitchListTile(
            value: _urgente,
            onChanged: (v) => setState(() => _urgente = v),
            title: const Text('Urgente'),
            subtitle: const Text('Aplica taxa adicional configurável'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(height: 12),

          // Tipo de peça
          DropdownButtonFormField<String?>(
            initialValue: _tipoPeca,
            decoration: const InputDecoration(
              labelText: 'Tipo de peça',
              prefixIcon: Icon(Icons.checkroom),
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('Peça normal')),
              DropdownMenuItem(value: 'moletom_aberto', child: Text('Moletom aberto (+20%)')),
              DropdownMenuItem(value: 'moletom_fechado', child: Text('Moletom fechado (+60%)')),
            ],
            onChanged: (v) => setState(() => _tipoPeca = v),
          ),
          const SizedBox(height: 24),

          // Erro
          if (_erro != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_erro!, style: TextStyle(color: theme.colorScheme.error)),
            ),

          // Botão calcular
          FilledButton.icon(
            onPressed: _calculando ? null : _calcular,
            icon: _calculando
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.calculate_outlined),
            label: const Text('Calcular'),
          ),
          const SizedBox(height: 20),

          // Resultado
          if (_resultado != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(icon: Icons.receipt_long_outlined, title: 'Resultado'),
                    const SizedBox(height: 16),
                    _ResultadoLinha(
                      label: 'Preço por peça',
                      valor: moeda.format(_resultado!.precoPorPeca),
                      bold: true,
                    ),
                    _ResultadoLinha(
                      label: 'Subtotal (${_resultado!.quantidade} peças)',
                      valor: moeda.format(_resultado!.subtotal),
                    ),
                    _ResultadoLinha(
                      label: 'Matriz',
                      valor: _resultado!.matrizCobrada ? moeda.format(_resultado!.valorMatriz) : 'Grátis',
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Text(
                          'TOTAL',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          moeda.format(_resultado!.total),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => setState(() => _resultado = null),
                          child: const Text('Novo cálculo'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: () => context.pop(_resultado!.total),
                          icon: const Icon(Icons.check),
                          label: const Text('Usar este valor'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultadoLinha extends StatelessWidget {
  final String label;
  final String valor;
  final bool bold;
  const _ResultadoLinha({required this.label, required this.valor, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: bold ? FontWeight.w600 : null,
            ),
          ),
          const Spacer(),
          Text(
            valor,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}