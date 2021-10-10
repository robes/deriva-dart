import 'dart:convert' as convert;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_retry/http_retry.dart';

/// Retriable error codes in DERIVA.
///   -1: no connection
///    0: timeout
///  500: internal server error
///  503: service unavailable
Set<int> _retriableErrorCodes = {-1, 0, 500, 503};

/// Formats a Deriva client credential with either a [token] or a [username] and
/// [password].
///
/// Note that usage of [username] and [password] credentials are deprecated in
/// Deriva and users are strongly encouraged to upgrade their deployments to
/// use OAuth tokens.
Map<String, String> format_credential({String token, String username, String password}) {
  if (token != null) {
    return {"cookie": "webauthn=${token}"};
  }
  else if (username != null && password != null) {
    return {"username": username, "password": password};
  }
  throw ArgumentError('Missing required argument(s): an authentication token or a username and password must be provided.');
}


/// A generic Deriva service binding.
class DerivaBinding {

  /// The hostname of the Deriva server.
  String hostname;

  /// The client credential object.
  Map<String, String> credential;

  /// The internal state of the http client connection.
  http.Client _client;

  /// The http client connection.
  http.Client get client {
    _client = _client ?? RetryClient(
      http.Client(),
      retries: 5,
      when: ((response) => _retriableErrorCodes.contains(response.statusCode)),
      whenError: ((error, __) => error is SocketException || error.toString() == 'Connection closed before full header was received')
    );
    return _client;
  }

  /// Initializes a binding to a Deriva server at [hostname] with client
  /// [credential] (optional).
  DerivaBinding(this.hostname, {this.credential});

  /// Updates [headers] with the authorization header based on [credential].
  ///
  /// If necessary, will attempt to establish an authenticated session with the
  /// server.
  Future<Map<String, String>> _updateAuthorizationHeader(Map<String, String> headers) async {
    if (credential == null) {
      return null;
    }

    headers = headers != null ? headers : Map<String, String>();
    if (credential.containsKey('cookie')) {
      headers['cookie'] = credential['cookie'];
    }
    else if (credential.containsKey('bearer-token')) {
      headers['Authorization'] = "Bearer ${credential['bearer-token']}";
    }
    else if (credential.containsKey('username') && credential.containsKey('password')) {
      headers['cookie'] = credential['cookie'] = await _postAuthnSession();
    }
    else {
      throw ArgumentError('Credential does not contain correct keys');
    }

    return headers;
  }

  /// Attempts to establish an authenticated session with a Deriva server using
  /// the client [credential], which must include 'username' and 'password', and
  /// returns the server cookie token.
  Future<String> _postAuthnSession() async {
    // Post credential to the server
    var response = await client.post(Uri.parse('https://${this.hostname}/authn/session'), body: credential);
    if (response.statusCode != 200) {
      throw http.ClientException('Authentication Failure: ${response.body}');
    }

    // Get 'set-cookie' response header
    String set_cookie_response = response.headers['set-cookie'];
    if (set_cookie_response == null) {
      throw http.ClientException('Server did not send "set-cookie" response header.');
    }

    // Parse webauthn cookie from 'set-cookie' header
    String cookie = _parseWebauthnCookie(set_cookie_response);
    if (cookie == null) {
      throw http.ClientException('Invalid "set-cookie" response header sent from server.');
    }

    return cookie;
  }

  /// Parses the webauthn cookie from the 'set-cookie' response header value.
  String _parseWebauthnCookie(String message) {
    // This is a big kludgy but its simple and works reliably.
    const String WEBAUTHN_KEY = 'webauthn=';
    const int WEBAUTHN_KEY_LEN = WEBAUTHN_KEY.length;
    int start = message.indexOf(WEBAUTHN_KEY);
    if (start < 0) {
      return null;
    }
    else {
      start += WEBAUTHN_KEY_LEN;
      return WEBAUTHN_KEY + message.substring(start, message.indexOf(';', start));
    }
  }

  /// GETs the resource for [path] and returns the response body.
  Future<Object> get(String path, {Map<String, String> headers}) async {
    headers = await _updateAuthorizationHeader(headers);

    if (path == null || path == '') {
      throw ArgumentError("Invalid path: null or '' not allowed");
    }

    var response = await client.get(Uri.parse('https://${hostname}${path}'), headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException('Failed to get "${path}": ${response.body}');
    }
    return convert.utf8.decode(response.body.codeUnits);
  }

  /// POSTs [data] to the [path] and returns the response body.
  Future<Object> post(String path, {Object data, Map<String, String> headers}) async {
    headers = await _updateAuthorizationHeader(headers);

    var response = await client.post(Uri.parse('https://${hostname}${path}'), body: data, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException('Failed to post "${path}": ${response.body}');
    }
    return convert.utf8.decode(response.body.codeUnits);
  }

  /// PUTs [data] to the [path] and returns the response body.
  Future<Object> put(String path, {Object data, Map<String, String> headers}) async {
    headers = await _updateAuthorizationHeader(headers);

    var response = await client.put(Uri.parse('https://${hostname}${path}'), body: data, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException('Failed to post "${path}": ${response.body}');
    }
    return convert.utf8.decode(response.body.codeUnits);
  }

  /// Close the client connection.
  void close() {
    _client?.close();
    _client = null;
  }

  /// DELETEs the resource for [path].
  Future<Object> delete(String path, {Map<String, String> headers}) async {
    headers = await _updateAuthorizationHeader(headers);

    if (path == null || path == '') {
      throw ArgumentError("Invalid path: null or '' not allowed");
    }

    var response = await client.delete(Uri.parse('https://${hostname}${path}'), headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException('Failed to delete "${path}": ${response.body}');
    }
    return convert.utf8.decode(response.body.codeUnits);
  }
}


/// An ERMrest client binding.
class ERMrestClient extends DerivaBinding {

  /// The catalog identifier including snapshot (optional).
  String catalog;

  /// The system columns
  static const Set<String> _syscols = {'RID', 'RCB', 'RCT', 'RMB', 'RMT'};

  /// Initializes the ERMrest client binding to [hostname] and [catalog] with
  /// [credential].
  ERMrestClient(hostname, this.catalog, {credential}) : super(hostname, credential: credential);

  /// Updates the [headers] with the JSON content type and accept headers.
  Map<String, String> _updateContentTypeHeaders(Map<String, String> headers) {
    headers = headers != null ? headers : Map<String, String>();
    headers.addAll({'Content-Type': 'application/json', 'Accept': 'application/json'});
    return headers;
  }

  /// GETs the resource for [path] and returns JSON decoded response.
  Future<Object> get(String path, {Map<String, String> headers}) async {
    headers = _updateContentTypeHeaders(headers);
    var response = await super.get('/ermrest/catalog/${catalog}${path}', headers: headers);
    return convert.jsonDecode(response);
  }

  /// POSTs [data] to the [path] and returns JSON decoded response.
  Future<Object> post(String path, {Object data, Map<String, String> headers}) async {
    headers = _updateContentTypeHeaders(headers);
    String body = data != null ? convert.jsonEncode(data) : null;
    var response = await super.post('/ermrest/catalog/${catalog}${path}', data: body, headers: headers);
    return convert.jsonDecode(response);
  }

  /// PUTs [data] to the [path] and returns JSON decoded response.
  Future<Object> put(String path, {Object data, Map<String, String> headers}) async {
    headers = _updateContentTypeHeaders(headers);
    String body = data != null ? convert.jsonEncode(data) : null;
    var response = await super.put('/ermrest/catalog/${catalog}${path}', data: body, headers: headers);
    return convert.jsonDecode(response);
  }

  /// DELETEs the resource for [path].
  Future<Object> delete(String path, {Map<String, String> headers}) async {
    headers = _updateContentTypeHeaders(headers);
    return await super.delete('/ermrest/catalog/${catalog}${path}', headers: headers);
  }

  /// Queries the catalog data based on the given [path].
  Future<List<dynamic>> query(String path) async {
    return await get(path);
  }

  /// Creates [entities] in the [schemaName]:[tableName] table.
  ///
  /// Use [defaults] for columns that should be given a server-side generated
  /// default value. Use [nondefaults] to suppress server-side generated default
  /// values. By default, the ERMrest system columns will be added to the
  /// [deaults] set if not found in the [nondefaults] set, unless
  /// [addSystemDefaults] is `false`.
  Future<List<dynamic>> createEntities(
      String schemaName, String tableName, List<dynamic> entities,
      {Set<String> defaults=const {}, Set<String> nondefaults=const {}, addSystemDefaults=true}) async {

    // Base path string
    String path = '/entity/${Uri.encodeComponent(schemaName)}:${Uri.encodeComponent(tableName)}';

    // Defaults option
    List<String> options = [];
    if (defaults.isNotEmpty || addSystemDefaults) {
      defaults = Set<String>.from(defaults);
      if (addSystemDefaults) {
        defaults.addAll(_syscols.difference(nondefaults));
      }
      var defaultsEncoded = defaults.map((e) => Uri.encodeComponent(e)).join(',');
      options.add('defaults=${defaultsEncoded}');
    }

    // Nondefaults option
    if (nondefaults.isNotEmpty) {
      var nondefaultsEncoded = nondefaults.map((e) => Uri.encodeComponent(e)).join(',');
      options.add('nondefaults=${nondefaultsEncoded}');
    }

    // Append options to path, if any
    if (options.isNotEmpty) {
      path = '${path}?${options.join('&')}';
    }

    return await post(path, data: entities);
  }

  /// Updates [entities] in the [schemaName]:[tableName] table.
  ///
  /// Use [correlation] to specify the columns to use as the keys of the update,
  /// by default `{'RID'}`. Use [targets] to specify the columns to be updated
  /// in the matched rows, by default the keys in the first element in
  /// [entities] minus the system columns.
  Future<List<dynamic>> updateEntities(
      String schemaName, String tableName, List<dynamic> entities,
      {Set<String> correlation=const {'RID'}, Set<String> targets=const {}}) async {

    // Encode the correlation columns
    Set<String> correlationEnc = Set<String>.from(correlation.map((e) => Uri.encodeComponent(e)));

    // Initialize and encode the target columns
    Set<String> targetsEnc = {};
    if (targets.isNotEmpty) {
      targetsEnc = Set<String>.from(targets.map((e) => Uri.encodeComponent(e)));
    }
    else {
      var exclusionsEnc = correlationEnc.union(_syscols);
      var keysEnc = Set<String>.from(entities[0].keys.map((e) => Uri.encodeComponent(e)));
      targetsEnc = keysEnc.difference(exclusionsEnc);
    }

    // Path
    String path = '/attributegroup/${Uri.encodeComponent(schemaName)}:${Uri.encodeComponent(tableName)}';
    path += '/${correlationEnc.join(',')};${targetsEnc.join(',')}';

    return await put(path, data: entities);
  }
}
