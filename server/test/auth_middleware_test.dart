import 'dart:convert';

import 'package:empresa_server/auth_middleware.dart';
import 'package:empresa_server/rate_limiter.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

Response _ok(Request _) => Response.ok('ok');

Request _req({
  required String ip,
  String? token,
  String path = 'pedidos',
}) {
  return Request(
    'GET',
    Uri.parse('http://x/$path'),
    headers: {
      if (token != null) 'x-api-key': token,
      // Simula o connection_info que shelf_io injetaria.
      'x-forwarded-for': ip,
    },
  );
}

void main() {
  group('constantTimeEquals (A-03)', () {
    test('tokens iguais retornam true', () {
      const token = 'abc123XYZ_token-completo-256bit-fake';
      expect(constantTimeEquals(token, token), isTrue);
      expect(
        constantTimeEquals('mesmo-conteudo', 'mesmo-conteudo'),
        isTrue,
      );
    });

    test('tokens diferentes do mesmo tamanho retornam false', () {
      expect(
        constantTimeEquals('abcdefghij', 'abcdefghiX'),
        isFalse,
      );
      expect(
        constantTimeEquals('Xbcdefghij', 'abcdefghij'),
        isFalse,
      );
    });

    test('tokens de tamanhos diferentes retornam false', () {
      expect(constantTimeEquals('abc', 'abcd'), isFalse);
      expect(constantTimeEquals('abcd', 'abc'), isFalse);
      expect(constantTimeEquals('', 'a'), isFalse);
    });

    test('strings vazias iguais retornam true', () {
      expect(constantTimeEquals('', ''), isTrue);
    });
  });

  group('apiKeyAuth + rateLimiter (M-08)', () {
    test('token válido passa e não consome orçamento', () async {
      var now = DateTime.utc(2026, 1, 1, 12, 0, 0);
      final limiter = RateLimiter(
        maxFailures: 3,
        window: const Duration(seconds: 60),
        clock: () => now,
      );
      final handler = apiKeyAuth('correct', rateLimiter: limiter)(_ok);

      for (var i = 0; i < 10; i++) {
        final res = await handler(_req(ip: '10.0.0.1', token: 'correct'));
        expect(res.statusCode, 200);
      }
      // Mesmo após 10 requests legítimos, o IP não foi rastreado.
      expect(limiter.shouldBlock('10.0.0.1'), isFalse);
    });

    test('N falhas mesmo IP — após threshold retorna 429 com Retry-After',
        () async {
      var now = DateTime.utc(2026, 1, 1, 12, 0, 0);
      final limiter = RateLimiter(
        maxFailures: 5,
        window: const Duration(seconds: 60),
        clock: () => now,
      );
      final handler = apiKeyAuth('correct', rateLimiter: limiter)(_ok);

      // 5 falhas — todas 401, contam orçamento.
      for (var i = 0; i < 5; i++) {
        final res = await handler(_req(ip: '10.0.0.1', token: 'wrong'));
        expect(res.statusCode, 401);
      }
      // 6ª request — mesmo com token válido seria bloqueada (defesa).
      final blocked = await handler(_req(ip: '10.0.0.1', token: 'correct'));
      expect(blocked.statusCode, 429);
      expect(blocked.headers['Retry-After'], isNotNull);
      expect(int.parse(blocked.headers['Retry-After']!),
          inInclusiveRange(1, 60));
      final body = jsonDecode(await blocked.readAsString())
          as Map<String, dynamic>;
      expect(body['error'], 'tentativas em excesso');
      expect(body['retry_after'], isA<int>());
    });

    test('IPs diferentes são isolados — A bloqueado não afeta B', () async {
      var now = DateTime.utc(2026, 1, 1, 12, 0, 0);
      final limiter = RateLimiter(
        maxFailures: 3,
        window: const Duration(seconds: 60),
        clock: () => now,
      );
      final handler = apiKeyAuth('correct', rateLimiter: limiter)(_ok);

      // A estoura.
      for (var i = 0; i < 3; i++) {
        await handler(_req(ip: '10.0.0.1', token: 'wrong'));
      }
      final blockedA = await handler(_req(ip: '10.0.0.1', token: 'correct'));
      expect(blockedA.statusCode, 429);

      // B passa normalmente com token válido.
      final okB = await handler(_req(ip: '10.0.0.2', token: 'correct'));
      expect(okB.statusCode, 200);
    });

    test('após janela expirar, IP volta a poder tentar', () async {
      var now = DateTime.utc(2026, 1, 1, 12, 0, 0);
      final limiter = RateLimiter(
        maxFailures: 3,
        window: const Duration(seconds: 60),
        clock: () => now,
      );
      final handler = apiKeyAuth('correct', rateLimiter: limiter)(_ok);

      for (var i = 0; i < 3; i++) {
        await handler(_req(ip: '10.0.0.1', token: 'wrong'));
      }
      // Confirma bloqueado.
      final r1 = await handler(_req(ip: '10.0.0.1', token: 'correct'));
      expect(r1.statusCode, 429);

      // Avança o relógio.
      now = now.add(const Duration(seconds: 61));
      final r2 = await handler(_req(ip: '10.0.0.1', token: 'correct'));
      expect(r2.statusCode, 200);
    });

    test('sem rateLimiter (compatibilidade) — 401 segue para sempre',
        () async {
      final handler = apiKeyAuth('correct')(_ok);
      for (var i = 0; i < 20; i++) {
        final res = await handler(_req(ip: '10.0.0.1', token: 'wrong'));
        expect(res.statusCode, 401);
      }
    });

    test('preflight OPTIONS e /health não passam pelo rate limit',
        () async {
      final limiter = RateLimiter(
        maxFailures: 1,
        window: const Duration(seconds: 60),
      );
      final handler = apiKeyAuth('correct', rateLimiter: limiter)(_ok);

      // OPTIONS bypass.
      final opt = await handler(Request('OPTIONS', Uri.parse('http://x/x')));
      expect(opt.statusCode, 200);

      // /health bypass — mesmo sem token.
      final health = await handler(Request('GET', Uri.parse('http://x/health')));
      expect(health.statusCode, 200);

      // Confirma que o limiter está zerado (essas rotas não tocaram).
      expect(limiter.trackedIps, 0);
    });
  });

  group('clientIpFromRequest (M-08)', () {
    test('X-Forwarded-For tem prioridade', () {
      final req = Request(
        'GET',
        Uri.parse('http://x/x'),
        headers: {'x-forwarded-for': '203.0.113.5, 10.0.0.1'},
      );
      expect(clientIpFromRequest(req), '203.0.113.5');
    });

    test('fallback "unknown" quando não há header nem connection_info', () {
      final req = Request('GET', Uri.parse('http://x/x'));
      expect(clientIpFromRequest(req), 'unknown');
    });

    test('X-Forwarded-For vazio cai para fallback', () {
      final req = Request(
        'GET',
        Uri.parse('http://x/x'),
        headers: {'x-forwarded-for': '   '},
      );
      expect(clientIpFromRequest(req), 'unknown');
    });
  });
}
