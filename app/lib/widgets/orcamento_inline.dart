import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../models/orcamento.dart';
import '../state/orcamento_provider.dart';
import '../theme/status_colors.dart';

/// Resultado aplicado pelo usuário ao clicar em "Usar este valor".
/// Inclui todos os campos que o formulário de pedido deve sincronizar.
class OrcamentoInlineAplicado {
  final String tecnica;
  final int quantidade;
  final int cores;
  final bool urgente;
  final double total;
  const OrcamentoInlineAplicado({
    required this.tecnica,
    required this.quantidade,
    required this.cores,
    required this.urgente,
    required this.total,
  });
}

/// Calculadora de orçamento compacta — embutida no formulário de pedido.
///
/// Reúsa a mesma API (`calcularOrcamento`) da tela standalone, mas mantém
/// tudo numa única linha de fluxo: o usuário preenche aqui e clica em
/// "Usar este valor" pra sincronizar técnica, quantidade, cores, urgente e
/// valor no formulário sem digitar nada de novo.
class OrcamentoInline extends ConsumerStatefulWidget {
  final String? tecnicaInicial;
  final int quantidadeInicial;
  final int coresInicial;
  final bool urgenteInicial;
  final ValueChanged<OrcamentoInlineAplicado> onAplicar;

  const OrcamentoInline({
    super.key,
    this.tecnicaInicial,
    this.quantidadeInicial = 25,
    this.coresInicial = 1,
    this.urgenteInicial = false,
    required this.onAplicar,
  });

  @override
  ConsumerState<OrcamentoInline> createState() => _OrcamentoInlineState();
}

class _OrcamentoInlineState extends ConsumerState<OrcamentoInline> {
  late String? _tecnica = widget.tecnicaInicial;
  String _regiao = 'FRENTE/COSTAS';
  String? _tipoPeca;
  late int _quantidade = widget.quantidadeInicial;
  late int _cores = widget.coresInicial;
  late bool _urgente = widget.urgenteInicial;

  OrcamentoResultado? _resultado;
  bool _calculando = false;
  String? _erro;

  late final _quantidadeCtl = TextEditingController(text: _quantidade.toString());
  late final _coresCtl = TextEditingController(text: _cores.toString());

  @override
  void initState() {
    super.initState();
    _quantidadeCtl.addListener(() {
      final v = int.tryParse(_quantidadeCtl.text);
      if (v != null && v > 0 && v != _quantidade) {
        setState(() => _quantidade = v);
      }
    });
    _coresCtl.addListener(() {
      final v = int.tryParse(_coresCtl.text);
      if (v != null && v > 0 && v != _cores) {
        setState(() => _cores = v);
      }
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
    setState(() {
      _calculando = true;
      _erro = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final r = await api.calcularOrcamento({
        'tecnica': _tecnica,
        'regiao': _regiao,
        'quantidade': _quantidade,
        'cores': _cores,
        'urgente': _urgente,
        'tipo_peca': _tipoPeca,
      });
      setState(() => _resultado = r);
    } catch (e) {
      setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _calculando = false);
    }
  }

  void _aplicar() {
    final r = _resultado;
    if (r == null || _tecnica == null) return;
    widget.onAplicar(OrcamentoInlineAplicado(
      tecnica: _tecnica!,
      quantidade: r.quantidade,
      cores: _cores,
      urgente: _urgente,
      total: r.total,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final tecnicas = ref.watch(tecnicasProvider);
    final palette = statusColors(context, StatusTone.info);

    return Container(
      decoration: BoxDecoration(
        color: palette.bg.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.fg.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate_outlined, size: 18, color: palette.fg),
              const SizedBox(width: 8),
              Text(
                'Calcular preço',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: palette.fg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Técnica (chips)
          tecnicas.when(
            loading: () => const SizedBox(
              height: 36,
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
            error: (e, _) => Text('Erro ao carregar técnicas', style: TextStyle(color: theme.colorScheme.error)),
            data: (lista) => Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in lista)
                  ChoiceChip(
                    label: Text(t),
                    selected: _tecnica == t,
                    onSelected: (_) => setState(() => _tecnica = t),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Região
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'FRENTE/COSTAS', label: Text('Frente/Costas')),
              ButtonSegment(value: 'BOTTOM/NUCA', label: Text('Bottom/Nuca')),
            ],
            selected: {_regiao},
            onSelectionChanged: (s) => setState(() => _regiao = s.first),
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
          ),
          const SizedBox(height: 10),

          // Tipo de peça (compacto)
          DropdownButtonFormField<String?>(
            initialValue: _tipoPeca,
            isDense: true,
            decoration: const InputDecoration(
              labelText: 'Tipo de peça',
              prefixIcon: Icon(Icons.checkroom_outlined, size: 18),
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('Peça normal')),
              DropdownMenuItem(value: 'moletom_aberto', child: Text('Moletom aberto (+20%)')),
              DropdownMenuItem(value: 'moletom_fechado', child: Text('Moletom fechado (+60%)')),
            ],
            onChanged: (v) => setState(() => _tipoPeca = v),
          ),
          const SizedBox(height: 10),

          // Quantidade + Cores (lado a lado)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _quantidadeCtl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Qtd',
                    prefixIcon: Icon(Icons.numbers, size: 18),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.filledTonal(
                      onPressed: _cores <= 1 ? null : () {
                        setState(() => _cores--);
                        _coresCtl.text = _cores.toString();
                      },
                      icon: const Icon(Icons.remove, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _coresCtl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          labelText: 'Cores',
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () {
                        setState(() => _cores++);
                        _coresCtl.text = _cores.toString();
                      },
                      icon: const Icon(Icons.add, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            value: _urgente,
            onChanged: (v) => setState(() => _urgente = v),
            title: const Text('Urgente', style: TextStyle(fontSize: 14)),
            subtitle: const Text('Aplica taxa adicional', style: TextStyle(fontSize: 12)),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _calculando ? null : _calcular,
              icon: _calculando
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.calculate_outlined, size: 18),
              label: const Text('Calcular'),
            ),
          ),

          if (_erro != null) ...[
            const SizedBox(height: 8),
            Text(_erro!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
          ],

          if (_resultado != null) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LinhaResultado(
                    label: 'Preço/peça',
                    valor: moeda.format(_resultado!.precoPorPeca),
                  ),
                  _LinhaResultado(
                    label: 'Subtotal (${_resultado!.quantidade} pç)',
                    valor: moeda.format(_resultado!.subtotal),
                  ),
                  _LinhaResultado(
                    label: 'Matriz',
                    valor: _resultado!.matrizCobrada ? moeda.format(_resultado!.valorMatriz) : 'Grátis',
                  ),
                  const Divider(height: 18),
                  Row(
                    children: [
                      Text(
                        'TOTAL',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        moeda.format(_resultado!.total),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _aplicar,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Usar este valor'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LinhaResultado extends StatelessWidget {
  final String label;
  final String valor;
  const _LinhaResultado({required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const Spacer(),
          Text(
            valor,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
