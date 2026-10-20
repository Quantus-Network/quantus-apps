import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/quantus_sdk_riverpod.dart';

enum ColdSignStep { show, verify, scan, rejected, success }

enum ColdSignIssue { prepareFailed, expired, wrongSigner, invalidSignature, submitFailed, aborted }

/// One signing round trip with the cold wallet: build the request, show it,
/// have the user verify it on the device, scan the signature, broadcast.
class ColdSignFlow extends ChangeNotifier {
  static const freshnessCheck = Duration(seconds: 5);

  final ProviderReader read;
  final Account account;
  final RuntimeCall Function() buildCall;
  final ColdSignRequestKey key;
  final int bytesPerFrame;
  final void Function(String extrinsicHash, int blockNumber) onSubmitted;

  /// Runs after a valid signature and before broadcast; a non-null result is
  /// shown and the broadcast is abandoned.
  final Future<String?> Function()? beforeBroadcast;

  ColdSignRequest? request;
  ColdSignStep step = ColdSignStep.show;
  ColdSignIssue? issue;
  String? issueDetail;
  bool preparing = false;
  bool submitting = false;
  bool refreshed = false;
  String? extrinsicHash;
  ColdSignatureResponse? _lastResponse;
  Timer? _freshness;

  ColdSignFlow({
    required this.read,
    required this.account,
    required this.buildCall,
    required this.key,
    required this.bytesPerFrame,
    required this.onSubmitted,
    this.beforeBroadcast,
  });

  Duration? get remaining {
    final request = this.request;
    if (request == null) return null;
    final left = ColdSignEra.maxAge(request.unsignedData.payloadToSign) - DateTime.now().difference(request.createdAt);
    return left.isNegative ? Duration.zero : left;
  }

  Future<void> prepare() async {
    if (preparing) return;
    preparing = true;
    issue = null;
    notifyListeners();
    try {
      request = await ColdSignRequest.build(
        account: account,
        call: buildCall(),
        key: key,
        maxFragmentLength: bytesPerFrame,
        substrate: read(substrateServiceProvider),
      );
      _armFreshness();
    } catch (e) {
      issue = ColdSignIssue.prepareFailed;
      issueDetail = '$e';
    } finally {
      preparing = false;
      notifyListeners();
    }
  }

  void _armFreshness() {
    _freshness?.cancel();
    _freshness = Timer.periodic(freshnessCheck, (_) {
      if (step != ColdSignStep.show) return;
      if (request?.isStale() ?? false) {
        refreshed = true;
        unawaited(prepare());
      } else {
        notifyListeners();
      }
    });
  }

  void continueToVerify() {
    final request = this.request;
    if (request == null) return;
    if (request.isStale()) {
      refreshed = true;
      unawaited(prepare());
      return;
    }
    _freshness?.cancel();
    step = ColdSignStep.verify;
    notifyListeners();
  }

  void backToQr() {
    step = ColdSignStep.show;
    issue = null;
    refreshed = true;
    unawaited(prepare());
  }

  void matches() {
    step = ColdSignStep.scan;
    issue = null;
    notifyListeners();
  }

  void mismatch() {
    step = ColdSignStep.rejected;
    notifyListeners();
  }

  /// Verifies and broadcasts the scanned signature. Throws for a signature the
  /// scanner should discard and scan again; handles the other outcomes itself.
  Future<void> onSignature(List<String> parts) async {
    final response = ColdSignatureResponse.fromUrParts(parts);
    await _submit(response);
  }

  Future<void> retrySubmit() async {
    final response = _lastResponse;
    if (response != null) await _submit(response);
  }

  Future<void> _submit(ColdSignatureResponse response) async {
    final request = this.request!;
    submitting = true;
    issue = null;
    notifyListeners();
    try {
      response.verifyFor(account, request.unsignedData);
      final abort = await beforeBroadcast?.call();
      if (abort != null) {
        issue = ColdSignIssue.aborted;
        issueDetail = abort;
        return;
      }
      final hashBytes = await submitColdSigned(
        account: account,
        unsigned: request.unsignedData,
        response: response,
        substrate: read(substrateServiceProvider),
      );
      extrinsicHash = '0x${SubstrateService().bytesToHex(hashBytes)}';
      read(coldSignCacheProvider.notifier).reset();
      onSubmitted(extrinsicHash!, request.unsignedData.payloadToSign.blockNumber);
      step = ColdSignStep.success;
    } on ColdSignEraExpiredException {
      issue = ColdSignIssue.expired;
      step = ColdSignStep.show;
      unawaited(prepare());
    } on ColdSignerMismatchException {
      issue = ColdSignIssue.wrongSigner;
      rethrow;
    } on ColdSignatureInvalidException {
      issue = ColdSignIssue.invalidSignature;
      rethrow;
    } catch (e) {
      _lastResponse = response;
      issue = ColdSignIssue.submitFailed;
      issueDetail = '$e';
    } finally {
      submitting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _freshness?.cancel();
    super.dispose();
  }
}
