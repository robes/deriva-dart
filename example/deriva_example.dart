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
    List<dynamic> entities = await client.get('/entity/dataset?limit=10');
    for (var row in entities) {
      print(row);
    }
  }
  catch (e) {
    print(e);
  }

  // Close the client.
  client.close();
}
