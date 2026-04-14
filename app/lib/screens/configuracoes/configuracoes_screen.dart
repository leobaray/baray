import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../models/configuracao.dart';
import '../../state/configuracoes_provider.dart';
import '../../state/pedidos_provider.dart';
import '../../state/theme_provider.dart';
import '../../widgets/shimmer_skeleton.dart';

class ConfiguracoesScreen extends ConsumerStatefulWidget {
  const ConfiguracoesScreen({super.key});

  @override
  ConsumerState<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends ConsumerState<ConfiguracoesScreen> {
  final _serverUrlCtl = TextEditingController();
  bool _testando = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _serverUrlCtl.text = ref.read(serverUrlProvider);
  }

  @override
  void dispose() {
    _serverUrlCtl.dispose();
    super.dispose();
  }

  Future<void> _salvarUrl() async {
    final nova = _serverUrlCtl.text.trim();
    if (nova.isEmpty) return;
    await saveServerUrl(nova);
    ref.read(serverUrlProvider.notifier).state = nova;
    ref.invalidate(configuracoesProvider);
    ref.invalidate(pedidosProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servidor atualizado')),
      );
    }
  }

  Future<void> _testar() async {
    setState(() {
      _testando = true;
      _testResult = null;
    });
    try {
      final tempApi = ApiClient(_serverUrlCtl.text.trim());
      final ok = await tempApi.health();
      setState(() => _testResult = ok ? 'Conectado' : 'Sem resposta');
    } catch (e) {
      setState(() => _testResult = 'Erro: $e');
    } finally {
      if (mounted) setState(() => _testando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configs = ref.watch(configuracoesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _Section(
            icon: Icons.dns_outlined,
            title: 'Servidor',
            children: [
              TextField(
                controller: _serverUrlCtl,
                decoration: const InputDecoration(
                  labelText: 'URL do servidor',
                  hintText: 'http://10.150.60.100:8080',
                  prefixIcon: Icon(Icons.link_outlined),
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _testando ? null : _testar,
                    icon: _testando
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.wifi_tethering),
                    label: const Text('Testar conexão'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _salvarUrl,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Salvar'),
                  ),
                  const Spacer(),
                  if (_testResult != null)
                    Text(
                      _testResult!,
                      style: TextStyle(
                        color: _testResult == 'Conectado' ? Colors.green : theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _Section(
            icon: Icons.palette_outlined,
            title: 'Aparência',
            children: [
              Text('Tema do aplicativo', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Claro')),
                    ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Escuro')),
                    ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('Auto')),
                  ],
                  selected: {ref.watch(themeModeProvider)},
                  onSelectionChanged: (s) {
                    final m = s.first;
                    ref.read(themeModeProvider.notifier).state = m;
                    saveThemeMode(m);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _Section(
            icon: Icons.tune_outlined,
            title: 'Regras de negócio',
            children: [
              configs.when(
                loading: () => Column(
                  children: List.generate(4, (_) => const _ConfigSkeleton()),
                ),
                error: (e, _) => Text('Não consegui carregar: $e'),
                data: (lista) => Column(
                  children: [
                    for (final c in lista)
                      _ConfigEditor(
                        config: c,
                        onSave: (novoValor) async {
                          try {
                            await ref.read(apiClientProvider).atualizarConfiguracao(c.chave, novoValor);
                            ref.invalidate(configuracoesProvider);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${c.chave} atualizado')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erro: $e')),
                              );
                            }
                          }
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  const _Section({required this.icon, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: theme.colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 10),
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ConfigEditor extends StatefulWidget {
  final Configuracao config;
  final Future<void> Function(String) onSave;
  const _ConfigEditor({required this.config, required this.onSave});

  @override
  State<_ConfigEditor> createState() => _ConfigEditorState();
}

class _ConfigEditorState extends State<_ConfigEditor> {
  late final TextEditingController _ctl;
  late bool _bool;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.config.valor);
    _bool = widget.config.asBool;
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  String _label() {
    final c = widget.config;
    if (c.descricao != null && c.descricao!.isNotEmpty) return c.descricao!;
    return c.chave.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.config;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_label(), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          Text(c.chave, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 10),
          if (c.tipo == 'bool')
            Row(
              children: [
                Switch(
                  value: _bool,
                  onChanged: (v) {
                    setState(() => _bool = v);
                    widget.onSave(v ? 'true' : 'false');
                  },
                ),
                const SizedBox(width: 12),
                Text(_bool ? 'Sim' : 'Não'),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctl,
                    keyboardType: c.tipo == 'number'
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.text,
                    decoration: const InputDecoration(isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.check),
                  onPressed: () => widget.onSave(_ctl.text),
                ),
              ],
            ),
          const SizedBox(height: 4),
          Divider(color: theme.colorScheme.outlineVariant, thickness: 0.5),
        ],
      ),
    );
  }
}

class _ConfigSkeleton extends StatelessWidget {
  const _ConfigSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ShimmerSkeleton(width: 120, height: 16),
              const SizedBox(width: 12),
              const ShimmerSkeleton(width: 80, height: 12),
            ],
          ),
          const SizedBox(height: 10),
          const ShimmerSkeleton(width: double.infinity, height: 48, borderRadius: BorderRadius.horizontal(left: Radius.circular(12), right: Radius.circular(12))),
        ],
      ),
    );
  }
}