import 'dart:async';

import 'package:flutter/foundation.dart';
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

  testWidgets('the global default placeholder is shown during loading', (WidgetTester tester) async {
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

class _DeferredClient extends Fake implements http.Client {
  _DeferredClient(this.response);

  final Future<http.Response> response;

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) {
    return response;
  }
}
