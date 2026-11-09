// Copyright 2026 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  late WidgetBuilder originalBuilder;

  setUp(() {
    originalBuilder = SvgPicture.defaultPlaceholderBuilder;
    svg.cache.clear();
  });

  tearDown(() {
    SvgPicture.defaultPlaceholderBuilder = originalBuilder;
  });

  for (final size in <Size>[const Size(48, 36), const Size(48, 0), const Size(0, 36)]) {
    testWidgets('the original default reserves $size while loading', (WidgetTester tester) async {
      final response = Completer<ByteData>();
      final picture = SvgPicture(
        _DeferredLoader(response.future),
        width: size.width == 0 ? null : size.width,
        height: size.height == 0 ? null : size.height,
      );
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: Center(child: picture),
        ),
      );
      expect(tester.getSize(find.byWidget(picture)), size);
    });
  }

  testWidgets('the original default reserves logo height beside Hebrew text', (
    WidgetTester tester,
  ) async {
    final response = Completer<ByteData>();
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SvgPicture(_DeferredLoader(response.future), height: 36),
        const SizedBox(width: 8),
        const Text('ים החכמה'),
      ],
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: DefaultTextStyle(
          style: const TextStyle(fontSize: 16),
          child: Center(child: row),
        ),
      ),
    );
    expect(tester.getSize(find.byWidget(row)).height, 36);
  });

  testWidgets('restoring the original global builder restores dimension reservation', (
    WidgetTester tester,
  ) async {
    final response = Completer<ByteData>();
    final picture = SvgPicture(_DeferredLoader(response.future), width: 48, height: 36);
    SvgPicture.defaultPlaceholderBuilder = (BuildContext context) =>
        const SizedBox(width: 7, height: 9);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Center(child: picture),
      ),
    );
    expect(tester.getSize(find.byWidget(picture)), const Size(7, 9));
    SvgPicture.defaultPlaceholderBuilder = originalBuilder;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Center(child: SvgPicture(_DeferredLoader(response.future), width: 48, height: 36)),
      ),
    );
    expect(tester.getSize(find.byType(SvgPicture)), const Size(48, 36));
  });

  testWidgets('a configured empty global builder keeps its own layout', (
    WidgetTester tester,
  ) async {
    final response = Completer<ByteData>();
    SvgPicture.defaultPlaceholderBuilder = (BuildContext context) => const LimitedBox();
    final picture = SvgPicture(_DeferredLoader(response.future), width: 48, height: 36);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Center(child: picture),
      ),
    );
    expect(tester.getSize(find.byWidget(picture)), Size.zero);
  });

  testWidgets('an error builder replaces the global loading placeholder', (
    WidgetTester tester,
  ) async {
    final response = Completer<ByteData>();
    SvgPicture.defaultPlaceholderBuilder = (BuildContext context) {
      return const SizedBox(key: ValueKey<String>('global-placeholder'));
    };
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SvgPicture(
          _DeferredLoader(response.future),
          width: 24,
          height: 24,
          errorBuilder: (BuildContext context, Object error, StackTrace stackTrace) {
            return const SizedBox(key: ValueKey<String>('error'));
          },
        ),
      ),
    );
    expect(find.byKey(const ValueKey<String>('global-placeholder')), findsOneWidget);
    response.completeError(StateError('unavailable'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('global-placeholder')), findsNothing);
    expect(find.byKey(const ValueKey<String>('error')), findsOneWidget);
  });

  testWidgets('the global default placeholder is shown during loading', (
    WidgetTester tester,
  ) async {
    final response = Completer<http.Response>();
    SvgPicture.defaultPlaceholderBuilder = (BuildContext context) {
      return const SizedBox(key: ValueKey<String>('global-placeholder'));
    };

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SvgPicture.network(
          'https://example.com/default-placeholder.svg',
          httpClient: _DeferredClient(response.future),
          width: 24,
          height: 24,
        ),
      ),
    );

    expect(find.byKey(const ValueKey<String>('global-placeholder')), findsOneWidget);

    response.complete(http.Response('<svg width="10" height="10"></svg>', 200));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('global-placeholder')), findsNothing);
  });

  testWidgets('an explicit placeholder overrides the global default', (WidgetTester tester) async {
    final response = Completer<http.Response>();
    SvgPicture.defaultPlaceholderBuilder = (BuildContext context) {
      return const SizedBox(key: ValueKey<String>('global-placeholder'));
    };

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SvgPicture.network(
          'https://example.com/explicit-placeholder.svg',
          httpClient: _DeferredClient(response.future),
          width: 24,
          height: 24,
          placeholderBuilder: (BuildContext context) {
            return const SizedBox(key: ValueKey<String>('explicit-placeholder'));
          },
        ),
      ),
    );

    expect(find.byKey(const ValueKey<String>('explicit-placeholder')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('global-placeholder')), findsNothing);

    response.complete(http.Response('<svg width="10" height="10"></svg>', 200));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('explicit-placeholder')), findsNothing);
  });
}

class _DeferredLoader extends BytesLoader {
  const _DeferredLoader(this.response);

  final Future<ByteData> response;

  @override
  Future<ByteData> loadBytes(BuildContext? context) => response;
}

class _DeferredClient extends Fake implements http.Client {
  _DeferredClient(this.response);

  final Future<http.Response> response;

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) {
    return response;
  }
}
