import 'dart:convert';

import 'package:empresa_server/routes/configuracoes.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

// Helpers ────────────────────────────────────────────────────────────────────

Future<Response> _put(Handler handler, String path, Map<String, dynamic> body) async {
  return await handler(Request(
    'PUT',
    Uri.parse('http://localhost$path'),
    body: jsonEncode(body),
    headers: {'content-type': 'application/json'},
  ));
}

Future<Map<String, dynamic>?> _decode(Response r) async {
  final s = await r.readAsString();
  if (s.isEmpty) return null;
  return jsonDecode(s) as Map<String, dynamic>;
}

void main() {
  group('A-02: PUT /configuracoes/<chave> allowlist', () {
    late ({void Function() cleanup}) tmp;
    late dynamic db;
    late Handler handler;

    setUp(() {
      final f = novoDb();
      tmp = (cleanup: f.cleanup);
      db = f.db;
      handler = configuracoesRouter(db).call;
    });

    tearDown(() => tmp.cleanup());

    test('chave NA allowlist (taxa_urgencia_pct) passa e persiste', () async {
      final resp = await _put(handler, '/taxa_urgencia_pct', {'valor': '30'});
      expect(resp.statusCode, 200, reason: 'taxa_urgencia_pct é editável');
      final body = await _decode(resp);
      expect(body?['chave'], 'taxa_urgencia_pct');
      expect(body?['valor'], '30');

      final row = db.raw.select(
        'SELECT valor FROM configuracoes WHERE chave=?',
        ['taxa_urgencia_pct'],
      ).first;
      expect(row['valor'], '30');
    });

    test('proximo_lote é rejeitado (não editável via PUT)', () async {
      final resp = await _put(handler, '/proximo_lote', {'valor': '0'});
      expect(resp.statusCode, anyOf(400, 403),
          reason: 'proximo_lote nunca pode ser editado pela API');
      final body = await _decode(resp);
      expect(body?['error'], isNotNull);

      // E o valor original permanece intacto.
      final row = db.raw.select(
        "SELECT valor FROM configuracoes WHERE chave='proximo_lote'",
      ).first;
      expect(row['valor'], '100',
          reason: 'proximo_lote seedado em 100 não pode ter sido alterado');
    });

    test('chave fora da allowlist (inventada) rejeita com 400/403', () async {
      final resp = await _put(handler, '/chave_inexistente_xpto', {'valor': '1'});
      expect(resp.statusCode, anyOf(400, 403),
          reason: 'chave fora do whitelist não deve sequer alcançar UPDATE');
      final body = await _decode(resp);
      expect(body?['error'], isNotNull);
    });

    test('todas as 13 chaves seedadas (exceto proximo_lote) são editáveis',
        () async {
      // Cruza com defaults seedados em db.dart:209-223. Se alguém mexer no
      // seed, este teste avisa.
      const editaveis = <String>{
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
      for (final chave in editaveis) {
        final resp = await _put(handler, '/$chave', {'valor': 'X'});
        expect(resp.statusCode, 200,
            reason: '$chave deveria estar na allowlist e aceitar PUT');
      }
    });
  });
}
