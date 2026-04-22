import 'package:sqlite3/sqlite3.dart';

class Db {
  final Database raw;
  Db(this.raw);

  static Db open(String path) {
    final raw = sqlite3.open(path);
    raw.execute('PRAGMA foreign_keys = ON;');
    raw.execute('PRAGMA journal_mode = WAL;');
    final db = Db(raw);
    db._migrate();
    return db;
  }

  int _currentVersion() {
    raw.execute(
      'CREATE TABLE IF NOT EXISTS schema_version (version INTEGER PRIMARY KEY, aplicada_em TEXT NOT NULL)',
    );
    final row = raw.select('SELECT MAX(version) AS v FROM schema_version').first;
    final v = row['v'];
    if (v is int) return v;
    // DB vazia — mas pode ser DB antiga que já foi criada com o schema v1 via CREATE IF NOT EXISTS.
    final pedidosExiste = raw.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='pedidos'",
    );
    if (pedidosExiste.isNotEmpty) {
      final now = DateTime.now().toIso8601String();
      raw.execute('INSERT INTO schema_version VALUES (1, ?)', [now]);
      return 1;
    }
    return 0;
  }

  void _migrate() {
    final migrations = <_Migration>[
      _Migration(1, _migration001Base),
      _Migration(2, _migration002Expansao),
      _Migration(3, _migration003SeedTabelaPreco),
      _Migration(4, _migration004Fechamentos),
      _Migration(5, _migration005RegiaoTipoPeca),
      _Migration(6, _migration006PrecosOficiais2026),
    ];

    var current = _currentVersion();
    for (final m in migrations) {
      if (m.version <= current) continue;
      raw.execute('BEGIN');
      try {
        m.up(raw);
        raw.execute(
          'INSERT INTO schema_version VALUES (?, ?)',
          [m.version, DateTime.now().toIso8601String()],
        );
        raw.execute('COMMIT');
        print('[db] migration ${m.version} aplicada');
        current = m.version;
      } catch (e) {
        raw.execute('ROLLBACK');
        print('[db] ERRO na migration ${m.version}: $e');
        rethrow;
      }
    }
  }

  int proximoLote() {
    final row = raw.select("SELECT valor FROM configuracoes WHERE chave='proximo_lote'").first;
    final atual = int.parse(row['valor'] as String);
    raw.execute(
      "UPDATE configuracoes SET valor=?, atualizado_em=? WHERE chave='proximo_lote'",
      [(atual + 1).toString(), DateTime.now().toIso8601String()],
    );
    return atual;
  }

  Map<String, String> carregarConfiguracoes() {
    final rows = raw.select('SELECT chave, valor FROM configuracoes');
    return {for (final r in rows) r['chave'] as String: r['valor'] as String};
  }

  double configNumber(String chave, double padrao) {
    final rows = raw.select('SELECT valor FROM configuracoes WHERE chave=?', [chave]);
    if (rows.isEmpty) return padrao;
    return double.tryParse(rows.first['valor'] as String) ?? padrao;
  }

  bool configBool(String chave, bool padrao) {
    final rows = raw.select('SELECT valor FROM configuracoes WHERE chave=?', [chave]);
    if (rows.isEmpty) return padrao;
    final v = rows.first['valor'] as String;
    return v == 'true' || v == '1';
  }

  void close() => raw.dispose();
}

class _Migration {
  final int version;
  final void Function(Database) up;
  _Migration(this.version, this.up);
}

// ── 001 — esquema base (o que já existia) ─────────────────────────────────

void _migration001Base(Database raw) {
  raw.execute('''
    CREATE TABLE IF NOT EXISTS clientes (
      id TEXT PRIMARY KEY,
      nome TEXT NOT NULL,
      criado_em TEXT NOT NULL
    );
  ''');

  raw.execute('''
    CREATE TABLE IF NOT EXISTS pedidos (
      id TEXT PRIMARY KEY,
      lote INTEGER NOT NULL UNIQUE,
      cliente_id TEXT,
      cliente_nome TEXT NOT NULL,
      descricao TEXT NOT NULL,
      peca TEXT,
      tecnica TEXT,
      quantidade INTEGER,
      valor REAL NOT NULL,
      data_chegada TEXT,
      data_producao TEXT,
      prazo_dias INTEGER,
      status TEXT NOT NULL DEFAULT 'pendente',
      urgente INTEGER NOT NULL DEFAULT 0,
      observacao TEXT,
      criado_em TEXT NOT NULL,
      atualizado_em TEXT NOT NULL,
      FOREIGN KEY (cliente_id) REFERENCES clientes(id) ON DELETE SET NULL
    );
  ''');

  raw.execute('CREATE INDEX IF NOT EXISTS idx_pedidos_status ON pedidos(status);');
  raw.execute('CREATE INDEX IF NOT EXISTS idx_pedidos_data_producao ON pedidos(data_producao);');
  raw.execute('CREATE INDEX IF NOT EXISTS idx_pedidos_cliente ON pedidos(cliente_nome);');

  raw.execute('''
    CREATE TABLE IF NOT EXISTS configuracoes (
      chave TEXT PRIMARY KEY,
      valor TEXT NOT NULL,
      tipo TEXT NOT NULL,
      descricao TEXT,
      atualizado_em TEXT NOT NULL
    );
  ''');

  raw.execute('''
    CREATE TABLE IF NOT EXISTS tabela_preco (
      id TEXT PRIMARY KEY,
      tecnica TEXT NOT NULL,
      regiao TEXT NOT NULL,
      faixa_qtd TEXT NOT NULL,
      primeira_cor REAL NOT NULL,
      demais_cores REAL NOT NULL,
      UNIQUE(tecnica, regiao, faixa_qtd)
    );
  ''');

  // Seed de configurações (só se estiver vazia)
  final count = raw.select('SELECT COUNT(*) AS n FROM configuracoes').first['n'] as int;
  if (count == 0) {
    final now = DateTime.now().toIso8601String();
    final defaults = <List<String>>[
      ['limite_diario', '1200', 'number', 'Limite máximo de produção em R\$ por dia útil'],
      ['producao_sabado', 'false', 'bool', 'Sábado conta como dia de produção'],
      ['producao_domingo', 'false', 'bool', 'Domingo conta como dia de produção'],
      ['prazo_padrao_dias', '5', 'number', 'Prazo padrão em dias úteis para início da produção'],
      ['taxa_urgencia_pct', '25', 'number', 'Taxa adicional para pedidos urgentes (%)'],
      ['adicional_moletom_aberto_pct', '20', 'number', 'Adicional para moletom aberto (%)'],
      ['adicional_moletom_fechado_pct', '60', 'number', 'Adicional para moletom fechado (%)'],
      ['matriz_gratis_acima_pcs', '150', 'number', 'Não cobrar matriz acima desta quantidade'],
      ['matriz_padrao_40x50', '35', 'number', 'Valor da matriz padrão 40x50'],
      ['matriz_padrao_50x60', '45', 'number', 'Valor da matriz padrão 50x60'],
      ['lote_prefixo', 'LOTE', 'string', 'Prefixo do código do lote'],
      ['lote_digitos', '4', 'number', 'Quantidade de dígitos do código de lote'],
      ['empresa_nome', 'Serigrafia Baray', 'string', 'Nome da empresa exibido no cabeçalho'],
    ];
    final stmt = raw.prepare(
      'INSERT INTO configuracoes (chave, valor, tipo, descricao, atualizado_em) VALUES (?,?,?,?,?)',
    );
    for (final c in defaults) {
      stmt.execute([c[0], c[1], c[2], c[3], now]);
    }
    stmt.dispose();
    raw.execute(
      "INSERT INTO configuracoes (chave, valor, tipo, descricao, atualizado_em) VALUES ('proximo_lote','100','number','Próximo número de lote',?)",
      [now],
    );
  }
}

// ── 002 — expansão pra unificar com a planilha de saída ───────────────────

void _migration002Expansao(Database raw) {
  // Pedidos: campos novos. ADD COLUMN é idempotente-ish, mas aqui é nova migration então não re-executa.
  const colunasPedidos = <List<String>>[
    ['cliente_telefone', 'TEXT'],
    ['cliente_email', 'TEXT'],
    ['forma_entrega', 'TEXT'],
    ['endereco_entrega', 'TEXT'],
    ['data_entrega_combinada', 'TEXT'],
    ['entregue_em', 'TEXT'],
    ['entregue_por', 'TEXT'],
    ['cor_peca', 'TEXT'],
    ['tamanho_peca', 'TEXT'],
    ['tecido', 'TEXT'],
    ['arte_cores', 'INTEGER'],
    ['arte_tamanho_cm', 'TEXT'],
    ['arte_posicao', 'TEXT'],
    ['arte_observacao', 'TEXT'],
    ['forma_pagamento', 'TEXT'],
    ['valor_pago', 'REAL NOT NULL DEFAULT 0'],
    ['sinal_pago', 'REAL NOT NULL DEFAULT 0'],
    ['status_pagamento', "TEXT NOT NULL DEFAULT 'devendo'"],
    ['agendamento_fixo', 'INTEGER NOT NULL DEFAULT 0'],
  ];
  for (final c in colunasPedidos) {
    raw.execute('ALTER TABLE pedidos ADD COLUMN ${c[0]} ${c[1]};');
  }

  // Clientes: telefone, email, endereço, observacao, atualizado_em
  const colunasClientes = <List<String>>[
    ['telefone', 'TEXT'],
    ['email', 'TEXT'],
    ['endereco', 'TEXT'],
    ['observacao', 'TEXT'],
    ['atualizado_em', 'TEXT'],
  ];
  for (final c in colunasClientes) {
    raw.execute('ALTER TABLE clientes ADD COLUMN ${c[0]} ${c[1]};');
  }
  raw.execute('UPDATE clientes SET atualizado_em = criado_em WHERE atualizado_em IS NULL;');

  // Pagamentos
  raw.execute('''
    CREATE TABLE IF NOT EXISTS pedido_pagamentos (
      id TEXT PRIMARY KEY,
      pedido_id TEXT NOT NULL,
      valor REAL NOT NULL,
      forma TEXT,
      quando TEXT NOT NULL,
      observacao TEXT,
      FOREIGN KEY (pedido_id) REFERENCES pedidos(id) ON DELETE CASCADE
    );
  ''');
  raw.execute('CREATE INDEX IF NOT EXISTS idx_pagamentos_pedido ON pedido_pagamentos(pedido_id);');

  // Distribuição (pedido grande ocupa N dias)
  raw.execute('''
    CREATE TABLE IF NOT EXISTS pedido_distribuicao (
      id TEXT PRIMARY KEY,
      pedido_id TEXT NOT NULL,
      data TEXT NOT NULL,
      parcela_valor REAL NOT NULL,
      FOREIGN KEY (pedido_id) REFERENCES pedidos(id) ON DELETE CASCADE
    );
  ''');
  raw.execute('CREATE INDEX IF NOT EXISTS idx_distrib_data ON pedido_distribuicao(data);');
  raw.execute('CREATE INDEX IF NOT EXISTS idx_distrib_pedido ON pedido_distribuicao(pedido_id);');

  // Anexos (arte, foto)
  raw.execute('''
    CREATE TABLE IF NOT EXISTS pedido_anexos (
      id TEXT PRIMARY KEY,
      pedido_id TEXT NOT NULL,
      tipo TEXT NOT NULL,
      caminho TEXT NOT NULL,
      nome_original TEXT,
      criado_em TEXT NOT NULL,
      FOREIGN KEY (pedido_id) REFERENCES pedidos(id) ON DELETE CASCADE
    );
  ''');

  raw.execute('CREATE INDEX IF NOT EXISTS idx_pedidos_status_pgto ON pedidos(status_pagamento);');
  raw.execute('CREATE INDEX IF NOT EXISTS idx_pedidos_data_entrega ON pedidos(data_entrega_combinada);');
}

// ── 003 — seed da tabela de preços (extraído da aba PREÇOS 2026) ──────────

void _migration003SeedTabelaPreco(Database raw) {
  // Matriz simplificada baseada na tabela de referência 2026.
  // Usuário pode editar depois na tela de orçamento.
  // Estrutura: tecnica × regiao × faixa_qtd → (1ª cor, demais cores).
  final seed = <List<Object>>[
    // HIDRO (base d'água) — FRENTE/COSTAS
    ['HIDRO', 'FRENTE/COSTAS', '12-24', 15.0, 3.0],
    ['HIDRO', 'FRENTE/COSTAS', '25-50', 12.0, 2.5],
    ['HIDRO', 'FRENTE/COSTAS', '51-100', 10.0, 2.0],
    ['HIDRO', 'FRENTE/COSTAS', '100+', 8.0, 1.5],
    // HIDRO — BOTTOM/NUCA
    ['HIDRO', 'BOTTOM/NUCA', '12-24', 9.0, 2.0],
    ['HIDRO', 'BOTTOM/NUCA', '25-50', 7.0, 1.5],
    ['HIDRO', 'BOTTOM/NUCA', '51-100', 6.0, 1.0],
    ['HIDRO', 'BOTTOM/NUCA', '100+', 5.0, 1.0],
    // ELASTIC
    ['ELASTIC', 'FRENTE/COSTAS', '12-24', 18.0, 4.0],
    ['ELASTIC', 'FRENTE/COSTAS', '25-50', 15.0, 3.5],
    ['ELASTIC', 'FRENTE/COSTAS', '51-100', 12.0, 3.0],
    ['ELASTIC', 'FRENTE/COSTAS', '100+', 10.0, 2.5],
    ['ELASTIC', 'BOTTOM/NUCA', '12-24', 11.0, 2.5],
    ['ELASTIC', 'BOTTOM/NUCA', '25-50', 9.0, 2.0],
    ['ELASTIC', 'BOTTOM/NUCA', '51-100', 7.0, 1.5],
    ['ELASTIC', 'BOTTOM/NUCA', '100+', 6.0, 1.5],
    // PLASTISOL GEL
    ['PLASTISOL GEL', 'FRENTE/COSTAS', '12-24', 20.0, 4.5],
    ['PLASTISOL GEL', 'FRENTE/COSTAS', '25-50', 16.0, 4.0],
    ['PLASTISOL GEL', 'FRENTE/COSTAS', '51-100', 13.0, 3.0],
    ['PLASTISOL GEL', 'FRENTE/COSTAS', '100+', 11.0, 2.5],
    ['PLASTISOL GEL', 'BOTTOM/NUCA', '12-24', 12.0, 3.0],
    ['PLASTISOL GEL', 'BOTTOM/NUCA', '25-50', 10.0, 2.5],
    ['PLASTISOL GEL', 'BOTTOM/NUCA', '51-100', 8.0, 2.0],
    ['PLASTISOL GEL', 'BOTTOM/NUCA', '100+', 7.0, 1.5],
    // RELEVO / SILICON
    ['RELEVO/SILICON', 'FRENTE/COSTAS', '12-24', 22.0, 5.0],
    ['RELEVO/SILICON', 'FRENTE/COSTAS', '25-50', 18.0, 4.0],
    ['RELEVO/SILICON', 'FRENTE/COSTAS', '51-100', 14.0, 3.5],
    ['RELEVO/SILICON', 'FRENTE/COSTAS', '100+', 12.0, 3.0],
    ['RELEVO/SILICON', 'BOTTOM/NUCA', '12-24', 13.0, 3.5],
    ['RELEVO/SILICON', 'BOTTOM/NUCA', '25-50', 11.0, 3.0],
    ['RELEVO/SILICON', 'BOTTOM/NUCA', '51-100', 9.0, 2.5],
    ['RELEVO/SILICON', 'BOTTOM/NUCA', '100+', 8.0, 2.0],
  ];

  final stmt = raw.prepare(
    'INSERT OR IGNORE INTO tabela_preco (id, tecnica, regiao, faixa_qtd, primeira_cor, demais_cores) VALUES (?,?,?,?,?,?)',
  );
  var idx = 0;
  for (final row in seed) {
    idx++;
    stmt.execute([
      'tp_${idx.toString().padLeft(3, '0')}',
      row[0],
      row[1],
      row[2],
      row[3],
      row[4],
    ]);
  }
  stmt.dispose();
}

// ── 004 — ciclos de fechamento por cliente (faturamento) ─────────────────

void _migration004Fechamentos(Database raw) {
  // Colunas novas em clientes
  const colunasClientes = <List<String>>[
    ['fechamento_tipo', 'TEXT'],        // 'semanal', 'quinzenal', 'mensal', 'data_fixa'
    ['fechamento_dia', 'INTEGER'],      // semanal: 1-7, mensal: 1-31
    ['fechamento_data_fixa', 'TEXT'],   // ISO date para tipo data_fixa
    ['fechamento_ativo', 'INTEGER NOT NULL DEFAULT 0'], // 0/1
  ];
  for (final c in colunasClientes) {
    raw.execute('ALTER TABLE clientes ADD COLUMN ${c[0]} ${c[1]};');
  }

  // Coluna novo em pedidos
  raw.execute('ALTER TABLE pedidos ADD COLUMN fechamento_id TEXT;');

  // Tabela de fechamentos
  raw.execute('''
    CREATE TABLE IF NOT EXISTS cliente_fechamentos (
      id TEXT PRIMARY KEY,
      cliente_id TEXT NOT NULL,
      numero INTEGER NOT NULL,
      data_abertura TEXT NOT NULL,
      data_fechamento_prevista TEXT NOT NULL,
      data_fechamento_real TEXT,
      status TEXT NOT NULL DEFAULT 'aberto',
      total_pedidos INTEGER NOT NULL DEFAULT 0,
      valor_total REAL NOT NULL DEFAULT 0,
      valor_pago REAL NOT NULL DEFAULT 0,
      observacao TEXT,
      criado_em TEXT NOT NULL,
      atualizado_em TEXT NOT NULL,
      FOREIGN KEY (cliente_id) REFERENCES clientes(id) ON DELETE CASCADE
    );
  ''');
  raw.execute('CREATE INDEX IF NOT EXISTS idx_fech_cliente ON cliente_fechamentos(cliente_id);');
  raw.execute('CREATE INDEX IF NOT EXISTS idx_fech_status ON cliente_fechamentos(status);');
  raw.execute('CREATE INDEX IF NOT EXISTS idx_fech_data ON cliente_fechamentos(data_fechamento_prevista);');
  raw.execute('CREATE INDEX IF NOT EXISTS idx_pedidos_fechamento ON pedidos(fechamento_id);');
}

void _migration005RegiaoTipoPeca(Database raw) {
  raw.execute('ALTER TABLE pedidos ADD COLUMN regiao TEXT;');
  raw.execute('ALTER TABLE pedidos ADD COLUMN tipo_peca TEXT;');
}

// ── 006 — preços oficiais 2026 (extraídos da planilha PRE�OS) ─────────────
//
// Os valores seedados em 003 eram aproximados e divergiam da tabela oficial.
// Esta migration substitui a tabela inteira pelos valores reais usados no
// dia-a-dia pela Baray. RELEVO/SILICON não tem coluna "demais cores" na
// planilha — adotamos `demais = 1ª cor` (cobra-se cada cor pelo mesmo preço).
void _migration006PrecosOficiais2026(Database raw) {
  raw.execute('DELETE FROM tabela_preco;');

  final seed = <List<Object>>[
    // HIDRO — FRENTE/COSTAS
    ['HIDRO', 'FRENTE/COSTAS', '12-24', 4.90, 2.45],
    ['HIDRO', 'FRENTE/COSTAS', '25-50', 3.70, 1.85],
    ['HIDRO', 'FRENTE/COSTAS', '51-100', 3.00, 1.50],
    ['HIDRO', 'FRENTE/COSTAS', '100+', 2.40, 1.20],
    // HIDRO — BOTTOM/NUCA
    ['HIDRO', 'BOTTOM/NUCA', '12-24', 3.90, 1.95],
    ['HIDRO', 'BOTTOM/NUCA', '25-50', 2.70, 1.35],
    ['HIDRO', 'BOTTOM/NUCA', '51-100', 2.00, 1.00],
    ['HIDRO', 'BOTTOM/NUCA', '100+', 1.60, 0.80],

    // ELASTIC — FRENTE/COSTAS
    ['ELASTIC', 'FRENTE/COSTAS', '12-24', 5.40, 2.70],
    ['ELASTIC', 'FRENTE/COSTAS', '25-50', 4.20, 1.85],
    ['ELASTIC', 'FRENTE/COSTAS', '51-100', 3.50, 1.75],
    ['ELASTIC', 'FRENTE/COSTAS', '100+', 2.70, 1.20],
    // ELASTIC — BOTTOM/NUCA
    ['ELASTIC', 'BOTTOM/NUCA', '12-24', 4.40, 2.20],
    ['ELASTIC', 'BOTTOM/NUCA', '25-50', 3.20, 1.60],
    ['ELASTIC', 'BOTTOM/NUCA', '51-100', 2.50, 1.20],
    ['ELASTIC', 'BOTTOM/NUCA', '100+', 2.10, 1.05],

    // PLASTISOL GEL — FRENTE/COSTAS
    ['PLASTISOL GEL', 'FRENTE/COSTAS', '12-24', 5.90, 3.90],
    ['PLASTISOL GEL', 'FRENTE/COSTAS', '25-50', 4.70, 2.80],
    ['PLASTISOL GEL', 'FRENTE/COSTAS', '51-100', 4.00, 2.00],
    ['PLASTISOL GEL', 'FRENTE/COSTAS', '100+', 3.40, 1.70],
    // PLASTISOL GEL — BOTTOM/NUCA
    ['PLASTISOL GEL', 'BOTTOM/NUCA', '12-24', 5.40, 3.40],
    ['PLASTISOL GEL', 'BOTTOM/NUCA', '25-50', 4.20, 2.30],
    ['PLASTISOL GEL', 'BOTTOM/NUCA', '51-100', 3.50, 1.75],
    ['PLASTISOL GEL', 'BOTTOM/NUCA', '100+', 2.60, 1.30],

    // RELEVO/SILICON — só tem coluna 1ª cor na planilha; demais = 1ª.
    ['RELEVO/SILICON', 'FRENTE/COSTAS', '12-24', 8.00, 8.00],
    ['RELEVO/SILICON', 'FRENTE/COSTAS', '25-50', 6.75, 6.75],
    ['RELEVO/SILICON', 'FRENTE/COSTAS', '51-100', 5.75, 5.75],
    ['RELEVO/SILICON', 'FRENTE/COSTAS', '100+', 5.00, 5.00],
    ['RELEVO/SILICON', 'BOTTOM/NUCA', '12-24', 7.10, 7.10],
    ['RELEVO/SILICON', 'BOTTOM/NUCA', '25-50', 6.25, 6.25],
    ['RELEVO/SILICON', 'BOTTOM/NUCA', '51-100', 5.25, 5.25],
    ['RELEVO/SILICON', 'BOTTOM/NUCA', '100+', 4.50, 4.50],

    // CROMIA — FRENTE/COSTAS (cor única, demais = 1ª)
    ['CROMIA', 'FRENTE/COSTAS', '12-24', 12.25, 12.25],
    ['CROMIA', 'FRENTE/COSTAS', '25-50', 9.25, 9.25],
    ['CROMIA', 'FRENTE/COSTAS', '51-100', 7.50, 7.50],
    ['CROMIA', 'FRENTE/COSTAS', '100+', 6.00, 6.00],
    // CROMIA — BOTTOM/NUCA
    ['CROMIA', 'BOTTOM/NUCA', '12-24', 9.75, 9.75],
    ['CROMIA', 'BOTTOM/NUCA', '25-50', 6.75, 6.75],
    ['CROMIA', 'BOTTOM/NUCA', '51-100', 5.00, 5.00],
    ['CROMIA', 'BOTTOM/NUCA', '100+', 4.00, 4.00],
  ];

  final stmt = raw.prepare(
    'INSERT INTO tabela_preco (id, tecnica, regiao, faixa_qtd, primeira_cor, demais_cores) VALUES (?,?,?,?,?,?)',
  );
  var idx = 0;
  for (final row in seed) {
    idx++;
    stmt.execute([
      'tp_${idx.toString().padLeft(3, '0')}',
      row[0],
      row[1],
      row[2],
      row[3],
      row[4],
    ]);
  }
  stmt.dispose();
}
