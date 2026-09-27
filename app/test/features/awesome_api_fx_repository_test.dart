import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/features/screen_3_investments/data/awesome_api_fx_repository.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/fx_quote_set.dart';

void main() {
  test(
    'AwesomeAPI quotes convert existing BRL data to the selected currency',
    () async {
      final repository = AwesomeApiFxRepository(
        apiKey: 'test-key',
        client: MockClient((request) async {
          expect(request.headers['x-api-key'], 'test-key');
          return http.Response(
            '{"USDBRL":{"bid":"5.20"},"EURBRL":{"bid":"6.10"},"INRBRL":{"bid":"0.062"}}',
            200,
          );
        }),
      );

      final quotes = await repository.latest(CurrencyCode.usd);

      expect(quotes!.status, QuoteStatus.current);
      expect(quotes.convertToBaseMinor(52000, CurrencyCode.brl), 10000);
      expect(quotes.convertMinor(10000, CurrencyCode.brl), 52000);
    },
  );
}
