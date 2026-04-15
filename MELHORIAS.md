# Melhorias — o que ainda falta pra deixar o app robusto, bonito e fácil

Este arquivo foi reescrito em 2026-04-15 depois de uma auditoria do código real. Tudo que já estava implementado saiu (não era mais útil — só confundia na hora de implementar). O que ficou é o que de fato ainda precisa ser feito pra o sistema substituir as duas planilhas **e** ser uma ferramenta que a oficina queira usar.

**Ordem de leitura:** bloco 1 é base visual (faz antes de criar tela nova), bloco 2 é o coração do "não ser pé no saco" (integrações e atalhos entre o que já existe), 3-5 é o que ainda não tem.

Legenda de severidade (quando aplicável):
- 🔴 crítico — trava leitura, quebra em tamanhos de tela, ou esconde função importante
- 🟡 incômodo — inconsistência que suja mas não impede uso
- 🟢 polimento

---

## 1. Base visual (antes de qualquer tela nova)

Este bloco é o mais barato, mais impactante e **tem que vir antes** das features novas dos blocos 3-5 — senão cada tela nova nasce herdando os mesmos defeitos estruturais. É polimento do que já existe.

### 1.1. Tokens globais do tema

#### 🔴 `Card.color` igual ao `Scaffold` no light
`app/lib/theme.dart:118` — `CardTheme` do light usa `scheme.surface` (`0xFFF9F9F7`), que **é a cor do próprio Scaffold**. No light mode os cards não têm destaque — só sobrevivem pela sombra `alpha: 0.08`, que some em monitor de oficina mal calibrado. O dark mode faz certo com `surfaceContainer`.

Correção: trocar pra `scheme.surfaceContainerLow` (ou `surfaceContainerLowest`). Uma linha, afeta tudo.

#### 🔴 `inversePrimary` azul sobrou do template
`theme.dart:44` (`0xFF99CCFF`) e `:79` (`0xFF0066CC`) — azul puro, enquanto a paleta é verde-petróleo `#00897B`. Aparece no `SnackBar` action text. Trocar por tom derivado do primary.

#### 🟡 Sem tokens de spacing, raio e status
Cada tela escolheu seu próprio padding (`all(12/14/16/18/20)`) e seu próprio raio (cards 16, inputs 12, buttons 10, badges 8, tinted 12) — e cores de status são hardcoded (`Colors.green`, `Colors.orange`, `Colors.green.shade100`, `Color(0xFFFFE0B2)`).

Criar 3 arquivos base:
- `lib/theme/spacing.dart` — `cardPaddingSm/Md/Lg = 12/16/20`, `gapSm/Md/Lg = 8/12/16`.
- `lib/theme/radius.dart` — `radiusSm/Md/Lg/Pill = 8/12/16/999`.
- `lib/theme/status_colors.dart` — função `statusColors(context, status) → (bg, fg)` derivando do `ColorScheme` (variações de `primary`/`tertiary`/`error`/`secondary`). Usar no `_StatusBadge` do cliente detalhe, nos KPIs do dashboard e no chip "Vencendo" do `PedidoCard`.

Depois varrer o app substituindo pelos tokens. É chato mas uma vez feito, as inconsistências somem.

#### 🟡 `SectionHeader` sem gap padronizado
Cada uso escolheu um `SizedBox(height: 8|12|16)` depois dele. Padronizar dentro do próprio widget com `padding: EdgeInsets.only(bottom: 16)`.

---

### 1.2. Dashboard (`dashboard_screen.dart`)

#### 🔴 KPI grid com aspect-ratio errado — cards metade vazios
`:112` — `childAspectRatio: 1.4` (desktop) / `1.2` (mobile). O `KpiCard` tem ~100px de conteúdo real, mas o grid força altura proporcional à largura — em desktop cada card fica com **200+ px** e metade vazio embaixo.

Correção: trocar `childAspectRatio` por `mainAxisExtent: 130` (altura fixa). Isolado, é o fix mais visível do app.

#### 🔴 Hierarquia embaralhada — tudo com o mesmo peso visual
Saudação → data → 4 KPIs → "Ocupação da semana" → "Em produção hoje" → "Prazos vencendo" → "Últimos movimentos", todos empilhados verticalmente mesmo em desktop. Sem ponto focal.

- Mobile: reduzir gap saudação→KPIs de 24 pra 16.
- Desktop ≥ 1100px: pareá-los com `LayoutBuilder`. Linha A = `Ocupação da semana` + `Em produção hoje`; Linha B = `Prazos vencendo` + `Últimos movimentos`.

#### 🟡 `_OcupacaoBar` com label em `SizedBox(width: 130)`
`:309` — em mobile < 360px a barra de progresso fica com quase nada de espaço. Usar `Flexible` ou quebrar em duas linhas.

#### 🟡 KPI "VENCENDO" com hint `"7 dias"` solto
`:137` — o hint parece completar o label mas não emenda visualmente. Trocar o label pra `"VENCEM EM 7 DIAS"` e remover o hint, ou mover o contexto pra tooltip.

#### 🟢 Ícone `print_outlined` duplicado
Aparece na `AppBar` e na `NavigationRail` em desktop. Remover da AppBar no modo wide.

---

### 1.3. Pedidos — Lista (`pedidos_screen.dart`)

#### 🔴 Chip bar sem fade de overflow
`:93-147` — 6 `FilterChip` em `ListView` horizontal sem indicador de scroll. Em tela estreita, o último chip ("Devendo") fica escondido e o usuário não sabe que existe.

Correção: separar em dois grupos — `SegmentedButton` pros 4 status mutuamente exclusivos (pendente/agendado/produção/entregue) e chips separados pras flags independentes (urgentes, devendo). Cabe melhor e deixa claro que status é um e flags são outro.

#### 🔴 Ordenação por `SimpleDialog` sem estado visível
`:38-54` — usuário ordena por "valor maior" e depois não sabe mais qual está ativa.

Trocar por `PopupMenuButton` com checkmark na opção ativa, **ou** mostrar chip embaixo da busca ("Ordenado por: valor ↓") com ação de limpar.

#### 🟡 Toggle Lista ↔ Kanban
As duas telas compartilham a mesma fonte de dados. Kanban hoje é rota separada. Ideal: botão `SegmentedButton` no topo do body ("Lista | Kanban"), mesma tela, só troca o render.

---

### 1.4. Pedido — Detalhe (`pedido_detalhe_screen.dart`)

#### 🔴 7 cards empilhados mesmo em desktop
Cabeçalho → Peça → Arte → Agenda → Entrega → Pagamentos → Observação. Em desktop (≥720px) continua vertical, metade da tela em branco.

Usar `LayoutBuilder` pra emparelhar cards curtos em ≥900px:
- Linha 1: Cabeçalho (full)
- Linha 2: Peça | Arte
- Linha 3: Agenda | Entrega
- Linha 4: Pagamentos (full — dinâmico)
- Linha 5: Observação (full se houver)

#### 🔴 `_Info` com `SizedBox(width: 100)` estoura labels longos
`:562` — labels como "Entrega combinada" vão pra 2 linhas enquanto o valor fica em 1, criando desalinhamento.

Correção: trocar o layout pra coluna (label em `labelSmall` uppercase em cima, valor em `bodyMedium` embaixo) — mais moderno e resolve o problema em mobile e desktop.

#### 🟡 Badge URGENTE com `fontSize: 9.5`
`:95` — abaixo do mínimo legível. Promover pra chip maior ao lado do `StatusPill`, não esse microtexto vermelho.

#### 🟡 PopupMenu "Duplicar / Excluir" sem tratamento
`:41-48` — sem ícones, sem divider, sem cor de destrutivo. Padrão Material: `Duplicar` com `Icons.content_copy`, divider, `Excluir` em `colorScheme.error` com `Icons.delete_outline`.

#### 🟢 Card "Entrega — Entregue" com alpha dentro de card
`:204` — `primaryContainer.withValues(alpha: 0.5)` em cima de um card em cima do Scaffold. Depois do fix de 1.1 já melhora; de qualquer forma, usar `primaryContainer` cheio.

---

### 1.5. Clientes — Lista (`clientes_screen.dart`)

#### 🟡 `_ClienteCard` apertado em mobile
`:107-193` — avatar (44) + nome + telefone + "X pedidos" + valor total + chevron numa row única. Em mobile estreito o valor sobrepõe o telefone.

Remover o chevron, diminuir o avatar pra 36, mover o valor pra uma segunda linha junto com "X pedidos".

#### 🟡 Valor total sem rótulo
`:178-184` — `R$ 4.200,00` no canto sem contexto ("gasto total" ou "devendo"?). Adicionar chip "Total" ou labelzinho em cima.

---

### 1.6. Cliente — Detalhe (`cliente_detalhe_screen.dart`)

#### 🔴 `_StatusBadge` em `Colors.*.shade`
`:453-457` — `Colors.green.shade100`, `orange.shade100`, `grey.shade200`. Péssimo no dark mode. Trocar pelo helper `statusColors()` do 1.1.

#### 🔴 `_FechamentoAtualCard` com alpha em cima de card
`:213` — `primaryContainer.withValues(alpha: 0.15)` sobre card sobre scaffold. Depois do fix 1.1 fica aceitável, mas ideal é `primaryContainer` cheio pra realmente destacar o fechamento ativo.

#### 🟡 `SectionHeader "Histórico de pedidos"` fora de card
`:165` — todas as outras seções estão em card. Quebra a hierarquia. Envolver em card.

#### 🟡 `_StatChip` duplicando `_Chip` do `PedidoCard`
Extrair pra `widgets/tint_chip.dart` compartilhado.

---

### 1.7. Agenda (`agenda_screen.dart`)

#### 🔴 `PageView` mobile sem indicador
`:288-302` — modo Semana em mobile swipa entre 5 dias sem mostrar qual está ativo nem quantos há. Adicionar header `DD/MM ← →` ou `TabBar` em cima.

#### 🔴 5 colunas `Expanded` em desktop ficam ilegíveis
`:270-285` — em 720-1024px cada coluna tem ~150-200px. Cards ficam apertados, chips quebram em 3-4 linhas.

- Aumentar o breakpoint pra `>= 1200` (evita desktop estreito), ou
- Usar scroll horizontal com cada coluna `width: 280`, ou
- Criar uma versão ultra-compacta do card pra esse modo (só lote + cliente + valor + pill de status).

#### 🟡 Modo Lista usa row artesanal em vez de `PedidoCard`
`:182-204` — renderiza `Row` com `SizedBox(width: 76)` + textos. Não usa `PedidoCard`. Inconsistente com o resto do app. Trocar por `PedidoCard(compacto: true)`.

---

### 1.8. Kanban (`kanban_screen.dart`)

#### 🟡 5 colunas `width: 320` fixo estouram tela média
`:66-76` — 1600px mínimos. Em mobile é inusável.

- Mobile (<720): colapsar pra `DefaultTabController` com uma tab por status.
- Desktop: reduzir pra 280px e aceitar scroll horizontal.
- Permitir colapsar colunas vazias clicando no header.

#### 🟡 `DragTarget` border 1↔2 pula 1px no hover
`:182-183` — usar `AnimatedContainer` ou manter border 2px transparente quando não hover.

#### 🟢 Headers das colunas sem agregado
Só mostram `.length`. Adicionar "8 pedidos · R$4.200" — informação útil no fluxo.

---

### 1.9. Orçamento (`orcamento_screen.dart`)

#### 🔴 Inputs soltos sem card delimitador
`:97-217` — Técnica, Região, Quantidade, Cores, Urgente, Peça — tudo empilhado direto no `ListView`. Destoa do resto do app (que sempre envolve em card). Parece form solto.

Envolver em 2 cards: `"Peça e técnica"` + `"Parâmetros"`.

#### 🔴 Bug no stepper de `_cores`
`:158-189` — o listener (`:41`) só atualiza `_cores` se `int.tryParse != null`. Se o usuário apagar o texto, `_cores` trava no valor anterior. Correção: fallback pra `_cores = v ?? 1`, e `InputFormatter` que impede zerar.

#### 🟡 Botão "Calcular" perdido no meio da rolagem
`:228-234` — `FilledButton.icon` solto no ListView. Mover pra `persistentFooterButtons` do `Scaffold` — sempre visível, sem rolar.

#### 🟡 `ChoiceChip` pra Região com só 2 opções
`:123-138` — caso canônico de `SegmentedButton`. Consistência com o resto.

---

### 1.10. Pedido — Form (`pedido_form_screen.dart`)

Este é o arquivo mais longo do app (1072 linhas) e onde o usuário passa mais tempo. É o maior ofensor de UX.

#### 🔴 Scroll infinito sem divisão de etapas
8 seções empilhadas (Cliente → Peça → Arte → Agendamento → Entrega → Pagamento → Observação → Saída). Em mobile, 4 telas cheias pra criar um pedido.

Opção mais barata e que já resolve 70%: **`ExpansionTile` em cada `_SectionCard`**. Cliente + Peça + Agendamento abertos por default, Arte/Entrega/Pagamento/Observação recolhidos. Usuário pula direto pro que precisa.

Se sobrar fôlego depois: no desktop ≥900, mostrar nav lateral das seções à esquerda e form da ativa à direita.

#### 🔴 Card "Saída" em `tertiaryContainer` roxo, enterrado no fim
`:816-900` — único card colorido no form, no final do scroll. É uma ação importante (confirmar entrega) mas fica escondida.

Mover "Confirmar saída" pra `AppBar.actions` quando `_isEdicao && !entregue`. O card atual vira um bloco discreto só com o input "entregue por".

#### 🔴 Aviso "Cliente não vinculado" duplicado
`:420-430` tem warning no `suffixIcon` **e** `:452-497` tem Card grande com mesma mensagem + botão "Criar cliente". Manter só o Card (tem ação), remover o warning do suffix.

#### 🔴 Botão "Salvar" no fim do scroll
`:911-917` — usuário tem que rolar tudo pra salvar. Mover pra `persistentFooterButtons` do `Scaffold`.

#### 🟡 Gaps inconsistentes entre campos paralelos (12 vs 16)
Padronizar em `gapMd = 12` usando o token do 1.1.

#### 🟡 "Calcular orçamento" como `TextButton` alinhado à direita
`:581-588` — funcionalidade importante disfarçada como link. Promover pra `OutlinedButton.icon` full-width, ou ícone de calculadora no `suffixIcon` do campo valor.

#### 🟡 `_DateField` indistinguível de `TextFormField` desabilitado
`:1040-1072` — sem affordance de clique. Manter `Icons.edit_calendar_outlined` no `prefixIcon` quando há data; hover de mouse em desktop.

#### 🟡 Autocomplete registra listener novo a cada rebuild
`:401-413` — `controller.addListener(...)` dentro do `fieldViewBuilder` sem `removeListener`. Cada `setState` adiciona listener novo. Vazamento e chamadas duplicadas. Mover pra `initState` com controller dedicado.

---

### 1.11. Configurações (`configuracoes_screen.dart`)

#### 🟡 Testar / Salvar / Resultado numa linha só
`:90-115` — em mobile o texto "Conectado"/"Erro: ..." some. Transformar feedback em `SnackBar` ou mover pra Container próprio embaixo.

#### 🟡 `Divider` no fim de cada `_ConfigEditor`
`:304` — dentro de card com borda, divider entre itens fica pesado. Trocar por `SizedBox(height: 8)`.

#### 🟢 Chave técnica `c.chave` em cinza poluindo
Mover pra tooltip.

---

### 1.12. Componentes compartilhados (`widgets/pedido_card.dart`)

#### 🔴 Modo `compacto: true` esconde `StatusPill` e `PagamentoPill`
`:161-176` — `if (!compacto)` envolve o footer com as pills. Resultado: no dashboard, kanban, agenda e cliente detalhe (todos usam compacto), **não dá pra saber o status do pedido pelo card**. Compacto é usado onde status importa mais.

Correção: manter `StatusPill` sempre visível — colocar no topo do card, ao lado do lote. `PagamentoPill` pode sumir em compacto se for dar trabalho, mas status não pode.

#### 🟡 `Wrap` de chips sem limite
`:114-159` — em pedidos com muitos atributos viram 3-4 linhas só de chips. Limitar a 3-4 visíveis no compacto.

#### 🟡 Chip URGENTE com `fontSize: 9.5`
`:96` — aumentar pra 11, reduzir peso de `w800` pra `w700`.

#### 🟡 Chip "Vencendo" com cor hardcoded `0xFFFFE0B2 / 0xFFE65100`
`:156-157` — substituir pelo helper `statusColors()`.

---

## 2. Integrações e atalhos ("não ser pé no saco")

O app já tem todas as features básicas, mas várias ficam isoladas em suas telas. Este bloco é sobre **atalhos entre telas** — conseguir fazer o fluxo completo sem quebrar o contexto. É o "exemplo do orçamento ao dar entrada no pedido" do usuário, generalizado.

O princípio é: **cada vez que o usuário precisa fechar uma tela pra abrir outra pra depois voltar, é uma integração que falta.**

### 2.1. Orçamento standalone → criar pedido direto 🔴
Hoje o `orcamento_screen.dart:289` faz `context.pop(total)` — **só funciona quando foi aberto a partir do form de pedido**. Se o usuário abre orçamento pela nav rail, calcula, e quer criar o pedido: ele precisa anotar mentalmente, ir pra Pedidos, clicar "+", abrir o form, preencher de novo a mesma técnica/quantidade/valor.

Correção: detectar se tem rota anterior de form pedido (`GoRouter.of(context).canPop()` + parâmetro `?from=pedido`). Quando for standalone, trocar "Usar este valor" por **"Criar pedido"** que navega pra `/pedidos/novo?orcamento=<json>` pré-preenchendo técnica, peça, quantidade, cores, valor. Mantém o comportamento atual quando chamado do form.

### 2.2. Agenda → clicar dia vazio cria pedido com essa data 🔴
Hoje, pra criar um pedido pra um dia específico, o usuário vai em Agenda, vê o dia que quer, sai pra Pedidos, clica "+", abre o form, e desliga o `_autoAgendar` pra poder escolher a data manualmente.

Correção: no modo Semana, envolver cada `_ColunaDia` em `InkWell`; em `modoLista` cada header de dia. `onTap` → `context.push('/pedidos/novo?data_producao=<yyyy-mm-dd>&auto_agendar=false')`. Texto do empty state do dia vazio: "Nenhum pedido. **Toque pra criar**".

### 2.3. Form → mostrar últimos pedidos do cliente quando vinculado 🟡
Quando o usuário vincula um cliente no autocomplete, atualmente nada muda no resto do form. Serigrafia é recorrência — saber "esse cliente fez 3 camisetas hidro costas pro time semana passada" é ouro pro atendente.

Correção: embaixo do campo cliente, quando `_clienteId != null`, card pequeno com os 3 últimos pedidos desse cliente (lote, descrição, valor, quando) e um botão "Duplicar último". Duplicar copia todos os campos técnicos do último pedido dele.

### 2.4. Validação visual de limite do dia no form 🟡
Quando o usuário escolhe `data_producao` manualmente, mostrar em tempo real: "Esse dia já tem R$X de R$1.200 agendados". Vermelho se estourar, com sugestão "Próximo dia livre: DD/MM". Não bloqueia — só avisa. Usa o endpoint que alimenta a Agenda, cache local por 30s.

### 2.5. Dashboard — KPIs clicáveis 🟡
`widgets/kpi_card.dart` já aceita `onTap`, mas o dashboard nunca passa um. Wireing gratuito:
- "A receber" → `/pedidos?filtro=devendo`
- "Produção hoje" → `/agenda` centrada no dia
- "Vencendo" → `/pedidos?filtro=vencendo`
- "Faturamento do mês" → `/pedidos?de=<1ºdia>&ate=<ultimodia>` (depois que a busca 4.1 existir)

### 2.6. Reagendar automaticamente no pedido detalhe 🟡
O endpoint `POST /pedidos/:id/agendar` já existe (`api_client.dart:89`) mas não tem botão na UI. Adicionar no `PopupMenuButton` do detalhe: "Reagendar automaticamente" — confirma, chama o endpoint, dá feedback.

### 2.7. Duplicar deve ajustar datas 🟡
`duplicarPedido` (hoje) cria o novo copiando `data_chegada` e `data_producao` do original. Um pedido duplicado de 2 meses atrás entra em produção... 2 meses atrás. Garantir no servidor que duplicar zera essas duas datas e chama o agendador com `dataChegada: hoje`.

### 2.8. Telefone do cliente como link pro WhatsApp 🟡
`pedido_card.dart:170-173` mostra `Icons.call_outlined` mas não é clicável. Adicionar `url_launcher` e abrir `wa.me/55<fone>` ao tocar. Mesmo no `pedido_detalhe` e no `cliente_detalhe`. Requer `url_launcher` no pubspec.

### 2.9. Cliente autocomplete — dica de "criar" quando digita nome novo 🟢
Já existe "Criar novo cliente" no fim da lista de opções (`pedido_form:1021`), mas só aparece se houver alguma opção na lista. Quando o texto digitado não casa com nenhum cliente, a lista some inteira e a opção "criar" também. Forçar a opção "criar" a aparecer sempre que o texto não for vazio e não houver match exato.

### 2.10. "Ir pro pedido" ao confirmar saída 🟢
Quando o usuário confirma saída e fecha o form, ele volta pra lista de pedidos — perde o contexto. Voltar pro detalhe do próprio pedido, que agora mostra "✓ Entregue em DD/MM".

---

## 3. Features que ainda não existem

### 3.1. Fotos / upload de arte 🔴

A tabela `pedido_anexos` já existe no schema (`server/lib/db.dart:265`) mas **não tem rota, não tem UI, não tem dep de upload**. A infra está pela metade.

Serigrafia vive de arte visual. Sem anexo, o app não substitui o uso de planilha + pasta de imagens no WhatsApp.

- Rota `POST /pedidos/:id/anexos` com `multipart/form-data` no shelf (shelf suporta via `shelf_multipart` ou parse manual).
- Salvar arquivos em `server/uploads/<pedido_id>/<uuid>.<ext>`. `GET /anexos/:id` serve o arquivo com `Content-Type` certo.
- Deps Flutter: `image_picker` (câmera + galeria) e `file_picker` (arquivos).
- No pedido detalhe, seção "Arte" ganha: grid de thumbnails + botão "Adicionar foto". Tap em thumbnail abre fullscreen com swipe.
- No `PedidoCard`, mini thumbnail circular ao lado do lote quando houver anexo.
- No `pedidos_screen`, filtro "sem foto de arte" (ver 4.1).

### 3.2. Ordem de Serviço em PDF 🔴

A oficina hoje imprime a planilha. Sem uma OS, eles vão continuar dependendo dela.

- Deps: `printing` + `pdf`.
- Template `lib/pdf/ordem_servico.dart` com: cabeçalho (logo + empresa), lote grande, cliente + contato, peça/cor/tamanho/tecido, arte (thumbnail + descritivo), técnica, quantidade, data de produção, prazo, observação, campos em branco pra rubricar etapas (corte, estampa, finalização, embalagem), recibo de entrega.
- QR code do `pedido.id` no canto (ver 3.3).
- Botão "Imprimir OS" no `PopupMenuButton` do pedido detalhe. No Windows usa `printing.directPrint` pra mandar direto pra impressora. No Android usa `Printing.sharePdf`.

### 3.3. QR code + scanner 🟡
- Dep `qr_flutter` pra gerar, `mobile_scanner` pra ler.
- QR do lote no canto da OS (3.2).
- Botão "Escanear lote" na AppBar de Pedidos: abre câmera fullscreen, lê QR, navega direto pro detalhe. Mata o "qual é esse pedido?" na oficina.

### 3.4. Compartilhar pelo WhatsApp 🟡
No detalhe do pedido, botão "Enviar pro cliente" que gera mensagem formatada ("Olá Fulano, seu pedido LOTE0105 — 50 camisetas silk frente — está pronto pra retirada") e abre `wa.me/55<fone>?text=...`. Requer `url_launcher` (já usado na 2.8).

### 3.5. Export CSV 🟡
Contador sempre pede planilha. `GET /pedidos/export?de=&ate=` retornando CSV. Botão na tela de pedidos. Excel abre CSV sem drama.

### 3.6. Agenda visão Mês 🟡
Hoje só tem Lista e Semana. Adicionar `_Modo.mes` ao `SegmentedButton` (`:40-52`). Grid de 5-6 linhas × 7 colunas. Cada célula: número do dia + badge `R$X/R$Y`. Clique abre o dia no modo Lista centrado nele. Dias com ocupação acima do limite em vermelho.

### 3.7. Modo painel na oficina 🟢
Rota `/painel` sem nav bar, tela cheia, letras grandes. Lista pedidos do dia + próximos 2 dias, auto-refresh a cada 30s. Pra deixar num monitor velho na parede da oficina. Sem interação.

### 3.8. Logo + toggle tema manual 🟢
- Asset do logo da Serigrafia Baray em `app/assets/logo.png` (pedir ao dono). Usar no topo da `NavigationRail` em desktop e na `AppBar` do dashboard em mobile.
- Toggle claro/escuro/sistema em Configurações — hoje segue só o sistema. Salvar em `SharedPreferences`.
- Densidade `VisualDensity.compact` quando `width >= 720` (desktop da oficina é apertado de informação).

---

## 4. Produtividade

### 4.1. Busca melhor + filtros avançados 🟡
Hoje busca só por cliente exato. Adicionar:
- SQLite FTS5 (ou `LIKE` dupla pra começar) cobrindo descrição, observação, nome do cliente, lote.
- Filtros: intervalo de datas (chegada/produção/entrega), "urgentes", "devendo", "sem foto de arte" (quando 3.1 estiver pronto), por técnica, por status.
- Ordenação persistida (`SharedPreferences`) — some com a 1.3 "ordenação sem estado visível".

### 4.2. Atalhos desktop 🟡
O PC da oficina é o uso principal. `Actions`/`Shortcuts` do Flutter:
- `Ctrl+N` — novo pedido
- `Ctrl+F` — foca na busca
- `Ctrl+K` — command palette (busca unificada: pedidos, clientes, ações — "novo pedido", "abrir agenda", etc)
- `Esc` — fecha diálogos
- Setas ↑↓ navegam entre pedidos da lista; Enter abre
- Verificar ordem de `Tab` nos forms

---

## 5. Robustez

### 5.1. Autenticação mínima 🔴
O servidor roda em `server2.lbwma.com`. Hoje qualquer um que descubra a URL lê/cria/apaga tudo.
- Middleware `X-API-Key` no shelf, chave via env `EMPRESA_API_KEY`.
- Campo "Chave de acesso" em Configurações do app, salva em `SharedPreferences`, enviada como header em todos os requests do `Dio`.
- É barato e resolve 95% do risco real.

### 5.2. Backup automático + restauração pela UI 🟡
- Cron no servidor: `sqlite3 empresa.db ".backup backups/empresa-$(date +%F).db"` diário, rotação 30 dias.
- Cópia adicional pra Drive/rclone (opcional).
- `GET /admin/backups` lista, `POST /admin/restore/:id` restaura (sempre gerando backup do atual antes).
- Tela em Configurações: listar, baixar, restaurar com confirmação dupla. Atrás da chave da 5.1.

### 5.3. Sincronização em tempo real (SSE) 🟡
PC da oficina + celular do dono abertos ao mesmo tempo não se enxergam. SSE no shelf: `GET /events` emite `pedido.criado/atualizado/removido` como `text/event-stream`. App escuta via `dio` streaming ou `http` cru e invalida os providers Riverpod correspondentes. Unidirecional, simples, resolve.

### 5.4. Erros consistentes no servidor 🟢
Middleware de validação antes das rotas: tipos errados, strings gigantes. Retorno padronizado `{error, code, details}`. No app, interceptor do Dio traduz pra mensagem decente em vez de "Exception: ...".

### 5.5. Log de erro do app pro servidor 🟢
Quando o Flutter crashar ou um request falhar, POST pra `/admin/logs`. Debug remoto sem ter que pedir print pro dono.

---

## Ordem de ataque sugerida

Ordem pensada por **custo × impacto × dependências**. Não precisa seguir à risca, mas itens mais cedo destravam itens depois.

1. **Tokens do tema (1.1)** — fix do `Card.color`, `inversePrimary`, criar `spacing`/`radius`/`statusColors`. **Obrigatório antes de tela nova**, senão elas nascem herdando o defeito. ~2h.
2. **`PedidoCard` mostrar status em compacto (1.12)** — 3 linhas, destrava leitura em dashboard/kanban/agenda/cliente. ~15min.
3. **Dashboard (1.2)** — `mainAxisExtent: 130`, hierarquia desktop com `LayoutBuilder`. ~1h. Visível na hora.
4. **Pedido Form etapas (1.10)** — `ExpansionTile` nas seções, `persistentFooterButtons` pra Salvar, mover "Confirmar saída" pra AppBar. É o maior ofensor de UX. ~3h.
5. **Integrações 2.1 e 2.2 (orçamento↔form e agenda→criar)** — o que o usuário explicitamente pediu. ~2h.
6. **Pedido Detalhe grid desktop + `_Info` coluna (1.4)** — ~1h.
7. **Orçamento em cards + bug stepper + botão fixo (1.9)** — ~1h.
8. **Fotos de arte (3.1)** — infra de upload, rota, `image_picker`, UI de grid, thumbnail no card. Meia dia — é o maior feature que falta.
9. **Auth (5.1)** — deixar de rodar aberto na internet. ~1h. Fazer antes de colocar em uso diário.
10. **Integrações restantes (2.3 a 2.10)** — paralelizáveis, cada uma é pequena.
11. **OS PDF (3.2)** — meio dia. Destrava tirar as planilhas da oficina de vez.
12. **Auditoria restante (1.3, 1.5, 1.6, 1.7, 1.8, 1.11)** — polimento final. Paralelizável, cada tela é isolada.
13. **Backup (5.2), SSE (5.3)** — antes da virada pra uso diário.
14. **Resto sob demanda:** QR+scanner (3.3), WhatsApp share (3.4), CSV (3.5), Mês na agenda (3.6), Painel (3.7), Logo (3.8), Busca FTS (4.1), Atalhos desktop (4.2), Erros consistentes (5.4), Log remoto (5.5).

Depois do item 11 o app já pode ser usado como substituto das duas planilhas. Do 1 ao 9 é o mínimo bloqueador — sem eles o app ainda passa sensação de "CRUD bonitinho".
