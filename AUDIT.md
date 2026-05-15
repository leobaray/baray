# Auditoria de código — Baray

> Data: 2026-05-15
> Stack auditada: Flutter 3.x + Dart 3.11.4 (app mobile/desktop em `app/`), servidor Dart shelf + SQLite (`server/`). 84 arquivos `.dart` (~19.4k LOC). Sistema comercial de controle de produção de serigrafia (clientes, pedidos, agendamento, orçamento, fechamentos faturáveis, pagamentos).
> Suposições assumidas: produto em produção (ou prestes a entrar), executado em LAN da oficina; token estático compartilhado é a única credencial; auditor externo sem briefing sobre ameaças, escala ou políticas de backup; commit auditado = `f7ebc37`.
> Revisor independente: code-audit-reviewer — [17 originais revistos, 7 ajustes aplicados (fontes/framing/cortes), 1 contestado e removido (ex-B-02), 3 novos findings adicionados — total final: 19]

## Sumário executivo
- Total de achados: 19 (Críticos: 2, Altos: 5, Médios: 8, Baixos: 4)
- Top 5 prioridades:
  1. [C-01](#c-01-forma_entrega-da-ui-é-rejeitado-pelo-validador-do-server--toda-criação-de-pedido-quebra) — `forma_entrega` da UI (`'retirada'`/`'entrega'`) é rejeitado pelo validador do server (`'retirar'`/`'entregar'`/`'correios'`). Qualquer pedido novo via form quebra com HTTP 400.
  2. [C-02](#c-02-token-de-api-em-cleartext-http--sharedpreferences-plaintexto) — Token de API único em HTTP cleartext (`usesCleartextTraffic="true"`) + armazenamento em `SharedPreferences` plain. Vetor de takeover total via LAN.
  3. [A-01](#a-01-dashboardstats-mistura-data-local-com-timestamps-utc---kpis-do-mês-erram-nas-bordas) — Dashboard mistura `DateTime.now()` local com `criado_em` UTC. Pedidos das 21h-23:59 BRT no último dia do mês são misattribuídos.
  4. [A-02](#a-02-puts-configuracoeschave-aceita-edição-de-proximo_lote-e-de-pcts-sem-allowlist) — `PUT /configuracoes/<chave>` aceita escrita em qualquer chave existente, incluindo `proximo_lote` e percentuais. Pode quebrar criação de pedidos ou inverter regras de preço.
  5. [A-03](#a-03-comparação-de-token-com--não-é-constant-time) — Comparação de API token usa `!=` em `String`, vulnerável a side-channel timing (defesa em profundidade, OWASP).
- Avaliação geral: produto tem testes unitários decentes no core (44 server + 21 app passam) e arquitetura limpa por camadas, mas tem **um bug crítico de contrato cliente-servidor que reprovaria smoke-test do happy path** (criar pedido via form), camada de segurança rudimentar e suporta cenário de produção mal — token único em cleartext, sem audit log, sem rate limit, sem rotação. UI e domínio têm acabamento maduro; segurança e telemetria, não. Após revisão independente: paginação ausente em listagens e bind público sem rate limit foram adicionados como riscos latentes de performance/segurança em escala.

## Achados por severidade

### 🔴 Críticos

#### [C-01] `forma_entrega` da UI é rejeitado pelo validador do server — toda criação de pedido quebra

- **Localização:** `server/lib/validators.dart` linha 44; `app/lib/screens/pedidos/pedido_form_screen.dart` linhas 73, 2133-2135; chamado via `pedido_form_screen.dart` linha 407 e validador em `server/lib/routes/pedidos.dart` linha 109.
- **Trecho relevante:**
  ```dart
  // server/lib/validators.dart
  const Set<String> formasEntregaValidas = {'retirar', 'entregar', 'correios'};
  // ...
  _validarEnum(body, 'forma_entrega', formasEntregaValidas);

  // app/lib/screens/pedidos/pedido_form_screen.dart
  String _formaEntrega = 'retirada';
  // ...
  final opcoes = <(String, String, IconData)>[
    ('retirada', 'Retirada na loja', Icons.store_outlined),
    ('entrega', 'Entrega no endereço', Icons.local_shipping_outlined),
  ];
  // ...
  'forma_entrega': _formaEntrega,
  ```
- **Problema:** As únicas opções que a UI permite são `'retirada'` e `'entrega'`. O validador do server aceita só `'retirar'`, `'entregar'`, `'correios'`. Como o body sempre inclui a chave `forma_entrega` (não é wrapper condicional), todo POST/PUT de pedido criado pelo form sai com valor inválido. O server retorna `{"error":"forma_entrega inválido (use: retirar, entregar, correios)"}` com HTTP 400.
- **Impacto:** Funcionalidade central (criar pedido pelo formulário) quebrada 100% das vezes em commit `f7ebc37`. O tratamento de erro no app (`pedido_form_screen.dart:437-444`) mapeia explicitamente apenas `cliente_nome`, `descricao` e `valor` — `forma_entrega` cai no branch genérico "Erro ao salvar: ${e.toString()}" exibido ao usuário. Pedidos criados via UI ficam impossíveis.
- **Evidência / verificação:** Reproduzido executando `validarPedido({'cliente_nome':'X','descricao':'d','valor':1,'forma_entrega':'retirada'}, criar:true)` — output verbatim na transcript: `retirada: forma_entrega inválido (use: retirar, entregar, correios)`; `retirar: OK`. Nenhum teste em `server/test/validators_test.dart` cobre `forma_entrega`. `grep -n 'retirada'` retorna 4 locais no app; `grep -n 'retirar'` retorna apenas o set do server.
- **Devil's advocate:** Contexto considerado: olhei se o app envia `forma_entrega` condicionalmente (não — sempre envia, linha 407) e se o catch silencia o erro (não — só categoriza mensagens conhecidas). Verifiquei o teste e nenhum exercita esse path. Contra-argumento possível: "talvez tenha sido renomeado recentemente e o app tem fallback". Mas o commit atual contém o mismatch, sem fallback. Veredito: sobreviveu como Crítico — bug de produto reproduzível.
- **Fonte:** https://martinfowler.com/articles/consumerDrivenContracts.html — "Services encapsulate discrete, identifiable, reusable business functions whose integrity should not be compromised by unreasonable demands falling outside their mandate." (princípio canônico de contrato consumer-provider — quando duas pontas divergem no que aceitam, o serviço é violado por ambos).
- **Recomendação:** Unificar a fonte de verdade — gerar enum a partir do server e usar nas duas pontas (build script Dart compartilhado, ou contrato OpenAPI), ou no mínimo cobrir o caminho com integration test. Decidir qual nomenclatura ficar (verbos vs substantivos) e migrar o outro lado.
- **Risco de regressão se corrigido:** Pedidos antigos persistidos com `'retirar'`/`'entregar'` no DB ficam consistentes (não foram criados via UI atual quebrada). Mudar apenas o set do server pra aceitar `'retirada'`/`'entrega'` resolve sem migração de dados.
- **Pré-requisitos:** —
- **Confiança:** Alta — reproduzido empiricamente.
- **Esforço estimado:** Trivial (mudar 2 strings no validador ou no enum da UI).
- **Revisão independente:** confirmado — reviewer reproduziu a divergência no validators.dart:44 e no pedido_form_screen.dart:73,407,2133-2135; cobertura de teste verificada ausente. Ajuste aplicado: fonte trocada de OWASP API (tema authentication, não casava com contrato) para Martin Fowler Consumer-Driven Contracts com excerpt verbatim verificado via WebFetch.

#### [C-02] Token de API em cleartext HTTP + SharedPreferences plaintexto

- **Localização:** `app/android/app/src/main/AndroidManifest.xml` linha 10; `app/lib/api/api_client.dart` linhas 332-340; `server/lib/auth_middleware.dart` linhas 13-35.
- **Trecho relevante:**
  ```xml
  <!-- app/android/app/src/main/AndroidManifest.xml -->
  <application android:usesCleartextTraffic="true">
  ```
  ```dart
  // app/lib/api/api_client.dart
  Future<String> loadApiToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(prefsKeyApiToken) ?? '';
  }
  Future<void> saveApiToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKeyApiToken, token);
  }
  ```
- **Problema:** Token único administrativo (não escopado, sem rotação) é (a) enviado em texto plano sobre HTTP no header `X-API-Key`; (b) armazenado em `SharedPreferences`, que no Android é um XML em `/data/data/<pkg>/shared_prefs/` sem criptografia. Combina dois vetores: (i) qualquer ator no mesmo segmento de rede captura via sniffer (Wireshark, mesmo ARP-spoof em LAN); (ii) qualquer app malicioso instalado no mesmo device (ou root, ou bug de IPC) lê o XML. O token dá acesso *full* — não há separação de leitura/escrita, roles, ou tenant.
- **Impacto:** Vazamento de token = takeover total. Atacante consegue ler/escrever/deletar todos pedidos, clientes, configurações; alterar `taxa_urgencia_pct = -50` (cobra 50% a menos), zerar `proximo_lote`, exfiltrar lista de clientes (telefone/email/endereço — PII). Sem audit log (`requestLog` só registra método+path+status — não autentica o caller). Empresa fica sem rastro forense.
- **Evidência / verificação:** Manifest auditado em commit atual; comentário do próprio código confirma: *"usesCleartextTraffic=true é deliberado: o servidor Baray roda em LAN interna (http://10.x.x.x)"*. `auth_middleware.dart:13-35` documenta o token estático único. `grep -r FlutterSecureStorage app/` retorna 0 matches — não há fallback seguro.
- **Devil's advocate:** Contexto considerado: o comentário no manifest e no auth_middleware revela que a equipe **conhece** o trade-off ("LAN interna"). Threat model implícito: oficina pequena, todos confiáveis. Contra-argumento: produto é para uso comercial, dados de clientes (PII) e financeiros estão em jogo. Cenários realistas que quebram o threat model: roteador wifi compartilhado com hóspede/cliente; tablet de loja perdido/roubado; coworker com acesso ao device tira screenshot do token na tela de configurações (`configuracoes_screen.dart` mostra com toggle `_mostrarToken`); empresa expande pra ter acesso remoto via VPN frágil. Veredito: sobreviveu como Crítico — risco residual de PII + financial misuse, sem custo elevado de fix (HTTPS via reverse proxy / EncryptedSharedPreferences) é mitigação madura.
- **Fonte:** https://cheatsheetseries.owasp.org/cheatsheets/Transport_Layer_Security_Cheat_Sheet.html — "API-only endpoints should disable HTTP altogether and only support encrypted connections." Adicionalmente https://owasp.org/www-project-mobile-top-10/2023-risks/m9-insecure-data-storage — "Insecure Data Caching: The mobile application caches sensitive data, such as user authentication tokens or session information, without implementing appropriate security measures."
- **Recomendação:** (a) Forçar HTTPS — colocar reverse proxy (Caddy/Nginx) com cert local CA, e setar `usesCleartextTraffic="false"` + `networkSecurityConfig` whitelisting o domínio do reverse proxy. (b) Trocar `SharedPreferences` por `flutter_secure_storage` (Keystore no Android, Keychain no iOS) só para o token. (c) Considerar tokens por usuário com expiration. (d) Mascarar token no logger (`authLog.warning('API token gerado...')` em `auth_middleware.dart:25-27` — `${file.absolute.path}` está OK mas next time alguém logar token, vai pra arquivo).
- **Risco de regressão se corrigido:** Trocar pra HTTPS exige distribuir cert na intranet — quebra deploy se mal feito. Trocar pra secure_storage exige uma migração suave (read old → write new). Razoável tirar em 2 sprints.
- **Pré-requisitos:** —
- **Confiança:** Alta.
- **Esforço estimado:** Médio (reverse proxy + storage swap + testar dev/prod).
- **Revisão independente:** confirmado — reviewer verificou cleartext em manifest:10, SharedPreferences plain em api_client.dart:332-340, e token único em auth_middleware.dart:13-35. Ambos os excerpts OWASP verificados verbatim via WebFetch. Sem ajustes.

### 🟠 Altos

#### [A-01] `/dashboard/stats` mistura data local com timestamps UTC — KPIs do mês erram nas bordas

- **Localização:** `server/lib/routes/dashboard.dart` linhas 31-55.
- **Trecho relevante:**
  ```dart
  final hoje = DateTime.now();                 // local
  final inicioMes = DateTime(hoje.year, hoje.month, 1);
  final inicioMesStr = _dataStr(inicioMes);    // ex: '2026-05-01'

  final vendasRow = db.raw.select(
    'SELECT COALESCE(SUM(valor), 0) AS s, COUNT(*) AS n FROM pedidos WHERE criado_em >= ?',
    [inicioMesStr],
  ).first;
  ```
  Mas `criado_em` é gravado em `DateTime.now().toUtc().toIso8601String()` (server/lib/routes/pedidos.dart:129).
- **Problema:** `inicioMesStr` é YYYY-MM-DD em fuso local (BRT, UTC-3). `criado_em` é ISO8601 UTC. Comparação lexicográfica no SQLite: um pedido criado em `2026-04-30 22:00 BRT` vira `criado_em = '2026-05-01T01:00:00.000Z'`, que é `>= '2026-05-01'` → conta no mês de maio em vez de abril. Janela de erro: 3h (UTC offset de BRT) no último dia de cada mês. Mesmo padrão em três queries: `vendas_mes`, `recebido_mes` (campo `quando` em `pedido_pagamentos`), `concluidos_mes` (`entregue_em`).
- **Impacto:** Dashboard (tela inicial, primeira que o dono vê) exibe valores divergentes do que ele soma manualmente. Reconciliação "vendas do mês = soma manual dos pedidos do mês" falha por 0-2 pedidos/mês (≈ 0,4% dos casos, mas exatamente nas datas que o gerente está conferindo). Ticket médio também distorce.
- **Evidência / verificação:** Inspeção dos arquivos. Confirmado pelo padrão `DateTime.now().toUtc().toIso8601String()` em todos os INSERTs (server/lib/routes/pedidos.dart:129,290,398; pagamentos.dart:60).
- **Devil's advocate:** Contexto considerado: vi se há comentário explicando a decisão ou normalização. Não há. Vi se o app filtra/converte no client (não). Contra-argumento: "magnitude pequena, 0-2 pedidos/mês". Resposta: o usuário **confere o dashboard** porque é tela operacional, então mesmo magnitude pequena gera reclamação direta. Veredito: sobreviveu como Alto — afeta KPI público, é reproduzível, fix simples (gravar `criado_em` em local-ISO ou comparar com `datetime(criado_em, '-3 hours')`).
- **Fonte:** https://api.dart.dev/dart-core/DateTime-class.html — "Constructs a DateTime instance with current date and time in the local time zone." (`DateTime.now()` é local; misturar com UTC string sem normalização é o defeito). Adicional: https://www.sqlite.org/lang_datefunc.html descreve comparação lexicográfica de ISO8601 strings em SQLite.
- **Recomendação:** Padronizar: ou gravar `criado_em` em local-ISO (sem `Z`), ou gerar `inicioMesStr` como `'2026-05-01T00:00:00.000Z'` (com offset compensado). Adicionar índice em `criado_em` se ainda não tem.
- **Risco de regressão se corrigido:** Dados antigos foram gravados em UTC. Mudar para local quebra retroatividade. Solução menos invasiva: normalizar o filtro server-side (`inicioMesStr` em UTC) e documentar.
- **Pré-requisitos:** —
- **Confiança:** Alta.
- **Esforço estimado:** Pequeno.
- **Revisão independente:** confirmado — reviewer reproduziu o mismatch examinando dashboard.dart:31-55 vs pedidos.dart:129,290,398 e pagamentos.dart:60. Janela de 3h confirmada. Fonte DateTime verificada verbatim via WebFetch. Sem ajustes.

#### [A-02] `PUT /configuracoes/<chave>` aceita edição de `proximo_lote` e de pcts sem allowlist

- **Localização:** `server/lib/routes/configuracoes.dart` linhas 43-61.
- **Trecho relevante:**
  ```dart
  r.put('/<chave>', (Request req, String chave) async {
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final valor = body['valor']?.toString();
    if (valor == null) return json({'error': 'valor é obrigatório'}, status: 400);

    final exists = db.raw.select('SELECT chave FROM configuracoes WHERE chave = ?', [chave]);
    if (exists.isEmpty) return json({'error': 'chave não encontrada'}, status: 404);

    db.raw.execute(
      'UPDATE configuracoes SET valor = ?, atualizado_em = ? WHERE chave = ?',
      [valor, DateTime.now().toUtc().toIso8601String(), chave],
    );
  ```
- **Problema:** Qualquer chave existente é editável, inclusive `proximo_lote` (que o GET propositadamente filtra/expõe como read-only em `/proximo_lote`). Não há validação semântica de domínio: `taxa_urgencia_pct = '-50'` é aceito → calculadora aplica `(1 + -50/100) = 0.5` → cobra 50% **a menos**. `producao_sabado = 'banana'` vira `false` (resilient), OK. `proximo_lote = '0'` faz próximo pedido pegar lote 0 — colide com pedido antigo via UNIQUE → INSERT lança exception → HTTP 500. Sem try/catch no INSERT do pedido em `pedidos.dart:135-198`.
- **Impacto:** Atacante autenticado (ou usuário admin com erro humano) quebra criação de pedidos (`proximo_lote='lixo'`) ou inverte regras de preço (`taxa_urgencia_pct=-25`). Sem audit log do *quem* fez a mudança (só método+path+status no `requestLog`).
- **Evidência / verificação:** Inspeção do arquivo. Cruzou-se com `db.configNumber` em `calculadora_orcamento.dart:33-48` que faz `* (1 + pct/100)` sem clamp.
- **Devil's advocate:** Contexto considerado: é admin endpoint, deveria estar protegido por auth. **Está** — middleware `apiKeyAuth` cobre. Mas com token compartilhado (C-02), qualquer device da loja tem privilégios admin. Sem RBAC. Contra-argumento: "se é o dono editando, é por sua conta". Resposta: o app expõe a tela `configuracoes_screen.dart` com `TextInputType.number` mas não bloqueia negativos; e mais grave, a chave `proximo_lote` nunca aparece na UI mas o PUT direto via API funciona. Defense in depth ausente. Veredito: sobreviveu como Alto.
- **Fonte:** https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html — "Syntactic validation should enforce correct syntax of structured fields (e.g. SSN, date, currency symbol). Semantic validation should enforce correctness of their values in the specific business context (e.g. start date is before end date, price is within expected range)." (princípio de validação semântica do server, não confiar no client). Adicional sobre configuração: https://owasp.org/Top10/A05_2021-Security_Misconfiguration/ — categoria oficial.
- **Recomendação:** Whitelist de chaves editáveis + validação de domínio (min/max, regex) por chave. Bloquear `proximo_lote` explicitamente no PUT (já bloqueado no GET, é só replicar). Adicionar audit log com `caller_token_id` (mesmo que único, registrar pelo menos hash).
- **Risco de regressão se corrigido:** Baixo. Whitelist é aditiva.
- **Pré-requisitos:** —
- **Confiança:** Alta.
- **Esforço estimado:** Pequeno.
- **Revisão independente:** confirmado — reviewer cruzou configuracoes.dart:43-61 com db.dart:232 (proximo_lote seedado) e calculadora_orcamento.dart:33-42 (sem clamp). Ajuste aplicado: excerpt OWASP "syntactical and Semantic level" era paráfrase; substituído pelo texto verbatim da página ("Syntactic validation should enforce..."), verificado via WebFetch.

#### [A-03] Comparação de token com `!=` não é constant-time

- **Localização:** `server/lib/auth_middleware.dart` linha 54.
- **Trecho relevante:**
  ```dart
  if (provided == null || provided.isEmpty || provided != expectedToken) {
    authLog.warning('auth_fail method=${req.method} path=$path origin=${req.headers['origin'] ?? '-'}');
    return Response(401, ...);
  }
  ```
- **Problema:** `String.operator==` em Dart é code-unit-by-code-unit e curto-circuita no primeiro mismatch. Em condições de baixo jitter (LAN, sem TLS comprimindo timing), atacante com acesso a fazer muitos requests pode usar análise estatística de timing pra recuperar token byte a byte (CWE-208). Com o token 256-bit aleatório atual, a exploração é teoricamente possível mas extremamente difícil. Defense in depth ausente.
- **Impacto:** Em isolado, baixo (token alta entropia + ruído de rede mascara). Combinado com C-02 (cleartext, fácil sniff), é redundante — atacante captura o token direto. Mas se C-02 for fixado (HTTPS), este vira o vetor restante; deixar como está é dívida.
- **Evidência / verificação:** Inspeção. Dart docs: https://api.dart.dev/dart-core/String/operator_equals.html — "This method compares each individual code unit of the strings. It does not check for Unicode equivalence." Implementação em runtimes Dart faz short-circuit (verificado em código fonte SDK público).
- **Devil's advocate:** Contexto considerado: olhei se Dart tem `crypto`/`subtle` API. Há `package:crypto` com `Hash` mas não com `constantTimeBytesEqual` direto. A solução é XOR loop manual. Contra-argumento: "token 256-bit, attack impraticável". Resposta: OWASP recomenda explicitamente constant-time pra defesa em profundidade — não é "se vai ser explorado", é "não dar a oportunidade". Veredito: sobreviveu como Alto (não Crítico — combinado com C-02 mitigado, vira Alto isolado).
- **Fonte:** https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html — "Where possible, the user-supplied password should be compared to the stored password hash using a secure password comparison function provided by the language or framework, such as the password_verify() function in PHP." E na lista de propriedades: "Returns in constant time, to protect against timing attacks." Adicional: https://cwe.mitre.org/data/definitions/208.html — "Two separate operations in a product require different amounts of time to complete, in a way that is observable to an actor and reveals security-relevant information about the state of the product."
- **Recomendação:** Implementar comparação constant-time:
  ```
  bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var r = 0;
    for (var i = 0; i < a.length; i++) {
      r |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return r == 0;
  }
  ```
  Note que `a.length != b.length` ainda vaza length — para token único de length fixa, não é problema.
- **Risco de regressão se corrigido:** Nenhum funcional.
- **Pré-requisitos:** —
- **Confiança:** Alta.
- **Esforço estimado:** Trivial.
- **Revisão independente:** confirmado — reviewer verificou auth_middleware.dart:54 e ambas as fontes verbatim. Sem ajustes.

#### [A-04] Valores monetários em `double` (IEEE 754) — desvio acumulado em reconciliação

- **Localização:** schema `pedidos.valor REAL`, `valor_pago REAL`, `sinal_pago REAL` (server/lib/db.dart:166, 258-259); `pedido_pagamentos.valor REAL` (db.dart:285); cálculos em `server/lib/calculadora_orcamento.dart:8-71`, `server/lib/pagamentos_util.dart:5-29`, `server/lib/routes/clientes.dart:60-62, 100-111`.
- **Trecho relevante:**
  ```dart
  // calculadora_orcamento.dart
  var porPeca = precoPrimeira + (cores - 1).clamp(0, 10) * precoDemais;
  if (tipoPeca == 'moletom_aberto') {
    final pct = db.configNumber('adicional_moletom_aberto_pct', 20);
    porPeca *= (1 + pct / 100);
  }
  if (urgente) {
    final pct = db.configNumber('taxa_urgencia_pct', 25);
    porPeca *= (1 + pct / 100);
  }
  final subtotal = porPeca * quantidade;
  final total = subtotal + totalMatriz;
  ```
  ```dart
  // pagamentos_util.dart — tolerância arbitrária 1 centavo
  if (pago >= valorTotal - 0.01) {
    status = 'pago';
  }
  ```
- **Problema:** SQLite `REAL` é IEEE 754 64-bit (mesma representação do `double` Dart). Multiplicações encadeadas com pcts ímpares (25%, 20%, 60%) introduzem erro de representação. Para uma operação isolada, erro fica em 10^-13. Em agregações grandes (`SUM(valor)` em consulta de fechamento de mês com 200 pedidos), erros acumulam. Tolerância de R$ 0,01 em `pagamentos_util.dart` é band-aid que mascara — mas qualquer reconciliação contábil ou export pra extrato bancário pode mostrar centavos divergentes.
- **Impacto:** Latente. Não há bug observado *hoje* — exibição com `toStringAsFixed(2)` mascara. Mas: (a) export pra contabilidade vai divergir; (b) "valor_devendo = SUM(valor - valor_pago)" exibido no listão de clientes (`clientes.dart:61-62`) pode mostrar R$ 0,00 sendo cobrado de cliente que pagou tudo, mas com `0.009999...` residual; (c) cálculo de orçamento com 3+ pcts encadeados (moletom_fechado 60% + urgente 25%) sai diferente do feito a mão.
- **Evidência / verificação:** Inspeção. SQLite docs: `REAL`. The value is a floating point value, stored as an 8-byte IEEE floating point number.` (verbatim https://www.sqlite.org/datatype3.html). Dart docs: "Dart doubles are 64-bit floating-point numbers as specified in the IEEE 754 standard." (verbatim https://api.dart.dev/dart-core/double-class.html).
- **Devil's advocate:** Contexto considerado: a tolerância de R$ 0,01 mostra que a equipe já cruzou com esse problema e contornou. Os testes `pagamentos_test.dart:71-79` exercitam o limite. Contra-argumento: "centavo errado uma vez é tolerável, e ninguém faz reconciliação contábil precisa em ERP de oficina". Resposta: o sistema *armazena* dinheiro do cliente, `cliente.valor_devendo` é mostrado como número exato no UI. Em algum momento, alguém vai comparar com o WhatsApp do cliente. Veredito: sobreviveu como Alto (não Crítico porque não dispara hoje).
- **Fonte:** https://martinfowler.com/eaaCatalog/money.html — "Monetary calculations are often rounded to the smallest currency unit. When you do this it's easy to lose pennies (or your local equivalent) because of rounding errors." Adicional: https://api.dart.dev/dart-core/double-class.html — "Dart doubles are 64-bit floating-point numbers as specified in the IEEE 754 standard."
- **Recomendação:** Migrar valores para *inteiros em centavos* (`valor_centavos INTEGER`). Aplicar `BrlInputFormatter` no app já produz inteiros internamente (linha 105 de formatters.dart). Refactor é localizado em `Pedido.valor`, `Pagamento.valor`, queries de SUM, e cálculo de orçamento. Migration única no DB. Alternativa de menor risco: usar `Decimal` (pacote `decimal`/`big_decimal_v2`) — mas SQLite ainda armazena REAL, então não escapa.
- **Risco de regressão se corrigido:** Médio — migração de schema + reescrita de toda camada monetária. Tem testes (pagamentos_test, calculadora_orcamento_test) que cobrem comportamento básico.
- **Pré-requisitos:** —
- **Confiança:** Média-Alta (a) bug não dispara em uso típico hoje; (b) bem documentado como anti-pattern.
- **Esforço estimado:** Médio-Grande (migration + refactor + testes).
- **Revisão independente:** confirmado com nota de prioridade — reviewer verificou schema em db.dart:166,258-259,285, cálculos em calculadora_orcamento.dart:30-43 e tolerância em pagamentos_util.dart:17. Fontes Fowler Money e Dart double verificadas verbatim. **Nota anexada:** fix exige migração de schema completa — risco/esforço alto comparado a C-01/C-02/A-01 que têm fix trivial. Sugestão: tratar como dívida estruturada após críticos serem resolvidos; bug latente, não dispara hoje.

#### [A-05] App não fecha `Dio` ao recriar `ApiClient` — leak de connections em troca de servidor/token

- **Localização:** `app/lib/api/api_client.dart` linhas 316-320, 39-55.
- **Trecho relevante:**
  ```dart
  final apiClientProvider = Provider<ApiClient>((ref) {
    final url = ref.watch(serverUrlProvider);
    final token = ref.watch(apiTokenProvider);
    return ApiClient(url, apiToken: token);
  });
  ```
  `ApiClient` constructor cria `Dio(BaseOptions(...))` (linhas 41-46). Nenhum `ref.onDispose(() => oldClient.dio.close())`.
- **Problema:** Toda vez que `serverUrlProvider` ou `apiTokenProvider` muda (e.g. usuário troca URL em Configurações), Riverpod descarta o provider anterior e cria um novo. O novo cria um Dio novo (com novo connection pool). O antigo é coletado pelo GC, mas o Dio retém HTTP/2 connections, file descriptors, e listeners de DNS até GC finalmente passar. Mais grave: em hot-reload de desenvolvimento, vários instances acumulam.
- **Impacto:** Em produção raramente disparado (usuário troca URL 1-2x). Em dev hot-reload, dezenas de Dios coexistem. Em emergência (token comprometido, dono troca via app), o connect anterior ficou alive — security: usuário acha que mudou token mas requests in-flight do Dio antigo ainda usam o token antigo. Pequeno mas mensurável.
- **Evidência / verificação:** Inspeção. Padrão recomendado é `ref.onDispose(() => client.close())` em providers que detém recursos.
- **Devil's advocate:** Contexto considerado: vi se Riverpod 2/3 chama `dispose()` automaticamente. Não — para tipos não-AsyncDisposable, é responsabilidade do provider. Contra-argumento: "GC eventually". Resposta: HTTP/2 e DNS cache sobrevivem até GC, e na rotação de token isso vaza credenciais antigas. Veredito: sobreviveu como Alto (mais por correção de fluxo de segurança do que vazamento de FD).
- **Fonte:** https://pub.dev/documentation/dio/latest/dio/Dio/close.html — "Shuts down the dio client. If `force` is `false` (the default) the Dio will be kept alive until all active connections are done. If `force` is `true` any active connections will be closed to immediately release all resources." Adicional sobre lifecycle de provider: https://riverpod.dev/docs/concepts/about_code_generation — "When using code generation, providers are autoDispose by default. That means that they will automatically dispose of themselves when there are no listeners attached to them (ref.watch/ref.listen)."
- **Recomendação:**
  ```
  final apiClientProvider = Provider<ApiClient>((ref) {
    final client = ApiClient(...);
    ref.onDispose(() => client.dio.close(force: true));
    return client;
  });
  ```
- **Risco de regressão se corrigido:** Trivial.
- **Pré-requisitos:** —
- **Confiança:** Alta.
- **Esforço estimado:** Trivial.
- **Revisão independente:** confirmado com troca de fonte — reviewer verificou api_client.dart:316-320 (ref.watch recria, onDispose ausente) e que updateApiToken/updateBaseUrl existem mas não são chamados. Ajuste aplicado: excerpt Dio.close ("Closes the Dio instance to free up resources") era paráfrase inexistente na página; substituído pelo verbatim ("Shuts down the dio client..."). URL Riverpod trocada de tópico genérico para "about_code_generation" com excerpt verbatim sobre autoDispose verificado via WebFetch.

### 🟡 Médios

#### [M-01] `_faixa(qtd)` retorna `'12-24'` para qtd<12 — cobra menos por pedidos pequenos

- **Localização:** `server/lib/calculadora_orcamento.dart` linhas 73-78.
- **Trecho relevante:**
  ```dart
  String _faixa(int qtd) {
    if (qtd < 25) return '12-24';
    if (qtd <= 50) return '25-50';
    if (qtd <= 100) return '51-100';
    return '100+';
  }
  ```
- **Problema:** Validação em `orcamento.dart:57` exige `quantidade > 0`. Combinação `quantidade=1..11` é aceita → cai no preço da faixa `'12-24'`. Se a regra de negócio é "abaixo de 12 não há venda", deveria retornar erro estruturado. Se há venda (1-11), o preço aplicado é o da faixa de 12-24 — provavelmente menor do que o cobrado a mão pra pedido pequeno.
- **Impacto:** Receita perdida em pedidos pequenos. Magnitude depende de quanto a oficina aceita pedidos sub-12. Se aceita, é prejuízo recorrente.
- **Evidência / verificação:** Inspeção; nenhum teste em `calculadora_orcamento_test.dart` cobre qtd<12.
- **Devil's advocate:** Contexto considerado: nem README nem comentários documentam regra de mínimo. Conversa com o dono ausente. Contra-argumento: "loja só vende ≥12 peças". Veredito: sobreviveu como Médio — falta de validação defensiva clara, com efeito monetário se for chamado fora do contrato implícito.
- **Fonte:** https://owasp.org/Top10/A04_2021-Insecure_Design/ — "Insecure design represents different weaknesses, expressed as missing or ineffective control design." (categoria oficial de design inseguro, validação ausente).
- **Recomendação:** Adicionar erro estruturado:
  ```
  if (qtd < 12) return {'erro': 'quantidade mínima é 12'};
  ```
  E validação em `orcamento.dart` antes de chamar `calc.calcular`.
- **Risco de regressão se corrigido:** Pode quebrar fluxo de "orçamento pra mostra-amostra" se houver. Confirmar com produto.
- **Pré-requisitos:** —
- **Confiança:** Média (depende da regra de negócio).
- **Esforço estimado:** Trivial.
- **Revisão independente:** confirmado — reviewer verificou calculadora_orcamento.dart:73-78 e orcamento.dart:56. Nota requires_product_context mantida. Sem ajustes.

#### [M-02] `String.fromEnvironment('LOG_LEVEL')` é compile-time, não runtime

- **Localização:** `server/lib/logger.dart` linha 10.
- **Trecho relevante:**
  ```dart
  void setupLogging() {
    final levelName = (const String.fromEnvironment('LOG_LEVEL')).toUpperCase();
    Logger.root.level = switch (levelName) {
      'SEVERE' => Level.SEVERE,
      // ...
      _ => Level.INFO,
    };
    // ...
  }
  ```
- **Problema:** `String.fromEnvironment` lê valor de `--dart-define` no momento da compilação. Variáveis de ambiente *runtime* (`LOG_LEVEL=FINE dart run server.dart`) são **ignoradas**. O resto do server usa `Platform.environment['BARAY_API_TOKEN']`, `Platform.environment['PORT']`, etc. (runtime). Há contrato implícito quebrado.
- **Impacto:** Operador não consegue elevar nível de log sem recompilar. Se subir um stacktrace estranho em produção, não há como ativar FINE sem redeploy do binário compilado.
- **Evidência / verificação:** Inspeção; cruzou-se com README que não menciona LOG_LEVEL; usa `Platform.environment` em outras envs.
- **Devil's advocate:** Contexto considerado: vi se `const` é deliberado pra otimização (compilador remove código morto). Pode ser. Mas combinar com `--dart-define` exige doc — README não cita. Contra-argumento: "ninguém usa LOG_LEVEL". Resposta: alguém vai precisar quando der pau — e aí dor é grande. Veredito: sobreviveu como Médio.
- **Fonte:** https://dart.dev/libraries/core/environment-declarations — "Compilation environment declarations specify configuration options as key-value pairs that are accessed and evaluated at compile time." E: "To access specified environment declaration values, use one of the fromEnvironment constructors with const or within a constant context... The environment declaration constructors are only guaranteed to work when invoked as const. Most compilers must be able to evaluate their value at compile time."
- **Recomendação:** Trocar `String.fromEnvironment` por `Platform.environment['LOG_LEVEL'] ?? ''` pra consistência com PORT, EMPRESA_DB, BARAY_API_TOKEN, ALLOWED_ORIGINS.
- **Risco de regressão se corrigido:** Trivial.
- **Pré-requisitos:** —
- **Confiança:** Alta.
- **Esforço estimado:** Trivial.
- **Revisão independente:** confirmado — reviewer verificou logger.dart:10 (const String.fromEnvironment) e server.dart:22-23 (Platform.environment runtime) — inconsistência interna confirmada. Fonte Dart docs verificada verbatim. Sem ajustes.

#### [M-03] Sem handler global de exceções — stack traces 500 expostos ao client

- **Localização:** `server/bin/server.dart` linhas 60-64 (Pipeline) — falta middleware de erro.
- **Trecho relevante:**
  ```dart
  final handler = Pipeline()
      .addMiddleware(_logRequests())
      .addMiddleware(_cors(allowedOrigins))
      .addMiddleware(apiKeyAuth(token))
      .addHandler(root.call);
  ```
- **Problema:** Se uma rota lançar exception não tratada (e.g. `Map.cast` falhando, SQL com schema-drift, qualquer null deref), o shelf default responde HTTP 500 com `exception.toString()` no body, expondo classe da exceção e às vezes paths.
- **Impacto:** Information disclosure menor. Em produção, errors detalhados ajudam atacante a mapear stack interno. Em dev, ajuda — em prod, machuca.
- **Evidência / verificação:** Inspeção. Nenhum `try/catch` cobrindo `Handler` global, nenhum `Pipeline.addMiddleware` de erro.
- **Devil's advocate:** Contexto considerado: rotas têm try/catch local em jsonDecode e operações conhecidas. Contra-argumento: "DB schema é controlado, rara exception generalizada". Resposta: migrations futuras podem dar drift, `int.parse` em campos não numéricos vinde de DB pode crashear. Veredito: sobreviveu como Médio.
- **Fonte:** https://cheatsheetseries.owasp.org/cheatsheets/Error_Handling_Cheat_Sheet.html — "when an unexpected error occurs then a generic response is returned by the application but the error details are logged server side for investigation, and not returned to the user." (princípio canônico: não expor detalhe pro client, logar server-side).
- **Recomendação:** Adicionar middleware de erro:
  ```
  Middleware _catchAll() => (inner) => (req) async {
    try { return await inner(req); }
    catch (e, st) {
      appLog.severe('uncaught', e, st);
      return Response(500, body: jsonEncode({'error': 'erro interno'}), headers: {...});
    }
  };
  ```
- **Risco de regressão se corrigido:** Nenhum.
- **Pré-requisitos:** —
- **Confiança:** Alta.
- **Esforço estimado:** Trivial.
- **Revisão independente:** confirmado com excerpt corrigido — reviewer verificou server.dart:60-64 (Pipeline sem catch-all). Ajuste aplicado: excerpt OWASP "Generic error pages and HTTP responses..." era paráfrase; substituído pelo texto verbatim ("when an unexpected error occurs then a generic response is returned..."), verificado via WebFetch.

#### [M-04] `status` aceita `'entregue'` na criação sem validação semântica de fluxo

- **Localização:** `server/lib/validators.dart` linha 12-18, `server/lib/routes/pedidos.dart` linha 190.
- **Trecho relevante:**
  ```dart
  // validators.dart
  const Set<String> statusValidos = {'pendente', 'agendado', 'producao', 'concluido', 'entregue'};

  // pedidos.dart (POST /pedidos)
  body['status'] ?? 'pendente',
  ```
- **Problema:** Cliente pode POST `{'cliente_nome':'X','descricao':'d','valor':10,'status':'entregue'}` → INSERT com `status='entregue'` mas `entregue_em=NULL` (não setado no INSERT). Estado inválido segundo regras do app: pedido "entregue" deve ter `entregue_em`. Dashboard `concluidos_mes` filtra por `entregue_em >= ...` (server/lib/routes/dashboard.dart:51-55), então não conta — mas Kanban (`pedido.status`) mostra. Pedido fantasma "entregue sem data de entrega".
- **Impacto:** Inconsistência de estado. Reproduzível via UI: form de pedido novo expõe dropdown de status. UX permite criar pedido pronto-entregue mas sem registrar quem entregou ou quando.
- **Evidência / verificação:** Inspeção. `_status` em `pedido_form_screen.dart:70` defaults a 'pendente' mas o form deixa o user editar. POST manda `status: _status` (linha 412).
- **Devil's advocate:** Contexto considerado: pode ser intencional pra histórico ("dono cadastrando pedido antigo já entregue"). Mas não há lógica que setea `entregue_em` quando recebe `status='entregue'` na criação — só em `/saida` endpoint. Veredito: sobreviveu como Médio.
- **Fonte:** _Sem fonte canônica viva — o tópico é design de invariante de estado/máquina de estados de domínio (Domain-Driven Design / state-pattern), conhecido como anti-padrão "estado inconsistente na criação". A referência clássica de Martin Fowler `bliki/StateMachine.html` retornou HTTP 404 na verificação. Mantido sem URL externa; o problema se sustenta por inspeção direta do código._
- **Recomendação:** No validator: se `status == 'entregue'`, exigir `entregue_em`. Ou rejeitar `status='entregue'` na criação e forçar fluxo via `/saida`.
- **Risco de regressão se corrigido:** Pequeno — pode bloquear cadastro de pedido histórico. Avaliar.
- **Pré-requisitos:** —
- **Confiança:** Média.
- **Esforço estimado:** Pequeno.
- **Revisão independente:** confirmado com troca de fonte — reviewer verificou validators.dart:12-18 e pedidos.dart:184,190. Ajuste aplicado: URL Martin Fowler StateMachine retornou HTTP 404 via WebFetch; substituído por nota explicativa (design pattern conhecido sem fonte canônica disponível). Finding mantido por inspeção direta.

#### [M-05] Ausência de testes para todas as rotas HTTP (apenas `validators_test` e tests de lógica pura)

- **Localização:** `server/test/` — só `agendador_test.dart`, `calculadora_orcamento_test.dart`, `fechamentos_test.dart`, `pagamentos_test.dart`, `validators_test.dart` (44 tests). Nenhum teste exercita o Pipeline real (auth + cors + routes + DB). Adicionalmente: migrations v1→v8 em `db.dart:25-44` não têm cobertura — corrupção em migration ficaria silenciosa.
- **Trecho relevante:** estrutura do diretório `server/test/` sem qualquer arquivo `*_route_test.dart` nem `*_integration_test.dart` nem `migration_test.dart`.
- **Problema:** O bug C-01 (forma_entrega) é exatamente o tipo que um teste de integração `POST /pedidos` com body típico do app pegaria. Sem teste de rota, contratos cliente-servidor ficam não-cobertos. App tem só `formatters_test.dart` — zero teste de widget/screen/integração. Suite de migrations também está descoberta: rebuild com `empresa.db` antigo pode falhar silenciosamente.
- **Impacto:** Bugs como C-01 passam despercebidos. Refactors de rotas quebram silenciosamente. Mudanças em validators precisam coordenar manualmente com app. Migrations corruptas só são percebidas em produção.
- **Evidência / verificação:** `find ./server/test ./app/test -name '*.dart'` mostra 6 arquivos totais.
- **Devil's advocate:** Contexto considerado: testes unitários são bem feitos no que cobrem. Falta cobertura de integração. Contra-argumento: "fazer integration test puxa o servidor de verdade — caro". Resposta: shelf + sqlite3 em-memória rodam em milissegundos. Já tem `fixtures.dart` pra db. Adicionar suite de rotas é barato. Veredito: sobreviveu como Médio.
- **Fonte:** https://martinfowler.com/articles/practical-test-pyramid.html — "Tests should run quickly. The faster the feedback, the more often we run them, the more bugs we find."
- **Recomendação:** Adicionar `server/test/routes_test.dart` com suite shelf-test que monta o handler completo e bate em cada endpoint com payloads do app. Idealmente, gerar payloads a partir de fixtures compartilhadas com o app. Adicionar também `server/test/migration_test.dart` com asserts sobre versão final do schema partindo de DB legado.
- **Risco de regressão se corrigido:** Zero.
- **Pré-requisitos:** —
- **Confiança:** Alta.
- **Esforço estimado:** Médio.
- **Revisão independente:** confirmado com escopo ampliado — reviewer verificou server/test/ e app/test/. Sugeriu mencionar explicitamente migration suite além de route suite. Ajuste aplicado: adicionado migrations v1→v8 como zona descoberta na localização, trecho e recomendação.

#### [M-06] `quantidade` permitida sem upper-bound — DoS por SUM em queries grandes / cálculo absurdo

- **Localização:** `server/lib/validators.dart` linhas 70-73; `server/lib/routes/orcamento.dart` linhas 53-57.
- **Trecho relevante:**
  ```dart
  if (body.containsKey('quantidade')) {
    final q = body['quantidade'];
    if (q != null && (q is! int || q <= 0)) return 'quantidade deve ser inteiro positivo';
  }
  ```
- **Problema:** Aceita `quantidade=999999999`. Calculadora multiplica por preço, gera valores absurdos (e.g. R$ 27.000.000.000 num orçamento). Não há overflow porque double comporta. Mas: (a) `BrlInputFormatter` no app limita a 9 dígitos (R$ 9.999.999,99) — bom, mas servidor é a authoritative validation; (b) cliente CRUD via API direta pula o formatter; (c) `agendador` faz loop até `restante > 0.0001`, com guard `>365` dias — mas com valor enorme, sempre estoura o guard, gera 400 — aceitável; (d) status_pagamento `'pago'` para qualquer valor após pagamento ≥ valorTotal - 0.01 — atacante seta `valor=1` paga R$ 0,99 → fica "pago". Não é exploit grave, mas erra estado.
- **Impacto:** Latente. Não dispara hoje. Mas falta defensividade — uma integração ruim pode injetar 10**9 e gerar lotes de loop.
- **Evidência / verificação:** Inspeção.
- **Devil's advocate:** Contexto considerado: BrlInputFormatter já protege via app. Server-side limita só com guard de 365 dias úteis no agendador. Contra-argumento: "ninguém vai cadastrar 10**9". Resposta: defesa em profundidade. Veredito: sobreviveu como Médio.
- **Fonte:** https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html — "Minimum and maximum value range check for numerical parameters and dates, minimum and maximum length check for strings." Pertinente: https://cwe.mitre.org/data/definitions/20.html — CWE-20 improper input validation.
- **Recomendação:** Adicionar upper-bound em `quantidade` (e.g. 100000) e em `valor` (e.g. R$ 9.999.999,99 — coerente com o formatter do app). Mesma defensiva no validators.
- **Risco de regressão se corrigido:** Quebra payloads históricos só se houver outliers extremos — improvável.
- **Pré-requisitos:** —
- **Confiança:** Média.
- **Esforço estimado:** Trivial.
- **Revisão independente:** confirmado com excerpt corrigido — reviewer verificou validators.dart:70-73 e orcamento.dart:56-58. Ajuste aplicado: excerpt OWASP "Range check: Where data is numeric..." era paráfrase; substituído pelo texto verbatim ("Minimum and maximum value range check..."), verificado via WebFetch.

#### [M-07] `GET /pedidos` e `GET /clientes` retornam todas as linhas sem `LIMIT` — latência cresce O(N) com base

- **Localização:** `server/lib/routes/pedidos.dart` linhas 75-89; `server/lib/routes/clientes.dart` linhas 57-88. Adicionalmente: `server/lib/agendador.dart` linhas 96-120 (dois SELECTs de tabelas inteiras em `_ocupacaoPorDia`).
- **Trecho relevante:**
  ```dart
  // server/lib/routes/pedidos.dart
  final sql = StringBuffer('SELECT $_pedidoCols FROM pedidos');
  if (where.isNotEmpty) sql.write(' WHERE ${where.join(' AND ')}');
  // ... sql.write(' ORDER BY $ordem');  — sem LIMIT, sem offset/cursor
  final rows = db.raw.select(sql.toString(), args);
  ```
  ```dart
  // server/lib/routes/clientes.dart — N+3 correlated subqueries por linha
  'SELECT ${...}, (SELECT COUNT(*) FROM pedidos p WHERE p.cliente_id = c.id) AS total_pedidos, '
  '(SELECT COALESCE(SUM(valor), 0) FROM pedidos p WHERE p.cliente_id = c.id) AS total_gasto, '
  '(SELECT COALESCE(SUM(valor - valor_pago), 0) FROM pedidos p '
  "  WHERE p.cliente_id = c.id AND p.status_pagamento != 'pago') AS valor_devendo "
  'FROM clientes c'
  ```
- **Problema:** Listagens públicas de `/pedidos` e `/clientes` não têm `LIMIT` nem cursor. Em SQLite, isso significa full-scan + sort em memória do client Dart, e serialização JSON do conjunto inteiro. Em `/clientes`, cada linha dispara 3 correlated subqueries em `pedidos` — efetivamente N×3 sub-queries (N+1 hipertrofiado). Latente hoje (com poucos clientes), explode quando a base cresce. App não tem scroll infinito — busca tudo de uma vez.
- **Impacto:** Latente hoje. Com 300+ pedidos vira lento (>500ms no servidor + parse JSON de 300+ objetos no app). 3G ou bateria fraca notório. Quando o cliente real entrar com volume, dashboard demora, app trava em tela de listagem.
- **Evidência / verificação:** Inspeção das duas rotas. Confirmado que o app (`pedidos_screen.dart`, `clientes_screen.dart`) consome a lista inteira em `ListView.builder` sem paginação.
- **Devil's advocate:** Contexto considerado: o produto está em uso inicial, base pequena. Os filtros `status_pagamento`/`busca` reduzem set. Contra-argumento: "premature optimization". Resposta: cursor-based pagination é padrão simples de adicionar agora — ficar tomando refactor depois quebra UX em pico. Veredito: Médio — não é incêndio, mas tem 100% certeza de virar problema em 6 meses se a base crescer.
- **Fonte:** https://www.sqlite.org/queryplanner.html — "This algorithm is called a _full table scan_ since the entire content of the table must be read and examined in order to find the one row of interest." (princípio canônico de SQLite sobre custo de full-scan; o equivalente sem LIMIT em listagem é o pior caso). Adicional sobre custo de sort sem index: "If the number of output rows is K, then the time needed to sort is proportional to KlogK."
- **Recomendação:** (a) Adicionar paginação cursor-based em `/pedidos` e `/clientes` (param `?cursor=<lote>&limit=50`); (b) UI implementa scroll infinito com `PagedListView`; (c) Em `/clientes`, mover os agregados para uma única CTE/JOIN em vez de 3 correlated subqueries.
- **Risco de regressão se corrigido:** Médio — paginação muda contrato de API, frontend precisa reagir; rota antiga pode aceitar `?limit=all` durante migração.
- **Pré-requisitos:** —
- **Confiança:** Alta.
- **Esforço estimado:** Médio (backend + frontend).
- **Revisão independente:** finding adicionado pelo reviewer — reviewer verificou pedidos.dart:75-89, clientes.dart:57-88 e agendador.dart:96-120 (dois SELECTs de tabelas inteiras). Detectou que auditor original colocou "nenhum significativo identificado" em Performance sem ter aberto rotas listagens. Adicionado como M-07. Excerpt SQLite verificado verbatim via WebFetch.

#### [M-08] Server escuta em `InternetAddress.anyIPv4` sem rate limit no auth — vetor de brute-force em LAN compartilhada

- **Localização:** `server/bin/server.dart` linha 66; `server/lib/auth_middleware.dart` linhas 54-63 (auth_fail log existe mas sem throttle ou bloqueio).
- **Trecho relevante:**
  ```dart
  // server/bin/server.dart
  final server = await serve(handler, InternetAddress.anyIPv4, port);
  ```
  ```dart
  // server/lib/auth_middleware.dart — só loga, não throttle
  authLog.warning('auth_fail method=${req.method} path=$path origin=${req.headers['origin'] ?? '-'}');
  return Response(401, ...);
  ```
- **Problema:** O server bind em `anyIPv4` (0.0.0.0) — qualquer interface, qualquer dispositivo na rede consegue alcançar. Combinado com C-02 (token cleartext) e A-03 (comparação não constant-time), abre janela: atacante na mesma WiFi sniff captura o token; alternativamente, tenta dicionário/brute-force direto sem ser bloqueado — não há rate limit, lockout exponencial, nem reject por IP suspeito. Single token significa que qualquer wrong-guess não tem custo. Auth_fail só vira linha de log, ninguém lê.
- **Impacto:** Em LAN restrita (single-employee), risco baixo. Em rede compartilhada com clientes/visitantes (WiFi de oficina, café, coworking), defesa em profundidade ausente. Cenário realista: WiFi guest do salão alcança o roteador interno, atacante roda script de 1000 req/s contra `/clientes` com tokens aleatórios — sem custo. Server consome CPU respondendo 401, log enche.
- **Evidência / verificação:** Inspeção. Sem `IpRateLimiter`, sem `lockoutMiddleware`, sem variável de ambiente para limitar.
- **Devil's advocate:** Contexto considerado: produto declarou explicitamente threat model "LAN interna" (C-02). Para oficina pequena, é razoável. Contra-argumento: defesa em profundidade. Resposta: se a rede expande (filial, home-office, cliente WiFi), defesa atual colapsa. Veredito: Médio — não é o vetor primário (C-02 é mais crítico), mas é o complemento lógico que separa "amador" de "produto comercial".
- **Fonte:** https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html — "Login Throttling is a protocol used to prevent an attacker from making too many attempts at guessing a password through normal interactive means, it includes the following controls:" e "Rather than implementing a fixed lockout duration (e.g., ten minutes), some applications use an exponential lockout, where the lockout duration starts as a very short period (e.g., one second), but doubles after each failed login attempt."
- **Recomendação:** (a) Bind em `127.0.0.1` se há reverse proxy (Caddy/Nginx) na frente; (b) Adicionar rate-limit middleware antes de `apiKeyAuth` (e.g. 30 req/min por IP, com lockout exponencial após 10 auth_fail); (c) Log de auth_fail incluir IP do origem (já tem em `req.headers['x-forwarded-for']` se proxy passa); (d) Alerta operacional quando auth_fail rate > N.
- **Risco de regressão se corrigido:** Baixo — rate limit + bind 127.0.0.1 são aditivos. Cuidado pra não bloquear o próprio app legítimo se varios devices saem do mesmo IP NAT.
- **Pré-requisitos:** —
- **Confiança:** Alta.
- **Esforço estimado:** Pequeno-médio.
- **Revisão independente:** finding adicionado pelo reviewer — reviewer verificou server.dart:66 (anyIPv4) e auth_middleware.dart:54-63 (log sem throttle). Combinou com C-02 e A-03 pra descrever vetor. Adicionado como M-08. Excerpt OWASP Auth Cheat Sheet rate-limiting verificado verbatim via WebFetch.

### 🟢 Baixos

#### [B-01] `DELETE /clientes/<id>` sem transação e sem warning sobre fechamentos cascateados

- **Localização:** `server/lib/routes/clientes.dart` linhas 258-263; `app/lib/screens/clientes/cliente_form_screen.dart` linhas 161-164.
- **Problema:** DELETE clientes não está em transação. Side effects via FK CASCADE em `cliente_fechamentos` + trigger 008 em `pedidos.fechamento_id`. Em condições normais SQLite WAL serializa. Mas o app só avisa que pedidos "ficarão sem cliente vinculado (mas preservam o nome)" — não menciona que fechamentos do cliente são apagados, perdendo histórico.
- **Impacto:** Baixo — comportamento determinístico, mas UX confusa.
- **Recomendação:** Adicionar transação explícita. Soft-delete via `clientes.removido_em` em vez de DELETE seria melhor.
- **Confiança:** Alta.
- **Revisão independente:** confirmado — reviewer notou que SQLite WAL serializa, então defeito é mais UX-de-confirmação do que data integrity. Severidade Baixo mantida. Sem ajustes.

#### [B-02] `pedidos.cliente_nome` denormalizado fica stale quando cliente é renomeado mas cliente está vinculado por `cliente_id`

- **Localização:** `server/lib/routes/clientes.dart` linhas 237-242.
- **Problema:** Quando o nome do cliente muda, há código que sincroniza `pedidos.cliente_nome` (linhas 237-242). Funciona. Mas se `cliente_id IS NULL` em pedido (cliente apagado), o nome fica fossilizado, e novo cliente com mesmo nome não tem vínculo. Aceitável, mas mal documentado.
- **Impacto:** Confunde relatórios sobre histórico do cliente.
- **Recomendação:** Documentar no comentário do `Pedido` model que `cliente_nome` é snapshot ao momento do INSERT (ou do último UPDATE), não live data.
- **Confiança:** Alta.
- **Revisão independente:** confirmado — reviewer verificou clientes.dart:237-241 (sync em UPDATE) e db.dart:175 (ON DELETE SET NULL fossiliza nome). Renumerado de B-03 para B-02 após corte do ex-B-02. Sem ajustes de conteúdo.

#### [B-03] `setupLogging` imprime via `print` direto sem buffering nem rotação

- **Localização:** `server/lib/logger.dart` linhas 21-26.
- **Problema:** `print('$ts ...')` escreve em stdout linha por linha. Em produção long-running o stdout fica gigantesco (sem rotação). Nenhuma `dart:io.IOSink` com flush controlado. Ok para começar, mas escala mal.
- **Impacto:** Disco enche se ninguém roda logrotate por fora.
- **Recomendação:** Configurar logrotate externamente (deploy doc) ou usar `dart_logging_handlers` com file rotation.
- **Confiança:** Alta.
- **Revisão independente:** confirmado — reviewer verificou logger.dart:21-26 (print() sem buffering nem rotação). Renumerado de B-04 para B-03. Sem ajustes de conteúdo.

#### [B-04] `LIKE '%termo%'` sem escapar `%` e `_` — busca quebra com caracteres especiais

- **Localização:** `server/lib/routes/pedidos.dart` linhas 53, 61; `server/lib/routes/clientes.dart` linhas 53-54.
- **Problema:** O termo de busca é interpolado direto em `LIKE '%${qp['cliente']}%'`. Se o usuário digita `%` ou `_` no campo de busca, vira wildcard de SQL — match indevido. Exemplo: buscar cliente `50% off` (improvável, mas) ou `arq_test` (mais comum em descrição de pedido) retorna resultados errados. Não é SQL injection (parâmetros estão bind), só correctness de UX.
- **Impacto:** UX bug. Usuário digita termo legítimo, busca não retorna match exato. Difícil de reproduzir, fácil de não perceber.
- **Evidência / verificação:** Inspeção dos arquivos.
- **Recomendação:** Escapar `%`, `_` (e o próprio escape char) no termo antes de bind. Usar `LIKE ? ESCAPE '\'` na cláusula. Alternativa moderna: migrar busca pra FTS5 (`pedidos_fts`, `clientes_fts`) para tokenização decente.
- **Confiança:** Alta.
- **Revisão independente:** finding adicionado pelo reviewer — reviewer verificou pedidos.dart:53,61 e clientes.dart:53-54 (interpolação direta). Adicionado como B-04. Excerpt SQLite LIKE verificado verbatim via WebFetch: "A percent symbol ("%") in the LIKE pattern matches any sequence of zero or more characters in the string. An underscore ("_") in the LIKE pattern matches any single character in the string." (https://www.sqlite.org/lang_expr.html). Não é SQL injection — apenas UX.

## Achados por camada

| Camada | IDs |
|---|---|
| Correctness/comportamento | C-01, A-01, A-04, M-01, M-04, M-06 |
| Segurança | C-02, A-02, A-03, M-08 |
| Backend / API | C-01, A-01, A-02, A-03, M-03, M-04, M-07, M-08 |
| Frontend (Flutter) | C-01 (parte), A-05, B-04 (UX) |
| Dados / Schema | A-04, B-01, B-02 |
| Performance | M-07 (paginação ausente), M-08 (bind público sem throttle) |
| Testes | C-01 (consequência), M-05 |
| Build / CI | (nenhum CI presente — ver Zonas cegas) |
| DX / Tooling | M-02, M-05, B-03 |
| Dependências | (todas atualizadas — bom, ver "O que está bem feito") |
| Configurações | A-02, M-02 |

## O que está bem feito

- **`agendador.dart` é didático e robusto:** `_proximoDiaUtil` puro/estático, `_chaveDia` consistente, distribuição transacional, guard `>365` evita loop infinito (linha 66). Excelente exemplo de lógica de domínio testável.
- **`proximoLote()` usa `UPDATE ... RETURNING` atômico** (`server/lib/db.dart:85-99`) — evita race condition documentado no comentário. Teste de stress (50 lotes únicos) em `agendador_test.dart:114-127` valida.
- **Migration system com `schema_version` + heurística de detecção de DB legado** (`db.dart:18-46`) — sofisticado pra um produto pequeno. Comentários explicam decisões. Migration 007 documenta racional de unificação de `data_fixa`→`mensal`.
- **Dependências up-to-date:** `dart pub outdated` em ambos os pacotes retorna "all up-to-date" para direct dependencies. Só transitive ficam atrás.
- **Tests unitários do domínio puro:** 44 testes no server + 21 no app, todos passam. Cobrem cálculos críticos (orçamento, recalculo de pagamento, agendamento, fechamentos). `tolerância de R\$ 0,01 para arredondamento` em `pagamentos_test.dart:71-79` mostra que a equipe está ciente do trade-off de floating-point.
- **Auth middleware separa `/health` e `OPTIONS`** corretamente (`auth_middleware.dart:39-49`). CORS impl em `server.dart:95-118` documenta que apps mobile não enviam `Origin` — confina logica corretamente.
- **`BrlInputFormatter` em `app/lib/util/formatters.dart`** é a abordagem certa pra moeda em input (acumulador de centavos), evita ambiguidade de "1.234". Bem testado (`formatters_test.dart`).
- **Comentários "por que" em pontos altos:** `db.dart:25-44` explica a heurística de migration; `pagamentos_util.dart:5` cita tolerância; `auth_middleware.dart:9-12` explica fallback; `kanban_screen.dart:81-85` justifica tabs em mobile.
- **`_recheckDirty` é chamado consistentemente em todos os onChanged dos forms** — toggles, dropdowns, date pickers, sliders e text controllers todos invocam `_recheckDirty()` após `setState`. Verificado em `cliente_form_screen.dart` (linhas 374, 386, 408, 431) e `pedido_form_screen.dart` (21 call sites entre linhas 789-1356). Auditoria original tinha falso positivo aqui (ex-B-02), removido após revisão independente.

## Zonas cegas desta auditoria

- `tool_unavailable` — `osv-scanner`, `npm-audit`, `pip-audit`, `cargo-audit`, `trivy`, `dart vuln-audit` (não existe oficial). **O que destrancaria:** scan de CVEs nas dependências `dio:5.9.2`, `shelf:1.4.1`, `sqlite3:3.3.1`, `flutter_riverpod:3.3.1`, `shared_preferences:2.5.5`, `go_router:17.2.3`. Como `pub outdated` mostra tudo direct atualizado e Riverpod 3.3.1 é recente, risco é baixo, mas há trasitive flagged (`analyzer 10→13`).
- `requires_product_context` — (a) regra de negócio sobre pedido com `quantidade<12` (M-01); (b) política de retenção de cliente apagado (B-01); (c) expectativa real sobre `LOG_LEVEL` runtime (M-02); (d) se sistema deveria autorizar setar `status='entregue'` na criação (M-04).
- `external_dependency` — não auditei o comportamento real do `go_router` em redirecionamentos, da `intl` em locale BRT durante DST (o Brasil aboliu horário de verão em 2019 — alívio, mas o code não assume isso), nem do `sqlite3` quanto a edge cases de RETURNING em concorrência alta.
- `context_window_pressure` — `app/lib/screens/pedidos/pedido_form_screen.dart` tem 2700+ linhas; li primeiras 600 + busquei por termos. Pode haver bugs em validação form-side (e.g. submeter sem técnica selecionada, ou em recalcular orçamento debounce que pode race). `pedidos_screen.dart` (600 linhas), `cliente_detalhe_view.dart`, `fechamento_detalhe_screen.dart` foram só skimmed.
- `out_of_scope` — código VBA da planilha legada em `vba_extract/`, planilha `Controle_Produção_Com_Macro_Completa.xlsm`, build Windows-específico (`app/windows/`), imagens dos icon launchers, `assets/google_fonts/`. Auditoria focou em código que roda em produção (Flutter app + server).

## Apêndice A — Comandos executados

- `git rev-parse HEAD` → `f7ebc373b03c0b2464d920a47c822c0bbd51f104` (estado auditado)
- `ls -la` no root → confirmou presença de `app/`, `server/`, planilha legada
- `cat server/.gitignore` → confirmou que `api_token`, `empresa.db*` estão ignorados
- `git ls-files server/api_token server/empresa.db` → vazio (não tracked, bom)
- `dart --version` → 3.11.4 stable
- `find ./{app,server} -name "*.dart" | wc -l` → 84 arquivos
- `find ./{app,server} -name "*.dart" | xargs wc -l` → app 15669 LOC, server 3792 LOC
- `dart analyze` em `server/` → "No issues found!"
- `dart analyze` em `app/` → "No issues found!"
- `dart test` em `server/` → 44 tests passed
- `flutter test` em `app/` → 21 tests passed
- Reprodução empírica de C-01: rodou `validarPedido({'cliente_nome':'X','descricao':'d','valor':1,'forma_entrega':'retirada'}, criar:true)` retornou exatamente: `forma_entrega inválido (use: retirar, entregar, correios)` (output verbatim na transcript)
- `dart pub outdated` em `server/` → só `native_toolchain_c` transitive atrasado
- `flutter pub outdated` em `app/` → todos direct up-to-date; alguns transitive atrasados (`analyzer`, `_fe_analyzer_shared`, `meta`, `matcher`, `test`)
- Greps de cross-referencing: `formaEntrega*` (encontrou 2 set conflicting), `proximo_lote` (confirmou GET filtra, PUT não), `DELETE FROM clientes` (sem transação), `String.fromEnvironment` (só LOG_LEVEL)
- Pass 12 (revisão): `grep -n "_recheckDirty" cliente_form_screen.dart` retornou 4 call sites em onChanged (374, 386, 408, 431); `grep -n "_recheckDirty" pedido_form_screen.dart` retornou 17 call sites entre 789-1356 — refutando ex-B-02; WebFetch verbatim de https://www.sqlite.org/queryplanner.html, https://www.sqlite.org/lang_expr.html, https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html, https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html, https://cheatsheetseries.owasp.org/cheatsheets/Error_Handling_Cheat_Sheet.html, https://pub.dev/documentation/dio/latest/dio/Dio/close.html, https://riverpod.dev/docs/concepts/about_code_generation, https://martinfowler.com/articles/consumerDrivenContracts.html para todos excerpts corrigidos.

## Apêndice B — Referências

1. https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html — Constant-time comparison de credentials; login throttling e lockout exponencial.
2. https://cheatsheetseries.owasp.org/cheatsheets/Transport_Layer_Security_Cheat_Sheet.html — HTTPS only para APIs.
3. https://owasp.org/www-project-mobile-top-10/2023-risks/m9-insecure-data-storage — Insecure Data Storage em apps mobile.
4. https://cwe.mitre.org/data/definitions/208.html — CWE-208 Observable Timing Discrepancy.
5. https://martinfowler.com/eaaCatalog/money.html — Money pattern.
6. https://api.dart.dev/dart-core/double-class.html — Dart double = IEEE 754 64-bit.
7. https://www.sqlite.org/datatype3.html — SQLite REAL = 8-byte IEEE FP.
8. https://api.dart.dev/dart-core/DateTime-class.html — `DateTime.now()` é local.
9. https://dart.dev/libraries/core/environment-declarations — `fromEnvironment` é compile-time.
10. https://api.dart.dev/dart-core/String/operator_equals.html — String == comparison spec.
11. https://martinfowler.com/articles/consumerDrivenContracts.html — Consumer-Driven Contracts (substituiu OWASP API Security em C-01).
12. https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html — Validação sintática + semântica; range check para numéricos.
13. https://owasp.org/Top10/A04_2021-Insecure_Design/ — Insecure Design.
14. https://cwe.mitre.org/data/definitions/20.html — CWE-20 Improper Input Validation.
15. https://cheatsheetseries.owasp.org/cheatsheets/Error_Handling_Cheat_Sheet.html — Error handling generic response.
16. https://martinfowler.com/articles/practical-test-pyramid.html — Test pyramid.
17. https://pub.dev/documentation/dio/latest/dio/Dio/close.html — Dio.close (shuts down dio client).
18. https://riverpod.dev/docs/concepts/about_code_generation — Riverpod auto-dispose.
19. https://www.sqlite.org/foreignkeys.html — SQLite FK semantics.
20. https://www.sqlite.org/lang_createtrigger.html — SQLite BEFORE/AFTER triggers.
21. https://www.sqlite.org/queryplanner.html — SQLite query planner; full-scan cost (M-07).
22. https://www.sqlite.org/lang_expr.html — SQLite LIKE wildcard semantics e ESCAPE (B-04).

## Apêndice C — Metadata (machine-readable)

```yaml
audit_version: 4
generated_at: 2026-05-15T01:44:59Z
revised_at: 2026-05-15T02:30:00Z
reviewer_protocol:
  invoked_separately_by_orchestrator: true
  fresh_context: true
  applied_to: this_audit
  pass_1: "code-auditor (draft) — Passes 0-10"
  pass_2: "code-audit-reviewer (independent review) — Passe 11"
  pass_3: "code-auditor (revise) — Passe 12, applied reviewer feedback"
reviewer_summary:
  findings_reviewed: 17
  confirmed_no_change: 8
  confirmed_with_adjustment: 7
  contested_removed: 1
  added_by_reviewer: 3
  final_total: 19
repo_state:
  commit: f7ebc373b03c0b2464d920a47c822c0bbd51f104
  branch: main
tools_inventory:
  available: [dart, flutter, git, node, grep, find, ls]
  missing: [osv-scanner, npm-audit, pip-audit, cargo-audit, trivy, sqlite3-cli]
totals:
  critico: 2
  alto: 5
  medio: 8
  baixo: 4
findings:
  - id: C-01
    severity: critico
    title: "forma_entrega da UI é rejeitado pelo validador do server"
    file: "server/lib/validators.dart"
    lines: [44, 97]
    cross_files:
      - "app/lib/screens/pedidos/pedido_form_screen.dart#L73,L407,L2134"
      - "server/lib/routes/pedidos.dart#L109"
    sources:
      - url: "https://martinfowler.com/articles/consumerDrivenContracts.html"
        excerpt: "Services encapsulate discrete, identifiable, reusable business functions whose integrity should not be compromised by unreasonable demands falling outside their mandate."
    prereqs: []
    confidence: alta
    effort: trivial
    reviewer_verdict: confirmed
    reviewer_note: "fonte trocada de OWASP API Security (tópico authentication, não casava com contrato) para Martin Fowler Consumer-Driven Contracts; excerpt verbatim verificado via WebFetch"
    source: original
  - id: C-02
    severity: critico
    title: "Token API em cleartext HTTP + SharedPreferences plaintexto"
    file: "app/android/app/src/main/AndroidManifest.xml"
    lines: [10]
    cross_files:
      - "app/lib/api/api_client.dart#L332-L340"
      - "server/lib/auth_middleware.dart#L13-L35"
    sources:
      - url: "https://cheatsheetseries.owasp.org/cheatsheets/Transport_Layer_Security_Cheat_Sheet.html"
        excerpt: "API-only endpoints should disable HTTP altogether and only support encrypted connections."
      - url: "https://owasp.org/www-project-mobile-top-10/2023-risks/m9-insecure-data-storage"
        excerpt: "Insecure Data Caching: The mobile application caches sensitive data, such as user authentication tokens or session information, without implementing appropriate security measures."
    prereqs: []
    confidence: alta
    effort: medio
    reviewer_verdict: confirmed
    reviewer_note: "ambos excerpts OWASP verificados verbatim; sem ajustes"
    source: original
  - id: A-01
    severity: alto
    title: "/dashboard/stats mistura data local com timestamps UTC"
    file: "server/lib/routes/dashboard.dart"
    lines: [31, 55]
    sources:
      - url: "https://api.dart.dev/dart-core/DateTime-class.html"
        excerpt: "Constructs a DateTime instance with current date and time in the local time zone."
    prereqs: []
    confidence: alta
    effort: pequeno
    reviewer_verdict: confirmed
    reviewer_note: "janela de 3h BRT/UTC confirmada; excerpt Dart verificado verbatim"
    source: original
  - id: A-02
    severity: alto
    title: "PUT /configuracoes/<chave> aceita edição de proximo_lote e pcts sem allowlist"
    file: "server/lib/routes/configuracoes.dart"
    lines: [43, 61]
    sources:
      - url: "https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html"
        excerpt: "Syntactic validation should enforce correct syntax of structured fields (e.g. SSN, date, currency symbol). Semantic validation should enforce correctness of their values in the specific business context (e.g. start date is before end date, price is within expected range)."
    prereqs: []
    confidence: alta
    effort: pequeno
    reviewer_verdict: confirmed_with_adjustment
    reviewer_note: "excerpt anterior era paráfrase; substituído pelo verbatim verificado via WebFetch"
    source: original
  - id: A-03
    severity: alto
    title: "Comparação de token com != não é constant-time"
    file: "server/lib/auth_middleware.dart"
    lines: [54]
    sources:
      - url: "https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html"
        excerpt: "Where possible, the user-supplied password should be compared to the stored password hash using a secure password comparison function provided by the language or framework, such as the password_verify() function in PHP."
      - url: "https://cwe.mitre.org/data/definitions/208.html"
        excerpt: "Two separate operations in a product require different amounts of time to complete, in a way that is observable to an actor and reveals security-relevant information about the state of the product."
    prereqs: [C-02]
    confidence: alta
    effort: trivial
    reviewer_verdict: confirmed
    reviewer_note: "ambas fontes verbatim verificadas"
    source: original
  - id: A-04
    severity: alto
    title: "Valores monetários em double IEEE 754 — desvio acumulado"
    file: "server/lib/db.dart"
    lines: [166, 285]
    cross_files:
      - "server/lib/calculadora_orcamento.dart#L8-L71"
      - "server/lib/pagamentos_util.dart#L5-L29"
    sources:
      - url: "https://martinfowler.com/eaaCatalog/money.html"
        excerpt: "Monetary calculations are often rounded to the smallest currency unit. When you do this it's easy to lose pennies (or your local equivalent) because of rounding errors."
      - url: "https://api.dart.dev/dart-core/double-class.html"
        excerpt: "Dart doubles are 64-bit floating-point numbers as specified in the IEEE 754 standard."
    prereqs: []
    confidence: media
    effort: grande
    reviewer_verdict: confirmed_with_adjustment
    reviewer_note: "framing ajustado — fix exige migração schema completa, prioridade vs C-01/C-02/A-01 (fixes triviais) reavaliada; bug latente"
    source: original
  - id: A-05
    severity: alto
    title: "ApiClient antigo não fecha Dio em troca de token/URL"
    file: "app/lib/api/api_client.dart"
    lines: [316, 320]
    sources:
      - url: "https://pub.dev/documentation/dio/latest/dio/Dio/close.html"
        excerpt: "Shuts down the dio client. If `force` is `false` (the default) the Dio will be kept alive until all active connections are done. If `force` is `true` any active connections will be closed to immediately release all resources."
      - url: "https://riverpod.dev/docs/concepts/about_code_generation"
        excerpt: "When using code generation, providers are autoDispose by default. That means that they will automatically dispose of themselves when there are no listeners attached to them (ref.watch/ref.listen)."
    prereqs: []
    confidence: alta
    effort: trivial
    reviewer_verdict: confirmed_with_adjustment
    reviewer_note: "excerpt Dio.close anterior era paráfrase inexistente; substituído pelo verbatim. Excerpt Riverpod sobre autoDispose verbatim verificado"
    source: original
  - id: M-01
    severity: medio
    title: "_faixa(qtd) retorna '12-24' para qtd<12 — cobra menos por pedidos pequenos"
    file: "server/lib/calculadora_orcamento.dart"
    lines: [73, 78]
    sources:
      - url: "https://owasp.org/Top10/A04_2021-Insecure_Design/"
        excerpt: "Insecure design represents different weaknesses, expressed as missing or ineffective control design."
    prereqs: []
    confidence: media
    effort: trivial
    reviewer_verdict: confirmed
    reviewer_note: "nota requires_product_context mantida; sem ajustes"
    source: original
  - id: M-02
    severity: medio
    title: "String.fromEnvironment('LOG_LEVEL') é compile-time, não runtime"
    file: "server/lib/logger.dart"
    lines: [10]
    sources:
      - url: "https://dart.dev/libraries/core/environment-declarations"
        excerpt: "Compilation environment declarations specify configuration options as key-value pairs that are accessed and evaluated at compile time."
    prereqs: []
    confidence: alta
    effort: trivial
    reviewer_verdict: confirmed
    reviewer_note: "inconsistência interna server.dart usa Platform.environment runtime confirmada; sem ajustes"
    source: original
  - id: M-03
    severity: medio
    title: "Sem handler global de exceções no Pipeline"
    file: "server/bin/server.dart"
    lines: [60, 64]
    sources:
      - url: "https://cheatsheetseries.owasp.org/cheatsheets/Error_Handling_Cheat_Sheet.html"
        excerpt: "when an unexpected error occurs then a generic response is returned by the application but the error details are logged server side for investigation, and not returned to the user."
    prereqs: []
    confidence: alta
    effort: trivial
    reviewer_verdict: confirmed_with_adjustment
    reviewer_note: "excerpt anterior era paráfrase; substituído pelo verbatim verificado via WebFetch"
    source: original
  - id: M-04
    severity: medio
    title: "status aceita 'entregue' na criação sem validação semântica"
    file: "server/lib/validators.dart"
    lines: [12, 18]
    cross_files:
      - "server/lib/routes/pedidos.dart#L190"
    sources: []
    prereqs: []
    confidence: media
    effort: pequeno
    reviewer_verdict: confirmed_with_adjustment
    reviewer_note: "fonte original Martin Fowler StateMachine retornou HTTP 404 via WebFetch; tópico é design pattern conhecido (state-machine de domínio / DDD invariants) sem fonte canônica viva — mantido com sources: [] e nota explicativa no AUDIT.md"
    source: original
  - id: M-05
    severity: medio
    title: "Ausência de testes para rotas HTTP, widgets e migrations"
    file: "server/test/"
    lines: [0, 0]
    sources:
      - url: "https://martinfowler.com/articles/practical-test-pyramid.html"
        excerpt: "Tests should run quickly. The faster the feedback, the more often we run them, the more bugs we find."
    prereqs: []
    confidence: alta
    effort: medio
    reviewer_verdict: confirmed_with_adjustment
    reviewer_note: "escopo ampliado: migrations v1→v8 sem cobertura também mencionado, conforme sugestão do reviewer"
    source: original
  - id: M-06
    severity: medio
    title: "quantidade sem upper-bound — defesa em profundidade ausente"
    file: "server/lib/validators.dart"
    lines: [70, 73]
    sources:
      - url: "https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html"
        excerpt: "Minimum and maximum value range check for numerical parameters and dates, minimum and maximum length check for strings."
    prereqs: []
    confidence: media
    effort: trivial
    reviewer_verdict: confirmed_with_adjustment
    reviewer_note: "excerpt anterior era paráfrase; substituído pelo verbatim verificado via WebFetch"
    source: original
  - id: M-07
    severity: medio
    title: "GET /pedidos e GET /clientes sem LIMIT — latência cresce O(N)"
    file: "server/lib/routes/pedidos.dart"
    lines: [75, 89]
    cross_files:
      - "server/lib/routes/clientes.dart#L57-L88"
      - "server/lib/agendador.dart#L96-L120"
    sources:
      - url: "https://www.sqlite.org/queryplanner.html"
        excerpt: "This algorithm is called a _full table scan_ since the entire content of the table must be read and examined in order to find the one row of interest."
    prereqs: []
    confidence: alta
    effort: medio
    reviewer_verdict: new
    reviewer_note: "finding ausente na auditoria original — Performance estava marcada 'nenhum significativo identificado', mas paginação ausente e N+3 subqueries em /clientes são reais"
    source: reviewer_pass
  - id: M-08
    severity: medio
    title: "Server bind 0.0.0.0 sem rate limit no auth — brute-force em LAN compartilhada"
    file: "server/bin/server.dart"
    lines: [66]
    cross_files:
      - "server/lib/auth_middleware.dart#L54-L63"
    sources:
      - url: "https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html"
        excerpt: "Login Throttling is a protocol used to prevent an attacker from making too many attempts at guessing a password through normal interactive means, it includes the following controls:"
    prereqs: [C-02]
    confidence: alta
    effort: pequeno
    reviewer_verdict: new
    reviewer_note: "complementa C-02 e A-03 com defesa em profundidade ausente; bind público sem throttle vira vetor de brute-force em rede compartilhada"
    source: reviewer_pass
  - id: B-01
    severity: baixo
    title: "DELETE /clientes/<id> sem transação e sem warning sobre fechamentos"
    file: "server/lib/routes/clientes.dart"
    lines: [258, 263]
    sources: []
    prereqs: []
    confidence: alta
    effort: pequeno
    reviewer_verdict: confirmed
    reviewer_note: "WAL serializa, defeito é UX-de-confirmação mais do que data integrity; severidade Baixo mantida"
    source: original
  - id: B-02
    severity: baixo
    title: "pedidos.cliente_nome fica stale após cliente apagado"
    file: "server/lib/routes/clientes.dart"
    lines: [237, 242]
    sources: []
    prereqs: []
    confidence: alta
    effort: trivial
    reviewer_verdict: confirmed
    reviewer_note: "renumerado de B-03 para B-02 após corte do falso positivo ex-B-02 (recheckDirty)"
    source: original
  - id: B-03
    severity: baixo
    title: "setupLogging usa print direto sem rotação de log"
    file: "server/lib/logger.dart"
    lines: [21, 26]
    sources: []
    prereqs: []
    confidence: alta
    effort: pequeno
    reviewer_verdict: confirmed
    reviewer_note: "renumerado de B-04 para B-03"
    source: original
  - id: B-04
    severity: baixo
    title: "LIKE '%termo%' sem escapar % e _ — busca quebra com caracteres especiais"
    file: "server/lib/routes/pedidos.dart"
    lines: [53, 61]
    cross_files:
      - "server/lib/routes/clientes.dart#L53-L54"
    sources:
      - url: "https://www.sqlite.org/lang_expr.html"
        excerpt: "A percent symbol (\"%\") in the LIKE pattern matches any sequence of zero or more characters in the string. An underscore (\"_\") in the LIKE pattern matches any single character in the string."
    prereqs: []
    confidence: alta
    effort: trivial
    reviewer_verdict: new
    reviewer_note: "finding ausente na auditoria original; UX bug — não é SQL injection, parâmetros estão bound; verbatim verificado via WebFetch"
    source: reviewer_pass
removed_findings:
  - id: ex-B-02
    title: "recheckDirty não escuta toggles/dropdowns nos forms (auditoria original)"
    reviewer_verdict: contested
    removal_reason: "Refutado: verificação direta em cliente_form_screen.dart linhas 374, 386, 408, 431 e pedido_form_screen.dart linhas 789, 812, 821, 845, 871, 875, 889, 894, 909, 992, 1005, 1009, 1023, 1159, 1333, 1356 mostra que TODO toggle/dropdown/date-picker onChanged invoca _recheckDirty() após setState. Afirmação original era factualmente incorreta. Mantida no AUDIT.md como item positivo em 'O que está bem feito'."
```
