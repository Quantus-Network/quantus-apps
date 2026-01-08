import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/main/screens/send/send_screen_logic.dart';
import 'package:quantus_sdk/generated/schrodinger/pallets/balances.dart' as balances;

void main() {
  group('SendScreenLogic', () {
    late NumberFormattingService formattingService;

    setUp(() {
      formattingService = NumberFormattingService();
    });

    group('getAmountStatus', () {
      test('returns zeroOrNegative for zero', () {
        final status = SendScreenLogic.getAmountStatus(BigInt.zero, BigInt.from(1000), BigInt.from(10));
        expect(status, AmountStatus.zero);
      });

      test('returns belowExistential when < ED', () {
        final status = SendScreenLogic.getAmountStatus(
          balances.Constants().existentialDeposit - BigInt.one,
          BigInt.from(5000000000000),
          BigInt.from(100),
        );
        expect(status, AmountStatus.belowExistential);
      });

      test('returns insufficientBalance when amount + fee > balance', () {
        final status = SendScreenLogic.getAmountStatus(BigInt.from(1_000_000_000), BigInt.from(1000), BigInt.from(10));
        expect(status, AmountStatus.insufficientBalance);
      });

      test('returns valid for correct inputs', () {
        final status = SendScreenLogic.getAmountStatus(
          BigInt.from(1_000_000_000),
          BigInt.from(1_000_000_000_000),
          BigInt.from(10),
        );
        expect(status, AmountStatus.valid);
      });
    });

    group('hasAmountError', () {
      test('returns true for zero amount', () {
        final result = SendScreenLogic.hasAmountError(
          amount: BigInt.zero,
          balance: BigInt.from(5000000000000),
          networkFee: BigInt.from(100000000),
        );
        expect(result, isTrue);
      });

      test('returns true when amount + fee exceeds balance', () {
        final result = SendScreenLogic.hasAmountError(
          amount: BigInt.from(4999900000000),
          balance: BigInt.from(5000000000000),
          networkFee: BigInt.from(200000000),
        );
        expect(result, isTrue);
      });

      test('returns false for valid amount', () {
        final result = SendScreenLogic.hasAmountError(
          amount: BigInt.from(1000000000000),
          balance: BigInt.from(5000000000000),
          networkFee: BigInt.from(100000000),
        );
        expect(result, isFalse);
      });
    });

    group('isButtonDisabled', () {
      test('returns true when address has error', () {
        final result = SendScreenLogic.isButtonDisabled(
          hasAddressError: true,
          amountStatus: AmountStatus.valid,
          recipientText: 'valid_address',
          activeAccountId: 'sender_address',
          isFetchingFee: false,
        );
        expect(result, isTrue);
      });

      test('returns true when amount has error', () {
        final result = SendScreenLogic.isButtonDisabled(
          hasAddressError: false,
          amountStatus: AmountStatus.belowExistential,
          recipientText: 'valid_address',
          activeAccountId: 'sender_address',
          isFetchingFee: false,
        );
        expect(result, isTrue);
      });

      test('returns true when recipient text is empty', () {
        final result = SendScreenLogic.isButtonDisabled(
          hasAddressError: false,
          amountStatus: AmountStatus.valid,
          recipientText: '',
          activeAccountId: 'sender_address',
          isFetchingFee: false,
        );
        expect(result, isTrue);
      });

      test('returns true when fetching fee', () {
        final result = SendScreenLogic.isButtonDisabled(
          hasAddressError: false,
          amountStatus: AmountStatus.valid,
          recipientText: 'valid_address',
          activeAccountId: 'sender_address',
          isFetchingFee: true,
        );
        expect(result, isTrue);
      });

      test('returns true for self transfer', () {
        final result = SendScreenLogic.isButtonDisabled(
          hasAddressError: false,
          amountStatus: AmountStatus.valid,
          recipientText: 'same_address',
          activeAccountId: 'same_address',
          isFetchingFee: false,
        );
        expect(result, isTrue);
      });

      test('returns false for valid input', () {
        final result = SendScreenLogic.isButtonDisabled(
          hasAddressError: false,
          amountStatus: AmountStatus.valid,
          recipientText: 'valid_address',
          activeAccountId: 'sender_address',
          isFetchingFee: false,
        );
        expect(result, isFalse);
      });
    });

    group('getButtonText', () {
      test('returns "Enter Address" when address is empty', () {
        final result = SendScreenLogic.getButtonText(
          hasAddressError: false,
          amountStatus: AmountStatus.valid, // Status doesn't matter if address is empty
          recipientText: '',
          amount: BigInt.from(1000),
          activeAccountId: 'sender_address',
          formattingService: formattingService,
        );
        expect(result, equals('Enter Address'));
      });

      test('returns "Enter Amount" when status is zeroOrNegative', () {
        final result = SendScreenLogic.getButtonText(
          hasAddressError: false,
          amountStatus: AmountStatus.zero,
          recipientText: 'valid_address',
          amount: BigInt.zero,
          activeAccountId: 'sender_address',
          formattingService: formattingService,
        );
        expect(result, equals('Enter Amount'));
      });

      test('returns "Insufficient Balance" when status is insufficient', () {
        final result = SendScreenLogic.getButtonText(
          hasAddressError: false,
          amountStatus: AmountStatus.insufficientBalance,
          recipientText: 'valid_address',
          amount: BigInt.from(1000),
          activeAccountId: 'sender_address',
          formattingService: formattingService,
        );
        expect(result, equals('Insufficient Balance'));
      });

      test('returns "Can\'t Self Transfer" for same address', () {
        final result = SendScreenLogic.getButtonText(
          hasAddressError: false,
          amountStatus: AmountStatus.valid,
          recipientText: 'same_address',
          amount: BigInt.from(1000),
          activeAccountId: 'same_address',
          formattingService: formattingService,
        );
        expect(result, equals("Can't Self Transfer"));
      });

      test('returns "Below Existential Deposit" when status matches', () {
        final result = SendScreenLogic.getButtonText(
          hasAddressError: false,
          amountStatus: AmountStatus.belowExistential,
          recipientText: 'valid_address',
          amount: BigInt.from(1),
          activeAccountId: 'sender_address',
          formattingService: formattingService,
        );
        expect(result, equals('Below Existential Deposit'));
      });

      test('returns formatted send amount for valid status', () {
        final result = SendScreenLogic.getButtonText(
          hasAddressError: false,
          amountStatus: AmountStatus.valid,
          recipientText: 'valid_address',
          amount: BigInt.from(1000000000000),
          activeAccountId: 'sender_address',
          formattingService: formattingService,
        );
        expect(result, startsWith('Send'));
      });
    });

    group('calculateMaxSendableAmount', () {
      test('calculates correct max when fee is less than balance', () {
        final result = SendScreenLogic.calculateMaxSendableAmount(
          balance: BigInt.from(5000000000000),
          networkFee: BigInt.from(100000000),
        );
        expect(result, equals(BigInt.from(4999900000000)));
      });

      test('returns zero when fee exceeds balance', () {
        final result = SendScreenLogic.calculateMaxSendableAmount(
          balance: BigInt.from(50000000),
          networkFee: BigInt.from(100000000),
        );
        expect(result, equals(BigInt.zero));
      });
    });

    group('getReversibleTimeComponents', () {
      test('calculates components correctly', () {
        const seconds = 176460; // 2 days, 1 hour, 1 minute
        final result = SendScreenLogic.getReversibleTimeComponents(seconds);
        expect(result.days, equals(2));
        expect(result.hours, equals(1));
        expect(result.minutes, equals(1));
      });
    });

    group('formatReversibleTime', () {
      test('formats time with days, hours, and minutes', () {
        const seconds = 176460;
        final result = SendScreenLogic.formatReversibleTime(seconds);
        expect(result, equals('2d, 1h, 1m'));
      });

      test('formats zero time', () {
        const seconds = 0;
        final result = SendScreenLogic.formatReversibleTime(seconds);
        expect(result, equals('0m'));
      });
    });

    group('isReversible', () {
      test('returns true for positive seconds', () {
        expect(SendScreenLogic.isReversible(600), isTrue);
      });
      test('returns false for zero seconds', () {
        expect(SendScreenLogic.isReversible(0), isFalse);
      });
    });
  });
}
