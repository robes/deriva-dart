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

  try {
    // Get an entity resource
    var entities = await client.query('/entity/isa:dataset?limit=3');
    print("Queried entities: ${entities}");

    // Add a new dataset entity (all post/puts are by lists of entities)
    entities = [{'title': 'a new dataset', 'project': 311}]; // these are required fields
    entities = await client.createEntities('isa', 'dataset', entities, defaults: {'id', 'accession', 'released'});
    print("Created entities: ${entities}");

    // Update the new dataset entity
    entities[0]['title'] = 'an updated dataset';
    entities = await client.updateEntities('isa', 'dataset', entities, targets: {'title'});
    print("Updated entities: ${entities}");

    // Delete the new dataset entity
    await client.delete('/entity/isa:dataset/RID=${entities[0]['RID']}');
  }
  catch (e) {
    print("Ooops: ${e}");
  }
  finally {
    // Close the client.
    client.close();
  }
}
