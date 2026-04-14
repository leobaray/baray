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

  // Fechamento
  bool _fechamentoAtivo = false;
  String? _fechamentoTipo; // 'semanal', 'quinzenal', 'mensal', 'data_fixa'
  int? _fechamentoDia;
  DateTime? _fechamentoDataFixa;

  // Opções de dia da semana
  static const _diasSemana = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];

  bool get _isEdicao => widget.clienteId != null;

  @override
  void initState() {
    super.initState();
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
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _excluir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir cliente?'),
        content: Text(_nomeCtl.text.trim()),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_carregando) {
      return Scaffold(
        appBar: AppBar(title: Text(_isEdicao ? 'Editar cliente' : 'Novo cliente')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            // ── Dados básicos ───────────────────────────────────────────
            TextFormField(
              controller: _nomeCtl,
              decoration: const InputDecoration(
                labelText: 'Nome *',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
              textInputAction: TextInputAction.next,
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
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _enderecoCtl,
              decoration: const InputDecoration(
                labelText: 'Endereço',
                prefixIcon: Icon(Icons.home_outlined),
                alignLabelWithHint: true,
              ),
              maxLines: 2,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _observacaoCtl,
              decoration: const InputDecoration(
                labelText: 'Observação',
                prefixIcon: Icon(Icons.note_outlined),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),

            // ── Fechamento ──────────────────────────────────────────────
            const SizedBox(height: 32),
            Divider(color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 16),
            SwitchListTile(
              value: _fechamentoAtivo,
              onChanged: (v) => setState(() {
                _fechamentoAtivo = v;
                if (!v) {
                  _fechamentoTipo = null;
                  _fechamentoDia = null;
                  _fechamentoDataFixa = null;
                }
              }),
              title: const Text('Fechamento recorrente'),
              subtitle: Text(
                _fechamentoAtivo
                    ? 'Cliente com ciclo de faturamento'
                    : 'Sem ciclo de fechamento',
                style: theme.textTheme.bodySmall,
              ),
              secondary: Icon(
                Icons.receipt_long_outlined,
                color: _fechamentoAtivo ? theme.colorScheme.primary : null,
              ),
            ),

            if (_fechamentoAtivo) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _fechamentoTipo,
                decoration: const InputDecoration(
                  labelText: 'Tipo de fechamento',
                  prefixIcon: Icon(Icons.event_repeat_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'semanal', child: Text('Semanal')),
                  DropdownMenuItem(value: 'quinzenal', child: Text('Quinzenal')),
                  DropdownMenuItem(value: 'mensal', child: Text('Mensal')),
                  DropdownMenuItem(value: 'data_fixa', child: Text('Data fixa')),
                ],
                onChanged: (v) => setState(() {
                  _fechamentoTipo = v;
                  _fechamentoDia = null;
                  _fechamentoDataFixa = null;
                }),
              ),

              if (_fechamentoTipo == 'semanal') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _fechamentoDia,
                  decoration: const InputDecoration(
                    labelText: 'Dia da semana',
                    prefixIcon: Icon(Icons.calendar_view_week_outlined),
                  ),
                  items: List.generate(7, (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text(_diasSemana[i]),
                  )),
                  onChanged: (v) => setState(() => _fechamentoDia = v),
                ),
              ],

              if (_fechamentoTipo == 'mensal') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _fechamentoDia,
                  decoration: const InputDecoration(
                    labelText: 'Dia do mês',
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                  items: List.generate(28, (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text('Dia ${i + 1}'),
                  )),
                  onChanged: (v) => setState(() => _fechamentoDia = v),
                ),
              ],

              if (_fechamentoTipo == 'data_fixa') ...[
                const SizedBox(height: 16),
                InkWell(
                  onTap: _selecionarDataFixa,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Data de fechamento',
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                      suffixIcon: _fechamentoDataFixa != null
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                    ),
                    child: Text(
                      _fechamentoDataFixa != null
                          ? '${_fechamentoDataFixa!.day.toString().padLeft(2, '0')}/'
                              '${_fechamentoDataFixa!.month.toString().padLeft(2, '0')}/'
                              '${_fechamentoDataFixa!.year}'
                          : 'Selecionar data',
                      style: _fechamentoDataFixa != null
                          ? theme.textTheme.bodyLarge
                          : theme.textTheme.bodyLarge?.copyWith(
                              color: theme.hintColor,
                            ),
                    ),
                  ),
                ),
              ],

              if (_fechamentoTipo == 'quinzenal')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Card(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Fecha nos dias 15 e último dia do mês',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],

            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_erro!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _salvando ? null : _salvar,
              icon: _salvando
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
              label: Text(_isEdicao ? 'Salvar alterações' : 'Criar cliente'),
            ),
          ],
        ),
      ),
    );
  }
}