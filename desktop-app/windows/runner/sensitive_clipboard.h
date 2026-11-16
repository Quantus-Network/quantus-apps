#ifndef RUNNER_SENSITIVE_CLIPBOARD_H_
#define RUNNER_SENSITIVE_CLIPBOARD_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>
#include <optional>
#include <string>

// Puts a secret such as a recovery phrase on the clipboard for a short time,
// and asks clipboard history not to keep it. SensitiveClipboard in
// lib/services/sensitive_clipboard.dart is the app's side.
//
// The copy carries the formats Windows documents for this: it is excluded
// from clipboard monitors, from clipboard history (Win+V) and from cloud
// clipboard sync. Other clipboard managers may still ignore them: they are a
// request, not a guarantee.
//
// "clear", and closing the window, empty the clipboard only while it still
// holds that copy, so something the user copied since is left alone.
class SensitiveClipboard {
 public:
  // Answers the app on |messenger|. The clipboard is opened as |owner|.
  SensitiveClipboard(flutter::BinaryMessenger* messenger, HWND owner);

  SensitiveClipboard(const SensitiveClipboard&) = delete;
  SensitiveClipboard& operator=(const SensitiveClipboard&) = delete;

  // Empties the clipboard if it still holds the last copy.
  void ClearIfUnchanged();

 private:
  // Copies |utf8_text|, or says in |error| why it could not.
  bool Copy(const std::string& utf8_text, std::string* error);

  HWND owner_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;

  // The clipboard's sequence number just after the last copy, while that copy
  // has not been cleared.
  std::optional<DWORD> copied_sequence_;
};

#endif  // RUNNER_SENSITIVE_CLIPBOARD_H_
