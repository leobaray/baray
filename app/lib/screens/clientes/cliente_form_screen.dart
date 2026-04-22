import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../state/clientes_provider.dart';

class ClienteFormScreen extends ConsumerStatefulWidget {
  final String? clienteId;
  const ClienteFormScreen({super.key, this.clienteId});

  @override
  ConsumerState<ClienteFormScreen> createState() => _ClienteFormScreenState();
}

class _ClienteFormScreenState extends ConsumerState<ClienteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtl = TextEditingController();
  final _telefoneCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _enderecoCtl = TextEditingController();
  final _observacaoCtl = TextEditingController();

  bool _carregando = false;
  bool _salvando = false;
  String? _erro;
  int _totalPedidosOriginal = 0;

  bool _fechamentoAtivo = false;
  String? _fechamentoTipo;
  int? _fechamentoDia;
  DateTime? _fechamentoDataFixa;

  bool _dirty = false;

  static const _diasSemana = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];

  bool get _isEdicao => widget.clienteId != null;

  void _markDirty() {
    if (!_dirty) _dirty = true;
  }

  @override
  void initState() {
    super.initState();
    for (final c in [_nomeCtl, _telefoneCtl, _emailCtl, _enderecoCtl, _observacaoCtl]) {
      c.addListener(_markDirty);
    }
    if (_isEdicao) _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final api = ref.read(apiClientProvider);
      final c = await api.buscarCliente(widget.clienteId!);
      if (!mounted) return;
      _nomeCtl.text = c.nome;
      _telefoneCtl.text = c.telefone ?? '';
      _emailCtl.text = c.email ?? '';
      _enderecoCtl.text = c.endereco ?? '';
      _observacaoCtl.text = c.observacao ?? '';
      _fechamentoAtivo = c.fechamentoAtivo;
      _fechamentoTipo = c.fechamentoTipo;
      _fechamentoDia = c.fechamentoDia;
      if (c.fechamentoDataFixa != null && c.fechamentoDataFixa!.isNotEmpty) {
        _fechamentoDataFixa = DateTime.tryParse(c.fechamentoDataFixa!);
      }
      _totalPedidosOriginal = c.totalPedidos;
      _dirty = false;
    } catch (e) {
      _erro = e.toString();
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  void dispose() {
    _nomeCtl.dispose();
    _telefoneCtl.dispose();
    _emailCtl.dispose();
    _enderecoCtl.dispose();
    _observacaoCtl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fechamentoAtivo && _fechamentoTipo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o tipo de fechamento')),
      );
      return;
    }
    if (_fechamentoAtivo && _fechamentoTipo == 'data_fixa' && _fechamentoDataFixa == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a data de fechamento')),
      );
      return;
    }

    setState(() => _salvando = true);
    try {
      final api = ref.read(apiClientProvider);
      final body = <String, dynamic>{
        'nome': _nomeCtl.text.trim(),
        if (_telefoneCtl.text.trim().isNotEmpty) 'telefone': _telefoneCtl.text.trim(),
        if (_emailCtl.text.trim().isNotEmpty) 'email': _emailCtl.text.trim(),
        if (_enderecoCtl.text.trim().isNotEmpty) 'endereco': _enderecoCtl.text.trim(),
        if (_observacaoCtl.text.trim().isNotEmpty) 'observacao': _observacaoCtl.text.trim(),
        'fechamento_ativo': _fechamentoAtivo,
        if (_fechamentoAtivo && _fechamentoTipo != null) ...{
          'fechamento_tipo': _fechamentoTipo,
          if (_fechamentoTipo != 'data_fixa' && _fechamentoDia != null)
            'fechamento_dia': _fechamentoDia,
          if (_fechamentoTipo == 'data_fixa' && _fechamentoDataFixa != null)
            'fechamento_data_fixa':
                '${_fechamentoDataFixa!.year.toString().padLeft(4, '0')}-'
                '${_fechamentoDataFixa!.month.toString().padLeft(2, '0')}-'
                '${_fechamentoDataFixa!.day.toString().padLeft(2, '0')}',
        },
      };

      if (_isEdicao) {
        await api.atualizarCliente(widget.clienteId!, body);
        ref.invalidate(clienteDetalheProvider(widget.clienteId!));
      } else {
        await api.criarCliente(body);
      }
      ref.invalidate(clientesProvider);
      _dirty = false;
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _excluir() async {
    final nome = _nomeCtl.text.trim();
    final msg = _totalPedidosOriginal > 0
        ? '$nome tem $_totalPedidosOriginal pedido${_totalPedidosOriginal == 1 ? '' : 's'} cadastrados. Eles ficarão sem cliente vinculado (mas preservam o nome).'
        : nome;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Excluir cliente?'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogCtx).colorScheme.errorContainer,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).deletarCliente(widget.clienteId!);
      ref.invalidate(clientesProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: $e')),
        );
      }
    }
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
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogCtx).colorScheme.errorContainer,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _selecionarDataFixa() async {
    final data = await showDatePicker(
      context: context,
      initialDate: _fechamentoDataFixa ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      locale: const Locale('pt', 'BR'),
    );
    if (data != null) {
      setState(() => _fechamentoDataFixa = data);
      _markDirty();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return Scaffold(
        appBar: AppBar(title: Text(_isEdicao ? 'Editar cliente' : 'Novo cliente')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
          title: Text(_isEdicao ? 'Editar cliente' : 'Novo cliente'),
          actions: [
            if (_isEdicao)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Excluir',
                onPressed: _salvando ? null : _excluir,
              ),
          ],
        ),
        bottomNavigationBar: _FormFooter(
          salvando: _salvando,
          isEdicao: _isEdicao,
          onSalvar: _salvar,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            children: [
              _Block(
                icon: Icons.person_outline,
                title: 'Dados do cliente',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nomeCtl,
                      decoration: const InputDecoration(
                        labelText: 'Nome *',
                        prefixIcon: Icon(Icons.person_outline, size: 18),
                        isDense: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, c) {
                        final estreito = c.maxWidth < 460;
                        final tel = TextFormField(
                          controller: _telefoneCtl,
                          decoration: const InputDecoration(
                            labelText: 'Telefone',
                            prefixIcon: Icon(Icons.call_outlined, size: 18),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                        );
                        final email = TextFormField(
                          controller: _emailCtl,
                          decoration: const InputDecoration(
                            labelText: 'E-mail',
                            prefixIcon: Icon(Icons.mail_outline, size: 18),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                        );
                        if (estreito) {
                          return Column(
                            children: [tel, const SizedBox(height: 10), email],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: tel),
                            const SizedBox(width: 10),
                            Expanded(child: email),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _enderecoCtl,
                      decoration: const InputDecoration(
                        labelText: 'Endereço',
                        prefixIcon: Icon(Icons.home_outlined, size: 18),
                        isDense: true,
                        alignLabelWithHint: true,
                      ),
                      maxLines: 2,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _observacaoCtl,
                      decoration: const InputDecoration(
                        labelText: 'Observação interna',
                        prefixIcon: Icon(Icons.note_outlined, size: 18),
                        isDense: true,
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _Block(
                icon: Icons.receipt_long_outlined,
                title: 'Fechamento por ciclo',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AtivarTile(
                      ativo: _fechamentoAtivo,
                      onChanged: (v) {
                        setState(() {
                          _fechamentoAtivo = v;
                          if (!v) {
                            _fechamentoTipo = null;
                            _fechamentoDia = null;
                            _fechamentoDataFixa = null;
                          }
                        });
                        _markDirty();
                      },
                    ),
                    if (_fechamentoAtivo) ...[
                      const SizedBox(height: 12),
                      _TipoSelector(
                        value: _fechamentoTipo,
                        onChanged: (v) {
                          setState(() {
                            _fechamentoTipo = v;
                            _fechamentoDia = null;
                            _fechamentoDataFixa = null;
                          });
                          _markDirty();
                        },
                      ),
                      if (_fechamentoTipo == 'semanal') ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int>(
                          initialValue: _fechamentoDia,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: 'Dia da semana',
                            prefixIcon: Icon(Icons.calendar_view_week_outlined, size: 18),
                            isDense: true,
                          ),
                          items: List.generate(
                            7,
                            (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text(_diasSemana[i]),
                            ),
                          ),
                          onChanged: (v) {
                            setState(() => _fechamentoDia = v);
                            _markDirty();
                          },
                        ),
                      ],
                      if (_fechamentoTipo == 'mensal') ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int>(
                          initialValue: _fechamentoDia,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: 'Dia do mês',
                            prefixIcon: Icon(Icons.calendar_month_outlined, size: 18),
                            isDense: true,
                          ),
                          items: List.generate(
                            28,
                            (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text('Dia ${i + 1}'),
                            ),
                          ),
                          onChanged: (v) {
                            setState(() => _fechamentoDia = v);
                            _markDirty();
                          },
                        ),
                      ],
                      if (_fechamentoTipo == 'data_fixa') ...[
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: _selecionarDataFixa,
                          borderRadius: BorderRadius.circular(10),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Data de fechamento',
                              prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                              isDense: true,
                              suffixIcon: _fechamentoDataFixa != null
                                  ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                                  : null,
                            ),
                            child: Text(
                              _fechamentoDataFixa != null
                                  ? '${_fechamentoDataFixa!.day.toString().padLeft(2, '0')}/'
                                      '${_fechamentoDataFixa!.month.toString().padLeft(2, '0')}/'
                                      '${_fechamentoDataFixa!.year}'
                                  : 'Selecionar data',
                              style: TextStyle(
                                fontSize: 13,
                                color: _fechamentoDataFixa != null
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Theme.of(context).hintColor,
                                fontWeight: _fechamentoDataFixa != null ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (_fechamentoTipo == 'quinzenal')
                        _InfoNote(
                          texto: 'Fecha nos dias 15 e último dia do mês.',
                        ),
                    ],
                  ],
                ),
              ),
              if (_erro != null) ...[
                const SizedBox(height: 10),
                _ErroBanner(mensagem: _erro!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _Block extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _Block({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
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

class _AtivarTile extends StatelessWidget {
  final bool ativo;
  final ValueChanged<bool> onChanged;
  const _AtivarTile({required this.ativo, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => onChanged(!ativo),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: ativo ? cs.primaryContainer.withValues(alpha: 0.35) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: ativo ? cs.primary.withValues(alpha: 0.5) : cs.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(
              ativo ? Icons.event_repeat : Icons.event_repeat_outlined,
              size: 18,
              color: ativo ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Fechamento recorrente',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: ativo ? cs.onPrimaryContainer : cs.onSurface,
                    ),
                  ),
                  Text(
                    ativo
                        ? 'Cliente com ciclo de faturamento'
                        : 'Sem ciclo — pagamento por pedido',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
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

class _TipoSelector extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const _TipoSelector({required this.value, required this.onChanged});

  static const _opcoes = <(String, String, String, IconData)>[
    ('semanal', 'Semanal', 'Um dia fixo por semana', Icons.calendar_view_week_outlined),
    ('quinzenal', 'Quinzenal', 'Dias 15 e fim do mês', Icons.date_range_outlined),
    ('mensal', 'Mensal', 'Um dia fixo por mês', Icons.calendar_month_outlined),
    ('data_fixa', 'Data fixa', 'Uma data específica', Icons.event_available_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tipo de fechamento',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, c) {
            final duasCol = c.maxWidth < 460;
            if (duasCol) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _opcao(context, _opcoes[0])),
                      const SizedBox(width: 6),
                      Expanded(child: _opcao(context, _opcoes[1])),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: _opcao(context, _opcoes[2])),
                      const SizedBox(width: 6),
                      Expanded(child: _opcao(context, _opcoes[3])),
                    ],
                  ),
                ],
              );
            }
            return Row(
              children: [
                for (var i = 0; i < _opcoes.length; i++) ...[
                  Expanded(child: _opcao(context, _opcoes[i])),
                  if (i < _opcoes.length - 1) const SizedBox(width: 6),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _opcao(BuildContext context, (String, String, String, IconData) o) {
    final cs = Theme.of(context).colorScheme;
    final selecionado = value == o.$1;
    return InkWell(
      onTap: () => onChanged(o.$1),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selecionado ? cs.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selecionado ? cs.primary : cs.outlineVariant,
            width: selecionado ? 1.3 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(o.$4, size: 15, color: selecionado ? cs.primary : cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    o.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: selecionado ? FontWeight.w800 : FontWeight.w700,
                      color: selecionado ? cs.onPrimaryContainer : cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              o.$3,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: selecionado
                    ? cs.onPrimaryContainer.withValues(alpha: 0.8)
                    : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  final String texto;
  const _InfoNote({required this.texto});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                texto,
                style: TextStyle(
                  fontSize: 11.5,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
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
              style: TextStyle(
                color: cs.onErrorContainer,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormFooter extends StatelessWidget {
  final bool salvando;
  final bool isEdicao;
  final VoidCallback onSalvar;
  const _FormFooter({
    required this.salvando,
    required this.isEdicao,
    required this.onSalvar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
            TextButton(
              onPressed: salvando ? null : () => Navigator.of(context).maybePop(),
              child: const Text('Cancelar'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: salvando ? null : onSalvar,
              icon: salvando
                  ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check, size: 16),
              label: Text(salvando ? 'Salvando...' : (isEdicao ? 'Salvar' : 'Criar cliente')),
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
