import 'dart:collection';

/// Sliding-window rate limiter contra brute-force de autenticação (M-08).
///
/// Conta **falhas** por IP nos últimos [window] segundos. Quando o número de
/// falhas atinge [maxFailures], todas as requisições do IP são rejeitadas até
/// que a janela deslize e a falha mais antiga expire.
///
/// Apenas falhas contam — requests bem-sucedidos não consomem orçamento.
/// Cleanup é lazy (a cada chamada de [shouldBlock] / [recordFailure] o IP
/// alvo tem suas entradas antigas dropadas). Um cap global [maxTrackedIps]
/// limita o uso de memória contra atacante que muda IP a cada request.
///
/// Não é persistente: o estado é in-memory, reset no restart. Para single-
/// instance + LAN, é suficiente (ver M-08 no AUDIT.md).
///
/// Algoritmo:
///   * `recordFailure(ip)` → push timestamp atual no deque do IP.
///   * `shouldBlock(ip)` → drop entries com idade > window; bloqueia se
///     `length >= maxFailures`.
///   * `retryAfter(ip)` → segundos até a falha mais antiga sair da janela.
///
/// Sliding window foi escolhido sobre token bucket porque o requisito do
/// finding é literal — "N falhas em M segundos" — e sliding-window expressa
/// isso diretamente, sem precisar reconciliar taxa média vs burst.
class RateLimiter {
  RateLimiter({
    this.maxFailures = 5,
    this.window = const Duration(seconds: 60),
    this.maxTrackedIps = 10000,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  /// Quantidade de falhas dentro da janela que dispara o bloqueio.
  final int maxFailures;

  /// Tamanho da janela deslizante.
  final Duration window;

  /// Cap global de IPs distintos rastreados. Quando excedido, o IP mais antigo
  /// (LRU pela ordem de inserção do LinkedHashMap) é removido. Defesa contra
  /// atacante que rotaciona IPs pra consumir memória do server.
  final int maxTrackedIps;

  final DateTime Function() _now;

  // LinkedHashMap preserva ordem de inserção, que aproxima LRU (cada acesso
  // refaz a inserção, então o head é "menos recentemente tocado").
  final LinkedHashMap<String, Queue<DateTime>> _failures =
      LinkedHashMap<String, Queue<DateTime>>();

  /// Registra uma falha de autenticação vinda de [ip].
  void recordFailure(String ip) {
    final now = _now();
    final queue = _touch(ip);
    queue.addLast(now);
    _prune(queue, now);
  }

  /// Verifica se o IP deve ser bloqueado (já atingiu o limite na janela).
  /// Não consome orçamento — pode ser chamado antes ou depois do auth.
  bool shouldBlock(String ip) {
    final queue = _failures[ip];
    if (queue == null) return false;
    _prune(queue, _now());
    if (queue.isEmpty) {
      _failures.remove(ip);
      return false;
    }
    return queue.length >= maxFailures;
  }

  /// Segundos até o IP poder tentar de novo. Retorna `1` no mínimo (Retry-
  /// After com `0` é semanticamente ambíguo — "tenta agora" volta a 429 já).
  /// Retorna 0 se o IP não está bloqueado no momento da chamada.
  int retryAfterSeconds(String ip) {
    final queue = _failures[ip];
    if (queue == null || queue.isEmpty) return 0;
    final oldest = queue.first;
    final expiresAt = oldest.add(window);
    final remaining = expiresAt.difference(_now()).inSeconds;
    return remaining < 1 ? 1 : remaining;
  }

  /// Apaga todo o estado. Útil em testes.
  void reset() => _failures.clear();

  /// Número de IPs atualmente rastreados (não filtra entradas vazias —
  /// pruning é lazy). Exposto para inspeção em testes.
  int get trackedIps => _failures.length;

  Queue<DateTime> _touch(String ip) {
    final existing = _failures.remove(ip);
    final queue = existing ?? Queue<DateTime>();
    _failures[ip] = queue;
    if (_failures.length > maxTrackedIps) {
      // Drop o IP menos recentemente tocado (head do LinkedHashMap).
      _failures.remove(_failures.keys.first);
    }
    return queue;
  }

  void _prune(Queue<DateTime> queue, DateTime now) {
    final cutoff = now.subtract(window);
    while (queue.isNotEmpty && queue.first.isBefore(cutoff)) {
      queue.removeFirst();
    }
  }
}
