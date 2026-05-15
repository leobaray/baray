import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../calculadora_orcamento.dart';
import '../db.dart';
import '../models/item_preco.dart';

Router orcamentoRouter(Db db) {
  final r = Router();
  final calc = CalculadoraOrcamento(db);

  Response json(Object? body, {int status = 200}) => Response(
        status,
        body: jsonEncode(body),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  r.get('/tabela', (Request req) {
    final rows = db.raw.select(
      'SELECT id, tecnica, regiao, faixa_qtd, primeira_cor, demais_cores '
      'FROM tabela_preco ORDER BY tecnica, regiao, faixa_qtd',
    );
    return json(rows.map((row) => ItemPreco.fromRow(row).toJson()).toList());
  });

  r.get('/tecnicas', (Request req) {
    final rows = db.raw.select('SELECT DISTINCT tecnica FROM tabela_preco ORDER BY tecnica');
    return json(rows.map((r) => r['tecnica']).toList());
  });

  // M-01: regiões dinâmicas a partir da tabela_preco (não mais hardcoded no app).
  r.get('/regioes', (Request req) {
    final rows = db.raw.select('SELECT DISTINCT regiao FROM tabela_preco ORDER BY regiao');
    return json(rows.map((r) => r['regiao']).toList());
  });

  r.post('/calcular', (Request req) async {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return json({'error': 'body inválido'}, status: 400);
    }
    final tecnica = body['tecnica'] as String?;
    final regiao = body['regiao'] as String?;
    final quantidade = body['quantidade'] as int?;
    final cores = (body['cores'] as int?) ?? 1;
    final urgente = body['urgente'] == true;
    final tipoPeca = body['tipo_peca'] as String?;

    if (tecnica == null || regiao == null || quantidade == null) {
      return json({'error': 'tecnica, regiao e quantidade são obrigatórios'}, status: 400);
    }
    if (quantidade <= 0) {
      return json({'error': 'quantidade deve ser maior que 0'}, status: 400);
    }
    if (cores < 1 || cores > 10) {
      return json({'error': 'cores deve estar entre 1 e 10'}, status: 400);
    }

    final resultado = calc.calcular(
      tecnica: tecnica,
      regiao: regiao,
      quantidade: quantidade,
      cores: cores,
      urgente: urgente,
      tipoPeca: tipoPeca,
    );
    if (resultado['erro'] != null) {
      return json(resultado, status: 404);
    }
    return json(resultado);
  });

  return r;
}
