import 'dart:convert' as convert;
import 'package:http/http.dart' as http;

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

  /// The http client connection.
  http.Client _client;

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
    var response = await _client.post('https://${this.hostname}/authn/session', body: credential);
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

  /// Gets the resource for [path] from [hostname] and returns the response
  /// body.
  Future<Object> get(String path, {Map<String, String> headers}) async {
    _client = _client != null ? _client : http.Client();
    headers = await _updateAuthorizationHeader(headers);

    if (path == null || path == '') {
      throw ArgumentError("Invalid path: null or '' not allowed");
    }

    var response = await _client.get('https://${hostname}${path}', headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException('Failed to get "${path}": ${response.body}');
    }
    return response.body;
  }

  /// Posts [data] to the [path] and returns the response body.
  Future<Object> post(String path, {Object data, Map<String, String> headers}) async {
    _client = _client != null ? _client : http.Client();
    headers = await _updateAuthorizationHeader(headers);

    var response = await _client.post(path, body: data);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException('Failed to post "${path}": ${response.body}');
    }
    return response.body;
  }

  /// Close the client connection.
  void close() {
    _client?.close();
  }
}


/// An ERMrest client binding.
class ERMrestClient extends DerivaBinding {

  /// The catalog identifier including snapshot (optional).
  String catalog;

  /// Initializes the ERMrest client binding to [hostname] and [catalog] with
  /// [credential].
  ERMrestClient(hostname, this.catalog, {credential}) : super(hostname, credential: credential);

  /// Updates the [headers] with the JSON content type and accept headers.
  Map<String, String> _updateContentTypeHeaders(Map<String, String> headers) {
    headers = headers != null ? headers : Map<String, String>();
    headers.addAll({'Content-Type': 'application/json', 'Accept': 'application/json'});
    return headers;
  }

  /// Gets the resource for [path] from [hostname] and returns JSON decoded object.
  Future<Object> get(String path, {Map<String, String> headers}) async {
    headers = _updateContentTypeHeaders(headers);
    var response = await super.get('/ermrest/catalog/${catalog}${path}', headers: headers);
    return convert.jsonDecode(response);
  }

  /// Posts [data] to the [path] and returns JSON decoded object.
  Future<Object> post(String path, {Object data, Map<String, String> headers}) async {
    headers = _updateContentTypeHeaders(headers);
    String body = data != null ? convert.jsonEncode(data) : null;
    var response = await super.post('/ermrest/catalog/${catalog}${path}', data: body, headers: headers);
    return convert.jsonDecode(response);
  }
}
