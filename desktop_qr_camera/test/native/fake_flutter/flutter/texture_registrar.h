// The part of Flutter's Windows client wrapper that TextureHandler uses, so its
// lifetime can be tested on any platform. CI's Windows build compiles the
// handler against the real header.
#ifndef FAKE_FLUTTER_TEXTURE_REGISTRAR_H
#define FAKE_FLUTTER_TEXTURE_REGISTRAR_H

#include <cstddef>
#include <cstdint>
#include <functional>
#include <utility>
#include <variant>

typedef struct {
  const uint8_t* buffer;
  size_t width;
  size_t height;
  void (*release_callback)(void* release_context);
  void* release_context;
} FlutterDesktopPixelBuffer;

namespace flutter {

class PixelBufferTexture {
 public:
  typedef std::function<const FlutterDesktopPixelBuffer*(size_t width, size_t height)> CopyBufferCallback;

  explicit PixelBufferTexture(CopyBufferCallback copy_buffer_callback)
      : copy_buffer_callback_(std::move(copy_buffer_callback)) {}

  const FlutterDesktopPixelBuffer* CopyPixelBuffer(size_t width, size_t height) const {
    return copy_buffer_callback_(width, height);
  }

 private:
  const CopyBufferCallback copy_buffer_callback_;
};

typedef std::variant<PixelBufferTexture> TextureVariant;

class TextureRegistrar {
 public:
  virtual ~TextureRegistrar() = default;
  virtual int64_t RegisterTexture(TextureVariant* texture) = 0;
  virtual bool MarkTextureFrameAvailable(int64_t texture_id) = 0;
  virtual void UnregisterTexture(int64_t texture_id, std::function<void()> callback) = 0;
  virtual bool UnregisterTexture(int64_t texture_id) = 0;
};

}  // namespace flutter

#endif  // FAKE_FLUTTER_TEXTURE_REGISTRAR_H
