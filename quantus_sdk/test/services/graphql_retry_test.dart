import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/src/services/network/redundant_endpoint.dart';

void main() {
  bool transient(Object? errors) => GraphQlEndpointService.isTransientGraphQlError(errors);

  test('retries the indexer failure seen under concurrent load', () {
    // Verbatim from the indexer when a valid query hits a statement timeout.
    expect(
      transient([
        {
          'message': 'database query error',
          'extensions': {'path': '\$', 'code': 'unexpected'},
        },
      ]),
      isTrue,
    );
  });

  test('does not retry an error the query itself caused', () {
    expect(
      transient([
        {
          'message': "field 'nope' not found in type: 'account_event'",
          'extensions': {'path': '\$.selectionSet', 'code': 'validation-failed'},
        },
      ]),
      isFalse,
    );
  });

  test('does not retry when only some errors are transient', () {
    expect(
      transient([
        {
          'extensions': {'code': 'unexpected'},
        },
        {
          'extensions': {'code': 'validation-failed'},
        },
      ]),
      isFalse,
    );
  });

  test('malformed or empty error payloads are not transient', () {
    expect(transient(null), isFalse);
    expect(transient(<dynamic>[]), isFalse);
    expect(transient('database query error'), isFalse);
    expect(
      transient([
        {'message': 'no extensions'},
      ]),
      isFalse,
    );
  });
}
