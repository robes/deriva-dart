Dart API for the DERIVA platform.

This library is an early prototype and is not yet ready for broad usage.

## Usage

A simple usage example:

```dart
import 'package:deriva/deriva.dart';

main() {
  // properties that will be needed to establish a client connection
  String hostname = 'localhost';
  String catalog_id = '1';
  String token = '12345678909';
  
  // create credential and client
  var credential = format_credential(token: token);
  var client = ERMrestClient(hostname, catalog_id, credential: credential);
  
  // query the catalog using ERMrest paths
  try {
    var data = client.query('/entity/dataset?limit=10');
    print(data);
  } catch (e) {
    print(e);
  } finally {
    // close the client connection, when finished
    client.close();
  }
}
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/robes/deriva-dart/issues
