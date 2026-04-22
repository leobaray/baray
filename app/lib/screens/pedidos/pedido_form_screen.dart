import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../models/cliente.dart';
import '../../models/orcamento.dart';
import '../../models/pedido.dart';
import '../../state/clientes_provider.dart';
import '../../state/dashboard_provider.dart';
import '../../state/configuracoes_provider.dart';
import '../../state/orcamento_provider.dart';
import '../../state/pedidos_provider.dart';

// Breakpoint pra layout 2 colunas no form (cabe num monitor de oficina apertado).
const double _kWide = 1080;

class PedidoFormScreen extends ConsumerStatefulWidget {
  final String? pedidoId;

  /// Valores iniciais pra pedidos novos, vindos da query string (/pedidos/novo).
  /// Chaves suportadas: cliente_id, data_producao, auto_agendar, peca, tecnica,
  /// regiao, tipo_peca, quantidade, valor, arte_cores, urgente.
  final Map<String, String>? initial;

  const PedidoFormScreen({
    super.key,
    this.pedidoId,
    this.initial,
  });

  @override
  ConsumerState<PedidoFormScreen> createState() => _PedidoFormScreenState();
}

class _PedidoFormScreenState extends ConsumerState<PedidoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _data = DateFormat('dd/MM/yyyy', 'pt_BR');

  // Controllers
  final _telefoneCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _pecaCtl = TextEditingController();
  final _quantidadeCtl = TextEditingController();
  final _valorCtl = TextEditingController();
  final _corPecaCtl = TextEditingController();
  final _tamanhoPecaCtl = TextEditingController();
  final _tecidoCtl = TextEditingController();
  final _arteCoresCtl = TextEditingController();
  final _arteTamanhoCtl = TextEditingController();
  final _artePosicaoCtl = TextEditingController();
  final _arteObservacaoCtl = TextEditingController();
  final _enderecoCtl = TextEditingController();
  final _entreguePorCtl = TextEditingController();
  final _observacaoCtl = TextEditingController();

  // Non-text state
  String? _clienteId;
  DateTime? _dataChegada = DateTime.now();
  DateTime? _dataProducao;
  DateTime? _dataEntregaCombinada;
  String? _tecnica;
  String _regiao = 'FRENTE/COSTAS';
  String? _tipoPeca;
  String _status = 'pendente';
  String _statusPagamento = 'devendo';
  bool _urgente = false;
  String _formaEntrega = 'retirada';
  String? _formaPagamento;
  bool _autoAgendar = true;

  // Orçamento auto-calculado
  OrcamentoResultado? _orcamentoResultado;
  bool _calculandoOrcamento = false;
  String? _erroOrcamento;

  // Control state
  bool _carregando = false;
  bool _salvando = false;
  bool _confirmandoSaida = false;
  String? _erro;
  Pedido? _original;
  late final TextEditingController _autoClienteCtl;
  late final FocusNode _autoClienteFocus;
  bool _selecionandoCliente = false;
  Timer? _calcDebounce;
  bool _dirty = false;

  void _markDirty() {
    if (_selecionandoCliente) return;
    if (!_dirty) _dirty = true;
  }

  bool get _isEdicao => widget.pedidoId != null;

  @override
  void initState() {
    super.initState();
    _autoClienteCtl = TextEditingController();
    _autoClienteFocus = FocusNode();
    _autoClienteCtl.addListener(() {
      if (!_selecionandoCliente && _clienteId != null) {
        setState(() => _clienteId = null);
      }
    });
    _quantidadeCtl.addListener(_agendarRecalculo);
    _arteCoresCtl.addListener(_agendarRecalculo);
    for (final c in [
      _telefoneCtl, _emailCtl, _pecaCtl, _quantidadeCtl, _valorCtl,
      _corPecaCtl, _tamanhoPecaCtl, _tecidoCtl, _arteCoresCtl,
      _arteTamanhoCtl, _artePosicaoCtl, _arteObservacaoCtl,
      _enderecoCtl, _entreguePorCtl, _observacaoCtl, _autoClienteCtl,
    ]) {
      c.addListener(_markDirty);
    }
    if (widget.pedidoId != null) {
      _carregar();
    } else {
      final initial = widget.initial;
      if (initial != null) {
        _selecionandoCliente = true;
        if (initial['cliente_id'] != null) _carregarClienteInicial(initial['cliente_id']!);
        _aplicarValoresIniciais(initial);
        _selecionandoCliente = false;
      }
      _agendarRecalculo();
      _dirty = false;
    }
  }

  void _aplicarValoresIniciais(Map<String, String> initial) {
    if (initial['peca'] != null) _pecaCtl.text = initial['peca']!;
    if (initial['tecnica'] != null) _tecnica = initial['tecnica']!;
    if (initial['regiao'] != null) _regiao = initial['regiao']!;
    if (initial['tipo_peca'] != null) _tipoPeca = initial['tipo_peca']!;
    if (initial['quantidade'] != null) _quantidadeCtl.text = initial['quantidade']!;
    if (initial['valor'] != null) {
      final v = double.tryParse(initial['valor']!);
      _valorCtl.text = v != null
          ? v.toStringAsFixed(2).replaceAll('.', ',')
          : initial['valor']!;
    }
    if (initial['arte_cores'] != null) _arteCoresCtl.text = initial['arte_cores']!;
    if (initial['urgente'] == 'true') _urgente = true;
    if (initial['auto_agendar'] == 'false') _autoAgendar = false;
    final dataProd = initial['data_producao'];
    if (dataProd != null) {
      final parsed = DateTime.tryParse(dataProd);
      if (parsed != null) {
        _dataProducao = parsed;
        _autoAgendar = false;
      }
    }
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final api = ref.read(apiClientProvider);
      final p = await api.buscarPedido(widget.pedidoId!);
      _original = p;
      _selecionandoCliente = true;
      _preencherPedido(p);
      _selecionandoCliente = false;
      _agendarRecalculo();
      _dirty = false;
    } catch (e) {
      _erro = e.toString();
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _preencherPedido(Pedido p) {
    _clienteId = p.clienteId;
    _autoClienteCtl.text = p.clienteNome;
    _telefoneCtl.text = p.clienteTelefone ?? '';
    _emailCtl.text = p.clienteEmail ?? '';
    _pecaCtl.text = p.peca ?? '';
    _tecnica = p.tecnica;
    _regiao = p.regiao ?? 'FRENTE/COSTAS';
    _tipoPeca = p.tipoPeca;
    _quantidadeCtl.text = p.quantidade?.toString() ?? '';
    _valorCtl.text = p.valor.toStringAsFixed(2).replaceAll('.', ',');
    _corPecaCtl.text = p.corPeca ?? '';
    _tamanhoPecaCtl.text = p.tamanhoPeca ?? '';
    _tecidoCtl.text = p.tecido ?? '';
    _arteCoresCtl.text = p.arteCores?.toString() ?? '';
    _arteTamanhoCtl.text = p.arteTamanhoCm ?? '';
    _artePosicaoCtl.text = p.artePosicao ?? '';
    _arteObservacaoCtl.text = p.arteObservacao ?? '';
    _enderecoCtl.text = p.enderecoEntrega ?? '';
    _entreguePorCtl.text = p.entreguePor ?? '';
    _observacaoCtl.text = p.observacao ?? '';
    _dataChegada = p.dataChegada;
    _dataProducao = p.dataProducao;
    _dataEntregaCombinada = p.dataEntregaCombinada;
    _status = p.status;
    _statusPagamento = p.statusPagamento;
    _urgente = p.urgente;
    _formaEntrega = p.formaEntrega ?? 'retirada';
    _formaPagamento = p.formaPagamento;
  }

  Future<void> _carregarClienteInicial(String clienteId) async {
    try {
      final api = ref.read(apiClientProvider);
      final c = await api.buscarCliente(clienteId);
      _selecionandoCliente = true;
      _clienteId = c.id;
      _autoClienteCtl.text = c.nome;
      _telefoneCtl.text = c.telefone ?? '';
      _emailCtl.text = c.email ?? '';
      _selecionandoCliente = false;
      _dirty = false;
      if (mounted) setState(() {});
    } catch (_) {
      _selecionandoCliente = false;
    }
  }

  @override
  void dispose() {
    _calcDebounce?.cancel();
    _quantidadeCtl.removeListener(_agendarRecalculo);
    _arteCoresCtl.removeListener(_agendarRecalculo);
    _telefoneCtl.dispose();
    _emailCtl.dispose();
    _pecaCtl.dispose();
    _quantidadeCtl.dispose();
    _valorCtl.dispose();
    _corPecaCtl.dispose();
    _tamanhoPecaCtl.dispose();
    _tecidoCtl.dispose();
    _arteCoresCtl.dispose();
    _arteTamanhoCtl.dispose();
    _artePosicaoCtl.dispose();
    _arteObservacaoCtl.dispose();
    _enderecoCtl.dispose();
    _entreguePorCtl.dispose();
    _observacaoCtl.dispose();
    _autoClienteCtl.dispose();
    _autoClienteFocus.dispose();
    super.dispose();
  }

  double? _parseValor(String txt) {
    final t = txt.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(t);
  }

  Future<void> _pickDate(DateTime? current, ValueChanged<DateTime?> onPick) async {
    final inicial = current ?? DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('pt', 'BR'),
    );
    if (escolhida != null) onPick(escolhida);
  }

  Future<void> _recalcularOrcamento() async {
    if (!mounted) return;
    final qtd = int.tryParse(_quantidadeCtl.text.trim()) ?? 0;
    if (_tecnica == null || qtd <= 0) {
      setState(() {
        _orcamentoResultado = null;
        _erroOrcamento = null;
      });
      return;
    }
    setState(() {
      _calculandoOrcamento = true;
      _erroOrcamento = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final resultado = await api.calcularOrcamento({
        'tecnica': _tecnica,
        'regiao': _regiao,
        'quantidade': qtd,
        'cores': int.tryParse(_arteCoresCtl.text.trim()) ?? 1,
        'urgente': _urgente,
        'tipo_peca': _tipoPeca,
      });
      if (!mounted) return;
      setState(() => _orcamentoResultado = resultado);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _orcamentoResultado = null;
        _erroOrcamento = e.toString();
      });
    } finally {
      if (mounted) setState(() => _calculandoOrcamento = false);
    }
  }

  void _agendarRecalculo() {
    _calcDebounce?.cancel();
    _calcDebounce = Timer(const Duration(milliseconds: 350), _recalcularOrcamento);
  }

  void _aplicarTotalCalculado() {
    final r = _orcamentoResultado;
    if (r == null) return;
    final txt = r.total.toStringAsFixed(2).replaceAll('.', ',');
    _valorCtl.value = TextEditingValue(
      text: txt,
      selection: TextSelection.collapsed(offset: txt.length),
    );
  }

  String _montarDescricao() {
    final partes = <String>[];
    final peca = _pecaCtl.text.trim();
    final qtd = _quantidadeCtl.text.trim();
    final qtdNum = int.tryParse(qtd) ?? 0;
    final tecnica = _tecnica ?? '';
    final cor = _corPecaCtl.text.trim();
    if (qtd.isNotEmpty && peca.isNotEmpty) {
      final pluralizada = (qtdNum > 1 && !peca.toLowerCase().endsWith('s')) ? '${peca}s' : peca;
      partes.add('$qtd $pluralizada');
    } else if (peca.isNotEmpty) {
      partes.add(peca);
    } else if (qtd.isNotEmpty) {
      partes.add('$qtd pçs');
    }
    if (cor.isNotEmpty) partes.add(cor);
    if (tecnica.isNotEmpty) partes.add(tecnica);
    final r = partes.join(' ').trim();
    return r.isEmpty ? 'Pedido' : r;
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      final api = ref.read(apiClientProvider);
      final descricao = _montarDescricao();
      final body = <String, dynamic>{
        'cliente_id': _clienteId,
        'cliente_nome': _autoClienteCtl.text.trim(),
        'cliente_telefone': _telefoneCtl.text.trim().isEmpty ? null : _telefoneCtl.text.trim(),
        'cliente_email': _emailCtl.text.trim().isEmpty ? null : _emailCtl.text.trim(),
        'descricao': descricao,
        'peca': _pecaCtl.text.trim().isEmpty ? null : _pecaCtl.text.trim(),
        'tecnica': _tecnica,
        'regiao': _regiao,
        'tipo_peca': _tipoPeca,
        'quantidade': int.tryParse(_quantidadeCtl.text.trim()),
        'valor': _parseValor(_valorCtl.text),
        'cor_peca': _corPecaCtl.text.trim().isEmpty ? null : _corPecaCtl.text.trim(),
        'tamanho_peca': _tamanhoPecaCtl.text.trim().isEmpty ? null : _tamanhoPecaCtl.text.trim(),
        'tecido': _tecidoCtl.text.trim().isEmpty ? null : _tecidoCtl.text.trim(),
        'arte_cores': int.tryParse(_arteCoresCtl.text.trim()),
        'arte_tamanho_cm': _arteTamanhoCtl.text.trim().isEmpty ? null : _arteTamanhoCtl.text.trim(),
        'arte_posicao': _artePosicaoCtl.text.trim().isEmpty ? null : _artePosicaoCtl.text.trim(),
        'arte_observacao': _arteObservacaoCtl.text.trim().isEmpty ? null : _arteObservacaoCtl.text.trim(),
        'data_chegada': _dataChegada?.toIso8601String().split('T').first,
        'data_producao': _dataProducao?.toIso8601String().split('T').first,
        'forma_entrega': _formaEntrega,
        'endereco_entrega': _enderecoCtl.text.trim().isEmpty ? null : _enderecoCtl.text.trim(),
        'data_entrega_combinada': _dataEntregaCombinada?.toIso8601String().split('T').first,
        'forma_pagamento': _formaPagamento,
        'status_pagamento': _statusPagamento,
        'status': _status,
        'urgente': _urgente,
        'observacao': _observacaoCtl.text.trim().isEmpty ? null : _observacaoCtl.text.trim(),
      };
      if (!_isEdicao) body['auto_agendar'] = _autoAgendar;

      if (_isEdicao) {
        await api.atualizarPedido(widget.pedidoId!, body);
        ref.invalidate(pedidoProvider(widget.pedidoId!));
      } else {
        await api.criarPedido(body);
      }
      ref.invalidate(pedidosProvider);
      ref.invalidate(dashboardProvider);
      _dirty = false;
      if (mounted) context.pop();
    } catch (e) {
      final errorMsg = e.toString();
      final mensagem = errorMsg.contains('cliente_nome')
          ? 'Informe o nome do cliente'
          : errorMsg.contains('descricao')
              ? 'Informe a descrição do pedido'
              : errorMsg.contains('valor')
                  ? 'Informe o valor do pedido'
                  : 'Erro ao salvar: ${e.toString()}';
      setState(() => _erro = mensagem);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _excluir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Excluir pedido?'),
        content: Text('${_original?.loteFormatado ?? ''} ${_original?.clienteNome ?? ''}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(dialogCtx).colorScheme.errorContainer),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).deletarPedido(widget.pedidoId!);
      ref.invalidate(pedidosProvider);
      ref.invalidate(dashboardProvider);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _erro = e.toString());
    }
  }

  Future<void> _confirmarSaida() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Confirmar saída?'),
        content: Text('Confirmar saída do pedido ${_original?.loteFormatado ?? ""}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _confirmandoSaida = true);
    try {
      final entreguePor = _entreguePorCtl.text.trim().isEmpty ? null : _entreguePorCtl.text.trim();
      await ref.read(apiClientProvider).confirmarSaida(widget.pedidoId!, entreguePor: entreguePor);
      ref.invalidate(pedidosProvider);
      ref.invalidate(pedidoProvider(widget.pedidoId!));
      ref.invalidate(dashboardProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saída confirmada ✓')));
        context.pop();
      }
    } catch (e) {
      setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _confirmandoSaida = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return Scaffold(
        appBar: AppBar(title: Text(_isEdicao ? 'Editar pedido' : 'Novo pedido')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final clientes = ref.watch(clientesProvider).value ?? const <Cliente>[];
    final podeConfirmarSaida = _isEdicao && _original != null && !_original!.entregue;

    return PopScope(
      canPop: !_dirty || _salvando,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final sair = await _confirmarDescartar();
        if (sair && mounted) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Flexible(
                child: Text(
                  _isEdicao ? 'Editar pedido' : 'Novo pedido',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_original != null) ...[
                const SizedBox(width: 10),
                _LoteBadge(lote: _original!.loteFormatado),
              ],
            ],
          ),
          actions: [
            if (podeConfirmarSaida)
              IconButton(
                icon: const Icon(Icons.local_shipping_outlined),
                tooltip: 'Confirmar saída',
                onPressed: _confirmandoSaida ? null : _confirmarSaida,
              ),
            if (_isEdicao)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Excluir',
                onPressed: _salvando ? null : _excluir,
              ),
          ],
        ),
        bottomNavigationBar: _Footer(
          valorCtl: _valorCtl,
          salvando: _salvando,
          isEdicao: _isEdicao,
          onSalvar: _salvar,
          parseValor: _parseValor,
        ),
        body: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= _kWide;
              return wide ? _buildWide(clientes) : _buildNarrow(clientes);
            },
          ),
        ),
      ),
    );
  }

  // ── Layout wide (2 colunas) ─────────────────────────────────────────────
  Widget _buildWide(List<Cliente> clientes) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Coluna principal (formulário)
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _cardCliente(clientes),
                const SizedBox(height: 10),
                _cardPeca(),
                const SizedBox(height: 10),
                _cardImpressao(),
                const SizedBox(height: 10),
                _cardExtras(),
                if (_isEdicao && _original != null) ...[
                  const SizedBox(height: 10),
                  _cardSaida(),
                ],
                if (_erro != null) ...[
                  const SizedBox(height: 10),
                  _ErroBanner(mensagem: _erro!),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        // Coluna lateral (orçamento + agendamento sticky)
        SizedBox(
          width: 360,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _OrcamentoBox(
                    resultado: _orcamentoResultado,
                    calculando: _calculandoOrcamento,
                    erro: _erroOrcamento,
                    valorCtl: _valorCtl,
                    onAplicar: _aplicarTotalCalculado,
                    parseValor: _parseValor,
                  ),
                  const SizedBox(height: 10),
                  _cardAgendamento(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Layout narrow (coluna única) ────────────────────────────────────────
  Widget _buildNarrow(List<Cliente> clientes) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      children: [
        _cardCliente(clientes),
        const SizedBox(height: 10),
        _cardPeca(),
        const SizedBox(height: 10),
        _cardImpressao(),
        const SizedBox(height: 10),
        _OrcamentoBox(
          resultado: _orcamentoResultado,
          calculando: _calculandoOrcamento,
          erro: _erroOrcamento,
          valorCtl: _valorCtl,
          onAplicar: _aplicarTotalCalculado,
          parseValor: _parseValor,
        ),
        const SizedBox(height: 10),
        _cardAgendamento(),
        const SizedBox(height: 10),
        _cardExtras(),
        if (_isEdicao && _original != null) ...[
          const SizedBox(height: 10),
          _cardSaida(),
        ],
        if (_erro != null) ...[
          const SizedBox(height: 10),
          _ErroBanner(mensagem: _erro!),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  CARDS DAS SEÇÕES
  // ─────────────────────────────────────────────────────────────────────────

  Widget _cardCliente(List<Cliente> clientes) {
    return _Card(
      icon: Icons.person_outline,
      title: 'Cliente',
      child: Column(
        children: [
          _buildClienteAutocomplete(clientes),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, c) {
              final estreito = c.maxWidth < 420;
              if (estreito) {
                return Column(children: [_campoTel(), const SizedBox(height: 8), _campoEmail()]);
              }
              return Row(children: [
                Expanded(child: _campoTel()),
                const SizedBox(width: 8),
                Expanded(child: _campoEmail()),
              ]);
            },
          ),
        ],
      ),
    );
  }

  Widget _cardPeca() {
    return _Card(
      icon: Icons.checkroom_outlined,
      title: 'Peça',
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final estreito = c.maxWidth < 500;
              if (estreito) {
                return Column(
                  children: [
                    _campoPeca(),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: _campoCor()),
                      const SizedBox(width: 8),
                      Expanded(child: _campoTamanho()),
                    ]),
                  ],
                );
              }
              return Row(children: [
                Expanded(flex: 3, child: _campoPeca()),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: _campoCor()),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: _campoTamanho()),
              ]);
            },
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 150,
                child: _NumberStepper(
                  label: 'Quantidade',
                  obrigatorio: true,
                  controller: _quantidadeCtl,
                  min: 1,
                  max: 9999,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MoletomSelector(
                  value: _tipoPeca,
                  onChanged: (v) {
                    setState(() => _tipoPeca = v);
                    _markDirty();
                    _agendarRecalculo();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardImpressao() {
    return _Card(
      icon: Icons.brush_outlined,
      title: 'Impressão',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RegiaoSelector(
            value: _regiao,
            onChanged: (v) {
              setState(() => _regiao = v);
              _markDirty();
              _agendarRecalculo();
            },
          ),
          const SizedBox(height: 10),
          _TecnicaGrid(
            selecionada: _tecnica,
            onChanged: (t) {
              setState(() => _tecnica = t);
              _markDirty();
              _agendarRecalculo();
            },
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 150,
                child: _NumberStepper(
                  label: 'Cores da arte',
                  controller: _arteCoresCtl,
                  min: 1,
                  max: 10,
                  placeholder: '1',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _UrgenteToggle(
                  value: _urgente,
                  onChanged: (v) {
                    setState(() => _urgente = v);
                    _markDirty();
                    _agendarRecalculo();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardAgendamento() {
    return _Card(
      icon: Icons.calendar_month_outlined,
      title: 'Agendamento',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Chegada',
                  data: _dataChegada,
                  onPick: () => _pickDate(_dataChegada, (d) {
                    setState(() => _dataChegada = d);
                    _markDirty();
                  }),
                  onClear: () => setState(() {
                    _dataChegada = null;
                    _markDirty();
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DateField(
                  label: 'Produção',
                  data: _dataProducao,
                  enabled: _isEdicao || !_autoAgendar,
                  placeholderDesabilitado: 'Auto',
                  onPick: () => _pickDate(_dataProducao, (d) {
                    setState(() {
                      _dataProducao = d;
                      _markDirty();
                    });
                  }),
                  onClear: () => setState(() {
                    _dataProducao = null;
                    _markDirty();
                  }),
                ),
              ),
            ],
          ),
          if (!_isEdicao) ...[
            const SizedBox(height: 8),
            _AutoAgendarTile(
              ativo: _autoAgendar,
              onChanged: (v) {
                setState(() {
                  _autoAgendar = v;
                  if (v) _dataProducao = null;
                });
                _markDirty();
              },
            ),
          ],
          if (_isEdicao) ...[
            const SizedBox(height: 8),
            _statusDropdown(),
          ],
        ],
      ),
    );
  }

  /// Arte + Entrega + Pagamento + Observação em TabBar inline — 1 card só.
  Widget _cardExtras() {
    return _Card(
      icon: Icons.tune,
      title: 'Detalhes adicionais',
      padTop: 4,
      child: DefaultTabController(
        length: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              tabs: [
                _buildTab(Icons.local_shipping_outlined, 'Entrega', _formaEntrega == 'entrega' || _dataEntregaCombinada != null),
                _buildTab(Icons.payments_outlined, 'Pagamento', _formaPagamento != null || _statusPagamento != 'devendo'),
                _buildTab(Icons.palette_outlined, 'Arte', _artePreenchida()),
                _buildTab(Icons.note_outlined, 'Notas', _observacaoCtl.text.isNotEmpty),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 180,
              child: TabBarView(
                children: [
                  _tabEntrega(),
                  _tabPagamento(),
                  _tabArte(),
                  _tabNotas(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(IconData icon, String label, bool preenchido) {
    return Tab(
      height: 34,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(label),
          if (preenchido) ...[
            const SizedBox(width: 4),
            Container(width: 5, height: 5, decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            )),
          ],
        ],
      ),
    );
  }

  Widget _tabEntrega() {
    return Column(
      children: [
        _EntregaSelector(
          value: _formaEntrega,
          onChanged: (v) {
            setState(() => _formaEntrega = v);
            _markDirty();
          },
        ),
        const SizedBox(height: 8),
        if (_formaEntrega == 'entrega') ...[
          _campoEndereco(),
          const SizedBox(height: 8),
        ],
        _DateField(
          label: 'Data combinada',
          data: _dataEntregaCombinada,
          onPick: () => _pickDate(_dataEntregaCombinada, (d) {
            setState(() => _dataEntregaCombinada = d);
            _markDirty();
          }),
          onClear: () => setState(() {
            _dataEntregaCombinada = null;
            _markDirty();
          }),
        ),
      ],
    );
  }

  Widget _tabPagamento() {
    return Column(
      children: [
        _PagamentoStatusSelector(
          value: _statusPagamento,
          onChanged: (v) {
            setState(() => _statusPagamento = v);
            _markDirty();
          },
        ),
        const SizedBox(height: 8),
        _campoFormaPagamento(),
      ],
    );
  }

  Widget _tabArte() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _campoTecido()),
              const SizedBox(width: 8),
              Expanded(child: _campoArteTamanho()),
              const SizedBox(width: 8),
              Expanded(child: _campoArtePosicao()),
            ],
          ),
          const SizedBox(height: 8),
          _campoArteObs(),
        ],
      ),
    );
  }

  Widget _tabNotas() {
    return _campoObs();
  }

  Widget _cardSaida() {
    final cs = Theme.of(context).colorScheme;
    if (_original!.entregue) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 18, color: cs.onPrimaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _original!.entregueEm != null
                    ? 'Entregue em ${_data.format(_original!.entregueEm!)} por ${_original!.entreguePor ?? '—'}'
                    : 'Entregue por ${_original!.entreguePor ?? '—'}',
                style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return _Card(
      icon: Icons.local_shipping_outlined,
      title: 'Saída',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _entreguePorCtl,
            decoration: const InputDecoration(
              labelText: 'Entregue por',
              hintText: 'Nome de quem retira',
              prefixIcon: Icon(Icons.person_outlined, size: 18),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _confirmandoSaida ? null : _confirmarSaida,
            icon: _confirmandoSaida
                ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.local_shipping_outlined, size: 18),
            label: Text(_confirmandoSaida ? 'Confirmando...' : 'Confirmar saída'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmarDescartar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Descartar alterações?'),
        content: const Text('Você fez mudanças que não foram salvas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Continuar editando'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(dialogCtx).colorScheme.errorContainer),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  CAMPOS REUTILIZADOS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildClienteAutocomplete(List<Cliente> clientes) {
    final cs = Theme.of(context).colorScheme;
    return RawAutocomplete<Cliente>(
      textEditingController: _autoClienteCtl,
      focusNode: _autoClienteFocus,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.toLowerCase();
        if (query.isEmpty) return const Iterable<Cliente>.empty();
        return clientes.where((c) => c.nome.toLowerCase().contains(query));
      },
      displayStringForOption: (c) => c.nome,
      onSelected: (c) {
        _selecionandoCliente = true;
        setState(() {
          _clienteId = c.id;
          _autoClienteCtl.text = c.nome;
          _telefoneCtl.text = c.telefone ?? '';
          _emailCtl.text = c.email ?? '';
        });
        _selecionandoCliente = false;
        if (!_dirty) _dirty = true;
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
          decoration: InputDecoration(
            labelText: 'Nome do cliente *',
            hintText: 'Digite para buscar ou criar...',
            prefixIcon: const Icon(Icons.person_outline, size: 18),
            isDense: true,
            suffixIcon: _clienteId != null
                ? Tooltip(
                    message: 'Cliente vinculado',
                    child: Icon(Icons.link, color: cs.primary, size: 18),
                  )
                : null,
          ),
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return _AutocompleteOptions(
          options: options,
          onSelected: onSelected,
          onCriarNovo: _autoClienteCtl.text.trim().isNotEmpty
              ? () {
                  _autoClienteFocus.unfocus();
                  context.push('/clientes/novo').then((_) {
                    ref.invalidate(clientesProvider);
                  });
                }
              : null,
        );
      },
    );
  }

  Widget _campoTel() => TextFormField(
        controller: _telefoneCtl,
        decoration: const InputDecoration(
          labelText: 'Telefone',
          prefixIcon: Icon(Icons.call_outlined, size: 18),
          isDense: true,
        ),
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.next,
      );

  Widget _campoEmail() => TextFormField(
        controller: _emailCtl,
        decoration: const InputDecoration(
          labelText: 'Email',
          prefixIcon: Icon(Icons.mail_outline, size: 18),
          isDense: true,
        ),
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        validator: (v) {
          final t = v?.trim() ?? '';
          if (t.isEmpty) return null;
          if (!t.contains('@') || !t.contains('.')) return 'Email inválido';
          return null;
        },
      );

  Widget _campoPeca() => TextFormField(
        controller: _pecaCtl,
        decoration: const InputDecoration(
          labelText: 'Peça',
          hintText: 'camiseta, moletom...',
          isDense: true,
        ),
        textInputAction: TextInputAction.next,
      );

  Widget _campoCor() => TextFormField(
        controller: _corPecaCtl,
        decoration: const InputDecoration(labelText: 'Cor da peça', isDense: true),
        textInputAction: TextInputAction.next,
      );

  Widget _campoTamanho() => TextFormField(
        controller: _tamanhoPecaCtl,
        decoration: const InputDecoration(
          labelText: 'Tamanho',
          hintText: 'M, G, GG...',
          isDense: true,
        ),
        textInputAction: TextInputAction.next,
      );

  Widget _campoTecido() => TextFormField(
        controller: _tecidoCtl,
        decoration: const InputDecoration(labelText: 'Tecido', isDense: true),
        textInputAction: TextInputAction.next,
      );

  Widget _campoArteTamanho() => TextFormField(
        controller: _arteTamanhoCtl,
        decoration: const InputDecoration(
          labelText: 'Arte (cm)',
          hintText: '25x15',
          isDense: true,
        ),
        textInputAction: TextInputAction.next,
      );

  Widget _campoArtePosicao() => TextFormField(
        controller: _artePosicaoCtl,
        decoration: const InputDecoration(
          labelText: 'Posição',
          hintText: 'Frente...',
          isDense: true,
        ),
        textInputAction: TextInputAction.next,
      );

  Widget _campoArteObs() => TextFormField(
        controller: _arteObservacaoCtl,
        decoration: const InputDecoration(
          labelText: 'Observação da arte',
          isDense: true,
          alignLabelWithHint: true,
        ),
        maxLines: 2,
      );

  Widget _campoObs() => TextFormField(
        controller: _observacaoCtl,
        decoration: const InputDecoration(
          labelText: 'Notas internas sobre o pedido',
          isDense: true,
          alignLabelWithHint: true,
        ),
        maxLines: 5,
      );

  Widget _campoEndereco() => TextFormField(
        controller: _enderecoCtl,
        decoration: const InputDecoration(
          labelText: 'Endereço de entrega',
          prefixIcon: Icon(Icons.home_outlined, size: 18),
          isDense: true,
          alignLabelWithHint: true,
        ),
        maxLines: 2,
      );

  Widget _statusDropdown() => DropdownButtonFormField<String>(
        initialValue: _status,
        isDense: true,
        decoration: const InputDecoration(
          labelText: 'Status do pedido',
          prefixIcon: Icon(Icons.flag_outlined, size: 18),
          isDense: true,
        ),
        items: const [
          DropdownMenuItem(value: 'pendente', child: Text('Pendente')),
          DropdownMenuItem(value: 'agendado', child: Text('Agendado')),
          DropdownMenuItem(value: 'producao', child: Text('Em produção')),
          DropdownMenuItem(value: 'concluido', child: Text('Concluído')),
          DropdownMenuItem(value: 'entregue', child: Text('Entregue')),
        ],
        onChanged: (v) {
          setState(() => _status = v ?? 'pendente');
          _markDirty();
        },
      );

  Widget _campoFormaPagamento() => DropdownButtonFormField<String?>(
        initialValue: _formaPagamento,
        isDense: true,
        decoration: const InputDecoration(
          labelText: 'Forma de pagamento',
          prefixIcon: Icon(Icons.payment_outlined, size: 18),
          isDense: true,
        ),
        items: const [
          DropdownMenuItem<String?>(value: null, child: Text('— a definir —')),
          DropdownMenuItem(value: 'dinheiro', child: Text('Dinheiro')),
          DropdownMenuItem(value: 'pix', child: Text('Pix')),
          DropdownMenuItem(value: 'cartao_credito', child: Text('Crédito')),
          DropdownMenuItem(value: 'cartao_debito', child: Text('Débito')),
          DropdownMenuItem(value: 'boleto', child: Text('Boleto')),
          DropdownMenuItem(value: 'transferencia', child: Text('Transferência')),
        ],
        onChanged: (v) {
          setState(() => _formaPagamento = v);
          _markDirty();
        },
      );

  bool _artePreenchida() {
    return _tecidoCtl.text.isNotEmpty ||
        _arteTamanhoCtl.text.isNotEmpty ||
        _artePosicaoCtl.text.isNotEmpty ||
        _arteObservacaoCtl.text.isNotEmpty;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

/// Card leve com cabeçalho discreto e conteúdo denso.
/// Fundo = surfaceContainerLowest + 1px de borda. Sem "frame duplo".
class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final double padTop;

  const _Card({
    required this.icon,
    required this.title,
    required this.child,
    this.padTop = 12,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      padding: EdgeInsets.fromLTRB(14, padTop, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Stepper visual `[-] valor [+]` com label em cima — compacto.
class _NumberStepper extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int min;
  final int max;
  final bool obrigatorio;
  final String? placeholder;
  const _NumberStepper({
    required this.label,
    required this.controller,
    this.min = 0,
    this.max = 9999,
    this.obrigatorio = false,
    this.placeholder,
  });

  void _bump(int delta) {
    final txtAtual = controller.text.trim();
    final atual = int.tryParse(txtAtual);
    final int novo;
    if (atual == null) {
      novo = delta > 0 ? (min == 0 ? 1 : min) : min;
    } else {
      novo = (atual + delta).clamp(min, max);
    }
    final txt = novo.toString();
    if (txt == txtAtual) return;
    controller.value = TextEditingValue(
      text: txt,
      selection: TextSelection.collapsed(offset: txt.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          obrigatorio ? '$label *' : label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          height: 36,
          child: Row(
            children: [
              _StepBtn(icon: Icons.remove, onTap: () => _bump(-1), side: _StepSide.left),
              Container(width: 1, height: 22, color: cs.outlineVariant.withValues(alpha: 0.5)),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    hintText: placeholder,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  validator: obrigatorio
                      ? (v) {
                          if (v == null || v.trim().isEmpty) return 'Obrigatório';
                          final n = int.tryParse(v.trim());
                          if (n == null) return 'Inválido';
                          if (n < min) return '≥ $min';
                          return null;
                        }
                      : null,
                ),
              ),
              Container(width: 1, height: 22, color: cs.outlineVariant.withValues(alpha: 0.5)),
              _StepBtn(icon: Icons.add, onTap: () => _bump(1), side: _StepSide.right),
            ],
          ),
        ),
      ],
    );
  }
}

enum _StepSide { left, right }

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final _StepSide side;
  const _StepBtn({required this.icon, required this.onTap, required this.side});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = side == _StepSide.left
        ? const BorderRadius.horizontal(left: Radius.circular(7))
        : const BorderRadius.horizontal(right: Radius.circular(7));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: SizedBox(
          width: 34,
          height: 36,
          child: Icon(icon, size: 16, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// Seletor Normal / Moletom aberto / Moletom fechado — compacto.
/// Percentuais lidos das configs (`adicional_moletom_aberto_pct`,
/// `adicional_moletom_fechado_pct`) com fallback para 20/60.
class _MoletomSelector extends ConsumerWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const _MoletomSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final configs = ref.watch(configuracoesProvider).maybeWhen(
          data: (d) => d,
          orElse: () => const [],
        );
    int pct(String chave, int padrao) {
      final c = configs.where((x) => x.chave == chave);
      if (c.isEmpty) return padrao;
      return c.first.asNumber.toInt();
    }
    final pctAberto = pct('adicional_moletom_aberto_pct', 20);
    final pctFechado = pct('adicional_moletom_fechado_pct', 60);
    final opcoes = <(String?, String, String?)>[
      (null, 'Normal', null),
      ('moletom_aberto', 'Aberto', '+$pctAberto%'),
      ('moletom_fechado', 'Fechado', '+$pctFechado%'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Tipo de peça',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          height: 36,
          padding: const EdgeInsets.all(3),
          child: Row(
            children: List.generate(opcoes.length, (i) {
              final o = opcoes[i];
              final selecionado = value == o.$1;
              return Expanded(
                child: InkWell(
                  onTap: () => onChanged(o.$1),
                  borderRadius: BorderRadius.circular(6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: selecionado ? cs.primaryContainer : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          o.$2,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selecionado ? FontWeight.w800 : FontWeight.w600,
                            color: selecionado ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                          ),
                        ),
                        if (o.$3 != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            o.$3!,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: selecionado
                                  ? cs.onPrimaryContainer.withValues(alpha: 0.8)
                                  : cs.onSurfaceVariant.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

/// Seletor visual de região em botões lado a lado — compacto.
class _RegiaoSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _RegiaoSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final opcoes = <(String, String, String)>[
      ('FRENTE/COSTAS', 'Frente / Costas', '13–28 cm'),
      ('BOTTOM/NUCA', 'Bottom / Nuca', 'até 13 cm'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Região da estampa',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: List.generate(opcoes.length, (i) {
            final o = opcoes[i];
            final selecionado = value == o.$1;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: i == 0 ? 0 : 4,
                  right: i == opcoes.length - 1 ? 0 : 4,
                ),
                child: InkWell(
                  onTap: () => onChanged(o.$1),
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: selecionado ? cs.primaryContainer : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selecionado ? cs.primary : cs.outlineVariant,
                        width: selecionado ? 1.3 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                o.$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: selecionado ? FontWeight.w800 : FontWeight.w700,
                                  color: selecionado ? cs.onPrimaryContainer : cs.onSurface,
                                ),
                              ),
                              Text(
                                o.$3,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: selecionado
                                      ? cs.onPrimaryContainer.withValues(alpha: 0.75)
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// Grid compacto de técnicas — 1 linha horizontal scrollável.
class _TecnicaGrid extends ConsumerWidget {
  final String? selecionada;
  final ValueChanged<String> onChanged;
  const _TecnicaGrid({required this.selecionada, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tecnicas = ref.watch(tecnicasProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Técnica de impressão',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        tecnicas.when(
          loading: () => const SizedBox(
            height: 36,
            child: Center(
              child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
          error: (e, _) => Text(
            'Erro ao carregar técnicas',
            style: TextStyle(color: cs.error, fontSize: 12),
          ),
          data: (lista) => Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in lista)
                _TecnicaCard(nome: t, selecionada: selecionada == t, onTap: () => onChanged(t)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TecnicaCard extends StatelessWidget {
  final String nome;
  final bool selecionada;
  final VoidCallback onTap;
  const _TecnicaCard({required this.nome, required this.selecionada, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selecionada ? cs.primaryContainer : Colors.transparent,
          border: Border.all(
            color: selecionada ? cs.primary : cs.outlineVariant,
            width: selecionada ? 1.3 : 1,
          ),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selecionada) ...[
              Icon(Icons.check_circle, size: 12, color: cs.primary),
              const SizedBox(width: 5),
            ],
            Text(
              nome,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selecionada ? FontWeight.w800 : FontWeight.w700,
                letterSpacing: 0.3,
                color: selecionada ? cs.onPrimaryContainer : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Toggle Urgente compacto. Taxa lida de `taxa_urgencia_pct` com fallback 25%.
class _UrgenteToggle extends ConsumerWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _UrgenteToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final configs = ref.watch(configuracoesProvider).maybeWhen(
          data: (d) => d,
          orElse: () => const [],
        );
    final taxa = configs
        .where((c) => c.chave == 'taxa_urgencia_pct')
        .map((c) => c.asNumber.toInt())
        .firstOrNull ?? 25;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Prazo',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            height: 36,
            decoration: BoxDecoration(
              color: value ? cs.errorContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: value ? cs.error : cs.outlineVariant,
                width: value ? 1.3 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  value ? Icons.local_fire_department : Icons.local_fire_department_outlined,
                  size: 18,
                  color: value ? cs.error : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value ? 'URGENTE · +$taxa%' : 'Normal',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: value ? cs.onErrorContainer : cs.onSurface,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Card de orçamento sticky. Denso: título + total grande + info + valor final.
class _OrcamentoBox extends StatelessWidget {
  final OrcamentoResultado? resultado;
  final bool calculando;
  final String? erro;
  final TextEditingController valorCtl;
  final VoidCallback onAplicar;
  final double? Function(String) parseValor;

  const _OrcamentoBox({
    required this.resultado,
    required this.calculando,
    required this.erro,
    required this.valorCtl,
    required this.onAplicar,
    required this.parseValor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final temResultado = resultado != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: temResultado
            ? cs.primaryContainer.withValues(alpha: 0.25)
            : cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: temResultado ? cs.primary.withValues(alpha: 0.4) : cs.outlineVariant.withValues(alpha: 0.6),
          width: temResultado ? 1.3 : 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_outlined, size: 14, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                'ORÇAMENTO',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                  color: cs.primary,
                ),
              ),
              const Spacer(),
              if (calculando)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.6, color: cs.primary),
                )
              else if (resultado != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest,
                    border: Border.all(color: cs.outlineVariant),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Faixa ${resultado!.faixaQtd}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
            ],
          ),

          if (erro != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.warning_amber, size: 16, color: cs.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(erro!, style: TextStyle(fontSize: 12, color: cs.error)),
                ),
              ],
            ),
          ] else if (resultado == null) ...[
            const SizedBox(height: 8),
            Text(
              calculando
                  ? 'Calculando...'
                  : 'Selecione técnica e quantidade — sugestão aparece aqui.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Sugestão da tabela',
              style: TextStyle(
                fontSize: 10.5,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                moeda.format(resultado!.total),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: cs.primary,
                  height: 1.05,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _OrcMini(label: 'por peça', valor: moeda.format(resultado!.precoPorPeca)),
                _OrcMini(
                  label: 'subtotal',
                  valor: '${resultado!.quantidade}× = ${moeda.format(resultado!.subtotal)}',
                ),
                _OrcMini(
                  label: 'matriz',
                  valor: resultado!.matrizCobrada
                      ? moeda.format(resultado!.valorMatriz)
                      : 'grátis',
                  destaque: !resultado!.matrizCobrada,
                ),
              ],
            ),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextFormField(
                  controller: valorCtl,
                  decoration: const InputDecoration(
                    labelText: 'Valor final *',
                    hintText: '0,00',
                    prefixText: 'R\$ ',
                    isDense: true,
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Obrigatório';
                    if (parseValor(v) == null) return 'Inválido';
                    return null;
                  },
                ),
              ),
              if (resultado != null) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Usar sugestão',
                  child: FilledButton.tonal(
                    onPressed: onAplicar,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 40),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Icon(Icons.south, size: 16),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _OrcMini extends StatelessWidget {
  final String label;
  final String valor;
  final bool destaque;
  const _OrcMini({required this.label, required this.valor, this.destaque = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant),
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: destaque ? cs.tertiary : cs.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Seletor Retirada / Entrega.
class _EntregaSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _EntregaSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final opcoes = <(String, String, IconData)>[
      ('retirada', 'Retirada na loja', Icons.store_outlined),
      ('entrega', 'Entrega no endereço', Icons.local_shipping_outlined),
    ];
    return Row(
      children: List.generate(opcoes.length, (i) {
        final o = opcoes[i];
        final selecionado = value == o.$1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: i == 0 ? 0 : 4,
              right: i == opcoes.length - 1 ? 0 : 4,
            ),
            child: InkWell(
              onTap: () => onChanged(o.$1),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: selecionado ? cs.primaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selecionado ? cs.primary : cs.outlineVariant,
                    width: selecionado ? 1.3 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(o.$3, size: 16, color: selecionado ? cs.primary : cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        o.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selecionado ? FontWeight.w800 : FontWeight.w600,
                          color: selecionado ? cs.onPrimaryContainer : cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Seletor Devendo / Parcial / Pago.
class _PagamentoStatusSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _PagamentoStatusSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final opcoes = <(String, String, Color, Color, IconData)>[
      ('devendo', 'Devendo', cs.errorContainer, cs.onErrorContainer, Icons.error_outline),
      ('parcial', 'Parcial', cs.tertiaryContainer, cs.onTertiaryContainer, Icons.pending_outlined),
      ('pago', 'Pago', cs.primaryContainer, cs.onPrimaryContainer, Icons.check_circle_outline),
    ];
    return Row(
      children: List.generate(opcoes.length, (i) {
        final o = opcoes[i];
        final selecionado = value == o.$1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: i == 0 ? 0 : 4,
              right: i == opcoes.length - 1 ? 0 : 4,
            ),
            child: InkWell(
              onTap: () => onChanged(o.$1),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                decoration: BoxDecoration(
                  color: selecionado ? o.$3 : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selecionado ? o.$4.withValues(alpha: 0.45) : cs.outlineVariant,
                    width: selecionado ? 1.3 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(o.$5, size: 15, color: selecionado ? o.$4 : cs.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      o.$2,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selecionado ? FontWeight.w800 : FontWeight.w600,
                        color: selecionado ? o.$4 : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Tile "Agendar automaticamente" compacto.
class _AutoAgendarTile extends StatelessWidget {
  final bool ativo;
  final ValueChanged<bool> onChanged;
  const _AutoAgendarTile({required this.ativo, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => onChanged(!ativo),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        decoration: BoxDecoration(
          color: ativo ? cs.primaryContainer.withValues(alpha: 0.4) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: ativo ? cs.primary.withValues(alpha: 0.5) : cs.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(
              ativo ? Icons.auto_awesome : Icons.auto_awesome_outlined,
              size: 16,
              color: ativo ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ativo ? 'Agendar automaticamente' : 'Data manual de produção',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: ativo ? cs.onPrimaryContainer : cs.onSurface,
                ),
              ),
            ),
            SizedBox(
              height: 28,
              child: Switch(
                value: ativo,
                onChanged: onChanged,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Footer fixo com TOTAL e botão Salvar.
class _Footer extends StatelessWidget {
  final TextEditingController valorCtl;
  final bool salvando;
  final bool isEdicao;
  final VoidCallback onSalvar;
  final double? Function(String) parseValor;
  const _Footer({
    required this.valorCtl,
    required this.salvando,
    required this.isEdicao,
    required this.onSalvar,
    required this.parseValor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: valorCtl,
                builder: (context, value, _) {
                  final v = parseValor(value.text);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'TOTAL DO PEDIDO',
                        style: TextStyle(
                          fontSize: 9.5,
                          letterSpacing: 0.7,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          v != null ? moeda.format(v) : '—',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: v != null ? cs.onSurface : cs.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: salvando ? null : onSalvar,
              icon: salvando
                  ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check, size: 16),
              label: Text(salvando ? 'Salvando...' : (isEdicao ? 'Salvar' : 'Criar pedido')),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoteBadge extends StatelessWidget {
  final String lote;
  const _LoteBadge({required this.lote});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
      ),
      child: Text(
        lote,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: cs.onPrimaryContainer,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _ErroBanner extends StatelessWidget {
  final String mensagem;
  const _ErroBanner({required this.mensagem});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.error.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: cs.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensagem,
              style: TextStyle(color: cs.onErrorContainer, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Overlay do autocomplete de cliente.
class _AutocompleteOptions extends StatelessWidget {
  final Iterable<Cliente> options;
  final AutocompleteOnSelected<Cliente> onSelected;
  final VoidCallback? onCriarNovo;
  const _AutocompleteOptions({
    required this.options,
    required this.onSelected,
    this.onCriarNovo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final optionList = options.toList();
    final hasOptions = optionList.isNotEmpty;

    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(10),
        color: theme.colorScheme.surfaceContainerLowest,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260, maxWidth: 460),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                if (!hasOptions)
                  Padding(
                    padding: EdgeInsets.fromLTRB(12, 10, 12, onCriarNovo == null ? 10 : 4),
                    child: Row(
                      children: [
                        Icon(Icons.search_off, size: 14, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text(
                          'Nenhum cliente encontrado',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final c in optionList)
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        c.iniciais,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    title: Text(c.nome, style: const TextStyle(fontSize: 12.5)),
                    subtitle: c.telefone != null
                        ? Text(c.telefone!, style: theme.textTheme.labelSmall)
                        : null,
                    onTap: () => onSelected(c),
                  ),
                if (onCriarNovo != null)
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: Icon(Icons.person_add_outlined, color: theme.colorScheme.primary, size: 20),
                    title: Text(
                      'Criar novo cliente',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: onCriarNovo,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo de data compacto.
class _DateField extends StatelessWidget {
  final String label;
  final DateTime? data;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final bool enabled;
  final String? placeholderDesabilitado;

  const _DateField({
    required this.label,
    required this.data,
    required this.onPick,
    required this.onClear,
    this.enabled = true,
    this.placeholderDesabilitado,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: enabled ? onPick : null,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          prefixIcon: Icon(
            data != null ? Icons.event : Icons.event_outlined,
            size: 16,
            color: !enabled
                ? cs.onSurfaceVariant.withValues(alpha: 0.5)
                : (data != null ? cs.primary : cs.onSurfaceVariant),
          ),
          suffixIcon: data != null && enabled
              ? IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  onPressed: onClear,
                  visualDensity: VisualDensity.compact,
                  splashRadius: 16,
                )
              : (enabled
                  ? Icon(Icons.arrow_drop_down, size: 18, color: cs.onSurfaceVariant)
                  : Icon(Icons.lock_outline, size: 13, color: cs.onSurfaceVariant.withValues(alpha: 0.5))),
        ),
        child: Text(
          !enabled
              ? (placeholderDesabilitado ?? '—')
              : (data == null ? '—' : DateFormat('dd/MM/yyyy', 'pt_BR').format(data!)),
          style: TextStyle(
            fontSize: 12.5,
            color: !enabled
                ? cs.onSurfaceVariant.withValues(alpha: 0.6)
                : (data == null ? theme.hintColor : cs.onSurface),
            fontWeight: data != null && enabled ? FontWeight.w700 : FontWeight.w500,
            fontStyle: !enabled ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    );
  }
}
