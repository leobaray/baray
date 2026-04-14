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

## Sequência sugerida de implementação

Linha de corte = "app pode substituir as duas planilhas".

1. **Migrations versionadas (5.3)** — pré-requisito de tudo que mexe em schema.
2. **Clientes de verdade (1.2)** — destrava a 1.1 e a 3.4.
3. **Unificação com planilha de saída (1.1)** — é o pedido explícito do dono. Adiciona os campos, reorganiza o form em seções, botão "Confirmar saída".
4. **Agendador automático + prazo (1.3 + 1.4)** — sem isso o app é pior que a planilha.
5. **Calculadora de orçamento (1.5)** — liga as configs que hoje estão mortas e fecha a paridade com a planilha.
6. **Fotos de arte + OS em PDF (3.1 + 3.2)** — o que a oficina precisa no dia-a-dia.
7. **Dashboard (2.1) + identidade visual (2.4)** — transforma "um CRUD" em "um produto".
8. **Pagamento/fiado (1.6)** — dinheiro na mão do dono.
9. **Kanban e agenda semanal/mensal (2.2 + 2.3)** — refinamento visual.
10. **Auth + backup (5.1 + 5.2)** — antes de liberar pro uso diário de verdade.
11. **Resto:** SSE, busca FTS, atalhos, export CSV, WhatsApp, QR, painel de parede — sob demanda.

A partir do item 6, o app já pode ser instalado na oficina como substituto. Do 1 ao 5 é o mínimo bloqueador.
