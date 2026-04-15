# Melhorias — o que falta pro app substituir 100% as planilhas

Fonte única. Este arquivo lista tudo que falta pro sistema Flutter cobrir o que hoje é feito em duas planilhas (a de produção `Controle_Produção_Com_Macro_Completa.xlsm` e a planilha de saída que o dono mantém separada) e ficar **visualmente completo** pra entregar como produto final.

A ordem é por impacto real: primeiro o que é bloqueador pra parar de usar as planilhas, depois o que dá acabamento visual, por último o que é técnico de manutenção.

---

## Contexto do que é usado hoje

**Planilha de produção (`Pedidos`):** descrição livre, valor, data de chegada, lote gerado por macro, data de produção agendada por macro (limite R$1.200/dia, pula fim de semana), prazo calculado por macro. Aba `ORÇAMENTO` é uma calculadora por técnica × tamanho × quantidade. Aba `PREÇOS` é a tabela 2026 de referência + `Tabela3` com recebíveis futuros (data + valor).

**Planilha de saída (separada):** é onde o dono cadastra **os dados completos do pedido** (quem é o cliente, contato, o que foi combinado) e depois marca um "OK" confirmando a saída/entrega. Ele disse textualmente que isso **pode ser unificado** com o sistema.

**App atual:** navegação `Pedidos / Agenda / Ajustes`. CRUD de pedidos com campos básicos (cliente como texto livre, descrição, peça, técnica, qtd, valor, chegada, produção, status, urgente, observação). Agenda agrupa por dia e mostra barra até o limite. Configurações expõem as regras (urgência, moletom, matriz, limite diário) mas **nenhuma delas é aplicada em lugar nenhum** — são só números salvos. Schema tem tabelas `clientes` e `tabela_preco` criadas, **sem rotas e sem telas**.

---

## BLOCO 1 — O que ainda é planilha e precisa sair dela

### 1.1. Unificar com a planilha de saída (demanda explícita do dono)

Hoje o pedido no app tem só cliente_nome (string) e descrição. Pra matar a planilha de saída, o pedido precisa guardar **tudo que é necessário pra entrada e pra saída**, num único registro.

Campos novos na tabela `pedidos`:
- **Contato do cliente no ato do pedido:** `cliente_telefone`, `cliente_email` (opcional).
- **Entrega:** `forma_entrega` (retirada / entrega), `endereco_entrega`, `data_entrega_combinada`, `entregue_em` (timestamp do "OK"), `entregue_por` (quem autorizou/retirou).
- **Detalhes da peça:** `cor_peca`, `tamanho_peca` (P/M/G/GG/etc — pode ser string porque varia), `tecido`.
- **Arte:** `arte_cores` (número), `arte_tamanho_cm`, `arte_posicao` (frente / costas / manga / peito esquerdo / ...), `arte_observacao`.
- **Financeiro:** `forma_pagamento`, `valor_pago`, `sinal_pago`, `status_pagamento` (pago / parcial / devendo).

Form do pedido passa a ser organizado em seções recolhíveis: **Cliente • Peça • Arte • Prazo • Pagamento • Saída**. A última seção ("Saída") é um card grande com botão **"Confirmar saída"** — é o "OK" do dono, vira `entregue_em = now()` e muda status pra `entregue`.

### 1.2. Cadastro de clientes de verdade

A tabela `clientes` existe no schema e nunca foi usada. Enquanto cliente for string livre, "Jão", "João" e "JOAO" viram três clientes no relatório.

- Rota `/clientes` (GET/POST/PUT/DELETE) no servidor.
- Tela `/clientes` no app com busca, lista e CRUD (nome, telefone, email, endereço, observação).
- No form do pedido, campo de cliente vira autocomplete que busca na tabela e permite criar no ato.
- Histórico do cliente: tocar num cliente abre detalhe com todos os pedidos dele, total gasto, último pedido. Serigrafia é negócio de recorrência — isso tem valor comercial imediato.
- Migração one-shot: varrer pedidos existentes, agrupar por `cliente_nome` normalizado, criar clientes e ligar `cliente_id`.

### 1.3. Agendador automático (o que a macro `Módulo6` faz)

A macro é o coração da planilha: decide em que dia cada pedido entra em produção, respeitando R$1.200/dia e pulando fim de semana. Hoje o app depende do usuário escolher a data na mão — é um retrocesso em relação à planilha.

- Endpoint `POST /pedidos/:id/agendar` (ou parâmetro `auto_agendar: true` no POST).
- Lógica no servidor: começa no `data_chegada` (ou hoje se vazio), soma o valor dos pedidos já agendados por dia, procura o primeiro dia útil com espaço pro valor do pedido atual, grava em `data_producao`. Pula sábado/domingo conforme configs `producao_sabado` / `producao_domingo` (que já existem).
- **Correção do bug da macro original:** o `Módulo6` começa de `Date()` ignorando a data de chegada. O app deve começar da `data_chegada` (é o que o dono realmente quer).
- **Correção do bug de pedido grande:** se `valor > limite_diario`, distribuir em N dias consecutivos em vez de sobrescrever o mesmo dia. Gravar na tabela um registro `pedido_distribuicao (pedido_id, data, parcela_valor)` — fica explícito e permite a agenda renderizar certo.
- Botão "Reagendar automaticamente" na tela do pedido. Agenda mostra cadeado/pin nos que foram fixados manualmente.

### 1.4. Cálculo automático de prazo (o que a macro `Módulo7` faz)

Já existe o campo `prazo_dias` e a config `prazo_padrao_dias = 5`, mas nada preenche. Na planilha só 11 de 78 linhas tinham prazo.

- No servidor, ao agendar: `prazo_dias = diasUteis(data_chegada → data_producao)` e `data_prazo = data_chegada + prazo_padrao_dias` como limite alvo.
- No card do pedido, mostrar "⏰ entrega até dd/mm" com cor: verde (>2 dias), amarelo (≤2 dias), vermelho (atrasado).
- Filtro "Vencendo" e "Atrasado" na lista.

### 1.5. Calculadora de orçamento (a aba `ORÇAMENTO`)

Essa aba inteira não existe no app. É uma das principais coisas que o atendente usa pra fechar pedido. Tabela `tabela_preco` existe no schema mas está vazia e sem rotas.

- Popular `tabela_preco` com a matriz da aba `PREÇOS` da planilha (técnica × região × faixa de qtd → 1ª cor / demais cores). Seed inicial por migração.
- Rota `GET /tabela-preco` e `POST /orcamento/calcular` no servidor.
- Tela `/orcamento` no app: inputs (técnica, região, quantidade, nº de cores, urgente?, peça = moletom aberto/fechado/normal), saída = preço por peça e total.
- **Aplicar as regras das configurações que hoje estão mortas:**
  - `taxa_urgencia_pct` (25%) quando `urgente=true`
  - `adicional_moletom_aberto_pct` (20%) e `adicional_moletom_fechado_pct` (60%)
  - `matriz_padrao_40x50` (35) e `matriz_padrao_50x60` (45), **zerados acima de `matriz_gratis_acima_pcs` (150)**
- Botão "Usar este valor" preenche `valor` no form do pedido (editável — é sugestão, não trava).

### 1.6. Controle de fiado e recebíveis (a `Tabela3` da planilha)

A `Tabela3` da planilha (pedido / data / valor) é o jeito rústico do dono controlar quem deve o quê. Serigrafia frequentemente entrega antes de receber.

- Tabela `pedido_pagamentos (id, pedido_id, valor, forma, quando, observacao)`.
- No detalhe do pedido, seção "Pagamentos" com lista + botão "registrar pagamento".
- Chip de status de pagamento na lista (✓ pago / ◐ parcial / ⚠ devendo).
- Filtro e aba "A receber" listando devedores com total.
- Card "R$ a receber" no dashboard.

---

## BLOCO 2 — Visual completo

Falta identidade visual e sensação de produto acabado. Hoje o app abre direto numa lista crua.

### 2.1. Dashboard como tela inicial

Substituir `initialLocation` de `/pedidos` pra `/dashboard`. O que vai na tela:

- **Cards KPI:** faturamento do mês, pedidos em produção hoje, prazos vencendo em 7 dias, total a receber.
- **Ocupação da semana:** gráfico de barras (valor agendado vs limite) pros próximos 7 dias úteis. `fl_chart` resolve.
- **Fila de hoje:** card com os pedidos que entram em produção no dia, clicável.
- **Entregas previstas:** pedidos com `data_entrega_combinada` próxima.
- **Últimos movimentos:** lista compacta dos últimos 5 pedidos criados/atualizados.

### 2.2. Kanban por status (visão alternativa dos pedidos)

Lista vertical é ruim pra enxergar o fluxo. Colunas: **Pendente → Agendado → Em produção → Concluído → Entregue**. Drag entre colunas muda o status. Usa a mesma fonte de dados da lista — zero backend novo.

Adicionar o status **`entregue`** (hoje só vai até `concluido`). Converse com o "OK" da seção 1.1.

### 2.3. Agenda com visão de calendário real

Hoje a agenda é lista vertical de dias. Adicionar toggle **Lista ↔ Semana ↔ Mês**:
- Semana: 5 colunas (seg-sex), cards coloridos por status em cada dia, barra de ocupação no topo de cada coluna.
- Mês: grid com badge de valor total / limite em cada célula, clique abre o dia.
- Arrastar card entre dias reagenda (com confirmação se estourar limite).

### 2.4. Identidade visual coerente

- Definir paleta no `theme.dart` com cores da marca (hoje é o azul default do Material 3). Perguntar cor preferida ao dono; enquanto isso usar um tom sóbrio de azul/verde-petróleo.
- Logo da Serigrafia Baray no topo da nav rail (desktop) e no AppBar (mobile).
- `empresa_nome` da config já existe — usar consistentemente.
- Toggle claro/escuro manual nas Configurações (hoje segue o sistema).
- Densidade compacta no desktop (`VisualDensity.compact` quando `width >= 720`).

### 2.5. Card de pedido mais informativo

Hoje o card tem lote + cliente + descrição + valor + datas + status. Adicionar discretamente:
- Badge com nº de cores da arte e posição ("3c • costas").
- Foto da arte como thumbnail circular (ver 3.1).
- Ícone do telefone (tap abre WhatsApp do cliente — `wa.me/<fone>`).
- Indicador de pagamento (✓ / ◐ / ⚠).
- Chip "⚠ hoje" quando `data_producao == hoje`.

### 2.6. Empty states e microinterações

- Ilustração/ícone grande em cada empty state (lista vazia, agenda vazia, cliente sem pedidos).
- Snackbar com ação de desfazer ao excluir pedido (undo em 5s — guardar em memória e re-POST se desfizer).
- Animação de check quando confirmar saída do pedido — é o momento de satisfação do usuário, merece gosto.
- Haptic feedback no mobile em ações importantes (salvar, confirmar saída).

### 2.7. Modo "apresentação" na oficina

Tela cheia, letras grandes, auto-refresh a cada 30s, lista dos pedidos do dia + próximos 2 dias. Pra deixar num monitor velho na parede da oficina sem interação. Rota `/painel` sem nav bar.

---

## BLOCO 3 — Fechando o ciclo (produção → saída)

### 3.1. Anexar fotos / arquivo de arte ao pedido

Serigrafia vive de arte visual. Sem isso, o app **não substitui** a planilha + pasta de imagens no WhatsApp que eles usam hoje.

- Tabela `pedido_anexos (id, pedido_id, tipo, caminho, nome_original, criado_em)`.
- Upload multipart no servidor, arquivos em `/sistemas/server2/uploads/<pedido_id>/`.
- `image_picker` + `file_picker` no app (câmera, galeria, arquivo).
- Thumbnails no detalhe, fullscreen ao tocar, swipe entre anexos.
- Mini thumbnail no card da lista (ver 2.5).

### 3.2. Ordem de Serviço imprimível (PDF)

A oficina precisa de um papel pra trabalhar com o pedido. Hoje eles imprimem a planilha.

- Pacote `printing` + `pdf`.
- Template da OS com: cabeçalho da empresa, lote, cliente + contato, peça/cor/tamanho, arte (thumbnail + descritivo estruturado da 1.1), quantidade, técnica, data de produção, prazo, observação, campos em branco pra rubricar etapas e o recibo de entrega.
- QR code do lote no canto (ver 3.3).
- Botão "Imprimir OS" na tela do pedido — imprime direto no Windows da oficina e compartilha no Android.

### 3.3. QR code + scanner

- QR do `pedido.id` no canto da OS (3.2).
- `mobile_scanner` no app: botão "Escanear lote" no AppBar abre a câmera e navega direto pro pedido. Mata "qual é esse pedido?" na oficina.

### 3.4. Compartilhar pelo WhatsApp

Botão "Enviar pro cliente" no detalhe do pedido, gera mensagem formatada ("Olá Fulano, seu pedido LOTE0105 (50 camisetas silk frente) está pronto pra retirada") e abre `wa.me/<fone>?text=...`. Telefone sai do cadastro (1.2).

### 3.5. Exportar CSV/Excel

Contador sempre pede planilha. Endpoint `GET /pedidos/export?de=&ate=&formato=csv|xlsx` e botão na tela de pedidos. Por enquanto CSV basta (Excel abre).

---

## BLOCO 4 — Busca, filtros e produtividade

### 4.1. Busca melhor

Hoje é só cliente exato. Adicionar:
- Full-text por descrição/observação (SQLite FTS5 ou `LIKE` dupla já resolve no começo).
- Filtro por intervalo de datas (chegada, produção, entrega).
- Filtro "urgentes apenas", "com pendência de pagamento", "sem foto de arte".
- Ordenação: mais recente, prazo, valor, status.

### 4.2. Atalhos desktop (o PC da oficina é o uso principal)

- `Ctrl+N` novo pedido
- `Ctrl+F` busca
- `Ctrl+K` command palette (busca unificada de pedidos, clientes, ações)
- `Esc` fecha diálogos
- Setas pra navegar entre pedidos da lista
- Tab funcional no form (verificar ordem)

### 4.3. Duplicar pedido

Cliente recorrente pede a mesma coisa. Botão "Duplicar" no menu do pedido → abre o form já preenchido menos id/lote/datas. Uma linha, economiza minutos por dia.

### 4.4. Validação visual de limite no form

Ao escolher `data_producao` no form, mostrar em tempo real: "Esse dia já tem R$X agendado (limite R$1.200)". Se estourar, destaca em vermelho e sugere o próximo dia livre — não bloqueia, só avisa (coerente com pragmatismo > rigidez).

### 4.5. Seed inicial de clientes da planilha antiga

Script one-shot que lê o `.xlsm`, extrai nomes únicos da col A/B, cria registros em `clientes`. Pra o dono não começar do zero no dia da virada.

---

## BLOCO 5 — Confiabilidade e manutenção

### 5.1. Autenticação mínima

O servidor roda em tunnel (`server2.lbwma.com`). Hoje qualquer URL descoberta consegue ler/criar/apagar tudo.
- Middleware `X-API-Key` no shelf, chave via env `EMPRESA_API_KEY`.
- Campo "Chave de acesso" nas Configurações do app, salva em `SharedPreferences`.
- Barato e resolve 95% dos riscos reais.

### 5.2. Backup automático + restauração no app

- Cron diário no servidor: `sqlite3 empresa.db ".backup backups/empresa-$(date +%F).db"`, rotação de 30 dias.
- Cópia adicional pra um Drive/rclone.
- Endpoint `GET /admin/backups` lista, `POST /admin/restore` restaura (sempre gerando backup do atual antes).
- Tela em Configurações: listar, baixar, restaurar com confirmação dupla. Protegido pela chave da 5.1.

### 5.3. Migrations versionadas

`db.dart` usa `CREATE TABLE IF NOT EXISTS`. Este melhorias.md sozinho vai adicionar ~8 colunas novas em `pedidos` e 2 tabelas novas — na primeira alteração de coluna já dói.
- Tabela `schema_version`.
- Pasta `server/lib/migrations/NNN_nome.dart`, rodadas em ordem dentro de transação no boot.
- Framework não é necessário — 40 linhas de Dart. **Fazer isso antes de mexer no schema da 1.1.**

### 5.4. Sincronização em tempo real (SSE)

Dois dispositivos abertos (PC da oficina + celular do dono) não se enxergam. Server-Sent Events no shelf: `GET /events` emite `pedido.criado/atualizado/removido`. App escuta e invalida os providers Riverpod correspondentes. Unidirecional, simples, resolve.

### 5.5. Validação e erros consistentes no servidor

Middleware que rejeita payload inválido antes da rota (tipos errados, strings gigantes) e retorna `{error, code, details}` sempre no mesmo formato. O app mostra mensagem decente em vez de "Exception: ...".

### 5.6. Log de erro do app pro servidor

Quando o Flutter crashar ou um request falhar, POST pro `/admin/logs`. Debug remoto sem pedir print pro dono.

---

## BLOCO 6 — Auditoria visual e de layout (2026-04-15)

**Escopo deste bloco é diferente dos anteriores.** Os blocos 1–5 listam o que falta construir; este bloco lista o que já existe mas está **mal-arrumado na tela**. O app "está bonito", mas tem muita coisa pouco ordenada: espaçamentos inconsistentes, cards que somem no fundo, cores hardcoded fora do tema, aspect-ratio errado de grid, telas sem hierarquia clara, formulário gigante sem divisão em etapas. É polimento estrutural — sem ele o app passa sensação de "CRUD bonitinho" em vez de produto acabado.

Severidades usadas aqui:
- **🔴 Crítico** — trava leitura, quebra em certos tamanhos de tela, bug visual claro, ou funcionalidade escondida.
- **🟡 Incômodo** — inconsistência que suja, mas não impede uso.
- **🟢 Polimento** — detalhe fino, baixa prioridade.

### 6.1. Problemas globais do tema (afetam tudo)

#### 🔴 `Card.color` igual ao `Scaffold` no tema claro
Em `app/lib/theme.dart:118` o `CardTheme` do light mode usa `scheme.surface` como cor do card. Mas `scheme.surface` **é a mesma cor do fundo do Scaffold** (`0xFFF9F9F7`). Resultado: no light mode os cards não têm destaque nenhum contra o fundo — só sobrevivem pela sombra com `alpha: 0.08`, que some em monitores de oficina menos calibrados. O dark mode faz certo usando `surfaceContainer`.

Correção: usar `scheme.surfaceContainerLow` (ou `surfaceContainerLowest`) no light. É uma linha. Mexe em TODAS as telas do app e é o item de maior impacto visual pelo menor esforço.

#### 🔴 `inversePrimary` azul sobrou do template
`theme.dart:44` e `theme.dart:79` têm `inversePrimary: Color(0xFF99CCFF)` / `Color(0xFF0066CC)` — azul puro, herança do template Material. A marca é verde-petróleo (`#00897B`). Só é usado no action text de `SnackBar`, mas destoa feio quando aparece. Trocar por um tom derivado do primary.

#### 🟡 Paddings de card inconsistentes
Sem tokens. Cada tela escolheu o próprio:
- Dashboard — `EdgeInsets.all(16)` (`dashboard_screen.dart:149`)
- Pedido detalhe — `all(20)` (`pedido_detalhe_screen.dart:67`)
- Cliente card — `all(18)` (`clientes_screen.dart:127`)
- KPI card — `all(20)` (`widgets/kpi_card.dart:30`)
- `PedidoCard` compacto — `all(14)` (`widgets/pedido_card.dart:43`)
- `PedidoCard` normal — `all(18)` (`widgets/pedido_card.dart:43`)
- Agenda `_ColunaDia` — `all(12)` (`agenda_screen.dart:341`)

Solução: criar `lib/theme/spacing.dart` com tokens fixos (`cardPaddingLg = 20`, `cardPaddingMd = 16`, `cardPaddingSm = 12`) e usar sempre um deles. Mesmo que os valores fiquem diferentes entre si, eles deixam de ser mágicos.

#### 🟡 Raios de borda inconsistentes
Pelo menos 6 valores diferentes em uso:
- Card `16`, Input `12`, Button `10`, Chip `999` (pill), badge `8`, container tinted `12`, mini-chip `8`.

Reduzir pra escalão único: `radiusSm = 8`, `radiusMd = 12`, `radiusLg = 16`, `radiusPill = 999`. Atribuir cada componente a um escalão (chip/badge→`sm`, input/tinted-box→`md`, card/surface→`lg`).

#### 🟡 Cores hardcoded fora do `ColorScheme`
Estragam o dark mode e fogem da paleta:
- `dashboard_screen.dart:118` — `Colors.green` no KPI faturamento
- `dashboard_screen.dart:124` — `Colors.orange` no KPI a receber
- `cliente_detalhe_screen.dart:453-457` — `_StatusBadge` usa `Colors.green.shade100 / orange.shade100 / grey.shade200` direto
- `widgets/pedido_card.dart:156-157` — `Color(0xFFFFE0B2)` e `Color(0xFFE65100)` pro chip "Vencendo"
- `configuracoes_screen.dart:110` — `Colors.green` pro feedback "Conectado"

Criar um helper `statusColors(context, status)` que devolve `(bg, fg)` a partir do `ColorScheme` (variações do `primary`, `tertiary`, `error`, `secondary`) e usar em todos os lugares.

#### 🟡 FAB tampa último item em `pedido_detalhe`
Todas as listas usam `padding: EdgeInsets.fromLTRB(16, 16, 16, 96)` pra não deixar o FAB cobrir o último card. **Menos uma:** `pedido_detalhe_screen.dart:63` usa `(16, 16, 16, 32)`. O detalhe não tem FAB, então é ok — **mas** o `cliente_detalhe` tem FAB e usa `96` corretamente (`cliente_detalhe_screen.dart:57`). Revisar cada tela que tem FAB e padronizar `bottom: 96`.

#### 🟡 `SectionHeader` sem padrão
Usado em dashboard, pedido_detalhe, cliente_detalhe, orcamento, configuracoes, pedido_form — cada um com espaçamento diferente depois dele (`SizedBox(height: 8)`, `12`, `16`). Padronizar dentro do próprio widget.

---

### 6.2. Dashboard (`dashboard_screen.dart`)

#### 🔴 KPI grid com `childAspectRatio` errado
`dashboard_screen.dart:112` usa `childAspectRatio: 1.4` em desktop e `1.2` em mobile. O `KpiCard` tem cerca de 100px de conteúdo real (ícone + label + valor), mas o grid força altura proporcional à largura — resultado: em desktop os cards ficam com **200+ px de altura**, metade disso em branco. Página rola sem motivo. Em mobile é menos grave mas ainda sobra.

Correção: trocar `childAspectRatio` por **`mainAxisExtent: 130`** (altura fixa) — ou aumentar o ratio pra `1.9` desktop / `1.7` mobile. Testar visualmente.

Isso é o problema isolado de maior impacto no dashboard.

#### 🔴 Hierarquia visual embaralhada
A tela empilha, de cima pra baixo: saudação (headlineMedium) → data (bodyMedium) → 4 KPIs → "Ocupação da semana" → "Em produção hoje" → "Prazos vencendo" → "Últimos movimentos". **Tudo com peso visual parecido.** Em mobile vira rolagem longa sem ponto focal; em desktop (`>=720`) o layout continua empilhado verticalmente, desperdiçando metade da largura.

Sugestão de reorganização:
- **Mobile:** manter ordem, mas reduzir gap saudação→KPIs de `24` pra `16`.
- **Desktop:** usar `LayoutBuilder` e em `width >= 1100` parear: linha 1 = `Ocupação da semana` + `Em produção hoje`, linha 2 = `Prazos vencendo` + `Últimos movimentos`. Cada um ocupa metade.

#### 🟡 `_OcupacaoBar` — largura fixa de texto em 130px
`dashboard_screen.dart:309` — `SizedBox(width: 130)` pro label `"R$ X / R$ Y"`. Em mobile estreito (< 360px, orientação retrato), a barra de progresso fica com quase nada de espaço. Solução: usar `Flexible` com `TextAlign.end` ou quebrar em duas linhas (valor ocupado em cima, limite embaixo).

#### 🟡 KPI "VENCENDO" com hint enigmático
`dashboard_screen.dart:137` — label `"VENCENDO"` + hint `"7 dias"`. O hint parece completar o label ("vencendo em 7 dias") mas visualmente vira rótulo solto. Ou move pra tooltip do card, ou troca o label pra `"VENCEM EM 7 DIAS"` e tira o hint.

#### 🟡 KPI "PRODUÇÃO HOJE" usa `theme.colorScheme.tertiary` e "VENCENDO" usa `error`
Mistura cores do tema com cores hardcoded (`Colors.green`, `Colors.orange`) nos outros dois KPIs. Uniformizar: ou todos do tema, ou todos da paleta custom.

#### 🟢 Ícone `print_outlined` duplicado
Aparece no AppBar (`dashboard_screen.dart:36`) E na `NavigationRail` leading (`home_shell.dart:42`) em desktop. Quando a NavigationRail está visível, o ícone na AppBar é redundante. Remover da AppBar no modo wide.

---

### 6.3. Pedidos — Lista (`pedidos_screen.dart`)

#### 🔴 Chip bar horizontal sem indicação de overflow
`pedidos_screen.dart:93-147` — 6 `FilterChip` em `ListView` horizontal, sem shadow/fade nas laterais, sem scroll hint. Em telas estreitas o último chip ("Devendo") fica escondido e o usuário não sabe que existe. Correção: adicionar gradient fade-out à direita (via `ShaderMask`) ou limitar a 4 chips principais e mover os outros pra menu "mais filtros".

Melhor ainda: segmentar o `FilterChip` de status (pendente/agendado/producao/entregue são mutuamente exclusivos) em um `SegmentedButton` separado do chip `Urgentes` / `Devendo` (que são flags independentes). Hoje os 4 status + 2 flags estão misturados no mesmo row e confunde.

#### 🔴 `SimpleDialog` pra ordenação é datado
`pedidos_screen.dart:38-54` — abre um `SimpleDialog` com 6 opções de ordenação. O estado atual (qual ordenação está ativa?) **não aparece em lugar nenhum depois de fechado**. Usuário ordenou por "valor maior" e não sabe mais.

Correções possíveis:
1. Trocar por `PopupMenuButton<String>` com checkmark na opção ativa.
2. Ou mostrar chip abaixo da busca: `"Ordenado por: valor ↓"` (com ação de limpar).
3. Ou bottom sheet modal com radio list.

#### 🟡 AppBar com 3 ícones sem agrupar
`pedidos_screen.dart:33-67` — Sort + Refresh + Kanban soltos. Refresh não precisa ficar ali (pull-to-refresh já funciona). Kanban poderia virar **toggle `Lista ↔ Kanban` no topo do body**, como a Agenda faz com `SegmentedButton` — as duas telas compartilham mesma fonte de dados, faz sentido serem "modos" da mesma tela.

#### 🟡 Hierarquia de padding incoerente
Busca `(16, 12, 16, 4)` + chips horizontal scroll com padding interno `horizontal: 16` mas externo zero + `SizedBox(height: 4)` + lista `(16, 4, 16, 96)`. Três cadeias de padding diferentes pra organizar três componentes. Solução: envolver busca + chips em um `Container` com padding vertical único e `Divider` sutil separando do ListView.

---

### 6.4. Pedido — Detalhe (`pedido_detalhe_screen.dart`)

#### 🔴 7 cards empilhados verticalmente
Cabeçalho → Peça → Arte → Agenda → Entrega → Pagamentos → Observação. Em mobile é aceitável; em **desktop (≥720)** continua empilhado, resultando em scroll longo com metade da tela em branco à direita. A solução é `LayoutBuilder` emparelhando cards curtos:
- Linha 1: Cabeçalho (width total, tem valor grande)
- Linha 2: `Peça` | `Arte`
- Linha 3: `Agenda` | `Entrega`
- Linha 4: `Pagamentos` (width total — lista dinâmica)
- Linha 5: `Observação` (width total se houver)

#### 🔴 `_Info` com label width fixo em 100px
`pedido_detalhe_screen.dart:562` — `SizedBox(width: 100)` pro label. Labels como `"Entrega combinada"` ou `"Observação"` (do card Arte) estouram e vão pra 2 linhas enquanto o valor fica em 1 só, criando desalinhamento feio. Mesmo quando o label cabe, o valor cola visualmente nele sem respiro quando é longo.

Correções:
1. Aumentar pra `120px` (cabe tudo) e adicionar `SizedBox(width: 12)` entre label e valor.
2. Ou trocar o layout pra coluna: label em cima em `labelSmall` uppercase + valor embaixo em `bodyMedium`. Mais moderno e usa espaço melhor em mobile.

#### 🟡 Badge URGENTE duplicado
Aparece no card cabeçalho (`pedido_detalhe_screen.dart:78-100`) E na `PedidoCard` quando essa tela é acessada via lista que mostrou o card antes. Mais sério: o badge no detalhe usa `fontSize: 9.5` — abaixo do mínimo de legibilidade. Deveria ser promovido a chip maior, ao lado do `StatusPill`.

#### 🟡 PopupMenu "Duplicar / Excluir" sem tratamento visual
`pedido_detalhe_screen.dart:41-48` — 2 opções sem ícone, sem divider, sem cor de destaque pra "Excluir" (destrutivo). Padrão Material espera:
- `Duplicar` com `Icons.content_copy`
- Divider
- `Excluir` em `colorScheme.error` com `Icons.delete_outline`

#### 🟡 `_PagamentosList` com `ListTile` de `contentPadding: EdgeInsets.zero`
`pedido_detalhe_screen.dart:373` — o ícone de check da esquerda cola na borda interna do card. Dá pra ver o avatar/leading sem margem do layout pai. Solução: manter `contentPadding: EdgeInsets.symmetric(horizontal: 4)` ou envolver em um `Container` com `padding`.

#### 🟡 Card de "Entrega — Entregue" usa `primaryContainer.withValues(alpha: 0.5)`
`pedido_detalhe_screen.dart:204` — box com transparência dentro de um card. Duas camadas de cor confundem. Melhor usar `primaryContainer` cheio OU um `SurfaceTint` sólido.

#### 🟢 Valor grande gruda na descrição
`pedido_detalhe_screen.dart:111-117` — `headlineSmall` logo após `bodyLarge` com só `SizedBox(height: 12)`. Dá sensação de apertado. Aumentar pra `20` ou adicionar divider sutil `outlineVariant`.

---

### 6.5. Clientes — Lista (`clientes_screen.dart`)

#### 🟡 `_ClienteCard` apertado demais em mobile
`clientes_screen.dart:107-193` — row com: avatar (44) + nome + telefone + "X pedidos" + valor total + chevron. Em mobile (~360px) com nome longo, o telefone é comprimido e o valor da direita sobrepõe. Soluções:
1. Remover o chevron (é óbvio que é clicável).
2. Mover o valor pra uma segunda linha junto com "X pedidos", ou pra um chip abaixo do nome.
3. Fazer o avatar menor (36).

#### 🟡 Valor total flutuando sem label
`clientes_screen.dart:178-184` — `R$ 4.200,00` no canto direito, sem contexto. Pode ser lido como "cliente deve R$4.200" ou "última compra". Adicionar chip "Total" na frente ou label pequena acima.

#### 🟢 Sem ordenação nem filtros
Só busca. Coerente com "pragmatismo > perfeição" mas vale uma nota — quando a base passar de ~100 clientes começa a incomodar.

---

### 6.6. Cliente — Detalhe (`cliente_detalhe_screen.dart`)

#### 🔴 `_StatusBadge` hardcoded em `Colors.*.shade`
`cliente_detalhe_screen.dart:453-457` — `Colors.green.shade100`, `orange.shade100`, `grey.shade200`. Péssimo no dark mode (fundo claro em cima de card escuro) e foge da paleta. Trocar pelo helper global de status mencionado na 6.1.

#### 🔴 `_FechamentoAtualCard` com alpha em cima do card
`cliente_detalhe_screen.dart:213` — `color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15)`. Isso sobre um card que está sobre o Scaffold. No light mode, com o bug do `Card.color` (6.1), vira 3 tons quase idênticos e o card "some". Depois do fix de 6.1 melhora, mas ainda é boa ideia usar `primaryContainer` sem alpha — dá destaque explícito pro fechamento ativo.

#### 🟡 Header do cliente — Column desnecessária
`cliente_detalhe_screen.dart:86-97` — `Column` com um único `Text` filho. Pode ser só `Text` direto.

#### 🟡 `_StatChip` repete padrão de `_Chip` do `PedidoCard`
Dois componentes diferentes pra fazer a mesma coisa (ícone + label em container tinted). Extrair pra `widgets/tint_chip.dart` compartilhado e reusar em clientes/pedidos/dashboard.

#### 🟡 `SectionHeader "Histórico de pedidos"` solto entre cards
`cliente_detalhe_screen.dart:165` — fora de card, no meio da rolagem. Todas as outras seções da tela estão em cards. Quebra a hierarquia visual. Envolver em card (mesmo que vazio só com o header e a lista dentro) ou criar um estilo claro de "section divider fora de card" e usar consistentemente.

#### 🟢 "Histórico de fechamentos" dentro de uma Column solta, não em Card
Mesmo ponto do item acima. Padronizar: tudo em card ou nada em card.

---

### 6.7. Agenda (`agenda_screen.dart`)

#### 🔴 `PageView` mobile sem indicador de página
`agenda_screen.dart:288-302` — modo Semana em mobile usa `PageView` pra swipar entre os 5 dias. **Nenhum indicador** de qual dia está ativo nem quantos há. Usuário perde referência. Adicionar:
- `TabBar` no topo com os dias, ou
- Dots (`smooth_page_indicator` ou custom), ou
- Header com `DD/MM ← →` mostrando posição.

#### 🔴 5 colunas `Expanded` em desktop ficam ilegíveis
`agenda_screen.dart:270-285` — em `width >= 720`, divide a tela em 5 colunas iguais. Numa tela de 1024px, cada coluna tem ~200px. Card compacto de pedido dentro dessa coluna (`all(12)` de padding + chips empilhados) fica apertado. Os chips do `PedidoCard` quebram em 3-4 linhas.

Correções:
1. Aumentar o breakpoint para `>= 1200` (evita desktop estreito).
2. Ou usar `SingleChildScrollView` horizontal com cada coluna em `width: 280` (padrão do Kanban).
3. Ou reduzir conteúdo do card no modo coluna (versão ultra-compacta: lote + cliente + valor + status pill apenas).

#### 🟡 Modo Lista usa layout row artesanal em vez de `PedidoCard`
`agenda_screen.dart:182-204` — dentro de cada dia, os pedidos são renderizados como `Row` com `SizedBox(width: 76)` pro lote + nome + valor. **Não usa `PedidoCard`.** Resultado: inconsistência visual com o resto do app (lista de pedidos, dashboard, kanban, cliente detalhe — todos usam `PedidoCard`). Trocar por `PedidoCard(compacto: true)`.

#### 🟡 `SegmentedButton` na AppBar action entope em mobile
`agenda_screen.dart:40-52` — `Lista | Semana` na `AppBar.actions`. Em mobile, o título "Agenda de produção" + segmented button + refresh estrangulam. Mover o segmented pra abaixo do título (dentro do body, em `Container` próprio).

#### 🟢 Navegação `< semana >` com `IconButton.outlined`
`agenda_screen.dart:240-256` — outlined dá mais ênfase do que navegação merece. Usar `IconButton` simples, o texto "Semana de X a Y" já é o foco.

---

### 6.8. Kanban (`kanban_screen.dart`)

#### 🟡 5 colunas de 320px estouram tela média
`kanban_screen.dart:66-76` — cada coluna `width: 320` fixo, 5 colunas = **1600px mínimos**. Em mobile (< 720) é inusável. Opções:
1. Em mobile, colapsar pra lista segmentada por status (uma tab por status, usando `DefaultTabController`).
2. Permitir colapsar colunas vazias (header clicável).
3. Reduzir largura pra 280px e aceitar scroll horizontal como padrão mesmo em desktop.

#### 🟡 `DragTarget` border width 1 ↔ 2 no hover causa pulo
`kanban_screen.dart:182-183` — quando o usuário arrasta um card sobre a coluna, o border muda de 1 pra 2px e o conteúdo da coluna pula 1px. Usar `AnimatedContainer` ou manter `width: 2` com `color: transparent` quando não hover.

#### 🟢 Headers de coluna sem agregado financeiro
Só mostram contagem (`"${pedidos.length}"`). Dá pra mostrar "8 pedidos · R$4.200" — informação útil no fluxo de produção.

---

### 6.9. Orçamento (`orcamento_screen.dart`)

#### 🔴 `SectionHeader` solto fora de card
`orcamento_screen.dart:97-217` — Técnica, Região, Quantidade, Nº de cores, Urgente, Tipo de peça — **tudo empilhado direto no ListView sem card delimitador**. Destoa totalmente do padrão do resto do app (que sempre envolve grupos em `Card`). A tela inteira parece um formulário solto. Correção: envolver todos os inputs num único `Card` (são poucos grupos) ou em 2 cards ("Peça e técnica" + "Parâmetros").

#### 🔴 Bug no input de `_cores` (stepper `+/-`)
`orcamento_screen.dart:158-189` — botões `+/-` mexem direto em `_cores` e depois no `_coresCtl.text`, mas o `addListener` do controller (linha 41) só atualiza `_cores` se `int.tryParse != null`. Se o usuário apagar o texto: `_cores` fica travado no último valor, botão "-" desabilita em `_cores <= 1` mas o usuário pode ter digitado 0 ou vazio e o estado fica inconsistente. Correção:
- Adicionar validação e fallback no listener (`_cores = v ?? 1`).
- Usar `InputFormatter` que impede apagar pra zero.

#### 🟡 Botão "Calcular" sem destaque, no meio da rolagem
`orcamento_screen.dart:228-234` — `FilledButton.icon` full-width solto no ListView. Em formulário longo, é fácil passar batido e não achar o botão. Deveria ser **fixo no rodapé** via `bottomNavigationBar` ou `persistentFooterButtons`.

#### 🟡 `ChoiceChip` pra Região com só 2 opções
`orcamento_screen.dart:123-138` — 2 opções mutuamente exclusivas. Esse é o caso de uso canônico de `SegmentedButton` (que o app usa em outros lugares — tema, entrega, etc). Manter consistência.

#### 🟢 "Preço por peça" em `bold:true` sem destacar que é o KPI principal
`orcamento_screen.dart:247-251` — todas as linhas do resultado usam o mesmo `_ResultadoLinha`; "Preço por peça" só fica bold. Mas o valor que o atendente mais usa é o preço unitário. Podia ter destaque maior (tamanho, cor primary, fundo leve).

---

### 6.10. Pedido — Form (`pedido_form_screen.dart`)

Este é o **maior ofensor do app**. 1072 linhas, 8 seções empilhadas, formulário gigante de rolagem única.

#### 🔴 Scroll infinito sem divisão de etapas
Seções: Lote badge → Cliente → Peça → Arte → Agendamento → Entrega → Pagamento → Observação → Saída → botão Salvar. Em mobile, o usuário rola ~4 telas cheias pra criar um pedido. Em desktop, metade da largura fica em branco. Correções possíveis, do mais simples ao mais profundo:

1. **Collapse por seção:** `ExpansionTile` em cada `_SectionCard`, com Cliente/Peça/Agendamento abertos por default e Arte/Entrega/Pagamento/Observação recolhidos. Usuário pula direto pro que precisa.
2. **Stepper** (`Stepper` do Material): 4 passos — `1. Cliente e peça` → `2. Arte e agenda` → `3. Entrega e pagamento` → `4. Revisão`. Mais trabalhoso mas melhor UX.
3. **Abas verticais no desktop:** em `width >= 900`, lado esquerdo com lista de seções (nav interna), lado direito com o form da seção ativa. Mobile mantém empilhado.

A opção 1 é a mais barata e já resolve 70% do problema.

#### 🔴 Aviso "Cliente não vinculado" duplicado
`pedido_form_screen.dart:420-430` — o `suffixIcon` do campo cliente já mostra `Icons.warning_amber` em vermelho quando não há ID vinculado.
`pedido_form_screen.dart:452-497` — e abaixo do campo, aparece um **Card grande de erro** com mesma mensagem + botão "Criar cliente". É a mesma informação duas vezes. Manter só o Card grande (que tem ação) e remover o warning do suffix. Ou manter o warning e mover a ação "Criar cliente" pro `_AutocompleteOptions` (que já tem uma opção "Criar novo cliente" quando digitado).

#### 🔴 Card de "Saída" em `tertiaryContainer` roxo destoa
`pedido_form_screen.dart:816-900` — o último card usa `color: theme.colorScheme.tertiaryContainer` (roxo claro), enquanto todos os outros são brancos. Visualmente grita "este é diferente" sem motivo claro. E "Confirmar saída" é uma ação importante — deveria estar num botão fixo no topo da tela (AppBar action) ou num floating action button contextual, não enterrada no fim do formulário.

Sugestão: mover "Confirmar saída" pra `AppBar.actions` quando `_isEdicao == true && !entregue`, e transformar o card atual em um bloco discreto só com o campo "entregue por" (que é o único input necessário antes da ação).

#### 🔴 Botão "Salvar" no fim do scroll
`pedido_form_screen.dart:911-917` — `FilledButton.icon` no fim do ListView. Usuário precisa rolar tudo pra salvar. Em formulário dessa altura é frustrante. Solução: `persistentFooterButtons` no `Scaffold` com o botão salvar sempre visível. Ou `bottomSheet` ancorado.

#### 🟡 Gaps horizontais inconsistentes entre campos paralelos
- "Peça / Técnica" (`pedido_form_screen.dart:542`) — gap `16`
- "Quantidade / Valor" (`562`) — gap `16`
- "Cor / Tamanho / Tecido" (`599, 607`) — gap `12`
- "Arte cores / Arte tamanho" (`636`) — gap `16`

Padronizar em `12` (economia de espaço) ou `16` (respiro). Escolher um.

#### 🟡 "Calcular orçamento" escondido como `TextButton.icon` alinhado à direita
`pedido_form_screen.dart:581-588` — funcionalidade importante disfarçada como link. Deveria ser um `OutlinedButton.icon` full-width abaixo do campo valor, ou um sufixo clicável com ícone de calculadora no próprio `TextFormField` de valor.

#### 🟡 `_DateField` indistinguível de `TextFormField`
`pedido_form_screen.dart:1040-1072` — usa `InputDecorator` + `InkWell` + `Text`. Visualmente idêntico a um TextField desabilitado. Falta affordance de que é clicável (hover em desktop? cursor? ícone calendário maior?). Solução simples: manter o ícone de calendário no `prefixIcon` mesmo quando há data, e trocar `suffixIcon: Icon(arrow_drop_down)` por `Icon(Icons.edit_calendar_outlined)` quando há data.

#### 🟡 Autocomplete registra listener novo a cada rebuild
`pedido_form_screen.dart:401-413` — dentro do `fieldViewBuilder`, o código faz `controller.addListener(...)` **sem cancelar listeners anteriores**. Cada `setState` da tela adiciona um listener novo no controller. Em formulários longos é fonte de vazamento e de chamadas duplicadas. Correção: extrair o listener pra `initState` (com controller próprio) ou usar `StatefulBuilder` com callback dedicado.

#### 🟡 Campos repetitivos prolixos
As `Row` com 2-3 `Expanded(TextFormField)` se repetem 5 vezes no arquivo com pequenas variações. Extrair pra helper `_formRow(List<Widget>, {double gap = 16})`.

---

### 6.11. Configurações (`configuracoes_screen.dart`)

#### 🟡 Testar / Salvar / Resultado numa linha só
`configuracoes_screen.dart:90-115` — `Row` com 2 botões + `Spacer` + `Text` do resultado. Em mobile, os botões quebram e o texto "Conectado"/"Erro: ..." fica comprimido ou desaparece. Soluções:
1. Transformar o feedback em `SnackBar` (remove do layout).
2. Ou colocar o feedback embaixo, num Container próprio com ícone.
3. Ou usar `Wrap` em vez de `Row`.

#### 🟡 `Divider` no fim de cada `_ConfigEditor`
`configuracoes_screen.dart:304` — dentro de um card que já tem borda, divider entre itens fica pesado. Substituir por `SizedBox(height: 8)` simples ou usar `ListTile` que já tem o espaçamento natural.

#### 🟢 Chave (`c.chave`) em labelSmall cinza
Mostra o nome técnico da config embaixo do label humano. Útil pra debug mas polui. Poderia ir só em tooltip ou num modo "avançado".

#### 🟢 Sem indicador do tipo de dado
Dá pra adicionar badge `number` / `text` / `bool` / `list` ao lado do label.

---

### 6.12. Componentes compartilhados

#### `widgets/pedido_card.dart`

**🔴 Modo `compacto: true` esconde status pills.** `pedido_card.dart:161-176` — o footer com `StatusPill` + `PagamentoPill` está dentro de `if (!compacto)`. Resultado: no dashboard, kanban e listas de cliente, **não dá pra saber o status do pedido pelo card**. O compacto é usado em exatamente os lugares onde status importa mais. Correção: manter `StatusPill` sempre visível (mesmo em compacto, no topo ao lado do lote). `PagamentoPill` pode sumir no compacto se for dar trabalho, mas status não.

**🟡 Chip URGENTE com `fontSize: 9.5`.** `pedido_card.dart:96` — abaixo do mínimo legível. Mesma coisa em `pedido_detalhe_screen.dart:95`. Aumentar pra `10.5` ou `11` e reduzir peso (`w700` em vez de `w800`).

**🟡 `Wrap` de chips sem limite.** `pedido_card.dart:114-159` — em pedidos com muitos atributos (quantidade, técnica, arte cores, produz hoje, vencendo) viram 3-4 linhas só de chips. Muito ruído visual. Limitar a 3-4 chips visíveis no modo compacto.

**🟡 Chip "Vencendo" com cor hardcoded.** `pedido_card.dart:156-157` — `Color(0xFFFFE0B2)` e `Color(0xFFE65100)`. Substituir por variação do `warning` (criar no tema) ou `tertiary`.

#### `widgets/kpi_card.dart`

**🟡 `mainAxisSize.min` conflita com `GridView` de aspect ratio.** `kpi_card.dart:33` — pede pra encolher, mas o grid pai força altura fixa proporcional à largura. Por isso os cards ficam vazios embaixo. Não é bug do `KpiCard` — é do `GridView.count` com `childAspectRatio` errado (ver 6.2). Mas vale remover o `mainAxisSize.min` já que não funciona com o pai.

**🟢 `onTap` opcional mas sem suporte a `hint` + `onTap`.** O ícone de arrow_forward só aparece quando `onTap != null`, mas os KPIs do dashboard nunca passam `onTap`. Remover a ramificação ou wireing `onTap` no dashboard (ex.: "A receber" leva pra lista filtrada de devedores — funcionalidade gratuita).

---

### 6.13. Proposta de ordem de ataque (visual)

Independente da sequência dos blocos 1–5, este bloco 6 tem uma ordem própria por custo × impacto:

1. **Tema e tokens (6.1)** — corrigir `Card.color`, remover `inversePrimary` azul, criar `spacing.dart` e `radius.dart`, extrair `statusColors()` helper. **1-2h, mexe em tudo. Base pra resto.**
2. **Dashboard (6.2)** — corrigir `childAspectRatio` dos KPIs + hierarquia. **Visível em 30 minutos.**
3. **`PedidoCard` compacto mostrar status (6.12)** — 1 linha de código, destrava leitura em dashboard/kanban/cliente.
4. **Pedido Detalhe grid desktop (6.4)** — `LayoutBuilder` parelha cards em tela larga. Corrigir `_Info` width.
5. **Orçamento em card + bug do stepper (6.9)** — envolver em card, arrumar `_cores`, botão fixo no rodapé.
6. **Pedido Form etapas (6.10)** — começar pelo `ExpansionTile` (opção 1). Mover "Salvar" pra `persistentFooterButtons`. Mover "Confirmar saída" pra AppBar.
7. **Agenda mobile indicator + Kanban mobile (6.7, 6.8)** — responsividade.
8. **Polimento** — Clientes (6.5), Cliente detalhe (6.6), Configurações (6.11).

Este bloco **não é pré-requisito** de nenhum dos blocos 1–5, mas é o que transforma a percepção de "CRUD bonitinho" em "produto". Ideal fazer 6.1 antes de qualquer trabalho nos blocos 1–5 que crie telas novas, senão as telas novas vão herdar os mesmos problemas de base.

---

## Sequência sugerida de implementação

Linha de corte = "app pode substituir as duas planilhas".

0. **Tema e tokens visuais (6.1)** — corrigir `Card.color` no light, criar `spacing.dart`/`radius.dart`, helper `statusColors()`. Pré-requisito implícito: qualquer tela nova criada nos itens abaixo vai herdar esses tokens, então fazer antes evita retrabalho. Custo 1-2h.
1. **Migrations versionadas (5.3)** — pré-requisito de tudo que mexe em schema.
2. **Clientes de verdade (1.2)** — destrava a 1.1 e a 3.4.
3. **Unificação com planilha de saída (1.1)** — é o pedido explícito do dono. Adiciona os campos, reorganiza o form em seções, botão "Confirmar saída". **Aproveitar e aplicar a divisão em etapas de 6.10** — o form já vai ser reescrito.
4. **Agendador automático + prazo (1.3 + 1.4)** — sem isso o app é pior que a planilha.
5. **Calculadora de orçamento (1.5)** — liga as configs que hoje estão mortas e fecha a paridade com a planilha. **Já nascer com o fix de 6.9** (em card, botão fixo, bug do stepper).
6. **Fotos de arte + OS em PDF (3.1 + 3.2)** — o que a oficina precisa no dia-a-dia.
7. **Dashboard (2.1) + identidade visual (2.4)** — transforma "um CRUD" em "um produto". **Incluir fixes do 6.2** (aspect ratio dos KPIs, hierarquia).
8. **Pagamento/fiado (1.6)** — dinheiro na mão do dono.
9. **Kanban e agenda semanal/mensal (2.2 + 2.3)** — refinamento visual. **Aplicar 6.7 e 6.8** (responsividade mobile).
10. **Varredura final do BLOCO 6** — itens que ainda não foram absorvidos nos passos anteriores (pedido detalhe grid, clientes card, configurações layout, componentes compartilhados). É o polimento final antes de liberar.
11. **Auth + backup (5.1 + 5.2)** — antes de liberar pro uso diário de verdade.
12. **Resto:** SSE, busca FTS, atalhos, export CSV, WhatsApp, QR, painel de parede — sob demanda.

A partir do item 6, o app já pode ser instalado na oficina como substituto. Do 0 ao 5 é o mínimo bloqueador. O item 0 é obrigatório antes de qualquer outro — sem ele, cada tela nova nasce com os mesmos problemas estruturais listados no BLOCO 6.
