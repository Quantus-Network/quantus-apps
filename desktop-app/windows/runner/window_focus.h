#ifndef RUNNER_WINDOW_FOCUS_H_
#define RUNNER_WINDOW_FOCUS_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>

// Brings the app's window to the front when the app asks, as it does when a
// notification is clicked. WindowChrome in lib/services/window_chrome.dart is
// the app's side; of its requests, Windows serves "bringToFront" only.
class WindowFocus {
 public:
  // Answers the app on |messenger| for the top-level |window|.
  WindowFocus(flutter::BinaryMessenger* messenger, HWND window);

  WindowFocus(const WindowFocus&) = delete;
  WindowFocus& operator=(const WindowFocus&) = delete;

 private:
  // Shows the window, restored when it is minimized, in front of the others.
  void BringToFront();

  HWND window_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_WINDOW_FOCUS_H_
