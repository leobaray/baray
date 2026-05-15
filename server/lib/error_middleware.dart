import 'dart:convert';

import 'package:shelf/shelf.dart';

import 'logger.dart';

/// Middleware global de erro (M-03).
///
/// Captura qualquer exception não-tratada de handlers internos, loga
/// server-side com stack trace (via `appLog.severe`) e responde ao client
/// com `HTTP 500` e corpo JSON genérico `{"error":"internal_server_error"}`.
///
/// Não vaza classe da exception, mensagem ou path interno para o cliente.
/// Princípio canônico OWASP — Error Handling Cheat Sheet: "when an unexpected
/// error occurs then a generic response is returned by the application but
/// the error details are logged server side for investigation, and not
/// returned to the user."
///
/// `HijackException` é re-lançada intencionalmente: ela é sinal de controle
/// do shelf adapter para conexões hijacked (WebSocket etc.) e nunca deve ser
/// capturada por middleware.
Middleware errorHandler() {
  return (Handler inner) {
    return (Request req) async {
      try {
        return await inner(req);
      } on HijackException {
        rethrow;
      } catch (e, st) {
        appLog.severe(
          'uncaught ${req.method} ${req.requestedUri.path}',
          e,
          st,
        );
        return Response(
          500,
          body: jsonEncode({'error': 'internal_server_error'}),
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }
    };
  };
}
