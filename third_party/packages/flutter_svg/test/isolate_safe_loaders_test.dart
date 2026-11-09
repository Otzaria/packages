import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const String _svg = '<svg width="12" height="12"><rect width="12" height="12"/></svg>';

void main() {
  setUp(svg.cache.clear);

  test('the asset loader can parse from a bundle retaining an unsendable Future', () async {
    final bundle = _FutureHoldingBundle();
    final loader = SvgAssetLoader('icon.svg', assetBundle: bundle);
    final ByteData bytes = await loader.loadBytes(null);

    expect(bytes.lengthInBytes, greaterThan(0));
    expect(bundle.loads, 1);
    expect(svg.cache.count, 1);
  });

  test('the network loader can parse from a client retaining an unsendable Future', () async {
    final client = _FutureHoldingClient();
    final loader = SvgNetworkLoader('https://example.com/icon.svg', httpClient: client);
    final ByteData bytes = await loader.loadBytes(null);

    expect(bytes.lengthInBytes, greaterThan(0));
    expect(client.requests, 1);
    expect(svg.cache.count, 1);
  });

  test('file and memory loaders still produce compiled data', () async {
    final Directory dir = await Directory.systemTemp.createTemp('flutter_svg_isolate');
    try {
      final file = File('${dir.path}/icon.svg');
      await file.writeAsString(_svg);
      final fileLoader = SvgFileLoader(file);
      final memoryLoader = SvgBytesLoader(Uint8List.fromList(utf8.encode(_svg)));
      const stringLoader = SvgStringLoader(_svg);

      final ByteData fromFile = await fileLoader.loadBytes(null);
      final ByteData fromMemory = await memoryLoader.loadBytes(null);
      final ByteData fromString = await stringLoader.loadBytes(null);

      expect(fromFile.lengthInBytes, greaterThan(0));
      expect(fromMemory.lengthInBytes, greaterThan(0));
      expect(fromString.lengthInBytes, greaterThan(0));
      expect(svg.cache.count, 3);
    } finally {
      await dir.delete(recursive: true);
    }
  });
}

class _FutureHoldingBundle extends Fake implements AssetBundle {
  final Completer<void> _unsendableState = Completer<void>();
  int loads = 0;

  @override
  Future<ByteData> load(String key) async {
    assert(!_unsendableState.isCompleted);
    loads++;
    return Uint8List.fromList(utf8.encode(_svg)).buffer.asByteData();
  }
}

class _FutureHoldingClient extends Fake implements http.Client {
  final Completer<void> _unsendableState = Completer<void>();
  int requests = 0;

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    assert(!_unsendableState.isCompleted);
    requests++;
    return http.Response(_svg, 200);
  }
}
