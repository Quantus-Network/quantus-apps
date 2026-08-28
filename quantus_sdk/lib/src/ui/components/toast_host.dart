import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Renders the current toast, sized to nothing while there is none. Place it
/// directly above whatever sits at the bottom of the surface (scaffold buttons,
/// a sheet) so toasts never cover it.
class ToastHost extends StatefulWidget {
  const ToastHost({super.key});

  @override
  State<ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<ToastHost> {
  @override
  void initState() {
    super.initState();
    ToastController.instance.registerHost();
  }

  @override
  void dispose() {
    ToastController.instance.unregisterHost();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ToastRequest?>(
      valueListenable: ToastController.instance,
      builder: (context, request, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: request == null
            ? const SizedBox.shrink()
            : Padding(
                key: ValueKey(request),
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Toaster(
                  message: request.message,
                  iconData: request.iconData,
                  iconColor: request.iconColor,
                  textColor: request.textColor,
                ),
              ),
      ),
    );
  }
}
