// Test da migração de token C-02: API token sai de SharedPreferences (plaintext)
// e passa a viver em flutter_secure_storage (Keystore/Keychain).
//
// Cenários cobertos:
//  1. Token novo: secure storage vazio + SharedPreferences vazio → '' .
//  2. Token legacy: SharedPreferences tem token, secure vazio → migra,
//     secure passa a ter o valor, SharedPreferences passa a estar vazio.
//  3. Token já migrado: secure tem valor → não toca SharedPreferences,
//     retorna direto.
//  4. saveApiToken('foo') grava em secure e remove de SharedPreferences
//     mesmo que tenha sobrado lixo legado.
//  5. saveApiToken('') deleta a chave do secure storage.

import 'package:baray/api/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secureBackingStore;
  late FlutterSecureStorage previousStorage;

  setUp(() {
    secureBackingStore = <String, String>{};
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform(secureBackingStore);
    previousStorage = debugSetApiTokenStorage(const FlutterSecureStorage());
  });

  tearDown(() {
    debugSetApiTokenStorage(previousStorage);
  });

  group('loadApiToken — C-02 migration', () {
    test('sem token em nenhum storage retorna string vazia', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      expect(await loadApiToken(), '');
      expect(secureBackingStore[secureKeyApiToken], isNull);
    });

    test('token só no secure storage retorna direto sem tocar prefs', () async {
      secureBackingStore[secureKeyApiToken] = 'secure-token-xyz';
      SharedPreferences.setMockInitialValues(<String, Object>{
        prefsKeyApiToken: 'fantasma-nao-deveria-aparecer',
      });

      expect(await loadApiToken(), 'secure-token-xyz');

      // O caminho rápido NÃO migra/limpa nada — a chave legada continua lá.
      // Quem garante a limpeza é a próxima escrita via saveApiToken.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(prefsKeyApiToken), 'fantasma-nao-deveria-aparecer');
    });

    test('migration: token só em SharedPreferences move para secure e apaga legado', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        prefsKeyApiToken: 'token-legado-em-plaintext',
      });

      final result = await loadApiToken();
      expect(result, 'token-legado-em-plaintext');

      // Pós-condição: secure storage tem o valor.
      expect(secureBackingStore[secureKeyApiToken], 'token-legado-em-plaintext');

      // Pós-condição: SharedPreferences foi limpa para evitar o vazamento
      // permanente do plaintext.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(prefsKeyApiToken), isFalse);
    });

    test('migration ignora valor legado vazio (não escreve no secure)', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        prefsKeyApiToken: '',
      });

      expect(await loadApiToken(), '');
      expect(secureBackingStore[secureKeyApiToken], isNull);
    });
  });

  group('saveApiToken — C-02 storage swap', () {
    test('saveApiToken escreve no secure e limpa SharedPreferences legada', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        prefsKeyApiToken: 'resto-de-versao-antiga',
      });

      await saveApiToken('novo-token-seguro');

      expect(secureBackingStore[secureKeyApiToken], 'novo-token-seguro');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(prefsKeyApiToken), isFalse);
    });

    test('saveApiToken vazio deleta a chave do secure', () async {
      secureBackingStore[secureKeyApiToken] = 'sera-removido';
      SharedPreferences.setMockInitialValues(<String, Object>{});

      await saveApiToken('');

      expect(secureBackingStore.containsKey(secureKeyApiToken), isFalse);
    });
  });
}
