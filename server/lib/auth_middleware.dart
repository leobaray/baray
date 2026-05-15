import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart';

import 'logger.dart';

/// Token estático compartilhado, lido de:
/// 1. variável de ambiente `BARAY_API_TOKEN` (preferida);
/// 2. arquivo `api_token` ao lado do executável (fallback dev/oficina).
/// Se nenhum dos dois existir, gera um token aleatório e grava o arquivo.
String resolveApiToken() {
  final fromEnv = (Platform.environment['BARAY_API_TOKEN'] ?? '').trim();
  if (fromEnv.isNotEmpty) return fromEnv;

  final file = File('api_token');
  if (file.existsSync()) {
    final v = file.readAsStringSync().trim();
    if (v.isNotEmpty) return v;
  }

  final gen = _generateToken();
  file.writeAsStringSync(gen);
  authLog.warning(
    'API token gerado e gravado em ${file.absolute.path} — configure os apps com este valor',
  );
  return gen;
}

String _generateToken() {
  final rnd = Random.secure();
  final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

/// Comparação constant-time de dois tokens (defesa em profundidade contra
/// timing attacks — CWE-208). Não usa `==` porque a implementação de
/// `String.operator==` em Dart curto-circuita no primeiro mismatch, vazando
/// informação de prefixo correto via timing observável.
///
/// Length mismatch ainda é detectável (retornamos `false` cedo), mas o token
/// tem comprimento fixo aqui, então isso não é relevante na prática.
bool constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}

const Set<String> _publicPaths = {'/health'};

bool _isPreflight(Request req) => req.method == 'OPTIONS';

/// Middleware que rejeita qualquer request sem o header `X-API-Key` válido.
/// `/health` e preflights `OPTIONS` permanecem abertos (saúde precisa funcionar
/// para reverse proxies; preflight precisa de CORS aplicado depois).
Middleware apiKeyAuth(String expectedToken) {
  return (Handler inner) {
    return (Request req) async {
      if (_isPreflight(req)) return inner(req);
      final path = '/${req.url.path}';
      if (_publicPaths.contains(path)) return inner(req);

      final provided = req.headers['x-api-key'] ??
          req.headers['X-API-Key'] ??
          _stripBearer(req.headers['authorization']);
      if (provided == null ||
          provided.isEmpty ||
          !constantTimeEquals(provided, expectedToken)) {
        authLog.warning(
          'auth_fail method=${req.method} path=$path origin=${req.headers['origin'] ?? '-'}',
        );
        return Response(
          401,
          body: jsonEncode({'error': 'autenticação obrigatória'}),
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return inner(req);
    };
  };
}

String? _stripBearer(String? auth) {
  if (auth == null) return null;
  const prefix = 'Bearer ';
  if (auth.startsWith(prefix)) return auth.substring(prefix.length).trim();
  return auth.trim();
}
