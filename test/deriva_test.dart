import 'dart:io';
import 'package:deriva/deriva.dart';
import 'package:test/test.dart';

void main() {
  group('Format credential tests', () {

    test('Username/password credential test', () {
      expect(
        format_credential(username: 'foo', password: 'bar'),
        {'username': 'foo', 'password': 'bar'}
      );
    });

    test('Token credential test', () {
      expect(
        format_credential(token: '1234567890'),
        {'cookie': 'webauthn=1234567890'}
      );
    });
  });

  group('ERMrest client tests', () {
    ERMrestClient client;

    setUp(() {
      Map<String, String> env = Platform.environment;
      client = ERMrestClient(
        env['DERIVA_TEST_HOSTNAME'], env['DERIVA_TEST_CATALOG']
      );
    });

    test('Get schema resource', () async {
      Map<String, dynamic> schema = await client.get('/schema');
      expect(schema.containsKey('schemas'), true);
    });

    test('Get dataset resource', () async {
      List<dynamic> datasets = await client.get('/entity/isa:dataset?limit=1');
      expect(datasets[0].containsKey('title'), true);
    });
  });
}
