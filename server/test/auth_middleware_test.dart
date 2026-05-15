import 'package:empresa_server/auth_middleware.dart';
import 'package:test/test.dart';

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
}
