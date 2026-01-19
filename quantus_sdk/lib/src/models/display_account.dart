import 'package:quantus_sdk/src/models/account.dart';
import 'package:quantus_sdk/src/models/base_account.dart';
import 'package:quantus_sdk/src/models/entrusted_account.dart';

// Union type for display accounts
sealed class DisplayAccount {
  const DisplayAccount();

  BaseAccount get account;

  Map<String, dynamic> toJson();

  static DisplayAccount fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'regular':
        return RegularAccount.fromJson(json);
      case 'entrusted':
        return EntrustedDisplayAccount.fromJson(json);
      default:
        throw Exception('Unknown display account type: $type');
    }
  }

  bool get isEntrustedAccount => this is EntrustedDisplayAccount;
  bool get isRegularAccount => this is RegularAccount;
}

class RegularAccount extends DisplayAccount {
  @override
  final Account account;
  const RegularAccount(this.account);

  factory RegularAccount.fromJson(Map<String, dynamic> json) {
    return RegularAccount(Account.fromJson(json['account'] as Map<String, dynamic>));
  }

  @override
  Map<String, dynamic> toJson() {
    return {'type': 'regular', 'account': account.toJson()};
  }
}

class EntrustedDisplayAccount extends DisplayAccount {
  @override
  final EntrustedAccount account;
  const EntrustedDisplayAccount(this.account);

  factory EntrustedDisplayAccount.fromJson(Map<String, dynamic> json) {
    return EntrustedDisplayAccount(EntrustedAccount.fromJson(json['account'] as Map<String, dynamic>));
  }

  @override
  Map<String, dynamic> toJson() {
    return {'type': 'entrusted', 'account': account.toJson()};
  }
}
