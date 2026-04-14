# Prompts para continuar o app (um de cada vez)

Este arquivo tem **13 prompts independentes** pra completar a parte visual do app Flutter. Foram pensados pra uma IA com capacidade menor que Claude Opus — por isso cada prompt é **extremamente detalhado**, autocontido, e inclui todos os nomes de classes, campos e imports que ela vai precisar.

## Como usar

1. **Antes de cada prompt**, cole o bloco **"CONTEXTO COMPARTILHADO"** logo abaixo. Ele explica o projeto inteiro, o que já existe, convenções.
2. Cole o prompt numerado em seguida.
3. Execute **na ordem** — alguns dependem dos anteriores.
4. Depois de cada prompt, teste o app (`flutter run`) pra pegar erros cedo.

---

# CONTEXTO COMPARTILHADO (colar antes de todo prompt)

```
Projeto: app Flutter pra uma serigrafia (Serigrafia Baray). Substitui uma planilha Excel.
Stack: Flutter 3.41 + Dart 3.11, Material 3.
Dependências (já no pubspec): flutter_riverpod, go_router, dio, intl, shared_preferences, shimmer, flutter_localizations.

Diretório base do app: C:/Users/Leonardo/Documents/codigos/empresa/app
Diretório do servidor (backend REST, Dart+Shelf+SQLite): C:/Users/Leonardo/Documents/codigos/empresa/server
Servidor roda em https://server2.lbwma.com (configurável pelo usuário em Configurações).

COISAS QUE JÁ ESTÃO FEITAS — NÃO REFAZER:

Server (backend) — 100% pronto:
- server/lib/db.dart: sistema de migrations versionadas, 3 migrations aplicadas.
- server/lib/scheduling.dart: Agendador (agenda automaticamente respeitando limite_diario),
  CalculadoraOrcamento (aplica regras das configs), recalcularPagamento.
- server/lib/routes/pedidos.dart: CRUD + POST /pedidos/:id/agendar, /saida, /duplicar.
- server/lib/routes/clientes.dart: CRUD completo.
- server/lib/routes/orcamento.dart: GET /orcamento/tabela, /tecnicas + POST /orcamento/calcular.
- server/lib/routes/pagamentos.dart: GET/POST /pagamentos/pedidos/:pedidoId, DELETE /:id.
- server/lib/routes/dashboard.dart: GET /dashboard/stats.
- server/lib/routes/configuracoes.dart: GET/PUT existentes.

Schema expandido. Tabela pedidos tem TODOS esses campos (snake_case):
  id, lote, cliente_id, cliente_nome, cliente_telefone, cliente_email,
  descricao, peca, tecnica, quantidade, valor,
  cor_peca, tamanho_peca, tecido,
  arte_cores, arte_tamanho_cm, arte_posicao, arte_observacao,
  data_chegada, data_producao, prazo_dias, agendamento_fixo,
  forma_entrega, endereco_entrega, data_entrega_combinada, entregue_em, entregue_por,
  forma_pagamento, valor_pago, sinal_pago, status_pagamento,
  status, urgente, observacao, criado_em, atualizado_em
Status possíveis: pendente, agendado, producao, concluido, entregue
Status pagamento: devendo, parcial, pago

App (frontend) — PARCIALMENTE PRONTO:

Modelos (PRONTOS, não mexer, só importar):
- app/lib/models/pedido.dart — classe Pedido com todos os campos acima em camelCase.
  Propriedades úteis: loteFormatado, valorRestante, pago, parcial, devendo, entregue.
- app/lib/models/cliente.dart — classe Cliente com id, nome, telefone, email, endereco,
  observacao, criadoEm, atualizadoEm, totalPedidos, totalGasto, pedidos (List<Pedido>?).
  Getter: iniciais (pra avatar).
- app/lib/models/pagamento.dart — classes Pagamento (id, pedidoId, valor, forma, quando,
  observacao), ItemPreco (id, tecnica, regiao, faixaQtd, primeiraCor, demaisCores),
  OrcamentoResultado (tecnica, regiao, faixaQtd, quantidade, cores, urgente, tipoPeca,
  precoPorPeca, subtotal, matrizCobrada, valorMatriz, total).
- app/lib/models/dashboard.dart — DashboardStats (faturamentoMes, aReceber, emProducaoHoje,
  prazosVencendo, ultimosMovimentos, ocupacaoSemana, porStatus) e DiaOcupacao
  (data, ocupado, limite, pct, estourado).
- app/lib/models/configuracao.dart — Configuracao (chave, valor, tipo, descricao,
  asNumber, asBool).

API client (PRONTO, não mexer, só importar):
- app/lib/api/api_client.dart — classe ApiClient + providers riverpod:
    serverUrlProvider (StateProvider<String>)
    apiClientProvider (Provider<ApiClient>)
  Métodos principais do ApiClient:
    health()
    listarPedidos({status, statusPagamento, cliente, clienteId, busca, urgente, de, ate, ordenar})
    criarPedido(body), atualizarPedido(id, patch), deletarPedido(id),
    agendarPedido(id), confirmarSaida(id, {entreguePor}), duplicarPedido(id)
    listarClientes({busca}), buscarCliente(id), criarCliente(body),
    atualizarCliente(id, patch), deletarCliente(id)
    listarConfiguracoes(), atualizarConfiguracao(chave, valor)
    listarTabelaPreco(), listarTecnicas(), calcularOrcamento(body)
    listarPagamentos(pedidoId), registrarPagamento(pedidoId, body), deletarPagamento(id)
    dashboardStats()
  Também: loadServerUrl(), saveServerUrl(url), defaultServerUrl.

Providers de estado (PRONTOS):
- app/lib/state/pedidos_provider.dart — PedidosFiltro (status, statusPagamento, busca,
  urgenteOnly, ordenar) + pedidosFiltroProvider + pedidosProvider (FutureProvider
  .autoDispose<List<Pedido>>) + pedidoProvider.family(id).
- app/lib/state/clientes_provider.dart — clientesBuscaProvider (StateProvider<String>)
  + clientesProvider + clienteDetalheProvider.family(id).
- app/lib/state/dashboard_provider.dart — dashboardProvider.
- app/lib/state/pagamentos_provider.dart — pagamentosProvider.family(pedidoId),
  tabelaPrecoProvider, tecnicasProvider.
- app/lib/state/configuracoes_provider.dart — configuracoesProvider.
- app/lib/state/theme_provider.dart — themeModeProvider (StateProvider<ThemeMode>),
  loadThemeMode(), saveThemeMode(mode).

Widgets compartilhados (PRONTOS, usar sempre):
- app/lib/widgets/status_pill.dart:
    StatusPill(status: String, small: bool) — pill colorido do status.
    PagamentoPill(statusPagamento: String, small: bool) — pill colorido do pagamento.
    statusInfo(context, status) — retorna StatusInfo com bg, fg, label, icon.
- app/lib/widgets/kpi_card.dart:
    KpiCard(icon, label, valor, hint?, accent?, onTap?)
- app/lib/widgets/empty_state.dart:
    EmptyState(icon, titulo, subtitulo?, acao?)
    ErrorState(message, onRetry?)
    SectionHeader(icon, title, subtitle?, trailing?)
- app/lib/widgets/pedido_card.dart:
    PedidoCard(pedido: Pedido, onTap: VoidCallback, compacto: bool)
    — card rico com lote, cliente, descrição, chips de valor/qtd/técnica/cores,
    badges HOJE/ATRASADO/VENCENDO, StatusPill + PagamentoPill, ícone do telefone.
- app/lib/widgets/shimmer_skeleton.dart:
    ShimmerSkeleton(width, height, borderRadius?)

Tema (PRONTO):
- app/lib/theme.dart — buildLightTheme() e buildDarkTheme(). Cor primária azul (#0066CC).
  Material 3, cards arredondados 16, inputs arredondados 12, etc.

Convenções:
- SEMPRE usar ConsumerStatefulWidget/ConsumerWidget (flutter_riverpod).
- Locale pt_BR. Formatar moeda: NumberFormat.currency(locale: 'pt_BR', symbol: 'R\\$').
- Datas: DateFormat('dd/MM/yyyy', 'pt_BR') ou 'EEEE, dd/MM/yyyy'.
- Navegação: context.push('/rota'), context.pop(), context.go('/rota').
- Para invalidar cache depois de mutação: ref.invalidate(pedidosProvider),
  ref.invalidate(clientesProvider), ref.invalidate(dashboardProvider), etc.
- Sempre usar Theme.of(context) — NUNCA cores hardcoded fora de StatusPill.
- Ícones: Icons.xxx_outlined pra elementos secundários, versão filled pra seleção.
- Para acessar cor do tema: theme.colorScheme.primary, .primaryContainer,
  .onPrimaryContainer, .surface, .surfaceContainerHighest, .error, .errorContainer,
  .onSurface, .onSurfaceVariant, .outline, .outlineVariant, .tertiaryContainer, etc.

O que falta (vai ser construído pelos prompts abaixo):
- app/lib/main.dart — atualizar pra ler themeMode do SharedPreferences.
- app/lib/screens/dashboard/dashboard_screen.dart — NOVO.
- app/lib/screens/clientes/clientes_screen.dart — NOVO.
- app/lib/screens/clientes/cliente_form_screen.dart — NOVO.
- app/lib/screens/clientes/cliente_detalhe_screen.dart — NOVO.
- app/lib/screens/orcamento/orcamento_screen.dart — NOVO.
- app/lib/screens/pedidos/pedido_form_screen.dart — REESCREVER (existe versão antiga com poucos campos).
- app/lib/screens/pedidos/pedido_detalhe_screen.dart — NOVO.
- app/lib/screens/pedidos/pedidos_screen.dart — ATUALIZAR pra usar PedidoCard novo e filtros ricos.
- app/lib/screens/kanban/kanban_screen.dart — NOVO.
- app/lib/screens/agenda/agenda_screen.dart — ATUALIZAR (adicionar toggle semana).
- app/lib/screens/configuracoes/configuracoes_screen.dart — ATUALIZAR (tema claro/escuro).
- app/lib/router.dart — ADICIONAR rotas novas.
- app/lib/screens/home_shell.dart — ATUALIZAR destinos do NavigationBar/NavigationRail.

REGRA: cada prompt vai te dizer exatamente qual arquivo criar/editar. Não crie arquivos
fora do escopo. Não mexa no server — está pronto. Não altere os modelos, api_client,
providers ou widgets compartilhados listados acima — já estão prontos.
```

---

# PROMPT 1 — Atualizar main.dart com theme mode persistente

**Arquivo a editar:** `C:/Users/Leonardo/Documents/codigos/empresa/app/lib/main.dart`

**Objetivo:** carregar o modo de tema (claro/escuro/sistema) do SharedPreferences no boot e passar pro `MaterialApp.router`. O provider `themeModeProvider` já existe em `app/lib/state/theme_provider.dart`.

**O arquivo atual é assim:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'api/api_client.dart';
import 'router.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  final url = await loadServerUrl();

  runApp(
    ProviderScope(
      overrides: [
        serverUrlProvider.overrideWith((ref) => url),
      ],
      child: const EmpresaApp(),
    ),
  );
}

class EmpresaApp extends StatelessWidget {
  const EmpresaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Controle de Produção',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
    );
  }
}
```

**O que mudar:**
1. Importar `state/theme_provider.dart`.
2. No `main()`, chamar `loadThemeMode()` e guardar.
3. No `ProviderScope`, adicionar override de `themeModeProvider` com o valor carregado.
4. Transformar `EmpresaApp` em `ConsumerWidget` (extends `ConsumerWidget`).
5. No `build`, fazer `ref.watch(themeModeProvider)` e passar como `themeMode:` no `MaterialApp.router`.

**Resultado esperado:** o app respeita a preferência de tema salva. Se nunca foi salvo, usa `ThemeMode.system`.

**Entregáveis:** apenas o arquivo `main.dart` atualizado. Nada mais.

---

# PROMPT 2 — Dashboard screen

**Arquivo a criar:** `C:/Users/Leonardo/Documents/codigos/empresa/app/lib/screens/dashboard/dashboard_screen.dart`

**Objetivo:** tela inicial rica em informação, mostrando o estado da serigrafia na hora. Primeira coisa que o dono vê quando abre o app.

**Dependências (importar):**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/dashboard.dart';
import '../../models/pedido.dart';
import '../../state/dashboard_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/pedido_card.dart';
import '../../widgets/status_pill.dart';
```

**Estrutura da tela (ordem vertical, dentro de ListView com padding 16):**

1. **AppBar** com título "Início" e ação de refresh (ícone Icons.refresh) que chama `ref.invalidate(dashboardProvider)`.

2. **Saudação dinâmica**: "Bom dia", "Boa tarde" ou "Boa noite" baseado em `DateTime.now().hour`. Abaixo, a data por extenso em pt_BR (ex: "segunda-feira, 14 de abril de 2026"). Use `DateFormat("EEEE, d 'de' MMMM 'de' y", 'pt_BR')` e `toBeginningOfSentenceCase`.

3. **Grid de 4 KPI cards** (usa o widget `KpiCard`). Em telas largas (width >= 720) usa GridView com 4 colunas; em mobile, 2 colunas. Cards:
   - `KpiCard(icon: Icons.trending_up, label: 'FATURAMENTO DO MÊS', valor: moeda(stats.faturamentoMes), accent: Colors.green)`
   - `KpiCard(icon: Icons.account_balance_wallet_outlined, label: 'A RECEBER', valor: moeda(stats.aReceber), accent: Colors.orange)`
   - `KpiCard(icon: Icons.precision_manufacturing_outlined, label: 'PRODUÇÃO HOJE', valor: '${stats.emProducaoHoje.length}', hint: '${moeda do total}', accent: theme.colorScheme.tertiary)`
   - `KpiCard(icon: Icons.schedule, label: 'VENCENDO', valor: '${stats.prazosVencendo.length}', hint: '7 dias', accent: theme.colorScheme.error)`

4. **Card "Ocupação da semana"**: um Card com SectionHeader(icon: Icons.bar_chart, title: 'Ocupação da semana'), e dentro um gráfico de barras **feito na mão** (SEM fl_chart). Para cada item de `stats.ocupacaoSemana`:
   - Barra horizontal com label do dia da semana curto (ex "seg 14"), LinearProgressIndicator com `value: dia.pct.clamp(0, 1)`, `color: dia.estourado ? theme.colorScheme.error : theme.colorScheme.primary`.
   - À direita, texto com valor ocupado / limite. Se `dia.estourado` texto em vermelho.
   - Use DateFormat('EEE d', 'pt_BR') pra formatar a data.

5. **Card "Em produção hoje"**: SectionHeader(icon: Icons.today, title: 'Em produção hoje', subtitle: '${stats.emProducaoHoje.length} pedidos'). Se vazio, mostra texto sutil "Nenhum pedido hoje". Se tiver, Column com cada pedido em PedidoCard(pedido, onTap: () => context.push('/pedidos/${p.id}'), compacto: true).

6. **Card "Prazos vencendo"** (só se tiver itens): SectionHeader(icon: Icons.warning_amber_rounded, title: 'Prazos vencendo'). Lista compacta com PedidoCard(compacto: true).

7. **Card "Últimos movimentos"**: SectionHeader(icon: Icons.history, title: 'Últimos movimentos'). Lista dos últimos 5 (stats.ultimosMovimentos) com PedidoCard compacto.

**FloatingActionButton.extended** no Scaffold: label "Novo pedido", icon Icons.add, onPressed abre `context.push('/pedidos/novo')`.

**Loading/Error:** usa `AsyncValue.when` do `ref.watch(dashboardProvider)`:
- loading: ListView com 4 placeholders KpiCard shimmer + cards em shimmer.
- error: usa widget `ErrorState(message: e.toString(), onRetry: () => ref.invalidate(dashboardProvider))`.
- data: monta a tela.

**Helpers locais:**
```dart
String _saudacao() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Bom dia';
  if (h < 18) return 'Boa tarde';
  return 'Boa noite';
}
```

**Cuidados:**
- Classe: `class DashboardScreen extends ConsumerWidget`.
- Não usar setState — tudo reativo via ref.watch.
- Moeda: `NumberFormat.currency(locale: 'pt_BR', symbol: 'R\\$')`.
- Use sempre theme.colorScheme, nunca cores fora de `Colors.green`/`Colors.orange` que são aceitas pra acent dos KPIs.
- Todos os Cards devem ter `const EdgeInsets.all(16)` de padding e usar o `cardTheme` do app automaticamente.

**Entregáveis:** apenas `dashboard_screen.dart`. Nada mais.

---

# PROMPT 3 — Tela de lista de clientes

**Arquivo a criar:** `C:/Users/Leonardo/Documents/codigos/empresa/app/lib/screens/clientes/clientes_screen.dart`

**Objetivo:** listar clientes cadastrados com busca, acessar detalhe, criar novo cliente.

**Dependências:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/cliente.dart';
import '../../state/clientes_provider.dart';
import '../../widgets/empty_state.dart';
```

**Estrutura:**

1. **AppBar** título "Clientes", ação refresh.
2. **FloatingActionButton.extended** icon Icons.person_add, label "Novo cliente", onPressed navega `context.push('/clientes/novo')`.
3. **Campo de busca** no topo do body: TextField com prefixIcon Icons.search, hintText "Buscar por nome ou telefone", onChanged com debounce simples (ou onSubmitted) que atualiza `ref.read(clientesBuscaProvider.notifier).state = valor`.
4. **Lista** reativa a `ref.watch(clientesProvider)`:
   - loading → `CircularProgressIndicator` centralizado OU list de shimmer.
   - error → `ErrorState(message: e.toString(), onRetry: () => ref.invalidate(clientesProvider))`.
   - data vazio → `EmptyState(icon: Icons.people_outline, titulo: 'Nenhum cliente', subtitulo: 'Toque em "Novo cliente" pra começar')`.
   - data com itens → ListView.separated de cards. Cada card:
     - Avatar circular com as iniciais (usar `cliente.iniciais`), bg primaryContainer.
     - À direita: nome (titleMedium bold) + telefone (bodySmall, com ícone Icons.call_outlined pequeno).
     - Na segunda linha: chips com "${cliente.totalPedidos} pedidos" e `NumberFormat.currency(locale: 'pt_BR', symbol: 'R\\$').format(cliente.totalGasto)`.
     - InkWell que navega `context.push('/clientes/${cliente.id}')`.

**Classe:**
```dart
class ClientesScreen extends ConsumerStatefulWidget {
  const ClientesScreen({super.key});
  @override
  ConsumerState<ClientesScreen> createState() => _ClientesScreenState();
}
```

**Entregáveis:** apenas `clientes_screen.dart`. Nada mais.

---

# PROMPT 4 — Formulário de cliente (criar/editar)

**Arquivo a criar:** `C:/Users/Leonardo/Documents/codigos/empresa/app/lib/screens/clientes/cliente_form_screen.dart`

**Objetivo:** formulário para cadastrar ou editar cliente. Usa a mesma tela para ambos os casos diferenciando por `clienteId` sendo null ou não.

**Assinatura:**
```dart
class ClienteFormScreen extends ConsumerStatefulWidget {
  final String? clienteId; // null = criação, preenchido = edição
  const ClienteFormScreen({super.key, this.clienteId});
  @override
  ConsumerState<ClienteFormScreen> createState() => _ClienteFormScreenState();
}
```

**Dependências:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../state/clientes_provider.dart';
```

**Estrutura da tela:**

1. **AppBar** título "Novo cliente" ou "Editar cliente". Ação delete (Icons.delete_outline) só na edição.

2. **Form** com `GlobalKey<FormState>`, ListView com padding 20. Campos (TextFormField com InputDecoration, labelText explícito):
   - `nome *` (obrigatório — validator verifica não-vazio). Icons.person_outline.
   - `telefone` (teclado phone). Icons.call_outlined.
   - `email` (teclado emailAddress). Icons.mail_outline.
   - `endereco` (multilinha, maxLines: 2). Icons.home_outlined.
   - `observacao` (multilinha, maxLines: 3). Icons.note_outlined.

3. **FilledButton.icon** com texto "Salvar" no final. Ao salvar:
   - Valida form.
   - Monta map com os campos.
   - Se `clienteId == null` → `api.criarCliente(body)`.
   - Senão → `api.atualizarCliente(clienteId!, body)`.
   - Invalida `clientesProvider` e, se edição, `clienteDetalheProvider(clienteId!)`.
   - `context.pop()`.

4. **Carregar dados na edição**: no `initState`, se `clienteId != null`, chamar `api.buscarCliente(clienteId!)` e preencher controllers.

5. **Excluir** (só edição): AlertDialog de confirmação. Se OK, `api.deletarCliente(id)`, invalida provider, volta pra lista. Cuidado: se o backend recusar (cliente com pedidos), mostrar SnackBar com o erro.

6. **Estado de loading/erro** com `_carregando` e `_salvando` e `_erro` em texto vermelho.

**Entregáveis:** apenas `cliente_form_screen.dart`.

---

# PROMPT 5 — Tela de detalhe do cliente

**Arquivo a criar:** `C:/Users/Leonardo/Documents/codigos/empresa/app/lib/screens/clientes/cliente_detalhe_screen.dart`

**Objetivo:** mostrar informações do cliente + histórico de pedidos dele.

**Assinatura:**
```dart
class ClienteDetalheScreen extends ConsumerWidget {
  final String clienteId;
  const ClienteDetalheScreen({super.key, required this.clienteId});
  @override
  Widget build(BuildContext context, WidgetRef ref) { ... }
}
```

**Dependências:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../state/clientes_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pedido_card.dart';
```

**Estrutura:**

1. AppBar com título do nome do cliente. Actions: Icons.edit_outlined → `context.push('/clientes/${clienteId}/editar')`.

2. Usa `ref.watch(clienteDetalheProvider(clienteId))`. AsyncValue.when loading/error/data.

3. Header grande dentro de um Card:
   - Avatar circular grande (54x54) com iniciais, bg primaryContainer.
   - Nome (titleLarge bold).
   - Telefone com ícone Icons.call_outlined (se existir).
   - Email com ícone Icons.mail_outline (se existir).
   - Endereço com ícone Icons.home_outlined (se existir).
   - Observação em itálico se existir.
   - Row com 2 stats: "{totalPedidos} pedidos" e "{moeda(totalGasto)} gasto".

4. SectionHeader(icon: Icons.history, title: 'Histórico de pedidos'). Abaixo:
   - Se `cliente.pedidos` vazio → "Nenhum pedido ainda".
   - Senão → ListView com PedidoCard (compacto: true) pra cada pedido, onTap → `context.push('/pedidos/${p.id}')`.

**Botão flutuante**: "Novo pedido" → `context.push('/pedidos/novo?cliente_id=$clienteId')`.

**Entregáveis:** apenas `cliente_detalhe_screen.dart`.

---

# PROMPT 6 — Tela de calculadora de orçamento

**Arquivo a criar:** `C:/Users/Leonardo/Documents/codigos/empresa/app/lib/screens/orcamento/orcamento_screen.dart`

**Objetivo:** tela onde o atendente insere os parâmetros (técnica, região, quantidade, cores, urgente, tipo de peça) e vê o preço calculado pelo servidor. Pode voltar pro form de pedido com "Usar este valor".

**Dependências:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../models/pagamento.dart'; // OrcamentoResultado e ItemPreco estão aqui
import '../../state/pagamentos_provider.dart';
import '../../widgets/empty_state.dart';
```

**Assinatura:**
```dart
class OrcamentoScreen extends ConsumerStatefulWidget {
  const OrcamentoScreen({super.key});
  @override
  ConsumerState<OrcamentoScreen> createState() => _OrcamentoScreenState();
}
```

**Estado interno:**
- `String? _tecnica` — opções vêm do provider `tecnicasProvider`.
- `String _regiao = 'FRENTE/COSTAS'` — opções: 'FRENTE/COSTAS', 'BOTTOM/NUCA'.
- `int _quantidade = 25`.
- `int _cores = 1`.
- `bool _urgente = false`.
- `String? _tipoPeca` — opções: null (normal), 'moletom_aberto', 'moletom_fechado'.
- `OrcamentoResultado? _resultado`.
- `bool _calculando`.
- `String? _erro`.

**Estrutura da tela:**

1. AppBar título "Calculadora de orçamento".

2. Form em ListView padding 20. Seções:
   - **Técnica**: `ref.watch(tecnicasProvider).when(...)`. Renderiza Wrap de ChoiceChip (um por técnica), selecionado quando `_tecnica == t`. Se loading, CircularProgressIndicator pequeno.
   - **Região**: Wrap de ChoiceChip com as 2 regiões.
   - **Quantidade**: TextFormField keyboardType number, com `inputFormatters: [FilteringTextInputFormatter.digitsOnly]`, valor default "25". Também Slider 1..500? Simples: só TextField.
   - **Nº de cores**: mesma coisa, default 1. Pequeno "-" e "+" ao redor.
   - **Urgente**: SwitchListTile.
   - **Tipo de peça**: DropdownButtonFormField<String?> com items:
     - null → 'Peça normal'
     - 'moletom_aberto' → 'Moletom aberto (+20%)'
     - 'moletom_fechado' → 'Moletom fechado (+60%)'

3. **Botão FilledButton.icon "Calcular"** com icon Icons.calculate_outlined. Ao clicar:
   - Valida que técnica e quantidade > 0.
   - Chama `ref.read(apiClientProvider).calcularOrcamento({'tecnica': _tecnica, 'regiao': _regiao, 'quantidade': _quantidade, 'cores': _cores, 'urgente': _urgente, 'tipo_peca': _tipoPeca})`.
   - setState com `_resultado`.

4. **Card de resultado** (só aparece se `_resultado != null`): dentro dele:
   - SectionHeader(icon: Icons.receipt_long_outlined, title: 'Resultado').
   - Lista vertical com:
     - "Preço por peça": `moeda(_resultado!.precoPorPeca)` (bold).
     - "Subtotal (${_resultado!.quantidade} peças)": `moeda(_resultado!.subtotal)`.
     - "Matriz": se `matrizCobrada` → moeda(valorMatriz); senão "Grátis".
   - Divider.
   - **TOTAL** em titleLarge bold: `moeda(_resultado!.total)`.
   - Row com 2 botões:
     - OutlinedButton "Novo cálculo" → setState(() => _resultado = null).
     - FilledButton.icon "Usar este valor" (Icons.check) → `context.pop(_resultado!.total)` (retorna o total pra tela que chamou).

**Observação importante:** essa tela pode ser aberta com `context.push('/orcamento')` (sem retorno) ou por `final total = await context.push<double?>('/orcamento')` (o form de pedido vai fazer isso). O pop precisa retornar o total quando o usuário confirmar.

**Formatação moeda:** `NumberFormat.currency(locale: 'pt_BR', symbol: 'R\\$').format(valor)`.

**Entregáveis:** apenas `orcamento_screen.dart`.

---

# PROMPT 7 — Reescrever pedido_form_screen com seções

**Arquivo a substituir:** `C:/Users/Leonardo/Documents/codigos/empresa/app/lib/screens/pedidos/pedido_form_screen.dart`

**Objetivo:** formulário completo de pedido, organizado em seções recolhíveis/visuais claras. Este é o form principal do app e precisa cobrir TODOS os campos do modelo Pedido (exceto id/lote/criado_em). Inclui a seção de SAÍDA com botão "Confirmar saída" que é o "OK" do dono.

Este prompt é maior — lê com atenção.

**Dependências:**
```dart
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
import '../../widgets/status_pill.dart';
```

**Assinatura:**
```dart
class PedidoFormScreen extends ConsumerStatefulWidget {
  final String? pedidoId;
  final String? clienteIdInicial; // quando vem de /clientes/:id com FAB "novo pedido"
  const PedidoFormScreen({super.key, this.pedidoId, this.clienteIdInicial});
  @override
  ConsumerState<PedidoFormScreen> createState() => _PedidoFormScreenState();
}
```

**Estado com TextEditingControllers para cada campo string/numérico**, e variáveis para os não-texto:
- clienteIdCtl (guardado em variável String? `_clienteId`, não tem controller — é seletor)
- `_clienteCtl` (TextEditingController — nome digitado/autocomplete)
- `_telefoneCtl`, `_emailCtl`, `_descricaoCtl`, `_pecaCtl`, `_tecnicaCtl`, `_quantidadeCtl`, `_valorCtl`
- `_corPecaCtl`, `_tamanhoPecaCtl`, `_tecidoCtl`
- `_arteCoresCtl`, `_arteTamanhoCtl`, `_artePosicaoCtl`, `_arteObservacaoCtl`
- `_enderecoCtl`, `_entreguePorCtl`, `_observacaoCtl`
- Estado: `_dataChegada`, `_dataProducao`, `_dataEntregaCombinada` (DateTime?), `_status`, `_statusPagamento`, `_urgente`, `_formaEntrega` ('retirada' ou 'entrega' — usar dropdown ou SegmentedButton), `_formaPagamento` (String?), `_autoAgendar` (bool, default true).
- `_carregando`, `_salvando`, `_confirmandoSaida`, `_erro`, `_original` (Pedido?).

**Seções da tela (cada uma num Card separado, com SectionHeader):**

### Seção 1: Cliente (SectionHeader icon: Icons.person_outline, title: 'Cliente')

- Campo de nome do cliente com **autocomplete**: usar `Autocomplete<Cliente>` do Flutter. Options vêm de `ref.watch(clientesProvider).value ?? []`, filtradas pelo texto digitado.
  - displayStringForOption: `(c) => c.nome`.
  - onSelected: preenche `_clienteId`, `_clienteCtl.text`, `_telefoneCtl.text`, `_emailCtl.text` com os dados do cliente selecionado.
  - fieldViewBuilder: usa o controller passado, mostra TextFormField estilizado (labelText "Cliente *", prefixIcon person_outline). Se o usuário digitar um nome que não existe, permitir seguir — ao salvar, o backend trata.
  - validator: obrigatório.
- `_telefoneCtl`: labelText 'Telefone', prefixIcon Icons.call_outlined, keyboardType phone.
- `_emailCtl`: labelText 'Email', keyboardType emailAddress.

### Seção 2: Peça (SectionHeader icon: Icons.checkroom_outlined, title: 'Peça')

Row com 2 colunas: `_pecaCtl` (label "Peça", hint "camiseta") e `_tecnicaCtl` (label "Técnica", hint "silk").
Row com 2 colunas: `_quantidadeCtl` (number) e `_valorCtl` (moeda — hint "800,00", obrigatório).
**Botão pequeno "Calcular orçamento"** (icone Icons.calculate_outlined) que navega `final total = await context.push<double?>('/orcamento')` e se `total != null` preenche `_valorCtl.text = total.toStringAsFixed(2).replaceAll('.', ',')`.
Row com 3 colunas: `_corPecaCtl` ('Cor'), `_tamanhoPecaCtl` ('Tamanho'), `_tecidoCtl` ('Tecido').

### Seção 3: Arte (SectionHeader icon: Icons.palette_outlined, title: 'Arte')

Row: `_arteCoresCtl` (number, label 'Nº de cores'), `_arteTamanhoCtl` ('Tamanho (cm)', hint "25x15").
`_artePosicaoCtl` — dropdown com opções: 'Frente', 'Costas', 'Manga direita', 'Manga esquerda', 'Peito esquerdo', 'Bottom', 'Nuca', ou campo livre. Pra simplificar: TextFormField normal com hint.
`_arteObservacaoCtl` maxLines 2, label 'Observação da arte'.

### Seção 4: Agendamento (SectionHeader icon: Icons.calendar_month_outlined, title: 'Agendamento')

- `_DateField` customizado (widget privado igual ao original): label 'Data de chegada', data `_dataChegada`, onTap abre showDatePicker (firstDate 2020, lastDate 2035, locale pt_BR).
- `_DateField`: 'Data de produção' (`_dataProducao`).
- `SwitchListTile` 'Agendar automaticamente': `_autoAgendar`. Subtitle "Pula fim de semana, respeita limite diário".
- `DropdownButtonFormField<String>` 'Status' com items: pendente, agendado, producao, concluido, entregue (veja widgets/status_pill para labels equivalentes).
- `SwitchListTile` 'Urgente' — subtitle 'Aplica taxa adicional'.

### Seção 5: Entrega (SectionHeader icon: Icons.local_shipping_outlined, title: 'Entrega')

- SegmentedButton<String> com opções 'retirada' e 'entrega' — seletor de `_formaEntrega`.
- `_enderecoCtl` (só mostrar se forma_entrega == 'entrega'), maxLines 2, label 'Endereço de entrega'.
- `_DateField` 'Data de entrega combinada' (`_dataEntregaCombinada`).

### Seção 6: Pagamento (SectionHeader icon: Icons.payments_outlined, title: 'Pagamento')

- `DropdownButtonFormField<String?>` 'Forma de pagamento' com items: null ('Não definido'), 'dinheiro', 'pix', 'cartao_credito', 'cartao_debito', 'boleto', 'transferencia'.
- `DropdownButtonFormField<String>` 'Status do pagamento' com items: 'devendo', 'parcial', 'pago'.

### Seção 7: Observação geral

- `_observacaoCtl` maxLines 3, label 'Observação'.

### Seção 8: Saída (só na EDIÇÃO, apenas se `_original != null`)

Card de destaque (bg tertiaryContainer):
- Se `_original!.entregue` → ícone grande Icons.check_circle + texto "Entregue em ${data formatada}" + "por ${entreguePor ?? '—'}".
- Senão → `_entreguePorCtl` (label 'Entregue por' — opcional, nome de quem está retirando).
  - FilledButton.icon grande com icon Icons.local_shipping, label 'CONFIRMAR SAÍDA'. Ao clicar:
    1. Mostra AlertDialog: "Confirmar saída do pedido ${lote}?".
    2. Se ok, chama `await api.confirmarSaida(pedidoId!, entreguePor: _entreguePorCtl.text.trim().isEmpty ? null : _entreguePorCtl.text.trim())`.
    3. Mostra SnackBar de sucesso "Saída confirmada ✓".
    4. Invalida `pedidosProvider`, `dashboardProvider`.
    5. `context.pop()`.

### Salvar

FilledButton.icon grande 'Salvar alterações' / 'Criar pedido' no final. Monta body com **TODOS os campos em snake_case** (o backend aceita null pra não-preenchidos):

```dart
final body = <String, dynamic>{
  'cliente_id': _clienteId,
  'cliente_nome': _clienteCtl.text.trim(),
  'cliente_telefone': _telefoneCtl.text.trim().isEmpty ? null : _telefoneCtl.text.trim(),
  'cliente_email': _emailCtl.text.trim().isEmpty ? null : _emailCtl.text.trim(),
  'descricao': _descricaoCtl.text.trim(),
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
```

Chamar `api.criarPedido(body)` ou `api.atualizarPedido(pedidoId!, body)`. Invalida `pedidosProvider`, `dashboardProvider`, e se for edição tbm `pedidoProvider(pedidoId!)`.

**Helper:**
```dart
double? _parseValor(String txt) {
  final t = txt.trim().replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(t);
}
```

**Carregar pedido na edição:** no `initState`, se `pedidoId != null`, chamar `api.listarPedidos()` e achar pelo id (ou `api.dio.get('/pedidos/$id')` — mais direto, mas tb funciona listar e firstWhere). Preencher todos os controllers e estados.

**Se vier `clienteIdInicial`:** chamar `api.buscarCliente(id)` e pré-preencher a seção cliente.

**Widget `_DateField` privado:**
```dart
class _DateField extends StatelessWidget {
  final String label;
  final DateTime? data;
  final VoidCallback onPick;
  final VoidCallback onClear;
  const _DateField({required this.label, required this.data, required this.onPick, required this.onClear});
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
          data == null ? 'Toque para selecionar' : DateFormat('dd/MM/yyyy', 'pt_BR').format(data),
          style: TextStyle(color: data == null ? Theme.of(context).hintColor : null),
        ),
      ),
    );
  }
}
```

**Cuidados:**
- Chamar `dispose` em TODOS os controllers.
- Dá pra reaproveitar o helper `_sectionHeader` do arquivo antigo ou usar o widget `SectionHeader` de `widgets/empty_state.dart`.
- Quando envolver `Autocomplete`, o controller vem do `fieldViewBuilder`. NÃO criar outro — use o fornecido e só mantenha sincronizado com `_clienteCtl` via initialValue + onSelected.
- NÃO criar o arquivo `pedido_detalhe_screen.dart` aqui — é o próximo prompt.

**Entregáveis:** apenas `pedido_form_screen.dart` totalmente reescrito.

---

# PROMPT 8 — Tela de detalhe do pedido com pagamentos

**Arquivo a criar:** `C:/Users/Leonardo/Documents/codigos/empresa/app/lib/screens/pedidos/pedido_detalhe_screen.dart`

**Objetivo:** visualização read-only do pedido + gerenciamento de pagamentos (adicionar, listar, deletar). Com botão editar que leva pro form.

**Dependências:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../models/pagamento.dart';
import '../../models/pedido.dart';
import '../../state/pagamentos_provider.dart';
import '../../state/pedidos_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_pill.dart';
```

**Assinatura:**
```dart
class PedidoDetalheScreen extends ConsumerWidget {
  final String pedidoId;
  const PedidoDetalheScreen({super.key, required this.pedidoId});
}
```

**Estrutura:**

1. **AppBar**: título = `pedido.loteFormatado` (quando carregado). Actions:
   - Icons.edit_outlined → `context.push('/pedidos/${pedidoId}/editar')`
   - PopupMenuButton com: 'Duplicar' (chama `api.duplicarPedido(id)` e navega pro novo), 'Excluir' (diálogo de confirmação).

2. **Body** usando `ref.watch(pedidoProvider(pedidoId))` com AsyncValue.when.

3. Quando carregado, ListView com cards:

**Card 1 — Cabeçalho**:
- Row com `StatusPill(status: pedido.status)` e `PagamentoPill(statusPagamento: pedido.statusPagamento)`.
- Se urgente, badge URGENTE.
- Cliente em titleLarge bold.
- Descrição em bodyLarge.
- Valor grande: `moeda(valor)` em headlineSmall bold.

**Card 2 — Peça**:
- SectionHeader(Icons.checkroom_outlined, 'Peça').
- Lista de pares label/valor: Peça, Técnica, Quantidade, Cor, Tamanho, Tecido. Usar widget privado `_Info(label, valor)` que só mostra se valor não-nulo.

**Card 3 — Arte**:
- SectionHeader(Icons.palette_outlined, 'Arte').
- Info: Nº cores, Tamanho, Posição, Observação.

**Card 4 — Agenda**:
- SectionHeader(Icons.calendar_month_outlined, 'Agenda').
- Info: Chegada, Produção, Prazo (dias), Entrega combinada.
- Se `pedido.dataProducao` existe, mostrar dia da semana também.

**Card 5 — Entrega**:
- SectionHeader(Icons.local_shipping_outlined, 'Entrega').
- Info: Forma, Endereço.
- Se entregue, destaque em verde "Entregue em ${data} por ${quem}".

**Card 6 — Pagamentos**:
- SectionHeader(Icons.payments_outlined, 'Pagamentos', subtitle: 'Valor restante: ${moeda(pedido.valorRestante)}').
- Ler `ref.watch(pagamentosProvider(pedidoId))`.
- Lista: cada pagamento é um ListTile com leading Icons.check_circle (verde), título `moeda(p.valor)`, subtítulo "${forma ?? ''} • ${DateFormat('dd/MM/yyyy').format(p.quando)}", trailing IconButton delete.
- Se vazio: "Nenhum pagamento registrado".
- Botão FilledButton.tonal "Registrar pagamento" abre BottomSheet com:
  - TextFormField valor (moeda), default = `pedido.valorRestante`.
  - DropdownButtonFormField forma: dinheiro, pix, cartao_credito, cartao_debito, boleto, transferencia.
  - TextFormField observação opcional.
  - Botão confirmar → `api.registrarPagamento(pedidoId, {'valor': ..., 'forma': ..., 'observacao': ...})`. Invalida `pagamentosProvider(pedidoId)`, `pedidoProvider(pedidoId)`, `pedidosProvider`, `dashboardProvider`.

**Card 7 — Observação geral** (se existir).

**Helper `_Info` privado:**
```dart
class _Info extends StatelessWidget {
  final String label;
  final String? valor;
  const _Info(this.label, this.valor);
  @override
  Widget build(BuildContext context) {
    if (valor == null || valor!.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
          ),
          Expanded(child: Text(valor!, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
```

**Entregáveis:** apenas `pedido_detalhe_screen.dart`.

---

# PROMPT 9 — Atualizar pedidos_screen com PedidoCard e filtros ricos

**Arquivo a substituir:** `C:/Users/Leonardo/Documents/codigos/empresa/app/lib/screens/pedidos/pedidos_screen.dart`

**Objetivo:** a lista de pedidos deve usar o novo widget `PedidoCard` e oferecer filtros visíveis (busca, status, status pagamento, urgente, ordenar).

**Dependências:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/pedidos_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pedido_card.dart';
```

**Estrutura:**

1. **AppBar** título "Pedidos". Actions:
   - Icons.refresh → invalida `pedidosProvider`.
   - Icons.view_kanban_outlined → `context.go('/kanban')`.

2. **Body**:
   - **Barra de busca** (TextField com Icons.search) — onSubmitted atualiza filtro.
   - **Linha horizontal de filtros** (SingleChildScrollView horizontal) com chips:
     - FilterChip "Urgentes" (ativa/desativa `urgenteOnly`).
     - FilterChip "Devendo" (ativa `statusPagamento = 'devendo'`).
     - FilterChip "Em produção" (status = 'producao').
     - FilterChip "Agendados" (status = 'agendado').
     - FilterChip "Pendentes" (status = 'pendente').
     - FilterChip "Entregues" (status = 'entregue').
   - **Menu de ordenação** (PopupMenuButton com Icons.sort) opções: "Mais recentes" (ordenar=lote), "Valor maior", "Valor menor", "Data produção", "Criado recente".

3. **Lista** (`pedidos.when`):
   - loading → ListView de ~5 skeletons (pode ser CircularProgressIndicator centralizado pra simplificar).
   - error → `ErrorState`.
   - data vazio → `EmptyState(icon: Icons.inbox_outlined, titulo: 'Nenhum pedido', subtitulo: filtro.algumFiltroAtivo ? 'Tente limpar os filtros' : 'Toque em "Novo pedido" para começar')`.
   - data com itens → ListView.separated com `PedidoCard(pedido, onTap: () => context.push('/pedidos/${p.id}'))`.

4. **FloatingActionButton.extended** "Novo pedido" → `context.push('/pedidos/novo')`.

**Importante:** ao tocar num card, **navegar pro DETALHE** (`/pedidos/:id`), não pro edit. O detalhe tem o botão de editar.

**Classe:** `class PedidosScreen extends ConsumerStatefulWidget`.

**Entregáveis:** apenas `pedidos_screen.dart`.

---

# PROMPT 10 — Tela Kanban

**Arquivo a criar:** `C:/Users/Leonardo/Documents/codigos/empresa/app/lib/screens/kanban/kanban_screen.dart`

**Objetivo:** visualizar pedidos como colunas por status. Arrastar um card entre colunas muda o status no servidor.

**Dependências:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../models/pedido.dart';
import '../../state/pedidos_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pedido_card.dart';
import '../../widgets/status_pill.dart';
```

**Assinatura:** `class KanbanScreen extends ConsumerWidget`.

**Estrutura:**

1. AppBar título "Kanban". Actions: refresh e botão Icons.list (volta pra `/pedidos`).

2. Body:
   - Busca todos os pedidos via `ref.watch(pedidosProvider)` (sem filtro).
   - Agrupa por status: `pendente`, `agendado`, `producao`, `concluido`, `entregue`. Um `Map<String, List<Pedido>>`.
   - Mostra **horizontal** (Row com SingleChildScrollView horizontal) uma coluna por status:
     - Largura fixa de 320.
     - Header da coluna (Container com cor StatusPill do status): nome do status + contagem `(${lista.length})`.
     - `DragTarget<Pedido>` que envolve um ListView vertical da coluna.
     - onAcceptWithDetails: chama `api.atualizarPedido(pedido.id, {'status': statusColuna})`, invalida `pedidosProvider`, `dashboardProvider`. Mostra SnackBar "Pedido movido".
     - Cada item é um `Draggable<Pedido>(data: pedido, ...)`:
       - feedback: PedidoCard compacto com opacidade leve dentro de Material.
       - childWhenDragging: Opacity(0.3, child: PedidoCard compacto).
       - child: PedidoCard compacto, onTap: `context.push('/pedidos/${p.id}')`.

3. Em telas estreitas (< 720), mostrar um Scaffold com "swipe entre páginas" (PageView horizontal, uma coluna por página, com dots abaixo). Ou, simplificar: sempre usar horizontal scroll.

4. No mobile o drag-and-drop é mais truncado — aceite que não vai ser perfeito. O principal é mostrar as colunas.

**Cuidados:**
- Ao aceitar drop no status já igual, não faz nada.
- Mostrar `LinearProgressIndicator` no topo enquanto salva.
- `const _statusOrdem = ['pendente', 'agendado', 'producao', 'concluido', 'entregue'];`

**Entregáveis:** apenas `kanban_screen.dart`.

---

# PROMPT 11 — Atualizar agenda_screen com toggle Lista/Semana

**Arquivo a substituir:** `C:/Users/Leonardo/Documents/codigos/empresa/app/lib/screens/agenda/agenda_screen.dart`

**Objetivo:** a agenda ganha um toggle entre 2 modos:
- **Lista** (o que já existia): cards por dia com barra de ocupação.
- **Semana**: 5 colunas (seg a sex), cada coluna mostra os pedidos agendados naquele dia.

**Dependências:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/pedido.dart';
import '../../state/configuracoes_provider.dart';
import '../../state/pedidos_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pedido_card.dart';
import '../../widgets/status_pill.dart';
```

**Classe:** `class AgendaScreen extends ConsumerStatefulWidget`.

Estado: `enum _Modo { lista, semana }`, `_Modo _modo = _Modo.lista`, `DateTime _semanaReferencia = DateTime.now()`.

**Estrutura:**

1. **AppBar** título "Agenda de produção". Actions:
   - `SegmentedButton<_Modo>` pequeno no centro: 'Lista' e 'Semana'.
   - Refresh icon.

2. **Body** muda conforme `_modo`:

### Modo Lista
Renderiza igual ao código antigo — agrupa pedidos com `dataProducao` por dia, mostra Card com:
- Título do dia (EEEE, dd/MM/yyyy).
- Barra de ocupação `total/limite`.
- Linhas de pedidos (lote + cliente + valor).

Mantém a lógica de ler `limite_diario` de `configuracoesProvider`.

### Modo Semana
- Row com 2 botões (<, >) e texto "Semana de dd/MM a dd/MM". Os botões movem `_semanaReferencia` ± 7 dias.
- Calcula os dias úteis (seg, ter, qua, qui, sex) da semana de referência.
- Em tela larga (width >= 720): Row com 5 colunas expandidas, cada uma um Card com:
  - Header: dia da semana em maiúsculas + data (ex "SEG\n14/04").
  - Barra de ocupação (total do dia / limite).
  - Lista vertical de PedidoCard compacto dos pedidos daquele dia.
- Em tela estreita: PageView horizontal, 1 coluna por vez, com dots indicators.

**Helper pra moeda:** `NumberFormat.currency(locale: 'pt_BR', symbol: 'R\\$')`.

**Cuidados:**
- A lógica antiga está em `agenda_screen.dart` — pode aproveitar muito código copiando.
- Não esqueça de tratar loading/error do `pedidosProvider`.
- Onde era "dias úteis (seg a sex)", considerar apenas Monday (1) a Friday (5) de `DateTime.weekday`.

**Entregáveis:** apenas `agenda_screen.dart` reescrito.

---

# PROMPT 12 — Atualizar configuracoes_screen com toggle de tema

**Arquivo a editar:** `C:/Users/Leonardo/Documents/codigos/empresa/app/lib/screens/configuracoes/configuracoes_screen.dart`

**Objetivo:** adicionar uma seção "Aparência" com um SegmentedButton pra escolher entre Claro / Escuro / Automático. O provider `themeModeProvider` e as funções `loadThemeMode`/`saveThemeMode` já existem em `app/lib/state/theme_provider.dart`.

**Instruções:**

1. Importar:
```dart
import 'package:flutter/material.dart';
import '../../state/theme_provider.dart';
```

2. Adicionar uma nova seção (Card) chamada "Aparência" **antes** da seção "Regras de negócio". Ela deve:
   - Usar o widget `_Section` (já existe no arquivo) com icon `Icons.palette_outlined` e title `'Aparência'`.
   - Conter: descrição ("Tema do aplicativo"), e um `SegmentedButton<ThemeMode>` com 3 segmentos:
     - `ThemeMode.light` → icon `Icons.light_mode_outlined`, label 'Claro'.
     - `ThemeMode.dark` → icon `Icons.dark_mode_outlined`, label 'Escuro'.
     - `ThemeMode.system` → icon `Icons.brightness_auto_outlined`, label 'Auto'.
   - `selected: {ref.watch(themeModeProvider)}`.
   - `onSelectionChanged: (Set<ThemeMode> s) { final m = s.first; ref.read(themeModeProvider.notifier).state = m; saveThemeMode(m); }`.

3. **NÃO remover nada do que já existe**. Só adicionar a seção nova no lugar certo (antes de 'Regras de negócio').

**Entregáveis:** apenas `configuracoes_screen.dart`.

---

# PROMPT 13 — Atualizar router.dart e home_shell.dart com novas rotas/abas

**Dois arquivos editados neste prompt:**

## A) `C:/Users/Leonardo/Documents/codigos/empresa/app/lib/router.dart`

Substituir o conteúdo inteiro. Rotas:

- `/dashboard` → `DashboardScreen` (DENTRO da shell)
- `/pedidos` → `PedidosScreen` (shell)
- `/agenda` → `AgendaScreen` (shell)
- `/clientes` → `ClientesScreen` (shell)
- `/configuracoes` → `ConfiguracoesScreen` (shell)
- `/kanban` → `KanbanScreen` (sem shell — tela cheia)
- `/orcamento` → `OrcamentoScreen` (sem shell)
- `/pedidos/novo` → `PedidoFormScreen()` (sem shell). Aceita query param `cliente_id` → passa como `clienteIdInicial`.
- `/pedidos/:id` → `PedidoDetalheScreen(pedidoId)` (sem shell).
- `/pedidos/:id/editar` → `PedidoFormScreen(pedidoId)` (sem shell).
- `/clientes/novo` → `ClienteFormScreen()` (sem shell).
- `/clientes/:id` → `ClienteDetalheScreen(clienteId)` (sem shell).
- `/clientes/:id/editar` → `ClienteFormScreen(clienteId)` (sem shell).

**initialLocation**: `/dashboard`.

**Usar a função `_fadeSlidePage` que já existia**, mantendo as transições suaves. Imports de todas as screens novas necessárias.

**Esqueleto:**
```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/agenda/agenda_screen.dart';
import 'screens/clientes/cliente_detalhe_screen.dart';
import 'screens/clientes/cliente_form_screen.dart';
import 'screens/clientes/clientes_screen.dart';
import 'screens/configuracoes/configuracoes_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/home_shell.dart';
import 'screens/kanban/kanban_screen.dart';
import 'screens/orcamento/orcamento_screen.dart';
import 'screens/pedidos/pedido_detalhe_screen.dart';
import 'screens/pedidos/pedido_form_screen.dart';
import 'screens/pedidos/pedidos_screen.dart';

CustomTransitionPage<T> _fadeSlidePage<T>({required Widget child, required String name}) {
  return CustomTransitionPage<T>(
    name: name,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.02, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 200),
  );
}

final appRouter = GoRouter(
  initialLocation: '/dashboard',
  routes: [
    ShellRoute(
      builder: (context, state, child) => HomeShell(child: child),
      routes: [
        GoRoute(path: '/dashboard', pageBuilder: (c, s) => _fadeSlidePage(child: const DashboardScreen(), name: 'dashboard')),
        GoRoute(path: '/pedidos', pageBuilder: (c, s) => _fadeSlidePage(child: const PedidosScreen(), name: 'pedidos')),
        GoRoute(path: '/agenda', pageBuilder: (c, s) => _fadeSlidePage(child: const AgendaScreen(), name: 'agenda')),
        GoRoute(path: '/clientes', pageBuilder: (c, s) => _fadeSlidePage(child: const ClientesScreen(), name: 'clientes')),
        GoRoute(path: '/configuracoes', pageBuilder: (c, s) => _fadeSlidePage(child: const ConfiguracoesScreen(), name: 'configuracoes')),
      ],
    ),
    GoRoute(path: '/kanban', pageBuilder: (c, s) => _fadeSlidePage(child: const KanbanScreen(), name: 'kanban')),
    GoRoute(path: '/orcamento', pageBuilder: (c, s) => _fadeSlidePage(child: const OrcamentoScreen(), name: 'orcamento')),
    GoRoute(
      path: '/pedidos/novo',
      pageBuilder: (c, s) => _fadeSlidePage(
        child: PedidoFormScreen(clienteIdInicial: s.uri.queryParameters['cliente_id']),
        name: 'novo-pedido',
      ),
    ),
    GoRoute(
      path: '/pedidos/:id',
      pageBuilder: (c, s) => _fadeSlidePage(
        child: PedidoDetalheScreen(pedidoId: s.pathParameters['id']!),
        name: 'pedido-detalhe',
      ),
    ),
    GoRoute(
      path: '/pedidos/:id/editar',
      pageBuilder: (c, s) => _fadeSlidePage(
        child: PedidoFormScreen(pedidoId: s.pathParameters['id']),
        name: 'editar-pedido',
      ),
    ),
    GoRoute(
      path: '/clientes/novo',
      pageBuilder: (c, s) => _fadeSlidePage(child: const ClienteFormScreen(), name: 'novo-cliente'),
    ),
    GoRoute(
      path: '/clientes/:id',
      pageBuilder: (c, s) => _fadeSlidePage(
        child: ClienteDetalheScreen(clienteId: s.pathParameters['id']!),
        name: 'cliente-detalhe',
      ),
    ),
    GoRoute(
      path: '/clientes/:id/editar',
      pageBuilder: (c, s) => _fadeSlidePage(
        child: ClienteFormScreen(clienteId: s.pathParameters['id']),
        name: 'editar-cliente',
      ),
    ),
  ],
);
```

## B) `C:/Users/Leonardo/Documents/codigos/empresa/app/lib/screens/home_shell.dart`

Substituir com 5 destinos: **Início, Pedidos, Agenda, Clientes, Ajustes**.

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeShell extends StatelessWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  static const _destinations = [
    (path: '/dashboard', label: 'Início', icon: Icons.dashboard_outlined, selected: Icons.dashboard),
    (path: '/pedidos', label: 'Pedidos', icon: Icons.assignment_outlined, selected: Icons.assignment),
    (path: '/agenda', label: 'Agenda', icon: Icons.calendar_month_outlined, selected: Icons.calendar_month),
    (path: '/clientes', label: 'Clientes', icon: Icons.people_outline, selected: Icons.people),
    (path: '/configuracoes', label: 'Ajustes', icon: Icons.settings_outlined, selected: Icons.settings),
  ];

  int _indexOf(String location) {
    for (var i = 0; i < _destinations.length; i++) {
      if (location.startsWith(_destinations[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index = _indexOf(location);
    final wide = MediaQuery.sizeOf(context).width >= 720;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              labelType: NavigationRailLabelType.all,
              groupAlignment: -0.9,
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selected),
                    label: Text(d.label),
                  ),
              ],
              onDestinationSelected: (i) => context.go(_destinations[i].path),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selected),
              label: d.label,
            ),
        ],
        onDestinationSelected: (i) => context.go(_destinations[i].path),
      ),
    );
  }
}
```

**Entregáveis:** ambos `router.dart` e `home_shell.dart` atualizados.

---

# APÓS OS 13 PROMPTS

Depois de rodar todos, execute no diretório do app:

```bash
cd C:/Users/Leonardo/Documents/codigos/empresa/app
flutter pub get
flutter analyze
flutter run
```

### Se der erro de análise

1. **"The method 'x' isn't defined"** — provavelmente esqueceu um import ou o arquivo não foi criado ainda. Verifique se todos os 13 prompts foram aplicados.

2. **"Type 'Pedido' doesn't have a field 'y'"** — o modelo Pedido já tem TODOS os campos listados no CONTEXTO COMPARTILHADO. Se a IA inventou um nome diferente, corrija pra usar o nome certo (por ex `dataEntregaCombinada`, não `dataEntrega`).

3. **"The argument type 'String' can't be assigned to 'ThemeMode'"** — `saveThemeMode` recebe `ThemeMode`, não string.

4. **Navegação quebrada** — certifique-se de que o `home_shell.dart` aponta pros caminhos certos (`/dashboard`, não `/home`).

### Fluxo de teste manual

1. Abre o app → deve cair em `/dashboard` com os 4 KPIs.
2. Toca em "Pedidos" na nav bar → vê lista com PedidoCard rico.
3. Toca em "Novo pedido" (FAB) → vê form com todas as 7 seções.
4. Em "Clientes" → cadastra um, edita, vê detalhe com histórico.
5. Em um pedido existente, entra no detalhe → registra um pagamento → vê status mudar.
6. "Kanban" (via ação do AppBar da lista) → drag entre colunas.
7. "Agenda" → alterna entre Lista e Semana.
8. "Ajustes" → muda tema → app atualiza.

---

Fim dos prompts. Se em algum momento a IA fraca inventar nome de campo ou método, confira na seção "COISAS QUE JÁ ESTÃO FEITAS" do CONTEXTO COMPARTILHADO — a verdade tá toda lá.
