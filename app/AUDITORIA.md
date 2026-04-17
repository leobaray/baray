# Auditoria Completa do `app/` — Baray

> Data: 2026-04-16
> Metodologia: leitura manual de todos os 43 arquivos Dart + `flutter analyze` + verificação cruzada com grep

---

## Bugs Reais (comportamento errado)

### BUG 1: `PedidoCard.onTap: () {}` — tap morto no fechamento

**Arquivo**: `lib/screens/clientes/fechamento_detalhe_screen.dart:186`

```dart
PedidoCard(
  pedido: p,
  onTap: () {}, // Navegação futura
  compacto: true,
),
```

O usuário toca no pedido dentro de um fechamento e nada acontece. O comentário "Navegação futura" confirma que é placeholder esquecido.

---

### BUG 2: Acesso direto ao `api.dio` quebra a abstração do ApiClient

**Arquivo**: `lib/screens/clientes/fechamento_detalhe_screen.dart:47-48`

```dart
final dio = api.dio;
final r = await dio.get('/clientes/${widget.clienteId}/fechamentos/${widget.fechamentoId}');
```

Burla o `ApiClient` completamente. Se interceptors, auth headers ou timeout mudarem no `ApiClient`, esse ponto fica desatualizado. O correto é adicionar um método no `ApiClient` que retorne o fechamento com pedidos.

---

### BUG 3: `catch (_)` engole qualquer exceção, não só `StateError`

**Arquivo**: `lib/state/cliente_fechamentos_provider.dart:20-24`

```dart
try {
  return fechamentos.firstWhere((f) => f.aberto);
} catch (_) {
  return null;
}
```

`firstWhere` lança `StateError` quando não encontra elemento. O `catch (_)` captura TUDO — incluindo erros de tipo, erros de rede, null pointer etc. O correto é:

```dart
catch (e) { if (e is StateError) return null; rethrow; }
```

---

### BUG 4: `fechamentoAtualProvider` faz chamada API duplicada desnecessária

**Arquivo**: `lib/state/cliente_fechamentos_provider.dart:17-19`

```dart
final fechamentoAtualProvider = FutureProvider.family.autoDispose<ClienteFechamento?, String>((
  ref, clienteId,
) async {
  final api = ref.watch(apiClientProvider);
  final fechamentos = await api.listarFechamentos(clienteId);  // <-- CHAMADA DUPLICADA
```

Já existe `fechamentosProvider` (linha 6-12) que faz a **mesma chamada** `api.listarFechamentos(clienteId)`. Se as duas rodam, são duas requests HTTP idênticas ao mesmo endpoint. O correto é `ref.watch(fechamentosProvider(clienteId))` para reaproveitar o cache.

---

### BUG 5: `DropdownButtonFormField` usa `value` deprecado em cliente_form_screen

**Arquivo**: `lib/screens/clientes/cliente_form_screen.dart:289,310,326`

```dart
DropdownButtonFormField<String>(
  value: _fechamentoTipo,  // <-- DEPRECADO
```

O `flutter analyze` confirma: `'value' is deprecated and shouldn't be used. Use initialValue instead.` Os outros formulários do app (pedido_form, pedido_detalhe, orcamento) já usam `initialValue` (correto). Este arquivo está desatualizado.

---

## Código Morto

### MORTO 1: `AppRadius` é 100% inútil

**Arquivo**: `lib/theme/radius.dart`

Define `AppRadius.sm=8, md=12, lg=16, pill=999`. **Zero imports** em todo o projeto. Nenhum arquivo, nenhuma tela, nenhum widget referencia. Todos os 62+ `BorderRadius.circular()` no app são hardcoded. Até o próprio `theme.dart` não usa `AppRadius`.

---

### MORTO 2: `AppSpacing` é 82% inútil

**Arquivo**: `lib/theme/spacing.dart`

Define 11 tokens. **Somente 2 são usados** e apenas em `pedido_card.dart`:
- `gapSm` — usado 4x
- `gapLg` — usado 1x (com aritmética `gapLg - 2`, o que é code smell)

Os outros 9 tokens (`gapXs`, `gapMd`, `gapXl`, `cardPaddingSm`, `cardPaddingMd`, `cardPaddingLg`, `screenPaddingH`, `screenPaddingV`, `fabBottomPad`) são **completamente ignorados**. Nenhuma tela importa `AppSpacing`.

---

### MORTO 3: 4 imports `flutter_riverpod/legacy.dart` sem uso

**Arquivos**:
- `lib/api/api_client.dart:3`
- `lib/state/clientes_provider.dart:2`
- `lib/state/pedidos_provider.dart:2`
- `lib/state/theme_provider.dart:2`

Nenhum desses arquivos usa API legacy que não esteja disponível via import principal `flutter_riverpod.dart`.

---

### MORTO 4: `StatusTone.active` nunca usado

**Arquivo**: `lib/theme/status_colors.dart:16`

O valor `active` do enum `StatusTone` existe mas nenhuma tela referencia. Único uso real de `StatusTone` é `StatusTone.warning` no `pedido_card.dart:197` e `StatusTone.success`/`warning`/`neutral` no `cliente_detalhe_screen.dart`.

---

## Duplicação / Incongruência Significativa

### INC 1: 3 sistemas de cores de status independentes

Três formas diferentes de definir cores de status, nenhuma usa a outra:

1. **`status_pill.dart:3-51`** — `StatusInfo` + `statusInfo()`: switch com cores hex hardcoded para `pendente`, `agendado`, `producao`, `concluido`, `entregue`
2. **`status_colors.dart:1-50`** — `StatusPalette` + `StatusTone` + `statusColors()`: tons genéricos `info`, `success`, `warning`, `danger`, `neutral`, `active`
3. **`fechamento_detalhe_screen.dart:229-233`** — `_StatusBadge` local com `Colors.green.shade100`, `Colors.orange.shade100`, `Colors.grey.shade200`

São ~150 linhas de cores duplicadas com propósito semelhante.

---

### INC 2: `buildLightTheme` e `buildDarkTheme` são ~90% duplicados

**Arquivo**: `lib/theme.dart:106-220` vs `lib/theme.dart:224-342`

Dois blocos de ~115 linhas cada. As únicas diferenças são: `_lightScheme` vs `_darkScheme`, shadow alpha (0.08 vs 0.24), e card border no dark. Todo o resto (button padding, chip theme, navigation bar/rail, progress indicator, divider, floating action button) é **copiado e colado**. ~200 linhas poderiam virar ~30 se os valores comuns fossem extraídos.

---

### INC 3: `_ResumoRow` idêntico em 2 arquivos

**Arquivos**: `lib/screens/clientes/cliente_detalhe_screen.dart:458-491` e `lib/screens/clientes/fechamento_detalhe_screen.dart:246-272`

Mesmo nome de classe, mesma implementação, mesmos parâmetros (`label`, `value`, `valueColor?`). Deveria ser widget compartilhado.

---

### INC 4: `_StatusBadge` definido 2x de formas diferentes

- `lib/screens/clientes/cliente_detalhe_screen.dart:433-456` — usa `StatusTone` enum + `statusColors()`
- `lib/screens/clientes/fechamento_detalhe_screen.dart:222-244` — usa `Colors.green.shade100` etc.

Ambos são private e resolvem o mesmo problema visual (badge de status de fechamento).

---

### INC 5: 2 formas de "info row" que fazem a mesma coisa

- `lib/screens/pedidos/pedido_detalhe_screen.dart:640-669` — `_Info(label, valor?)`: label uppercase + valor
- `lib/screens/clientes/cliente_detalhe_screen.dart:412-431` — `_InfoRow(icon, text, theme)`: icon + text row

Deveria haver widget(s) compartilhado(s).

---

### INC 6: `PagamentoPill` duplica estrutura de `StatusPill`

**Arquivo**: `lib/widgets/status_pill.dart`

- `StatusPill` (linhas 53-85): Container + Row(icon+label), padding `8/10 x 4/5`, radius 999, font size 10/11
- `PagamentoPill` (linhas 87-140): Container + Row(icon+label), padding `8/10 x 4/5`, radius 999, font size 10/11

Mesmo layout, mesmos padrões. A única diferença é o switch de cores. Deveria ser um widget "pill" genérico parametrizado.

---

### INC 7: `KpiCard` com cores `Colors.green`/`Colors.orange` bypassa dark mode

**Arquivo**: `lib/screens/dashboard/dashboard_screen.dart:124,131`

```dart
KpiCard(icon: Icons.trending_up, ..., accent: Colors.green, ...),
KpiCard(icon: Icons.account_balance_wallet_outlined, ..., accent: Colors.orange, ...),
```

`Colors.green` e `Colors.orange` são cores fixas do Material que não mudam entre light/dark. No dark mode, o fundo do card muda mas o accent fica igual, criando contraste ruim. Deveria usar cores do `ColorScheme` que respondem ao tema.

---

### INC 8: Breakpoints de responsividade espalhados e inconsistentes

| Arquivo | Linha | Valor | Propósito |
|---------|-------|-------|-----------|
| `home_shell.dart` | 27 | 720 | wide vs mobile |
| `dashboard_screen.dart` | 31 | 720 | wide |
| `dashboard_screen.dart` | 109 | 720 | KPI grid columns |
| `dashboard_screen.dart` | 168 | 1100 | desktop layout |
| `pedido_detalhe_screen.dart` | 92 | 900 | wide |
| `agenda_screen.dart` | 53 | 720 | wide check |
| `agenda_screen.dart` | 276 | 1200 | wide columns |
| `agenda_screen.dart` | 299 | 720 | tablet |

Não existe constante centralizada. Se quiser ajustar o breakpoint, precisa caçar em 6+ arquivos.

---

### INC 9: 2 providers sem `autoDispose` — inconsistente com todos os outros

**Arquivos**:
- `lib/state/clientes_provider.dart:7` — `StateProvider<String>((ref) => '')` sem autoDispose
- `lib/state/configuracoes_provider.dart:6` — `FutureProvider<List<Configuracao>>((ref) async {` sem autoDispose

Todos os outros providers no app usam `autoDispose`. Estes dois ficam na memória mesmo quando ninguém está ouvindo.

---

### INC 10: `Locale('en', 'US')` declarado mas nunca usado

**Arquivo**: `lib/main.dart:42-43`

```dart
locale: const Locale('pt', 'BR'),
supportedLocales: const [Locale('pt', 'BR'), Locale('en', 'US')],
```

Como `locale` está hardcoded para `pt_BR`, `en_US` nunca é selecionado. `localizationsDelegates` também é carregado para algo que nunca é usado. Se o app é só pt_BR, remova `en_US` e simplifique.

---

### INC 11: Router usa `!` em path parameters — pode crashar

**Arquivo**: `lib/router.dart:101,119,134,135`

```dart
child: PedidoDetalheScreen(pedidoId: s.pathParameters['id']!),
child: ClienteDetalheScreen(clienteId: s.pathParameters['id']!),
clienteId: s.pathParameters['clienteId']!,
fechamentoId: s.pathParameters['fechamentoId']!,
```

Se a URL estiver malformada, crash. Em GoRouter com rotas bem definidas é improvável na prática, mas é acesso forçado sem fallback.

---

## Formas que Poderiam Ser Extremamente Mais Simples

### SIMPLES 1: `PedidoFormScreen` com 10+ parâmetros de query no construtor

**Arquivos**: `lib/screens/pedidos/pedido_form_screen.dart:14-37` e `lib/router.dart:81-95`

```dart
const PedidoFormScreen({
  this.pedidoId,
  this.clienteIdInicial,
  this.dataProducaoInicial,
  this.autoAgendarInicial,
  this.pecaInicial,
  this.tecnicaInicial,
  this.quantidadeInicial,
  this.valorInicial,
  this.arteCoresInicial,
  this.urgenteInicial,
});
```

E no router, cada parâmetro é mapeado manualmente:

```dart
PedidoFormScreen(
  clienteIdInicial: qp['cliente_id'],
  dataProducaoInicial: qp['data_producao'],
  autoAgendarInicial: qp['auto_agendar'] == 'false' ? false : null,
  pecaInicial: qp['peca'],
  tecnicaInicial: qp['tecnica'],
  quantidadeInicial: qp['quantidade'],
  valorInicial: qp['valor'],
  arteCoresInicial: qp['arte_cores'],
  urgenteInicial: qp['urgente'] == 'true' ? true : null,
),
```

Deveria receber o `Map<String, String>` de query parameters e extrair internamente. Se adicionar um novo parâmetro, precisa tocar em 3 arquivos hoje.

---

### SIMPLES 2: `NumberFormat.currency` e `DateFormat` recriados a cada build

**23+ instâncias** em screens. Cada `build()` chama:

```dart
final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final dataFmt = DateFormat('dd/MM/yyyy', 'pt_BR');
```

`NumberFormat` faz parsing do locale a cada chamada — é caro. Deveria ser cacheado como `static final` ou via provider.

---

### SIMPLES 3: Parse/format manual de data em 2 locais

**`api_client.dart:158-160`**:

```dart
final dataStr = '${novaData.year.toString().padLeft(4, '0')}-'
    '${novaData.month.toString().padLeft(2, '0')}-'
    '${novaData.day.toString().padLeft(2, '0')}';
```

**`pedido_form_screen.dart:126-135`** faz o parse reverso manualmente:

```dart
final parts = widget.dataProducaoInicial!.split('-');
if (parts.length == 3) {
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
```

Dart tem `toIso8601String()` e `DateFormat('yyyy-MM-dd')` — não precisa recriar.

---

## Outros

- **Zero testes**: O diretório `app/test/` não existe. 43 arquivos Dart de lógica de negócio sem cobertura.
- **`flutter analyze`** retornou 22 infos (nenhum error/warning), incluindo `use_build_context_synchronously` em 3 locais e `deprecated_member_use` para `DropdownButtonFormField.value`.