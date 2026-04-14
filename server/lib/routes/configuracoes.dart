import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db.dart';
import '../models/configuracao.dart';

Router configuracoesRouter(Db db) {
  final r = Router();

  Response json(Object? body, {int status = 200}) => Response(
        status,
        body: jsonEncode(body),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  r.get('/', (Request req) {
    final rows = db.raw.select(
      "SELECT * FROM configuracoes WHERE chave != 'proximo_lote' ORDER BY chave",
    );
    return json(rows.map((row) => Configuracao.fromRow(row).toJson()).toList());
  });

  r.get('/<chave>', (Request req, String chave) {
    final rows = db.raw.select('SELECT * FROM configuracoes WHERE chave = ?', [chave]);
    if (rows.isEmpty) return json({'error': 'chave não encontrada'}, status: 404);
    return json(Configuracao.fromRow(rows.first).toJson());
  });

  r.put('/<chave>', (Request req, String chave) async {
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final valor = body['valor']?.toString();
    if (valor == null) return json({'error': 'valor é obrigatório'}, status: 400);

    final exists = db.raw.select('SELECT chave FROM configuracoes WHERE chave = ?', [chave]);
    if (exists.isEmpty) return json({'error': 'chave não encontrada'}, status: 404);

    db.raw.execute(
      'UPDATE configuracoes SET valor = ?, atualizado_em = ? WHERE chave = ?',
      [valor, DateTime.now().toIso8601String(), chave],
    );

    final updated = db.raw.select('SELECT * FROM configuracoes WHERE chave = ?', [chave]).first;
    return json(Configuracao.fromRow(updated).toJson());
  });

  return r;
}
