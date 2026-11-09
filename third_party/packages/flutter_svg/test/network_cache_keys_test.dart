import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  setUp(() {
    svg.cache.clear();
    svg.cache.maximumSize = 100;
  });

  test('equivalent HTTP header maps share one compiled SVG', () async {
    final _CountingSvgClient client = _CountingSvgClient();
    final SvgNetworkLoader first = SvgNetworkLoader(
      'https://example.com/logo.svg',
      headers: <String, String>{'Accept': 'image/svg+xml', 'X-Test': 'yes'},
      httpClient: client,
    );
    final SvgNetworkLoader second = SvgNetworkLoader(
      'https://example.com/logo.svg',
      headers: <String, String>{'X-Test': 'yes', 'Accept': 'image/svg+xml'},
      httpClient: client,
    );

    expect(first, equals(second));
    expect(first.hashCode, second.hashCode);
    expect(first.cacheKey(null), second.cacheKey(null));

    final ByteData firstBytes = await first.loadBytes(null);
    final ByteData secondBytes = await second.loadBytes(null);
    expect(identical(firstBytes, secondBytes), isTrue);
    expect(client.requests, 1);
  });

  test('different headers or injected clients cannot share network data', () async {
    final _CountingSvgClient firstClient = _CountingSvgClient();
    final _CountingSvgClient secondClient = _CountingSvgClient();
    final SvgNetworkLoader first = SvgNetworkLoader(
      'https://example.com/logo.svg',
      headers: <String, String>{'Authorization': 'A'},
      httpClient: firstClient,
    );
    final SvgNetworkLoader differentHeader = SvgNetworkLoader(
      'https://example.com/logo.svg',
      headers: <String, String>{'Authorization': 'B'},
      httpClient: firstClient,
    );
    final SvgNetworkLoader differentClient = SvgNetworkLoader(
      'https://example.com/logo.svg',
      headers: <String, String>{'Authorization': 'A'},
      httpClient: secondClient,
    );

    expect(first, isNot(equals(differentHeader)));
    expect(first.cacheKey(null), isNot(equals(differentHeader.cacheKey(null))));
    expect(first, isNot(equals(differentClient)));
    expect(first.cacheKey(null), isNot(equals(differentClient.cacheKey(null))));

    await first.loadBytes(null);
    await differentHeader.loadBytes(null);
    await differentClient.loadBytes(null);
    expect(firstClient.requests, 2);
    expect(secondClient.requests, 1);
    expect(svg.cache.count, 3);
  });

  test('cache keys snapshot mutable request headers', () {
    final Map<String, String> headers = <String, String>{'Authorization': 'old'};
    final SvgNetworkLoader loader = SvgNetworkLoader(
      'https://example.com/logo.svg',
      headers: headers,
    );
    final SvgCacheKey original = loader.cacheKey(null);

    headers['Authorization'] = 'new';
    final SvgCacheKey changed = loader.cacheKey(null);
    expect(original, isNot(equals(changed)));

    // Reconstructing the original request recovers the same stable key.
    final SvgCacheKey originalAgain = SvgNetworkLoader(
      'https://example.com/logo.svg',
      headers: <String, String>{'Authorization': 'old'},
    ).cacheKey(null);
    expect(original, originalAgain);
  });
}

class _CountingSvgClient extends http.BaseClient {
  int requests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests++;
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode('<svg width="10" height="10"></svg>')),
      200,
    );
  }
}
