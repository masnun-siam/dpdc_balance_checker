import 'package:flutter_test/flutter_test.dart';
import 'package:dpdc_balance_check/services/dpdc_api_service.dart';

void main() {
  group('isAccessDenied', () {
    test('true for Access denied error', () {
      expect(
        isAccessDenied({
          'errors': [
            {'message': 'Access denied'}
          ]
        }),
        isTrue,
      );
    });

    test('false for a normal data response', () {
      expect(
        isAccessDenied({
          'data': {
            'postBalanceDetails': {'accountId': '1'}
          }
        }),
        isFalse,
      );
    });

    test('false for an unrelated error message', () {
      expect(
        isAccessDenied({
          'errors': [
            {'message': 'Customer not found'}
          ]
        }),
        isFalse,
      );
    });

    test('false for empty body', () {
      expect(isAccessDenied({}), isFalse);
    });

    test('false for empty errors list', () {
      expect(isAccessDenied({'errors': []}), isFalse);
    });

    test('false when error entry has no message key', () {
      expect(
        isAccessDenied({
          'errors': [{}]
        }),
        isFalse,
      );
    });

    test('false when message is null', () {
      expect(
        isAccessDenied({
          'errors': [
            {'message': null}
          ]
        }),
        isFalse,
      );
    });

    test('false when errors is a String instead of a List', () {
      expect(isAccessDenied({'errors': 'Access denied'}), isFalse);
    });

    test('true when Access denied is the second entry (scans all entries)',
        () {
      expect(
        isAccessDenied({
          'errors': [
            {'message': 'warn'},
            {'message': 'Access denied'},
          ]
        }),
        isTrue,
      );
    });

    test('false for lowercase "access denied" (case-sensitive exact match)',
        () {
      // Contract pinned: the server always sends "Access denied" verbatim.
      // A loose/case-insensitive match risks retrying on unrelated errors
      // that happen to share the same words in different casing.
      expect(
        isAccessDenied({
          'errors': [
            {'message': 'access denied'}
          ]
        }),
        isFalse,
      );
    });
  });

  group('DpdcApiService.validateCustomerId', () {
    test('8 digit id is valid', () {
      expect(DpdcApiService.validateCustomerId('12345678'), isTrue);
    });

    test('12 digit id is valid', () {
      expect(DpdcApiService.validateCustomerId('123456789012'), isTrue);
    });

    test('7 digit id is invalid', () {
      expect(DpdcApiService.validateCustomerId('1234567'), isFalse);
    });

    test('13 digit id is invalid', () {
      expect(DpdcApiService.validateCustomerId('1234567890123'), isFalse);
    });

    test('empty string is invalid', () {
      expect(DpdcApiService.validateCustomerId(''), isFalse);
    });

    test('non-numeric character is invalid', () {
      expect(DpdcApiService.validateCustomerId('1234567a'), isFalse);
    });

    test('embedded space is invalid', () {
      expect(DpdcApiService.validateCustomerId('1234 5678'), isFalse);
    });

    test('leading plus sign is invalid', () {
      expect(DpdcApiService.validateCustomerId('+12345678'), isFalse);
    });
  });
}
