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
        env['DERIVA_TEST_HOSTNAME'], env['DERIVA_TEST_CATALOG'],
        credential: format_credential(token: env['DERIVA_TEST_CREDENTIAL'])
      );
    });

    test('Get schema resource', () async {
      Map<String, dynamic> schema = await client.get('/schema');
      expect(schema.containsKey('schemas'), true);
    });

    test('Get resource', () async {
      List<dynamic> datasets = await client.get('/entity/isa:dataset?limit=1');
      expect(datasets[0].containsKey('title'), true);
    });

    test('Insert, update, and delete resource', () async {
      // insert
      List<dynamic> entities = [{'title': 'a new dataset', 'project': 311}];
      entities = await client.post('/entity/isa:dataset?defaults=id,accession,released', data: entities);
      expect(entities[0].containsKey('RID'), true);
      expect(entities[0]['title'], 'a new dataset');
      String rid = entities[0]['RID'];

      // update
      entities[0]['title'] = 'an updated dataset';
      entities = await client.put('/entity/isa:dataset', data: entities);
      expect(entities[0]['title'], 'an updated dataset');

      // delete
      var response = await client.delete('/entity/isa:dataset/RID=${rid}');
      expect(response, '');
    });

    test('Query data', () async {
      List<dynamic> datasets = await client.query('/entity/isa:dataset?limit=1');
      expect(datasets[0].containsKey('title'), true);
    });

    test('Create, update, and delete entities', () async {
      var schemaName = 'isa';
      var tableName = 'dataset';

      // insert
      List<dynamic> entities = [{'title': 'a new dataset', 'project': 311}];
      entities = await client.createEntities(schemaName, tableName, entities,
          defaults: {'id', 'accession', 'released'});
      expect(entities[0].containsKey('RID'), true);
      expect(entities[0]['title'], 'a new dataset');

      // update
      entities[0]['title'] = 'an updated dataset';
      entities = await client.updateEntities(schemaName, tableName, entities, targets: {'title'});
      expect(entities[0]['title'], 'an updated dataset');

      // delete
      var response = await client.delete('/entity/isa:dataset/RID=${entities[0]['RID']}');
      expect(response, '');
    });
  });
}
