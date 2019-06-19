import 'package:deriva/deriva.dart';

/// A simple usage example of the deriva library.
///
/// The main function expects [arguments] to include hostname, catalog, and
/// optional credential token.
main(List<String> arguments) async {
  print('Running example with arguments: ${arguments}');
  var hostname = arguments[0];
  var catalog_id = arguments[1];
  var credential = arguments.length > 2 ? format_credential(token: arguments[2]) : null;

  // Establish binding to the server
  var client = ERMrestClient(hostname, catalog_id, credential: credential);

  // Define identifiers for schema:table name
  String schema = 'isa';
  String table = 'dataset';

  try {
    // Get an entity resource
    var entities = await client.query('/entity/${schema}:${table}?limit=3');
    print("Queried entities: ${entities}");

    // Add a new entity (all post/puts are by lists of entities)
    entities = [{'title': 'a new dataset', 'project': 311}]; // these are required fields
    entities = await client.createEntities(schema, table, entities, defaults: {'id', 'accession', 'released'});
    print("Created entities: ${entities}");

    // Update the new entity
    entities[0]['title'] = 'an updated dataset';
    entities = await client.updateEntities(schema, table, entities, correlation: {'RID'}, targets: {'title'});
    print("Updated entities: ${entities}");

    // Delete the new/updated entity
    await client.delete('/entity/${schema}:${table}/RID=${entities[0]['RID']}');
    print('Deleted the new/updated entity');
  }
  catch (e) {
    print("Ooops: ${e}");
  }
  finally {
    // Close the client.
    client.close();
  }
}
