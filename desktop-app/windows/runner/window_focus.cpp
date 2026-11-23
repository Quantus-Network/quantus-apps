#include "window_focus.h"

#include <flutter/standard_method_codec.h>

namespace {

constexpr char kChannelName[] = "com.quantus.desktop-wallet/window";

}  // namespace

WindowFocus::WindowFocus(flutter::BinaryMessenger* messenger, HWND window) : window_(window) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, kChannelName, &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "bringToFront") {
          BringToFront();
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
}

void WindowFocus::BringToFront() {
  ShowWindow(window_, IsIconic(window_) ? SW_RESTORE : SW_SHOW);
  // Windows keeps the foreground for the app in use, and when it refuses it
  // flashes the window's taskbar button instead.
  SetForegroundWindow(window_);
}
