Dart API for the DERIVA platform (preview).

This library is an early preview and is not yet ready for broad usage.

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
  
  // get a set of entity resources
  var data = client.get('/entity/dataset?limit=10');
  print(data);
  
  // close the client connection, when finished
  client.close();
}
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/robes/deriva-dart/issues
