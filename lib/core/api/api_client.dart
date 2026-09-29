import 'package:http/http.dart' as http;

class ApiClient {
  static const String baseUrl = 'https://vertextback.geoinfobox.com/api/v1/';
  final http.Client _client;
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  /// Builds a URL relative to [baseUrl]. The backend requires a trailing
  /// slash on every route (PATCH/DELETE can't be redirected), so one is
  /// appended when missing.
  Uri uri(String path, [Map<String, String>? query]) {
    final p = path.endsWith('/') ? path : '$path/';
    final u = Uri.parse(baseUrl).resolve(p);
    return query == null ? u : u.replace(queryParameters: query);
  }

  Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
      _client.get(url, headers: headers);

  Future<http.Response> post(Uri url,
          {Map<String, String>? headers, Object? body}) =>
      _client.post(url, headers: headers, body: body);

  Future<http.Response> patch(Uri url,
          {Map<String, String>? headers, Object? body}) =>
      _client.patch(url, headers: headers, body: body);

  Future<http.Response> delete(Uri url,
          {Map<String, String>? headers, Object? body}) =>
      _client.delete(url, headers: headers, body: body);

  /// For multipart uploads.
  Future<http.Response> send(http.BaseRequest request) async =>
      http.Response.fromStream(await _client.send(request));
}
