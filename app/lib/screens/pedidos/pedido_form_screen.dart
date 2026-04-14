import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../models/cliente.dart';
import '../../models/pedido.dart';
import '../../state/clientes_provider.dart';
import '../../state/dashboard_provider.dart';
import '../../state/pedidos_provider.dart';
import '../../widgets/empty_state.dart';

class PedidoFormScreen extends ConsumerStatefulWidget {
  final String? pedidoId;
  final String? clienteIdInicial;
  const PedidoFormScreen({super.key, this.pedidoId, this.clienteIdInicial});

  @override
  ConsumerState<PedidoFormScreen> createState() => _PedidoFormScreenState();
}

class _PedidoFormScreenState extends ConsumerState<PedidoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _data = DateFormat('dd/MM/yyyy', 'pt_BR');

  // Controllers
  final _clienteCtl = TextEditingController();
  final _telefoneCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _pecaCtl = TextEditingController();
  final _tecnicaCtl = TextEditingController();
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
  DateTime? _dataChegada;
  DateTime? _dataProducao;
  DateTime? _dataEntregaCombinada;
  String _status = 'pendente';
  String _statusPagamento = 'devendo';
  bool _urgente = false;
  String _formaEntrega = 'retirada';
  String? _formaPagamento;
  bool _autoAgendar = true;

  // Control state
  bool _carregando = false;
  bool _salvando = false;
  bool _confirmandoSaida = false;
  String? _erro;
  Pedido? _original;
  final _autocompleteKey = GlobalKey<FormFieldState<String>>();

  bool get _isEdicao => widget.pedidoId != null;

  @override
  void initState() {
    super.initState();
    if (widget.pedidoId != null) {
      _carregar();
    } else if (widget.clienteIdInicial != null) {
      _carregarClienteInicial();
    }
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final api = ref.read(apiClientProvider);
      final p = await api.buscarPedido(widget.pedidoId!);
      _original = p;
      _preencherPedido(p);
    } catch (e) {
      _erro = e.toString();
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _preencherPedido(Pedido p) {
    _clienteId = p.clienteId;
    _clienteCtl.text = p.clienteNome;
    _telefoneCtl.text = p.clienteTelefone ?? '';
    _emailCtl.text = p.clienteEmail ?? '';
    _pecaCtl.text = p.peca ?? '';
    _tecnicaCtl.text = p.tecnica ?? '';
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

  Future<void> _carregarClienteInicial() async {
    try {
      final api = ref.read(apiClientProvider);
      final c = await api.buscarCliente(widget.clienteIdInicial!);
      _clienteId = c.id;
      _clienteCtl.text = c.nome;
      _telefoneCtl.text = c.telefone ?? '';
      _emailCtl.text = c.email ?? '';
    } catch (_) {
      // silencioso — o campo fica vazio
    }
  }

  @override
  void dispose() {
    _clienteCtl.dispose();
    _telefoneCtl.dispose();
    _emailCtl.dispose();
    _pecaCtl.dispose();
    _tecnicaCtl.dispose();
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

  Future<void> _abrirOrcamento() async {
    final total = await context.push<double?>('/orcamento');
    if (total != null && mounted) {
      _valorCtl.text = total.toStringAsFixed(2).replaceAll('.', ',');
    }
  }

  String _montarDescricao() {
    final partes = <String>[];
    final peca = _pecaCtl.text.trim();
    final qtd = _quantidadeCtl.text.trim();
    final tecnica = _tecnicaCtl.text.trim();
    final cor = _corPecaCtl.text.trim();
    if (qtd.isNotEmpty && peca.isNotEmpty) {
      partes.add('$qtd ${peca}s');
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
        'cliente_nome': _clienteCtl.text.trim(),
        'cliente_telefone': _telefoneCtl.text.trim().isEmpty ? null : _telefoneCtl.text.trim(),
        'cliente_email': _emailCtl.text.trim().isEmpty ? null : _emailCtl.text.trim(),
        'descricao': descricao,
        'peca': _pecaCtl.text.trim().isEmpty ? null : _pecaCtl.text.trim(),
        'tecnica': _tecnicaCtl.text.trim().isEmpty ? null : _tecnicaCtl.text.trim(),
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
      if (!_isEdicao) {
        body['auto_agendar'] = _autoAgendar;
      }

      if (_isEdicao) {
        await api.atualizarPedido(widget.pedidoId!, body);
        ref.invalidate(pedidoProvider(widget.pedidoId!));
      } else {
        await api.criarPedido(body);
      }
      ref.invalidate(pedidosProvider);
      ref.invalidate(dashboardProvider);
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
      builder: (_) => AlertDialog(
        title: const Text('Excluir pedido?'),
        content: Text('${_original?.loteFormatado ?? ''} ${_original?.clienteNome ?? ''}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
            ),
            onPressed: () => Navigator.pop(context, true),
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
      builder: (_) => AlertDialog(
        title: const Text('Confirmar saída?'),
        content: Text('Confirmar saída do pedido ${_original?.loteFormatado ?? ""}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
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
      ref.invalidate(dashboardProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saída confirmada ✓')),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _confirmandoSaida = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return Scaffold(
        appBar: AppBar(title: Text(_isEdicao ? 'Editar pedido' : 'Novo pedido')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final clientes = ref.watch(clientesProvider).value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdicao ? 'Editar pedido' : 'Novo pedido'),
        actions: [
          if (_isEdicao)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Excluir',
              onPressed: _salvando ? null : _excluir,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // Lote badge
            if (_original != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _original!.loteFormatado,
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

            // ═══ Seção 1: Cliente ═══
            _SectionCard(
              icon: Icons.person_outline,
              title: 'Cliente',
              children: [
                Autocomplete<Cliente>(
                  key: _autocompleteKey,
                  initialValue: TextEditingValue(text: _clienteCtl.text),
                  optionsBuilder: (textEditingValue) {
                    final query = textEditingValue.text.toLowerCase();
                    if (query.isEmpty) return const Iterable<Cliente>.empty();
                    return clientes.where((c) => c.nome.toLowerCase().contains(query));
                  },
                  displayStringForOption: (c) => c.nome,
                  onSelected: (c) {
                    _clienteId = c.id;
                    _clienteCtl.text = c.nome;
                    _telefoneCtl.text = c.telefone ?? '';
                    _emailCtl.text = c.email ?? '';
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    // Sync external controller
                    controller.text = _clienteCtl.text;
                    controller.addListener(() {
                      if (controller.text != _clienteCtl.text) {
                        _clienteCtl.text = controller.text;
                        // Se o usuário digitou manualmente (não selecionou do autocomplete),
                        // o ID do cliente não corresponde mais — limpar
                        setState(() {
                          _clienteId = null;
                        });
                      }
                    });
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                      decoration: InputDecoration(
                        labelText: 'Cliente *',
                        prefixIcon: const Icon(Icons.person_outline),
                        suffixIcon: _clienteId != null
                            ? Tooltip(
                                message: 'Cliente vinculado',
                                child: Icon(Icons.link, color: theme.colorScheme.primary, size: 20),
                              )
                            : _clienteCtl.text.trim().isNotEmpty
                                ? Tooltip(
                                    message: 'Cliente NÃO vinculado — toque para selecionar ou criar',
                                    child: Icon(Icons.warning_amber, color: theme.colorScheme.error, size: 20),
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
                      onCriarNovo: _clienteCtl.text.trim().isNotEmpty ? () {
                        // Fecha o overlay e navega para criar cliente
                        Navigator.of(context).maybePop();
                        context.push('/clientes/novo').then((_) {
                          // Ao voltar, os clientes foram atualizados
                          ref.invalidate(clientesProvider);
                        });
                      } : null,
                    );
                  },
                ),
                if (_clienteId == null && _clienteCtl.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Card(
                      color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 18, color: theme.colorScheme.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cliente não vinculado',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: theme.colorScheme.onErrorContainer,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Selecione um cliente existente na lista ou crie um novo.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonal(
                              onPressed: () => context.push('/clientes/novo').then((_) {
                                ref.invalidate(clientesProvider);
                              }),
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.colorScheme.errorContainer,
                              ),
                              child: const Text('Criar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _telefoneCtl,
                  decoration: const InputDecoration(
                    labelText: 'Telefone',
                    prefixIcon: Icon(Icons.call_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailCtl,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
              ],
            ),

            // ═══ Seção 2: Peça ═══
            _SectionCard(
              icon: Icons.checkroom_outlined,
              title: 'Peça',
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _pecaCtl,
                        decoration: const InputDecoration(labelText: 'Peça', hintText: 'camiseta'),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _tecnicaCtl,
                        decoration: const InputDecoration(labelText: 'Técnica', hintText: 'silk'),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantidadeCtl,
                        decoration: const InputDecoration(labelText: 'Quantidade *'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Obrigatório';
                          if (int.tryParse(v.trim()) == null) return 'Inválido';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _valorCtl,
                        decoration: const InputDecoration(
                          labelText: 'Valor (R\$) *',
                          hintText: '800,00',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Obrigatório';
                          if (_parseValor(v) == null) return 'Inválido';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _abrirOrcamento,
                    icon: const Icon(Icons.calculate_outlined, size: 18),
                    label: const Text('Calcular orçamento'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _corPecaCtl,
                        decoration: const InputDecoration(labelText: 'Cor'),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _tamanhoPecaCtl,
                        decoration: const InputDecoration(labelText: 'Tamanho'),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _tecidoCtl,
                        decoration: const InputDecoration(labelText: 'Tecido'),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // ═══ Seção 3: Arte ═══
            _SectionCard(
              icon: Icons.palette_outlined,
              title: 'Arte',
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _arteCoresCtl,
                        decoration: const InputDecoration(labelText: 'Nº de cores'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _arteTamanhoCtl,
                        decoration: const InputDecoration(
                          labelText: 'Tamanho (cm)',
                          hintText: '25x15',
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _artePosicaoCtl,
                  decoration: const InputDecoration(
                    labelText: 'Posição',
                    hintText: 'Frente, Costas, Manga...',
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _arteObservacaoCtl,
                  decoration: const InputDecoration(
                    labelText: 'Observação da arte',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 2,
                ),
              ],
            ),

            // ═══ Seção 4: Agendamento ═══
            _SectionCard(
              icon: Icons.calendar_month_outlined,
              title: 'Agendamento',
              children: [
                _DateField(
                  label: 'Data de chegada',
                  data: _dataChegada,
                  onPick: () => _pickDate(_dataChegada, (d) => setState(() => _dataChegada = d)),
                  onClear: () => setState(() => _dataChegada = null),
                ),
                const SizedBox(height: 16),
                _DateField(
                  label: 'Data de produção',
                  data: _dataProducao,
                  onPick: () => _pickDate(_dataProducao, (d) => setState(() => _dataProducao = d)),
                  onClear: () => setState(() => _dataProducao = null),
                ),
                const SizedBox(height: 12),
                if (!_isEdicao)
                  SwitchListTile(
                    value: _autoAgendar,
                    onChanged: (v) => setState(() => _autoAgendar = v),
                    title: const Text('Agendar automaticamente'),
                    subtitle: const Text('Pula fim de semana, respeita limite diário'),
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'pendente', child: Text('Pendente')),
                    DropdownMenuItem(value: 'agendado', child: Text('Agendado')),
                    DropdownMenuItem(value: 'producao', child: Text('Em produção')),
                    DropdownMenuItem(value: 'concluido', child: Text('Concluído')),
                    DropdownMenuItem(value: 'entregue', child: Text('Entregue')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'pendente'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _urgente,
                  onChanged: (v) => setState(() => _urgente = v),
                  title: const Text('Urgente'),
                  subtitle: const Text('Aplica taxa adicional'),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ],
            ),

            // ═══ Seção 5: Entrega ═══
            _SectionCard(
              icon: Icons.local_shipping_outlined,
              title: 'Entrega',
              children: [
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'retirada', label: Text('Retirada'), icon: Icon(Icons.store_outlined)),
                      ButtonSegment(value: 'entrega', label: Text('Entrega'), icon: Icon(Icons.local_shipping_outlined)),
                    ],
                    selected: {_formaEntrega},
                    onSelectionChanged: (s) => setState(() => _formaEntrega = s.first),
                  ),
                ),
                if (_formaEntrega == 'entrega') ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _enderecoCtl,
                    decoration: const InputDecoration(
                      labelText: 'Endereço de entrega',
                      prefixIcon: Icon(Icons.home_outlined),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 2,
                  ),
                ],
                const SizedBox(height: 16),
                _DateField(
                  label: 'Data de entrega combinada',
                  data: _dataEntregaCombinada,
                  onPick: () => _pickDate(_dataEntregaCombinada, (d) => setState(() => _dataEntregaCombinada = d)),
                  onClear: () => setState(() => _dataEntregaCombinada = null),
                ),
              ],
            ),

            // ═══ Seção 6: Pagamento ═══
            _SectionCard(
              icon: Icons.payments_outlined,
              title: 'Pagamento',
              children: [
                DropdownButtonFormField<String?>(
                  initialValue: _formaPagamento,
                  decoration: const InputDecoration(
                    labelText: 'Forma de pagamento',
                    prefixIcon: Icon(Icons.payment_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Não definido')),
                    DropdownMenuItem(value: 'dinheiro', child: Text('Dinheiro')),
                    DropdownMenuItem(value: 'pix', child: Text('Pix')),
                    DropdownMenuItem(value: 'cartao_credito', child: Text('Cartão de crédito')),
                    DropdownMenuItem(value: 'cartao_debito', child: Text('Cartão de débito')),
                    DropdownMenuItem(value: 'boleto', child: Text('Boleto')),
                    DropdownMenuItem(value: 'transferencia', child: Text('Transferência')),
                  ],
                  onChanged: (v) => setState(() => _formaPagamento = v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _statusPagamento,
                  decoration: const InputDecoration(labelText: 'Status do pagamento'),
                  items: const [
                    DropdownMenuItem(value: 'devendo', child: Text('Devendo')),
                    DropdownMenuItem(value: 'parcial', child: Text('Parcial')),
                    DropdownMenuItem(value: 'pago', child: Text('Pago')),
                  ],
                  onChanged: (v) => setState(() => _statusPagamento = v ?? 'devendo'),
                ),
              ],
            ),

            // ═══ Seção 7: Observação ═══
            _SectionCard(
              icon: Icons.note_outlined,
              title: 'Observação',
              children: [
                TextFormField(
                  controller: _observacaoCtl,
                  decoration: const InputDecoration(
                    labelText: 'Observação',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
              ],
            ),

            // ═══ Seção 8: Saída (só edição) ═══
            if (_isEdicao && _original != null) ...[
              const SizedBox(height: 8),
              Card(
                color: theme.colorScheme.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        icon: Icons.local_shipping_outlined,
                        title: 'Saída',
                      ),
                      const SizedBox(height: 16),
                      if (_original!.entregue) ...[
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 48,
                                  color: theme.colorScheme.onTertiaryContainer,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Entregue',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: theme.colorScheme.onTertiaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (_original!.entregueEm != null)
                                  Text(
                                    'em ${_data.format(_original!.entregueEm!)}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onTertiaryContainer,
                                    ),
                                  ),
                                const SizedBox(height: 2),
                                Text(
                                  'por ${_original!.entreguePor ?? '—'}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onTertiaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        TextFormField(
                          controller: _entreguePorCtl,
                          decoration: InputDecoration(
                            labelText: 'Entregue por',
                            hintText: 'Nome de quem está retirando',
                            prefixIcon: Icon(
                              Icons.person_outlined,
                              color: theme.colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _confirmandoSaida ? null : _confirmarSaida,
                            icon: _confirmandoSaida
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.local_shipping),
                            label: const Text('CONFIRMAR SAÍDA'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            // Erro
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_erro!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: 24),

            // Salvar
            FilledButton.icon(
              onPressed: _salvando ? null : _salvar,
              icon: _salvando
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
              label: Text(_isEdicao ? 'Salvar alterações' : 'Criar pedido'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section Card ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.icon, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(icon: icon, title: title),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

// ── Autocomplete options overlay ────────────────────────────────────────────

class _AutocompleteOptions extends StatelessWidget {
  final Iterable<Cliente> options;
  final AutocompleteOnSelected<Cliente> onSelected;
  final VoidCallback? onCriarNovo;
  const _AutocompleteOptions({required this.options, required this.onSelected, this.onCriarNovo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final optionList = options.toList();
    final hasOptions = optionList.isNotEmpty;

    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surface,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 250, maxWidth: 300),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                if (!hasOptions)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      'Nenhum cliente encontrado',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                for (final c in optionList)
                  ListTile(
                    dense: true,
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        c.iniciais,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    title: Text(c.nome),
                    subtitle: c.telefone != null ? Text(c.telefone!, style: theme.textTheme.labelSmall) : null,
                    onTap: () => onSelected(c),
                  ),
                if (onCriarNovo != null)
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.person_add_outlined, color: theme.colorScheme.primary, size: 24),
                    title: Text(
                      'Criar novo cliente',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
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

// ── Date field ──────────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? data;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _DateField({
    required this.label,
    required this.data,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined),
          suffixIcon: data != null
              ? IconButton(icon: const Icon(Icons.close), onPressed: onClear)
              : const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          data == null ? 'Toque para selecionar' : DateFormat('dd/MM/yyyy', 'pt_BR').format(data!),
          style: TextStyle(color: data == null ? Theme.of(context).hintColor : null),
        ),
      ),
    );
  }
}