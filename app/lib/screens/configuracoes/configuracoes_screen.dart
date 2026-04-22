import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../models/configuracao.dart';
import '../../state/configuracoes_provider.dart';
import '../../state/pedidos_provider.dart';
import '../../state/theme_provider.dart';

// Versão do app — atualizar quando bumpar `version:` no pubspec.yaml.
const _appVersao = '1.0.0';

// Defaults do seed do servidor — fonte pro "Restaurar padrão" individual
// e pro botão global "Restaurar todas".
const _defaultsConfig = <String, String>{
  'limite_diario': '1200',
  'producao_sabado': 'false',
  'producao_domingo': 'false',
  'prazo_padrao_dias': '5',
  'taxa_urgencia_pct': '25',
  'adicional_moletom_aberto_pct': '20',
  'adicional_moletom_fechado_pct': '60',
  'matriz_gratis_acima_pcs': '150',
  'matriz_padrao_40x50': '35',
  'matriz_padrao_50x60': '45',
  'lote_prefixo': 'LOTE',
  'lote_digitos': '4',
  'empresa_nome': 'Serigrafia Baray',
};

class ConfiguracoesScreen extends ConsumerStatefulWidget {
  const ConfiguracoesScreen({super.key});

  @override
  ConsumerState<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends ConsumerState<ConfiguracoesScreen> {
  final _serverUrlCtl = TextEditingController();
  bool _testando = false;
  ServerHealth? _status;
  int? _proximoLote;

  @override
  void initState() {
    super.initState();
    _serverUrlCtl.text = ref.read(serverUrlProvider);
    _atualizarDiagnostico();
  }

  @override
  void dispose() {
    _serverUrlCtl.dispose();
    super.dispose();
  }

  Future<void> _atualizarDiagnostico() async {
    final api = ApiClient(ref.read(serverUrlProvider));
    final info = await api.healthInfo();
    if (!mounted) return;
    setState(() => _status = info);
    if (info.online) {
      final prox = await api.proximoLote();
      if (!mounted) return;
      setState(() => _proximoLote = prox);
    }
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
        const SnackBar(
          content: Text('Servidor atualizado'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
    await _atualizarDiagnostico();
  }

  Future<void> _testarConexao() async {
    setState(() => _testando = true);
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;
    try {
      final api = ApiClient(_serverUrlCtl.text.trim());
      final info = await api.healthInfo();
      if (!mounted) return;
      final ok = info.online;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Conectado · ${info.latenciaMs}ms' : 'Sem resposta do servidor',
            style: TextStyle(color: ok ? scheme.onPrimary : scheme.onError),
          ),
          backgroundColor: ok ? scheme.primary : scheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      setState(() => _status = info);
    } finally {
      if (mounted) setState(() => _testando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configs = ref.watch(configuracoesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: () {
              ref.invalidate(configuracoesProvider);
              _atualizarDiagnostico();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(configuracoesProvider);
          await _atualizarDiagnostico();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            _StatusCard(status: _status),
            const SizedBox(height: 16),
            configs.when(
              loading: () => const _CarregandoSecoes(),
              error: (e, _) => Text(
                'Não consegui carregar: $e',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              data: (lista) {
                final porChave = {for (final c in lista) c.chave: c};
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _secaoProducao(porChave),
                    const SizedBox(height: 16),
                    _secaoPreco(porChave),
                    const SizedBox(height: 16),
                    _secaoIdentidade(porChave),
                    const SizedBox(height: 16),
                    _secaoLotes(porChave),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            _secaoAparencia(),
            const SizedBox(height: 16),
            _secaoAvancado(),
            const SizedBox(height: 20),
            _botaoRestaurarTudo(),
          ],
        ),
      ),
    );
  }

  // ── Seções ──────────────────────────────────────────────────────────────

  Widget _secaoProducao(Map<String, Configuracao> porChave) {
    return _Secao(
      titulo: 'Regras de produção',
      descricao: 'Como a oficina trabalha no dia-a-dia.',
      children: [
        if (porChave['limite_diario'] != null)
          _StepperField(
            config: porChave['limite_diario']!,
            label: 'Limite diário de produção',
            descricao: 'Valor máximo agendado num dia antes do sistema sinalizar sobrecarga.',
            incremento: 100,
            minimo: 0,
            prefixo: 'R\$',
            onSave: (v) => _salvarConfig('limite_diario', v),
            onRestaurar: () => _restaurarPadrao('limite_diario'),
          ),
        if (porChave['producao_sabado'] != null)
          _BoolField(
            config: porChave['producao_sabado']!,
            label: 'Sábado conta como dia útil',
            descricao: 'Agendador pode alocar pedidos nesse dia.',
            onSave: (v) => _salvarConfig('producao_sabado', v),
            onRestaurar: () => _restaurarPadrao('producao_sabado'),
          ),
        if (porChave['producao_domingo'] != null)
          _BoolField(
            config: porChave['producao_domingo']!,
            label: 'Domingo conta como dia útil',
            descricao: 'Igual ao sábado, mas pra domingo.',
            onSave: (v) => _salvarConfig('producao_domingo', v),
            onRestaurar: () => _restaurarPadrao('producao_domingo'),
          ),
        if (porChave['prazo_padrao_dias'] != null)
          _StepperField(
            config: porChave['prazo_padrao_dias']!,
            label: 'Prazo padrão pra início de produção',
            descricao: 'Dias úteis entre o cadastro e a data de produção sugerida.',
            incremento: 1,
            minimo: 0,
            maximo: 60,
            sufixo: 'dias',
            onSave: (v) => _salvarConfig('prazo_padrao_dias', v),
            onRestaurar: () => _restaurarPadrao('prazo_padrao_dias'),
          ),
      ],
    );
  }

  Widget _secaoPreco(Map<String, Configuracao> porChave) {
    return _Secao(
      titulo: 'Cálculo de preço',
      descricao: 'Influencia o orçamento automático.',
      children: [
        if (porChave['taxa_urgencia_pct'] != null)
          _StepperField(
            config: porChave['taxa_urgencia_pct']!,
            label: 'Taxa pra pedidos urgentes',
            descricao: 'Acréscimo aplicado sobre o preço da tabela.',
            incremento: 5,
            minimo: 0,
            maximo: 200,
            sufixo: '%',
            preview: _previewPct(porChave['taxa_urgencia_pct']!.valor, 'urgente'),
            onSave: (v) => _salvarConfig('taxa_urgencia_pct', v),
            onRestaurar: () => _restaurarPadrao('taxa_urgencia_pct'),
          ),
        if (porChave['adicional_moletom_aberto_pct'] != null)
          _StepperField(
            config: porChave['adicional_moletom_aberto_pct']!,
            label: 'Adicional moletom aberto',
            descricao: 'Multiplica o preço por peça.',
            incremento: 5,
            minimo: 0,
            maximo: 200,
            sufixo: '%',
            preview: _previewPct(porChave['adicional_moletom_aberto_pct']!.valor, 'aberto'),
            onSave: (v) => _salvarConfig('adicional_moletom_aberto_pct', v),
            onRestaurar: () => _restaurarPadrao('adicional_moletom_aberto_pct'),
          ),
        if (porChave['adicional_moletom_fechado_pct'] != null)
          _StepperField(
            config: porChave['adicional_moletom_fechado_pct']!,
            label: 'Adicional moletom fechado',
            descricao: 'Multiplica o preço por peça.',
            incremento: 5,
            minimo: 0,
            maximo: 200,
            sufixo: '%',
            preview: _previewPct(porChave['adicional_moletom_fechado_pct']!.valor, 'fechado'),
            onSave: (v) => _salvarConfig('adicional_moletom_fechado_pct', v),
            onRestaurar: () => _restaurarPadrao('adicional_moletom_fechado_pct'),
          ),
        if (porChave['matriz_gratis_acima_pcs'] != null)
          _StepperField(
            config: porChave['matriz_gratis_acima_pcs']!,
            label: 'Matriz grátis acima de',
            descricao: 'Não cobra matriz em pedidos com essa quantidade ou mais.',
            incremento: 50,
            minimo: 0,
            sufixo: 'pçs',
            onSave: (v) => _salvarConfig('matriz_gratis_acima_pcs', v),
            onRestaurar: () => _restaurarPadrao('matriz_gratis_acima_pcs'),
          ),
        if (porChave['matriz_padrao_40x50'] != null)
          _StepperField(
            config: porChave['matriz_padrao_40x50']!,
            label: 'Matriz 40×50 (bottom/nuca)',
            descricao: 'Valor cobrado por cor abaixo do limite de quantidade.',
            incremento: 5,
            minimo: 0,
            prefixo: 'R\$',
            onSave: (v) => _salvarConfig('matriz_padrao_40x50', v),
            onRestaurar: () => _restaurarPadrao('matriz_padrao_40x50'),
          ),
        if (porChave['matriz_padrao_50x60'] != null)
          _StepperField(
            config: porChave['matriz_padrao_50x60']!,
            label: 'Matriz 50×60 (frente/costas)',
            descricao: 'Valor cobrado por cor abaixo do limite de quantidade.',
            incremento: 5,
            minimo: 0,
            prefixo: 'R\$',
            onSave: (v) => _salvarConfig('matriz_padrao_50x60', v),
            onRestaurar: () => _restaurarPadrao('matriz_padrao_50x60'),
          ),
      ],
    );
  }

  Widget _secaoIdentidade(Map<String, Configuracao> porChave) {
    return _Secao(
      titulo: 'Identidade',
      descricao: 'Informações da empresa exibidas no app.',
      children: [
        if (porChave['empresa_nome'] != null)
          _TextoField(
            config: porChave['empresa_nome']!,
            label: 'Nome da empresa',
            descricao: 'Aparece no cabeçalho e em documentos futuros.',
            onSave: (v) => _salvarConfig('empresa_nome', v),
            onRestaurar: () => _restaurarPadrao('empresa_nome'),
          ),
      ],
    );
  }

  Widget _secaoLotes(Map<String, Configuracao> porChave) {
    return _Secao(
      titulo: 'Numeração de lotes',
      descricao: null,
      warning:
          'Mudanças aqui afetam só os pedidos futuros. Lotes existentes mantêm a numeração original.',
      children: [
        if (porChave['lote_prefixo'] != null)
          _TextoField(
            config: porChave['lote_prefixo']!,
            label: 'Prefixo',
            descricao: 'Texto que aparece antes do número (ex: "LOTE").',
            maxLength: 10,
            onSave: (v) => _salvarConfig('lote_prefixo', v),
            onRestaurar: () => _restaurarPadrao('lote_prefixo'),
          ),
        if (porChave['lote_digitos'] != null)
          _StepperField(
            config: porChave['lote_digitos']!,
            label: 'Dígitos',
            descricao: 'Quantos números após o prefixo (ex: 4 → 0042).',
            incremento: 1,
            minimo: 2,
            maximo: 8,
            sufixo: 'díg',
            onSave: (v) => _salvarConfig('lote_digitos', v),
            onRestaurar: () => _restaurarPadrao('lote_digitos'),
          ),
        _LinhaInfo(
          label: 'Próximo lote a ser gerado',
          valor: _proximoLote != null ? _formatarProximoLote(porChave) : '—',
          descricao: 'Atualiza automaticamente a cada pedido novo.',
        ),
      ],
    );
  }

  Widget _secaoAparencia() {
    final modo = ref.watch(themeModeProvider);
    return _Secao(
      titulo: 'Aparência',
      descricao: null,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tema do aplicativo',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Claro, escuro ou seguir o sistema operacional.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SegmentedButton<ThemeMode>(
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined, size: 14),
                    label: Text('Claro'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined, size: 14),
                    label: Text('Escuro'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_outlined, size: 14),
                    label: Text('Auto'),
                  ),
                ],
                selected: {modo},
                onSelectionChanged: (s) {
                  ref.read(themeModeProvider.notifier).state = s.first;
                  saveThemeMode(s.first);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _secaoAvancado() {
    final versaoServidor = _status?.versao;
    return _Secao(
      titulo: 'Avançado',
      descricao: 'URL do servidor e informações técnicas.',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _serverUrlCtl,
                decoration: InputDecoration(
                  labelText: 'URL do servidor',
                  hintText: 'http://10.150.60.100:8080',
                  prefixIcon: const Icon(Icons.link_outlined, size: 18),
                  isDense: true,
                  suffixIcon: _serverUrlCtl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => setState(() => _serverUrlCtl.clear()),
                          visualDensity: VisualDensity.compact,
                          splashRadius: 16,
                          tooltip: 'Limpar',
                        )
                      : null,
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _testando ? null : _testarConexao,
                    icon: _testando
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_tethering, size: 16),
                    label: const Text('Testar', style: TextStyle(fontSize: 12.5)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _salvarUrl,
                    icon: const Icon(Icons.save_outlined, size: 16),
                    label: const Text('Salvar URL', style: TextStyle(fontSize: 12.5)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const _Divisor(),
        _LinhaInfo(label: 'Versão do app', valor: _appVersao),
        _LinhaInfo(label: 'Versão do servidor', valor: versaoServidor ?? '—'),
      ],
    );
  }

  Widget _botaoRestaurarTudo() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: OutlinedButton.icon(
        onPressed: _confirmarRestaurarTudo,
        icon: Icon(Icons.restart_alt, size: 16, color: cs.error),
        label: Text(
          'Restaurar regras aos padrões',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: cs.error,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
    );
  }

  Future<void> _confirmarRestaurarTudo() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Restaurar todas as regras?'),
        content: const Text(
          'Todas as regras de produção, cálculo de preço, identidade e lotes voltarão aos valores padrão de fábrica. Essa ação não pode ser desfeita.',
        ),
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
            child: const Text('Restaurar tudo'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    for (final entry in _defaultsConfig.entries) {
      try {
        await ref
            .read(apiClientProvider)
            .atualizarConfiguracao(entry.key, entry.value);
      } catch (_) {/* continua nas outras chaves mesmo se falhar */}
    }
    ref.invalidate(configuracoesProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Padrões restaurados'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Ações ───────────────────────────────────────────────────────────────

  Future<void> _salvarConfig(String chave, String novoValor) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(apiClientProvider).atualizarConfiguracao(chave, novoValor);
      ref.invalidate(configuracoesProvider);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erro: $e', style: const TextStyle(fontSize: 12.5)),
          behavior: SnackBarBehavior.floating,
        ),
      );
      rethrow;
    }
  }

  Future<void> _restaurarPadrao(String chave) async {
    final padrao = _defaultsConfig[chave];
    if (padrao == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Restaurar padrão?'),
        content: Text('O valor desta regra voltará para "$padrao".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _salvarConfig(chave, padrao);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  String? _previewPct(String valorStr, String tipo) {
    final pct = int.tryParse(valorStr);
    if (pct == null || pct == 0) return null;
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);
    final base = 1000.0;
    final resultado = base * (1 + pct / 100);
    final prefixo = switch (tipo) {
      'urgente' => 'Um pedido urgente de',
      'aberto' => 'Um moletom aberto de',
      'fechado' => 'Um moletom fechado de',
      _ => 'Um pedido de',
    };
    return '$prefixo ${moeda.format(base)} ficaria ${moeda.format(resultado)}';
  }

  String _formatarProximoLote(Map<String, Configuracao> porChave) {
    final prefix = porChave['lote_prefixo']?.valor ?? 'LOTE';
    final digitos = int.tryParse(porChave['lote_digitos']?.valor ?? '4') ?? 4;
    return '$prefix${_proximoLote.toString().padLeft(digitos, '0')}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  STATUS CARD (banner do servidor)
// ═══════════════════════════════════════════════════════════════════════════

class _StatusCard extends StatelessWidget {
  final ServerHealth? status;
  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final Color dot;
    final String label;
    final String sub;
    if (status == null) {
      dot = cs.outline;
      label = 'Verificando conexão...';
      sub = '';
    } else if (status!.online) {
      dot = cs.primary;
      label = 'Servidor online';
      sub = '${status!.latenciaMs}ms · resposta rápida';
    } else {
      dot = cs.error;
      label = 'Sem conexão com o servidor';
      sub = 'Verifique a URL em Avançado.';
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dot, borderRadius: BorderRadius.circular(5)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    letterSpacing: -0.1,
                  ),
                ),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SEÇÃO (com título + descrição opcional + warning opcional + filhos)
// ═══════════════════════════════════════════════════════════════════════════

class _Secao extends StatelessWidget {
  final String titulo;
  final String? descricao;
  final String? warning;
  final List<Widget> children;

  const _Secao({
    required this.titulo,
    required this.descricao,
    this.warning,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 18, descricao == null ? 12 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: cs.onSurface,
                  ),
                ),
                if (descricao != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    descricao!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (warning != null)
            Container(
              margin: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: cs.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warning!,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: cs.onErrorContainer,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Container(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1) const _Divisor(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Divisor extends StatelessWidget {
  const _Divisor();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Container(
        height: 1,
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CAMPOS (stepper numérico / bool / texto / info readonly)
// ═══════════════════════════════════════════════════════════════════════════

/// Layout base de um "item de config" — label em cima, descrição embaixo,
/// controle à direita. Mantém tudo respirando sem apertar.
class _LinhaConfig extends StatelessWidget {
  final String label;
  final String? descricao;
  final Widget controle;
  final bool podeRestaurar;
  final VoidCallback? onRestaurar;
  final Widget? extra;

  const _LinhaConfig({
    required this.label,
    required this.descricao,
    required this.controle,
    this.podeRestaurar = false,
    this.onRestaurar,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final texto = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                            height: 1.25,
                          ),
                        ),
                      ),
                      if (podeRestaurar) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Restaurar padrão',
                          child: InkWell(
                            onTap: onRestaurar,
                            borderRadius: BorderRadius.circular(999),
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: Icon(Icons.restart_alt, size: 13, color: cs.outline),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (descricao != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      descricao!,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: cs.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              );
              final estreito = c.maxWidth < 460;
              if (estreito) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    texto,
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerLeft, child: controle),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: texto),
                  const SizedBox(width: 12),
                  controle,
                ],
              );
            },
          ),
          if (extra != null) ...[
            const SizedBox(height: 8),
            extra!,
          ],
        ],
      ),
    );
  }
}

/// Stepper `[-] valor [+]` com prefixo/sufixo e valor central editável.
class _StepperField extends StatefulWidget {
  final Configuracao config;
  final String label;
  final String? descricao;
  final int incremento;
  final int? minimo;
  final int? maximo;
  final String? prefixo; // "R$"
  final String? sufixo; // "%", "dias"
  final String? preview; // texto abaixo do controle (opcional)
  final Future<void> Function(String) onSave;
  final VoidCallback onRestaurar;

  const _StepperField({
    required this.config,
    required this.label,
    required this.descricao,
    required this.incremento,
    required this.onSave,
    required this.onRestaurar,
    this.minimo,
    this.maximo,
    this.prefixo,
    this.sufixo,
    this.preview,
  });

  @override
  State<_StepperField> createState() => _StepperFieldState();
}

class _StepperFieldState extends State<_StepperField> {
  late final TextEditingController _ctl;
  late String _ultimoSalvo;
  FocusNode? _focus;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.config.valor);
    _ultimoSalvo = widget.config.valor;
    _focus = FocusNode();
    _focus!.addListener(() {
      // Ao tirar o foco, salva se mudou.
      if (!_focus!.hasFocus) _salvarSeMudou();
    });
  }

  @override
  void didUpdateWidget(covariant _StepperField old) {
    super.didUpdateWidget(old);
    if (widget.config.valor != _ultimoSalvo) {
      _ultimoSalvo = widget.config.valor;
      if (!_focus!.hasFocus) _ctl.text = widget.config.valor;
    }
  }

  @override
  void dispose() {
    _focus?.dispose();
    _ctl.dispose();
    super.dispose();
  }

  void _bump(int delta) {
    final atual = int.tryParse(_ctl.text.trim()) ?? 0;
    var novo = atual + delta;
    if (widget.minimo != null && novo < widget.minimo!) novo = widget.minimo!;
    if (widget.maximo != null && novo > widget.maximo!) novo = widget.maximo!;
    _ctl.text = novo.toString();
    _ctl.selection = TextSelection.collapsed(offset: _ctl.text.length);
    _salvarSeMudou();
  }

  Future<void> _salvarSeMudou() async {
    final v = _ctl.text.trim();
    if (v == _ultimoSalvo) return;
    if (v.isEmpty) {
      // Reverte pra último salvo — não salva vazio.
      _ctl.text = _ultimoSalvo;
      return;
    }
    try {
      await widget.onSave(v);
      if (mounted) _ultimoSalvo = v;
    } catch (_) {
      if (mounted) _ctl.text = _ultimoSalvo;
    }
  }

  bool get _podeRestaurar {
    final padrao = _defaultsConfig[widget.config.chave];
    if (padrao == null) return false;
    return padrao != widget.config.valor;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final preview = widget.preview;
    return _LinhaConfig(
      label: widget.label,
      descricao: widget.descricao,
      podeRestaurar: _podeRestaurar,
      onRestaurar: widget.onRestaurar,
      extra: preview != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lightbulb_outline, size: 12, color: cs.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      preview,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface,
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
      controle: Container(
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        height: 40,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepBtn(
              icon: Icons.remove,
              onTap: () => _bump(-widget.incremento),
              canto: _StepCanto.esquerdo,
            ),
            Container(width: 1, height: 22, color: cs.outlineVariant.withValues(alpha: 0.5)),
            IntrinsicWidth(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 72),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.prefixo != null) ...[
                        Text(
                          widget.prefixo!,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: TextField(
                          controller: _ctl,
                          focusNode: _focus,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            isDense: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          onSubmitted: (_) => _salvarSeMudou(),
                        ),
                      ),
                      if (widget.sufixo != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          widget.sufixo!,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Container(width: 1, height: 22, color: cs.outlineVariant.withValues(alpha: 0.5)),
            _StepBtn(
              icon: Icons.add,
              onTap: () => _bump(widget.incremento),
              canto: _StepCanto.direito,
            ),
          ],
        ),
      ),
    );
  }
}

enum _StepCanto { esquerdo, direito }

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final _StepCanto canto;
  const _StepBtn({required this.icon, required this.onTap, required this.canto});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final raio = canto == _StepCanto.esquerdo
        ? const BorderRadius.horizontal(left: Radius.circular(7))
        : const BorderRadius.horizontal(right: Radius.circular(7));
    return InkWell(
      onTap: onTap,
      borderRadius: raio,
      child: SizedBox(
        width: 34,
        height: 40,
        child: Icon(icon, size: 16, color: cs.onSurfaceVariant),
      ),
    );
  }
}

class _BoolField extends StatefulWidget {
  final Configuracao config;
  final String label;
  final String? descricao;
  final Future<void> Function(String) onSave;
  final VoidCallback onRestaurar;

  const _BoolField({
    required this.config,
    required this.label,
    required this.descricao,
    required this.onSave,
    required this.onRestaurar,
  });

  @override
  State<_BoolField> createState() => _BoolFieldState();
}

class _BoolFieldState extends State<_BoolField> {
  late bool _valor;

  @override
  void initState() {
    super.initState();
    _valor = widget.config.asBool;
  }

  @override
  void didUpdateWidget(covariant _BoolField old) {
    super.didUpdateWidget(old);
    if (widget.config.valor != old.config.valor) {
      _valor = widget.config.asBool;
    }
  }

  bool get _podeRestaurar {
    final padrao = _defaultsConfig[widget.config.chave];
    if (padrao == null) return false;
    return padrao != widget.config.valor;
  }

  @override
  Widget build(BuildContext context) {
    return _LinhaConfig(
      label: widget.label,
      descricao: widget.descricao,
      podeRestaurar: _podeRestaurar,
      onRestaurar: widget.onRestaurar,
      controle: Switch(
        value: _valor,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onChanged: (v) async {
          final anterior = _valor;
          setState(() => _valor = v);
          try {
            await widget.onSave(v ? 'true' : 'false');
          } catch (_) {
            if (mounted) setState(() => _valor = anterior);
          }
        },
      ),
    );
  }
}

class _TextoField extends StatefulWidget {
  final Configuracao config;
  final String label;
  final String? descricao;
  final int? maxLength;
  final Future<void> Function(String) onSave;
  final VoidCallback onRestaurar;

  const _TextoField({
    required this.config,
    required this.label,
    required this.descricao,
    required this.onSave,
    required this.onRestaurar,
    this.maxLength,
  });

  @override
  State<_TextoField> createState() => _TextoFieldState();
}

class _TextoFieldState extends State<_TextoField> {
  late final TextEditingController _ctl;
  late final FocusNode _focus;
  late String _ultimoSalvo;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.config.valor);
    _ultimoSalvo = widget.config.valor;
    _focus = FocusNode();
    _focus.addListener(() {
      if (!_focus.hasFocus) _salvarSeMudou();
    });
  }

  @override
  void didUpdateWidget(covariant _TextoField old) {
    super.didUpdateWidget(old);
    if (widget.config.valor != _ultimoSalvo) {
      _ultimoSalvo = widget.config.valor;
      if (!_focus.hasFocus) _ctl.text = widget.config.valor;
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _salvarSeMudou() async {
    final v = _ctl.text.trim();
    if (v == _ultimoSalvo) return;
    if (v.isEmpty) {
      _ctl.text = _ultimoSalvo;
      return;
    }
    try {
      await widget.onSave(v);
      if (mounted) _ultimoSalvo = v;
    } catch (_) {
      if (mounted) _ctl.text = _ultimoSalvo;
    }
  }

  bool get _podeRestaurar {
    final padrao = _defaultsConfig[widget.config.chave];
    if (padrao == null) return false;
    return padrao != widget.config.valor;
  }

  @override
  Widget build(BuildContext context) {
    return _LinhaConfig(
      label: widget.label,
      descricao: widget.descricao,
      podeRestaurar: _podeRestaurar,
      onRestaurar: widget.onRestaurar,
      controle: SizedBox(
        width: 220,
        child: TextField(
          controller: _ctl,
          focusNode: _focus,
          maxLength: widget.maxLength,
          decoration: InputDecoration(
            isDense: true,
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          onSubmitted: (_) => _salvarSeMudou(),
        ),
      ),
    );
  }
}

/// Linha readonly — usada pra mostrar info ("próximo lote", versão etc).
class _LinhaInfo extends StatelessWidget {
  final String label;
  final String valor;
  final String? descricao;

  const _LinhaInfo({
    required this.label,
    required this.valor,
    this.descricao,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                if (descricao != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    descricao!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            valor,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: cs.primary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SKELETONS
// ═══════════════════════════════════════════════════════════════════════════

class _CarregandoSecoes extends StatelessWidget {
  const _CarregandoSecoes();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (var i = 0; i < 3; i++) ...[
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          if (i < 2) const SizedBox(height: 16),
        ],
      ],
    );
  }
}
