import 'package:flutter/foundation.dart';

@immutable
class MultisigSigner {
  final String accountId;
  final String? checksum;
  final bool hasApproved;
  final bool isYou;

  const MultisigSigner({required this.accountId, this.checksum, this.hasApproved = false, this.isYou = false});

  MultisigSigner copyWith({String? checksum, bool? hasApproved, bool? isYou}) {
    return MultisigSigner(
      accountId: accountId,
      checksum: checksum ?? this.checksum,
      hasApproved: hasApproved ?? this.hasApproved,
      isYou: isYou ?? this.isYou,
    );
  }
}
