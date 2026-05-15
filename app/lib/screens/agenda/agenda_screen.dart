import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/agenda.dart';
import '../../models/pedido.dart';
import '../../state/agenda_provider.dart';
import '../../theme/breakpoints.dart';
import '../../util/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pedido_row.dart';
import '../../widgets/shimmer_skeleton.dart';
import '../../widgets/status_pill.dart';

enum _Modo { lista, semana, mes }

class AgendaScreen extends ConsumerStatefulWidget {
  /// Data inicial opcional (`?dia=YYYY-MM-DD`). Quando informada, centraliza
  /// na semana correspondente e troca pro modo semana se estiver fora da janela
  /// padrão "hoje+14 dias" da lista.
  final DateTime? diaInicial;

  const AgendaScreen({super.key, this.diaInicial});

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
  late _Modo _modo;
  // Referência do período selecionado — usado pelos modos Semana e Mês.
  late DateTime _referencia;

  @override
  void initState() {
    super.initState();
    final hoje = DateTime.now();
    final inicial = widget.diaInicial;
    _referencia = inicial ?? hoje;
    if (inicial == null) {
      _modo = _Modo.lista;
    } else {
      final hojeMid = DateTime(hoje.year, hoje.month, hoje.day);
      final alvo = DateTime(inicial.year, inicial.month, inicial.day);
      final diff = alvo.difference(hojeMid).inDays;
      // Lista cobre hoje + 13 dias; fora dessa janela, semana fica mais útil.
      _modo = (diff >= 0 && diff <= 13) ? _Modo.lista : _Modo.semana;
    }
  }

  String _yyyymmdd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _criarPedidoNoDia(DateTime dia) {
    context.push('/pedidos/novo?data_producao=${_yyyymmdd(dia)}&auto_agendar=false');
  }

  AgendaRange _rangeDoModo() {
    final hoje = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    switch (_modo) {
      case _Modo.lista:
        // Lista começa em hoje e mostra 14 dias à frente.
        return AgendaRange(hoje, hoje.add(const Duration(days: 13)));
      case _Modo.semana:
        final seg = _referencia.subtract(Duration(days: _referencia.weekday - 1));
        final monday = DateTime(seg.year, seg.month, seg.day);
        return AgendaRange(monday, monday.add(const Duration(days: 6)));
      case _Modo.mes:
        final inicio = DateTime(_referencia.year, _referencia.month, 1);
        final fim = DateTime(_referencia.year, _referencia.month + 1, 0);
        return AgendaRange(inicio, fim);
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = _rangeDoModo();
    final async = ref.watch(agendaOcupacaoProvider(range));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
        ],
      ),
      body: async.when(
        loading: () => const _LoadingState(),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(agendaOcupacaoProvider(range)),
        ),
        data: (dados) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(agendaOcupacaoProvider(range)),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                children: [
                  _ModoSelector(
                    modo: _modo,
                    onChanged: (m) => setState(() => _modo = m),
                    referencia: _referencia,
                    onReferenciaChange: (d) => setState(() => _referencia = d),
                    semData: dados.semData,
                  ),
                  Expanded(
                    child: _corpoPorModo(dados, constraints),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _corpoPorModo(AgendaOcupacao dados, BoxConstraints constraints) {
    switch (_modo) {
      case _Modo.lista:
        return _ModoListaView(
          dados: dados,
          onCriarNoDia: _criarPedidoNoDia,
        );
      case _Modo.semana:
        return _ModoSemanaView(
          dados: dados,
          onCriarNoDia: _criarPedidoNoDia,
          larguraTotal: constraints.maxWidth,
        );
      case _Modo.mes:
        return _ModoMesView(
          dados: dados,
          referencia: _referencia,
          onCriarNoDia: _criarPedidoNoDia,
        );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SELETOR DE MODO (header da agenda)
// ═══════════════════════════════════════════════════════════════════════════

class _ModoSelector extends StatelessWidget {
  final _Modo modo;
  final ValueChanged<_Modo> onChanged;
  final DateTime referencia;
  final ValueChanged<DateTime> onReferenciaChange;
  final int semData;

  const _ModoSelector({
    required this.modo,
    required this.onChanged,
    required this.referencia,
    required this.onReferenciaChange,
    required this.semData,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        children: [
          Row(
            children: [
              SegmentedButton<_Modo>(
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                segments: const [
                  ButtonSegment(value: _Modo.lista, icon: Icon(Icons.view_list_outlined, size: 16), label: Text('Lista')),
                  ButtonSegment(value: _Modo.semana, icon: Icon(Icons.view_week_outlined, size: 16), label: Text('Semana')),
                  ButtonSegment(value: _Modo.mes, icon: Icon(Icons.calendar_month_outlined, size: 16), label: Text('Mês')),
                ],
                selected: {modo},
                onSelectionChanged: (s) => onChanged(s.first),
              ),
              const Spacer(),
              if (modo == _Modo.semana || modo == _Modo.mes)
                _NavPeriodo(
                  modo: modo,
                  referencia: referencia,
                  onChange: onReferenciaChange,
                ),
            ],
          ),
          if (semData > 0) ...[
            const SizedBox(height: 8),
            _SemDataBanner(quantidade: semData),
          ],
        ],
      ),
    );
  }
}

class _NavPeriodo extends StatelessWidget {
  final _Modo modo;
  final DateTime referencia;
  final ValueChanged<DateTime> onChange;

  const _NavPeriodo({
    required this.modo,
    required this.referencia,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final diaNum = AppFormatters.dataCurta;
    final mesAno = DateFormat("MMMM' 'y", 'pt_BR');

    String label;
    if (modo == _Modo.semana) {
      final seg = referencia.subtract(Duration(days: referencia.weekday - 1));
      final dom = seg.add(const Duration(days: 6));
      label = '${diaNum.format(seg)} – ${diaNum.format(dom)}';
    } else {
      label = toBeginningOfSentenceCase(mesAno.format(referencia)) ?? '';
    }

    Duration delta() => modo == _Modo.semana
        ? const Duration(days: 7)
        : Duration(days: DateTime(referencia.year, referencia.month + 1, 0).day);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, size: 20),
          visualDensity: VisualDensity.compact,
          tooltip: modo == _Modo.semana ? 'Semana anterior' : 'Mês anterior',
          onPressed: () {
            if (modo == _Modo.semana) {
              onChange(referencia.subtract(delta()));
            } else {
              onChange(DateTime(referencia.year, referencia.month - 1, 1));
            }
          },
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 120),
          child: Container(
            key: ValueKey(label),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, size: 20),
          visualDensity: VisualDensity.compact,
          tooltip: modo == _Modo.semana ? 'Próxima semana' : 'Próximo mês',
          onPressed: () {
            if (modo == _Modo.semana) {
              onChange(referencia.add(delta()));
            } else {
              onChange(DateTime(referencia.year, referencia.month + 1, 1));
            }
          },
        ),
        TextButton.icon(
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          onPressed: () => onChange(DateTime.now()),
          icon: const Icon(Icons.today, size: 14),
          label: const Text('Hoje', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

class _SemDataBanner extends StatelessWidget {
  final int quantidade;
  const _SemDataBanner({required this.quantidade});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.tertiaryContainer.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => context.go('/pedidos'),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.tertiary.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(Icons.event_busy_outlined, size: 16, color: cs.onTertiaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$quantidade pedido${quantidade == 1 ? '' : 's'} sem data de produção',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: cs.onTertiaryContainer,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward, size: 14, color: cs.onTertiaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  MODO LISTA (timeline) — hoje no topo, 14 dias à frente, dias vazios visíveis
// ═══════════════════════════════════════════════════════════════════════════

class _ModoListaView extends StatelessWidget {
  final AgendaOcupacao dados;
  final void Function(DateTime) onCriarNoDia;

  const _ModoListaView({
    required this.dados,
    required this.onCriarNoDia,
  });

  /// Agrupa sequências de dias vazios consecutivos em uma única linha resumo.
  /// Dia de "hoje" nunca é colapsado mesmo se vazio — é o mais importante.
  List<_ItemLista> _agrupar(AgendaOcupacao dados) {
    final hojeStr = _chaveData(DateTime.now());
    final items = <_ItemLista>[];
    final List<DiaAgenda> runVazios = [];

    void flushVazios() {
      if (runVazios.isEmpty) return;
      if (runVazios.length == 1) {
        items.add(_ItemLista.dia(runVazios.first));
      } else {
        items.add(_ItemLista.gap(runVazios.first.data, runVazios.last.data));
      }
      runVazios.clear();
    }

    for (final d in dados.dias) {
      final isHoje = _chaveData(d.data) == hojeStr;
      if (d.vazio && !isHoje) {
        runVazios.add(d);
      } else {
        flushVazios();
        items.add(_ItemLista.dia(d));
      }
    }
    flushVazios();
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final hojeStr = _chaveData(DateTime.now());
    final items = _agrupar(dados);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        if (item.gap != null) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _GapVazio(
              inicio: item.gap!.$1,
              fim: item.gap!.$2,
              onCriar: onCriarNoDia,
            ),
          );
        }
        final dia = item.dia!;
        final isHoje = _chaveData(dia.data) == hojeStr;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _DiaListaCard(
            dia: dia,
            isHoje: isHoje,
            onCriarPedido: () => onCriarNoDia(dia.data),
          ),
        );
      },
    );
  }
}

/// Discriminated union: ou é um dia concreto, ou é um intervalo vazio.
class _ItemLista {
  final DiaAgenda? dia;
  final (DateTime, DateTime)? gap;
  const _ItemLista._(this.dia, this.gap);
  factory _ItemLista.dia(DiaAgenda d) => _ItemLista._(d, null);
  factory _ItemLista.gap(DateTime inicio, DateTime fim) => _ItemLista._(null, (inicio, fim));
}

/// Linha compacta representando N dias vazios consecutivos.
class _GapVazio extends StatelessWidget {
  final DateTime inicio;
  final DateTime fim;
  final void Function(DateTime) onCriar;
  const _GapVazio({required this.inicio, required this.fim, required this.onCriar});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dias = fim.difference(inicio).inDays + 1;
    final diaNum = AppFormatters.dataCurta;
    return Material(
      color: cs.surfaceContainerLow.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => onCriar(inicio),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.45),
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.more_horiz, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                '$dias dias livres',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '· ${diaNum.format(inicio)} a ${diaNum.format(fim)}',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Icon(Icons.add, size: 14, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiaListaCard extends StatelessWidget {
  final DiaAgenda dia;
  final bool isHoje;
  final VoidCallback onCriarPedido;

  const _DiaListaCard({
    required this.dia,
    required this.isHoje,
    required this.onCriarPedido,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final moeda = AppFormatters.moedaInteira;
    final dataFmt = DateFormat("EEE', 'dd/MM", 'pt_BR');
    final labelData = _capitalizar(dataFmt.format(dia.data));
    final pct = (dia.pct).clamp(0.0, 1.0);

    final borderColor = isHoje
        ? cs.primary.withValues(alpha: 0.45)
        : cs.outlineVariant.withValues(alpha: 0.6);
    final borderWidth = isHoje ? 1.3 : 1.0;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header do dia — compacto, uma linha só
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
            child: Row(
              children: [
                if (isHoje)
                  Container(
                    margin: const EdgeInsets.only(right: 7),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'HOJE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: cs.onPrimaryContainer,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                Text(
                  labelData,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: isHoje ? cs.primary : cs.onSurface,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(width: 8),
                // Barra inline (ocupa o resto da linha)
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 4,
                      backgroundColor: cs.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(
                        dia.acima ? cs.error : (isHoje ? cs.primary : cs.primary.withValues(alpha: 0.65)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  moeda.format(dia.ocupado),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: dia.acima ? cs.error : cs.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  ' / ${moeda.format(dia.limite)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  tooltip: 'Adicionar pedido',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed: onCriarPedido,
                ),
              ],
            ),
          ),
          // Lista de pedidos (sem cabeçalho de tabela)
          if (dia.vazio)
            _DiaVazioInline(onCriar: onCriarPedido)
          else
            Column(
              children: [
                Container(height: 1, color: cs.outlineVariant.withValues(alpha: 0.35)),
                for (var i = 0; i < dia.pedidos.length; i++)
                  _AgendaLinha(
                    pedido: dia.pedidos[i],
                    zebra: i.isOdd,
                    isLast: i == dia.pedidos.length - 1,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Linha compacta de pedido pra timeline da agenda (modo Lista).
/// Foco em leitura rápida: lote + cliente + peça/qtd + valor + indicadores.
/// Sem colunas de status/pagto/data — o dia já é o contexto.
class _AgendaLinha extends StatelessWidget {
  final Pedido pedido;
  final bool zebra;
  final bool isLast;

  const _AgendaLinha({
    required this.pedido,
    required this.zebra,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final moeda = AppFormatters.moedaInteira;
    final hojeData = DateTime.now();
    final atrasado = pedido.dataEntregaCombinada != null &&
        !pedido.entregue &&
        pedido.dataEntregaCombinada!.isBefore(DateTime(hojeData.year, hojeData.month, hojeData.day));

    final accent = atrasado
        ? cs.error
        : (pedido.urgente ? cs.tertiary : Colors.transparent);

    final peca = [
      if (pedido.quantidade != null) '${pedido.quantidade}×',
      if (pedido.peca != null && pedido.peca!.isNotEmpty)
        pedido.peca!
      else
        pedido.descricao,
      if (pedido.tecnica != null) pedido.tecnica!,
    ].join(' · ');

    return Material(
      color: zebra ? cs.surfaceContainerLow.withValues(alpha: 0.5) : Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/pedidos/${pedido.id}?from=agenda'),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(width: 3, color: accent),
              bottom: isLast
                  ? BorderSide.none
                  : BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
            child: Row(
              children: [
                SizedBox(
                  width: 62,
                  child: Text(
                    pedido.loteFormatado,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  flex: 3,
                  child: Text(
                    pedido.clienteNome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: Text(
                    peca,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                if (pedido.urgente) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.local_fire_department, size: 13, color: cs.tertiary),
                ],
                const SizedBox(width: 8),
                Text(
                  moeda.format(pedido.valor),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _capitalizar(String s) {
  if (s.isEmpty) return s;
  // Remove pontos de "seg.", "ter.", etc. e coloca primeira em caixa alta.
  final limpo = s.replaceAll('.', '');
  return limpo[0].toUpperCase() + limpo.substring(1);
}

class _DiaVazioInline extends StatelessWidget {
  final VoidCallback onCriar;
  const _DiaVazioInline({required this.onCriar});

  @override
  Widget build(BuildContext context) {
    return EmptyState.inline(
      icon: Icons.add_circle_outline,
      titulo: 'Sem pedidos · toque para adicionar',
      onTap: onCriar,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  MODO SEMANA
// ═══════════════════════════════════════════════════════════════════════════

class _ModoSemanaView extends StatefulWidget {
  final AgendaOcupacao dados;
  final void Function(DateTime) onCriarNoDia;
  final double larguraTotal;

  const _ModoSemanaView({
    required this.dados,
    required this.onCriarNoDia,
    required this.larguraTotal,
  });

  @override
  State<_ModoSemanaView> createState() => _ModoSemanaViewState();
}

class _ModoSemanaViewState extends State<_ModoSemanaView> {
  late PageController _pc;
  final ScrollController _chipsCtl = ScrollController();
  int _paginaAtual = 0;

  @override
  void initState() {
    super.initState();
    final diasUteis = _filtrarUteis(widget.dados.dias);
    final hojeStr = _chaveData(DateTime.now());
    var inicial = diasUteis.indexWhere((d) => _chaveData(d.data) == hojeStr);
    if (inicial < 0) inicial = 0;
    _paginaAtual = inicial;
    _pc = PageController(initialPage: inicial);
  }

  @override
  void didUpdateWidget(covariant _ModoSemanaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ao navegar pra outra semana, reposicionar o PageView na segunda-feira.
    if (oldWidget.dados != widget.dados) {
      _paginaAtual = 0;
      if (_pc.hasClients) {
        _pc.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _pc.dispose();
    _chipsCtl.dispose();
    super.dispose();
  }

  void _centralizarChip(int i) {
    if (!_chipsCtl.hasClients) return;
    // Material 3: a tab selecionada deve sempre estar visível.
    const larguraEstimadaChip = 110.0; // chip largura média + gap
    final alvo = (i * larguraEstimadaChip) - 80.0;
    final destino = alvo.clamp(0.0, _chipsCtl.position.maxScrollExtent);
    _chipsCtl.animateTo(
      destino,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  List<DiaAgenda> _filtrarUteis(List<DiaAgenda> dias) {
    return dias.where((d) => d.data.weekday >= 1 && d.data.weekday <= 5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final diasUteis = _filtrarUteis(widget.dados.dias);
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        // ≥1200: 5 colunas expandidas ocupando tudo.
        if (constraints.maxWidth >= AppBreakpoints.extraWide) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < diasUteis.length; i++) ...[
                  Expanded(
                    child: _ColunaSemana(
                      dia: diasUteis[i],
                      onCriar: () => widget.onCriarNoDia(diasUteis[i].data),
                    ),
                  ),
                  if (i < diasUteis.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          );
        }
        // 720-1200: scroll horizontal com colunas de 280px.
        if (constraints.maxWidth >= AppBreakpoints.compact) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < diasUteis.length; i++) ...[
                  SizedBox(
                    width: 280,
                    height: constraints.maxHeight - 30,
                    child: _ColunaSemana(
                      dia: diasUteis[i],
                      onCriar: () => widget.onCriarNoDia(diasUteis[i].data),
                    ),
                  ),
                  if (i < diasUteis.length - 1) const SizedBox(width: 10),
                ],
              ],
            ),
          );
        }
        // Mobile: PageView com chips indicando o dia.
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  controller: _chipsCtl,
                  scrollDirection: Axis.horizontal,
                  itemCount: diasUteis.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final dia = diasUteis[i];
                    final sel = i == _paginaAtual;
                    final hojeStr = _chaveData(DateTime.now());
                    final isHoje = _chaveData(dia.data) == hojeStr;
                    return FilterChip(
                      selected: sel,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      avatar: isHoje && !sel
                          ? Icon(Icons.today, size: 14, color: cs.primary)
                          : null,
                      label: Text(
                        '${_curto(dia.data)} ${AppFormatters.dataCurta.format(dia.data)}',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                      onSelected: (_) {
                        _pc.animateToPage(i,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut);
                      },
                    );
                  },
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: diasUteis.length,
                onPageChanged: (i) {
                  setState(() => _paginaAtual = i);
                  WidgetsBinding.instance.addPostFrameCallback((_) => _centralizarChip(i));
                },
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                  child: _ColunaSemana(
                    dia: diasUteis[i],
                    onCriar: () => widget.onCriarNoDia(diasUteis[i].data),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ColunaSemana extends StatelessWidget {
  final DiaAgenda dia;
  final VoidCallback onCriar;

  const _ColunaSemana({required this.dia, required this.onCriar});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final moeda = AppFormatters.moedaInteira;
    final hoje = DateTime.now();
    final isHoje = dia.data.year == hoje.year &&
        dia.data.month == hoje.month &&
        dia.data.day == hoje.day;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHoje ? cs.primary.withValues(alpha: 0.5) : cs.outlineVariant.withValues(alpha: 0.6),
          width: isHoje ? 1.3 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header da coluna
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isHoje ? cs.primaryContainer.withValues(alpha: 0.5) : cs.surfaceContainerLow,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              children: [
                Text(
                  _curto(dia.data),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: isHoje ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  AppFormatters.dataCurta.format(dia.data),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isHoje ? cs.onPrimaryContainer : cs.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                if (dia.pedidos.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${dia.pedidos.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Barra de ocupação
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: dia.pct.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  dia.acima ? cs.error : (isHoje ? cs.primary : cs.primary.withValues(alpha: 0.65)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
            child: Text(
              '${moeda.format(dia.ocupado)} / ${moeda.format(dia.limite)}',
              style: TextStyle(
                fontSize: 12,
                color: dia.acima ? cs.error : cs.onSurfaceVariant,
                fontWeight: dia.acima ? FontWeight.w800 : FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 0.5),
          // Lista de pedidos (ou empty clicável)
          Expanded(
            child: dia.vazio
                ? InkWell(
                    onTap: onCriar,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_circle_outline, size: 22, color: cs.onSurfaceVariant),
                          const SizedBox(height: 4),
                          Text(
                            'Adicionar',
                            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(6),
                    itemCount: dia.pedidos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (_, i) => _MiniPedido(pedido: dia.pedidos[i]),
                  ),
          ),
          if (!dia.vazio)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: TextButton.icon(
                onPressed: onCriar,
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Adicionar', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Linha compacta de pedido pra coluna de semana (menor que PedidoRow).
class _MiniPedido extends StatelessWidget {
  final Pedido pedido;
  const _MiniPedido({required this.pedido});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final moeda = AppFormatters.moedaInteira;
    return Material(
      color: pedido.urgente
          ? cs.errorContainer.withValues(alpha: 0.35)
          : cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: () => context.push('/pedidos/${pedido.id}?from=agenda'),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(7, 5, 7, 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    pedido.loteFormatado,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  if (pedido.urgente)
                    Icon(Icons.local_fire_department, size: 11, color: cs.error),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                pedido.clienteNome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        if (pedido.quantidade != null) '${pedido.quantidade}x',
                        if (pedido.tecnica != null) pedido.tecnica!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ),
                  Text(
                    moeda.format(pedido.valor),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              if (pedido.status != 'pendente' && pedido.status != 'agendado') ...[
                const SizedBox(height: 3),
                StatusPill(status: pedido.status, small: true),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  MODO MÊS — calendário com heatmap de ocupação
// ═══════════════════════════════════════════════════════════════════════════

class _ModoMesView extends StatefulWidget {
  final AgendaOcupacao dados;
  final DateTime referencia;
  final void Function(DateTime) onCriarNoDia;

  const _ModoMesView({
    required this.dados,
    required this.referencia,
    required this.onCriarNoDia,
  });

  @override
  State<_ModoMesView> createState() => _ModoMesViewState();
}

class _ModoMesViewState extends State<_ModoMesView> {
  DateTime? _diaSelecionado;

  @override
  void didUpdateWidget(covariant _ModoMesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.referencia.year != widget.referencia.year ||
        oldWidget.referencia.month != widget.referencia.month) {
      // Ao mudar de mês, descelecionar o dia.
      _diaSelecionado = null;
    }
  }

  DiaAgenda? _buscarDia(DateTime d) {
    final chave = _chaveData(d);
    for (final dia in widget.dados.dias) {
      if (_chaveData(dia.data) == chave) return dia;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Em desktop ≥1100, split: calendário à esquerda + detalhe à direita.
        if (constraints.maxWidth >= AppBreakpoints.wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: _Calendario(
                  referencia: widget.referencia,
                  dados: widget.dados,
                  diaSelecionado: _diaSelecionado,
                  onSelecionar: (d) => setState(() => _diaSelecionado = d),
                ),
              ),
              Container(
                width: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              Expanded(
                flex: 2,
                child: _DetalheDia(
                  dia: _diaSelecionado != null ? _buscarDia(_diaSelecionado!) : null,
                  dataSelecionada: _diaSelecionado,
                  onCriar: widget.onCriarNoDia,
                ),
              ),
            ],
          );
        }
        // Mobile/tablet: calendário em cima, detalhe rolável embaixo.
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            _Calendario(
              referencia: widget.referencia,
              dados: widget.dados,
              diaSelecionado: _diaSelecionado,
              onSelecionar: (d) => setState(() => _diaSelecionado = d),
            ),
            const SizedBox(height: 14),
            if (_diaSelecionado != null)
              _DetalheDia(
                dia: _buscarDia(_diaSelecionado!),
                dataSelecionada: _diaSelecionado,
                onCriar: widget.onCriarNoDia,
                embutido: true,
              ),
          ],
        );
      },
    );
  }
}

class _Calendario extends StatelessWidget {
  final DateTime referencia;
  final AgendaOcupacao dados;
  final DateTime? diaSelecionado;
  final void Function(DateTime) onSelecionar;

  const _Calendario({
    required this.referencia,
    required this.dados,
    required this.diaSelecionado,
    required this.onSelecionar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primeiroDiaMes = DateTime(referencia.year, referencia.month, 1);
    // Começar na segunda anterior (weekday 1=seg ... 7=dom).
    final offset = primeiroDiaMes.weekday - 1;
    final inicioGrid = primeiroDiaMes.subtract(Duration(days: offset));
    final ultimoDiaMes = DateTime(referencia.year, referencia.month + 1, 0);
    // Total de células: múltiplo de 7 cobrindo até o último dia do mês.
    final diasTotais = ultimoDiaMes.difference(inicioGrid).inDays + 1;
    final celulas = ((diasTotais + 6) ~/ 7) * 7;

    const diasSemana = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header dos dias da semana
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      diasSemana[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: i >= 5
                            ? cs.onSurfaceVariant.withValues(alpha: 0.7)
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Grid do mês
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 0.95,
            ),
            itemCount: celulas,
            itemBuilder: (_, i) {
              final data = inicioGrid.add(Duration(days: i));
              final dentroMes = data.month == referencia.month;
              final dia = _buscarDia(data);
              return _CelulaDia(
                data: data,
                dia: dia,
                dentroMes: dentroMes,
                selecionado: diaSelecionado != null &&
                    _chaveData(diaSelecionado!) == _chaveData(data),
                isHoje: _chaveData(data) == _chaveData(DateTime.now()),
                onTap: () => onSelecionar(data),
              );
            },
          ),
          const SizedBox(height: 10),
          _Legenda(),
        ],
      ),
    );
  }

  DiaAgenda? _buscarDia(DateTime d) {
    final chave = _chaveData(d);
    for (final dia in dados.dias) {
      if (_chaveData(dia.data) == chave) return dia;
    }
    return null;
  }
}

class _CelulaDia extends StatelessWidget {
  final DateTime data;
  final DiaAgenda? dia;
  final bool dentroMes;
  final bool selecionado;
  final bool isHoje;
  final VoidCallback onTap;

  const _CelulaDia({
    required this.data,
    required this.dia,
    required this.dentroMes,
    required this.selecionado,
    required this.isHoje,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final pct = dia?.pct ?? 0;
    final acima = dia?.acima ?? false;
    final numPedidos = dia?.pedidos.length ?? 0;

    // Heatmap: tons de primaryContainer conforme ocupação.
    // Dias fora do mês ficam num bg levemente acinzentado (em vez de alpha
    // no texto, que cairia para 2.21:1) e mantêm texto cheio em
    // onSurfaceVariant — distinguível dos dias do mês sem perder leitura.
    final Color bg;
    if (!dentroMes) {
      bg = cs.surfaceContainerLow;
    } else if (acima) {
      bg = cs.errorContainer.withValues(alpha: 0.55);
    } else if (pct <= 0) {
      bg = cs.surfaceContainerLowest;
    } else if (pct < 0.4) {
      bg = cs.primaryContainer.withValues(alpha: 0.2);
    } else if (pct < 0.75) {
      bg = cs.primaryContainer.withValues(alpha: 0.45);
    } else {
      bg = cs.primaryContainer.withValues(alpha: 0.75);
    }

    final Color fg = dentroMes ? cs.onSurface : cs.onSurfaceVariant;

    Color? borderColor;
    double borderWidth = 1;
    if (selecionado) {
      borderColor = cs.primary;
      borderWidth = 1.8;
    } else if (isHoje) {
      borderColor = cs.primary.withValues(alpha: 0.6);
      borderWidth = 1.3;
    } else {
      borderColor = cs.outlineVariant.withValues(alpha: 0.5);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${data.day}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isHoje ? FontWeight.w900 : FontWeight.w700,
                    color: isHoje ? cs.primary : fg,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                if (numPedidos > 0)
                  Text(
                    '$numPedidos',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: acima ? cs.error : cs.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const Spacer(),
            if (dia != null && pct > 0)
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: pct.clamp(0.0, 1.0),
                  minHeight: 3,
                  backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                  valueColor: AlwaysStoppedAnimation(
                    acima ? cs.error : cs.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Legenda extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget item(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(3),
                // SC 1.4.11 non-text contrast: borda visível >= 3:1.
                border: Border.all(color: cs.outline),
              ),
            ),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        );

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        item(cs.surfaceContainerLowest, 'vazio'),
        item(cs.primaryContainer.withValues(alpha: 0.2), '< 40%'),
        item(cs.primaryContainer.withValues(alpha: 0.45), '40–75%'),
        item(cs.primaryContainer.withValues(alpha: 0.75), '> 75%'),
        item(cs.errorContainer.withValues(alpha: 0.55), 'estourado'),
      ],
    );
  }
}

class _DetalheDia extends StatelessWidget {
  final DiaAgenda? dia;
  final DateTime? dataSelecionada;
  final void Function(DateTime) onCriar;
  final bool embutido;

  const _DetalheDia({
    required this.dia,
    required this.dataSelecionada,
    required this.onCriar,
    this.embutido = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (dataSelecionada == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Seta + ícone direcionam o olhar pro calendário à esquerda —
              // sem isso o usuário fica perdido com "Selecione um dia" solto.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_back, size: 22, color: cs.primary),
                  const SizedBox(width: 8),
                  Icon(Icons.calendar_today_outlined, size: 28, color: cs.primary),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Toque em um dia no calendário',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'O detalhe do dia aparece aqui.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    final data = dataSelecionada!;
    final dataFmt = DateFormat("EEEE', 'd 'de' MMMM", 'pt_BR');
    final moeda = AppFormatters.moedaInteira;
    final isHoje = _chaveData(data) == _chaveData(DateTime.now());

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (isHoje)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'HOJE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: cs.onPrimaryContainer,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        Flexible(
                          child: Text(
                            toBeginningOfSentenceCase(dataFmt.format(data)) ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isHoje ? cs.primary : cs.onSurface,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (dia != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${moeda.format(dia!.ocupado)} de ${moeda.format(dia!.limite)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: dia!.acima ? FontWeight.w800 : FontWeight.w600,
                          color: dia!.acima ? cs.error : cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                tooltip: 'Criar pedido neste dia',
                visualDensity: VisualDensity.compact,
                onPressed: () => onCriar(data),
              ),
            ],
          ),
        ),
        if (dia != null && dia!.pct > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: dia!.pct.clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  dia!.acima ? cs.error : cs.primary,
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        if (dia == null || dia!.vazio)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Column(
              children: [
                Icon(Icons.inbox_outlined, size: 28, color: cs.onSurfaceVariant),
                const SizedBox(height: 6),
                Text(
                  'Sem pedidos neste dia',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: () => onCriar(data),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Criar pedido', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
          )
        else ...[
          const PedidosHeader(),
          for (var i = 0; i < dia!.pedidos.length; i++)
            PedidoRow(
              pedido: dia!.pedidos[i],
              onTap: () => context.push('/pedidos/${dia!.pedidos[i].id}?from=agenda'),
              zebra: i.isOdd,
            ),
        ],
      ],
    );

    if (embutido) {
      return Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: content,
      );
    }

    return SingleChildScrollView(
      child: content,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  LOADING STATE
// ═══════════════════════════════════════════════════════════════════════════

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        ShimmerSkeleton(width: double.infinity, height: 40, borderRadius: BorderRadius.circular(8)),
        const SizedBox(height: 12),
        for (var i = 0; i < 4; i++) ...[
          ShimmerSkeleton(
            width: double.infinity,
            height: 140,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  UTILITÁRIOS
// ═══════════════════════════════════════════════════════════════════════════

String _chaveData(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Abreviação curta do dia da semana (pt_BR vem com ponto — tiramos e
/// caixamos alto pra ficar consistente).
String _curto(DateTime d) {
  final raw = AppFormatters.diaSemana.format(d);
  final sem = raw.replaceAll('.', '').trim();
  if (sem.isEmpty) return '';
  return sem[0].toUpperCase() + sem.substring(1).toLowerCase();
}
