import 'package:empresa_server/rate_limiter.dart';
import 'package:test/test.dart';

void main() {
  group('RateLimiter (M-08)', () {
    test('IP novo nunca está bloqueado', () {
      final limiter = RateLimiter();
      expect(limiter.shouldBlock('10.0.0.1'), isFalse);
      expect(limiter.retryAfterSeconds('10.0.0.1'), 0);
    });

    test('bloqueia após atingir maxFailures dentro da janela', () {
      var now = DateTime.utc(2026, 1, 1, 12, 0, 0);
      final limiter = RateLimiter(
        maxFailures: 5,
        window: const Duration(seconds: 60),
        clock: () => now,
      );

      const ip = '192.168.1.50';
      // 4 falhas — ainda não bloqueia.
      for (var i = 0; i < 4; i++) {
        limiter.recordFailure(ip);
        expect(limiter.shouldBlock(ip), isFalse,
            reason: 'falha $i não deveria bloquear');
      }

      // 5ª falha atinge o limite — bloqueado.
      limiter.recordFailure(ip);
      expect(limiter.shouldBlock(ip), isTrue);
      expect(limiter.retryAfterSeconds(ip), inInclusiveRange(1, 60));
    });

    test('IPs diferentes têm buckets independentes', () {
      var now = DateTime.utc(2026, 1, 1, 12, 0, 0);
      final limiter = RateLimiter(
        maxFailures: 3,
        window: const Duration(seconds: 60),
        clock: () => now,
      );

      const ipA = '10.0.0.1';
      const ipB = '10.0.0.2';

      // Estoura A.
      for (var i = 0; i < 3; i++) {
        limiter.recordFailure(ipA);
      }
      expect(limiter.shouldBlock(ipA), isTrue);
      // B continua livre.
      expect(limiter.shouldBlock(ipB), isFalse);
    });

    test('janela deslizante libera o IP depois que entries expiram', () {
      var now = DateTime.utc(2026, 1, 1, 12, 0, 0);
      final limiter = RateLimiter(
        maxFailures: 3,
        window: const Duration(seconds: 60),
        clock: () => now,
      );

      const ip = '10.0.0.1';
      for (var i = 0; i < 3; i++) {
        limiter.recordFailure(ip);
      }
      expect(limiter.shouldBlock(ip), isTrue);

      // Avança o relógio além da janela.
      now = now.add(const Duration(seconds: 61));
      expect(limiter.shouldBlock(ip), isFalse,
          reason: 'entries antigas devem ter expirado');
      expect(limiter.retryAfterSeconds(ip), 0);
    });

    test('retryAfterSeconds reflete o tempo até a falha mais antiga expirar',
        () {
      var now = DateTime.utc(2026, 1, 1, 12, 0, 0);
      final limiter = RateLimiter(
        maxFailures: 3,
        window: const Duration(seconds: 60),
        clock: () => now,
      );

      const ip = '10.0.0.1';
      limiter.recordFailure(ip); // t=0
      now = now.add(const Duration(seconds: 10));
      limiter.recordFailure(ip); // t=10
      now = now.add(const Duration(seconds: 10));
      limiter.recordFailure(ip); // t=20

      // Bloqueado. A falha mais antiga é em t=0, expira em t=60.
      // Agora estamos em t=20, então retry-after ~= 40.
      expect(limiter.shouldBlock(ip), isTrue);
      expect(limiter.retryAfterSeconds(ip), inInclusiveRange(39, 41));
    });

    test('retryAfterSeconds nunca retorna 0 enquanto bloqueado (mínimo 1)',
        () {
      var now = DateTime.utc(2026, 1, 1, 12, 0, 0);
      final limiter = RateLimiter(
        maxFailures: 2,
        window: const Duration(seconds: 60),
        clock: () => now,
      );

      const ip = '10.0.0.1';
      limiter.recordFailure(ip);
      limiter.recordFailure(ip);
      // Avança quase até o fim da janela.
      now = now.add(const Duration(seconds: 60));
      // No instante exato em que a entry expiraria, shouldBlock já libera.
      // O caso interessante é "quase no fim" — 59s adiantado.
      now = DateTime.utc(2026, 1, 1, 12, 0, 59);
      expect(limiter.retryAfterSeconds(ip), greaterThanOrEqualTo(1));
    });

    test('cap de IPs rastreados (LRU drop)', () {
      final limiter = RateLimiter(
        maxFailures: 5,
        maxTrackedIps: 3,
      );

      limiter.recordFailure('ip.A');
      limiter.recordFailure('ip.B');
      limiter.recordFailure('ip.C');
      expect(limiter.trackedIps, 3);

      // Inserção de um quarto IP deve ejetar o head (ip.A — menos
      // recentemente tocado).
      limiter.recordFailure('ip.D');
      expect(limiter.trackedIps, 3);
      // ip.A foi dropado — não conta mais falhas pra ele.
      expect(limiter.shouldBlock('ip.A'), isFalse);
    });

    test('reset() limpa todo o estado', () {
      final limiter = RateLimiter(maxFailures: 2);
      limiter.recordFailure('10.0.0.1');
      limiter.recordFailure('10.0.0.1');
      expect(limiter.shouldBlock('10.0.0.1'), isTrue);

      limiter.reset();
      expect(limiter.shouldBlock('10.0.0.1'), isFalse);
      expect(limiter.trackedIps, 0);
    });
  });
}
