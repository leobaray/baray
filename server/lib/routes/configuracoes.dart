import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db.dart';
import '../models/configuracao.dart';

/// Allowlist explícita de chaves que aceitam edição via `PUT /configuracoes/<chave>`.
///
/// `proximo_lote` é DELIBERADAMENTE omitido: ele é avançado automaticamente ao
/// criar pedidos (db.dart) e exposto só-leitura em `GET /configuracoes/proximo_lote`.
/// Permitir edição livre quebra a unicidade de lote (INSERT em `pedidos` viola
/// UNIQUE → HTTP 500) e foi o gatilho original do finding A-02 da auditoria.
///
/// Para introduzir uma nova chave editável: adicione aqui E ao seed em
/// `db.dart` (lista `defaults`). Mantém os dois lugares sincronizados.
const Set<String> chavesConfiguracaoEditaveis = {
  'limite_diario',
  'producao_sabado',
  'producao_domingo',
  'prazo_padrao_dias',
  'taxa_urgencia_pct',
  'adicional_moletom_aberto_pct',
  'adicional_moletom_fechado_pct',
  'matriz_gratis_acima_pcs',
  'matriz_padrao_40x50',
  'matriz_padrao_50x60',
  'lote_prefixo',
  'lote_digitos',
  'empresa_nome',
};

Router configuracoesRouter(Db db) {
  final r = Router();

  Response json(Object? body, {int status = 200}) => Response(
        status,
        body: jsonEncode(body),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  r.get('/', (Request req) {
    final rows = db.raw.select(
      'SELECT chave, valor, tipo, descricao, atualizado_em FROM configuracoes '
      "WHERE chave != 'proximo_lote' ORDER BY chave",
    );
    return json(rows.map((row) => Configuracao.fromRow(row).toJson()).toList());
  });

  // Contador do próximo lote — exposto separado porque é só-leitura pra UI
  // (admin não edita diretamente; ele avança automaticamente ao criar pedidos).
  r.get('/proximo_lote', (Request req) {
    final rows = db.raw.select("SELECT valor FROM configuracoes WHERE chave='proximo_lote'");
    if (rows.isEmpty) return json({'valor': null}, status: 404);
    return json({'valor': int.tryParse(rows.first['valor'] as String)});
  });

  r.get('/<chave>', (Request req, String chave) {
    final rows = db.raw.select(
      'SELECT chave, valor, tipo, descricao, atualizado_em FROM configuracoes WHERE chave = ?',
      [chave],
    );
    if (rows.isEmpty) return json({'error': 'chave não encontrada'}, status: 404);
    return json(Configuracao.fromRow(rows.first).toJson());
  });

  r.put('/<chave>', (Request req, String chave) async {
    // Allowlist primeiro (antes de tudo): chaves fora da lista são rejeitadas
    // independente de existirem no banco. `proximo_lote` cai aqui — é
    // intencionalmente só-leitura via PUT (avança automático em pedidos.dart).
    if (!chavesConfiguracaoEditaveis.contains(chave)) {
      return json(
        {'error': 'chave não editável', 'chave': chave},
        status: 403,
      );
    }

    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final valor = body['valor']?.toString();
    if (valor == null) return json({'error': 'valor é obrigatório'}, status: 400);

    final exists = db.raw.select('SELECT chave FROM configuracoes WHERE chave = ?', [chave]);
    if (exists.isEmpty) return json({'error': 'chave não encontrada'}, status: 404);

    db.raw.execute(
      'UPDATE configuracoes SET valor = ?, atualizado_em = ? WHERE chave = ?',
      [valor, DateTime.now().toUtc().toIso8601String(), chave],
    );

    final updated = db.raw.select(
      'SELECT chave, valor, tipo, descricao, atualizado_em FROM configuracoes WHERE chave = ?',
      [chave],
    ).first;
    return json(Configuracao.fromRow(updated).toJson());
  });

  return r;
}
