import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The visual style of a toast, mapped to a concrete toaster in the listener.
enum ToastType { success, error, info, warning, copy }

/// A single toast request: a fully-resolved (already localized) message plus
/// the style to render it with.
class ToastMessage {
  const ToastMessage({required this.message, required this.type});

  final String message;
  final ToastType type;
}

/// App-wide toast queue.
///
/// Any layer with a [Ref] can request a toast without holding a
/// [BuildContext]; a single listener widget near the app root observes this
/// provider and renders the toast. Producers resolve their own localized copy
/// (e.g. via `ref.read(l10nProvider)`) and push the finished string here.
class GlobalToastNotifier extends Notifier<ToastMessage?> {
  @override
  ToastMessage? build() => null;

  void show(String message, {ToastType type = ToastType.info}) {
    state = ToastMessage(message: message, type: type);
  }

  void showSuccess(String message) => show(message, type: ToastType.success);

  void showError(String message) => show(message, type: ToastType.error);

  void showInfo(String message) => show(message, type: ToastType.info);

  void showWarning(String message) => show(message, type: ToastType.warning);

  void showCopy(String message) => show(message, type: ToastType.copy);

  void clear() => state = null;
}

final globalToastProvider = NotifierProvider<GlobalToastNotifier, ToastMessage?>(GlobalToastNotifier.new);
