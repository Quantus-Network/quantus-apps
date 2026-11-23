#include "sensitive_clipboard.h"

#include <flutter/standard_method_codec.h>

#include <cstring>
#include <variant>

namespace {

constexpr char kChannelName[] = "app.quantus/sensitive_clipboard";

// The formats that keep a copy out of clipboard monitors, history and cloud
// sync (see "Clipboard Formats" in the Win32 documentation).
constexpr wchar_t kExcludeFromMonitors[] = L"ExcludeClipboardContentFromMonitorProcessing";
constexpr wchar_t kCanIncludeInHistory[] = L"CanIncludeInClipboardHistory";
constexpr wchar_t kCanUploadToCloud[] = L"CanUploadToCloudClipboard";

std::string LastErrorText(const char* what) {
  return std::string(what) + " failed (error " + std::to_string(GetLastError()) + ")";
}

std::optional<std::wstring> Utf16FromUtf8(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8.data(),
                                         static_cast<int>(utf8.size()), nullptr, 0);
  if (length <= 0) {
    return std::nullopt;
  }
  std::wstring utf16(length, L'\0');
  if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8.data(), static_cast<int>(utf8.size()),
                          utf16.data(), length) != length) {
    return std::nullopt;
  }
  return utf16;
}

// Puts |size| bytes of |data| on the open clipboard as |format|. The
// clipboard owns the memory once this succeeds.
bool PutOnClipboard(UINT format, const void* data, size_t size, std::string* error) {
  HGLOBAL memory = GlobalAlloc(GMEM_MOVEABLE, size);
  if (!memory) {
    *error = LastErrorText("GlobalAlloc");
    return false;
  }
  void* target = GlobalLock(memory);
  if (!target) {
    *error = LastErrorText("GlobalLock");
    GlobalFree(memory);
    return false;
  }
  std::memcpy(target, data, size);
  GlobalUnlock(memory);
  if (!SetClipboardData(format, memory)) {
    *error = LastErrorText("SetClipboardData");
    GlobalFree(memory);
    return false;
  }
  return true;
}

// Puts the DWORD |value| on the open clipboard under the registered format
// |name|.
bool PutMarker(const wchar_t* name, DWORD value, std::string* error) {
  const UINT format = RegisterClipboardFormatW(name);
  if (format == 0) {
    *error = LastErrorText("RegisterClipboardFormat");
    return false;
  }
  return PutOnClipboard(format, &value, sizeof(value), error);
}

}  // namespace

SensitiveClipboard::SensitiveClipboard(flutter::BinaryMessenger* messenger, HWND owner) : owner_(owner) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, kChannelName, &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "copy") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          const std::string* text = nullptr;
          if (arguments) {
            const auto found = arguments->find(flutter::EncodableValue("text"));
            if (found != arguments->end()) {
              text = std::get_if<std::string>(&found->second);
            }
          }
          if (!text) {
            result->Error("arguments", "copy needs the text to copy");
            return;
          }
          std::string error;
          if (Copy(*text, &error)) {
            result->Success();
          } else {
            result->Error("clipboard", error);
          }
        } else if (call.method_name() == "clear") {
          std::string error;
          if (ClearIfUnchanged(&error)) {
            result->Success();
          } else {
            result->Error("clipboard", error);
          }
        } else {
          result->NotImplemented();
        }
      });
}

bool SensitiveClipboard::Copy(const std::string& utf8_text, std::string* error) {
  // Until the clipboard is emptied below, it may still hold the last copy,
  // which stays tracked so that it is still cleared.
  const std::optional<std::wstring> text = Utf16FromUtf8(utf8_text);
  if (!text) {
    *error = "The text is not valid UTF-8";
    return false;
  }
  if (!OpenClipboard(owner_)) {
    *error = LastErrorText("OpenClipboard");
    return false;
  }
  if (!EmptyClipboard()) {
    *error = LastErrorText("EmptyClipboard");
    CloseClipboard();
    return false;
  }
  copied_sequence_.reset();
  // The markers go first, so no monitor sees the text without them.
  const bool copied =
      PutMarker(kExcludeFromMonitors, 0, error) && PutMarker(kCanIncludeInHistory, 0, error) &&
      PutMarker(kCanUploadToCloud, 0, error) &&
      PutOnClipboard(CF_UNICODETEXT, text->c_str(), (text->size() + 1) * sizeof(wchar_t), error);
  if (!copied) {
    // Nothing half made is left behind.
    EmptyClipboard();
  }
  CloseClipboard();
  if (copied) {
    // Read after closing, because closing adds the text formats Windows
    // derives from CF_UNICODETEXT, and that changes the number again. A copy
    // another program makes in between is told apart by its owner (see
    // ClearIfUnchanged).
    copied_sequence_ = GetClipboardSequenceNumber();
  }
  return copied;
}

bool SensitiveClipboard::ClearIfUnchanged(std::string* error) {
  if (!copied_sequence_) {
    return true;
  }
  // Another window may have the clipboard open. The copy then stays tracked,
  // so the next clear, or quitting, tries again.
  if (!OpenClipboard(owner_)) {
    *error = LastErrorText("OpenClipboard");
    return false;
  }
  // Checked while the clipboard is open, so nothing can be copied between
  // the check and the clear. Whoever copies over the secret empties the
  // clipboard first, which makes them its owner, so a copy made just after
  // Copy() closed the clipboard is caught even though its number was taken.
  if (GetClipboardSequenceNumber() != *copied_sequence_ || GetClipboardOwner() != owner_) {
    // Something else has been copied over it since, and is left alone.
    copied_sequence_.reset();
    CloseClipboard();
    return true;
  }
  if (!EmptyClipboard()) {
    *error = LastErrorText("EmptyClipboard");
    CloseClipboard();
    return false;
  }
  CloseClipboard();
  copied_sequence_.reset();
  return true;
}
