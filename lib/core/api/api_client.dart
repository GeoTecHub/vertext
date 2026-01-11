import 'package:http/http.dart' as http;

class ApiClient {
  static const String baseUrl = 'https://vertextback.geoinfobox.com/';
  final http.Client _client;
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Uri uri(String path, [Map<String, String>? query]) =>
      Uri.parse(baseUrl).resolve(path).replace(queryParameters: query);

  Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
      _client.get(url, headers: headers);

  Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body}) =>
      _client.post(url, headers: headers, body: body);

  Future<http.Response> patch(Uri url, {Map<String, String>? headers, Object? body}) =>
      _client.patch(url, headers: headers, body: body);

  // NEW
  Future<http.Response> delete(Uri url, {Map<String, String>? headers}) =>
      _client.delete(url, headers: headers);
}
