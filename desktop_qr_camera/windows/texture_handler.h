#ifndef TEXTURE_HANDLER_H
#define TEXTURE_HANDLER_H

#include <flutter/texture_registrar.h>

#include <cstdint>
#include <memory>
#include <mutex>
#include <vector>

namespace flutter_lite_camera
{

    // Wraps a flutter::PixelBufferTexture. The camera capture thread pushes
    // RGBA frames with UpdateBuffer(); the Flutter raster thread pulls them
    // through the pixel-buffer callback. The buffer mutex is handed to
    // Flutter via the release callback so the source buffer stays valid
    // until the rasterizer is done with it.
    class TextureHandler
    {
    public:
        explicit TextureHandler(flutter::TextureRegistrar *texture_registrar)
            : texture_registrar_(texture_registrar) {}
        ~TextureHandler();

        TextureHandler(const TextureHandler &) = delete;
        TextureHandler &operator=(const TextureHandler &) = delete;

        int64_t RegisterTexture();
        void UnregisterTexture();
        bool TextureRegistered() const { return texture_id_ >= 0; }
        int64_t texture_id() const { return texture_id_; }

        // Called from the camera capture thread with RGBA8888 data.
        void UpdateBuffer(const unsigned char *rgbaData, int width, int height);

    private:
        const FlutterDesktopPixelBuffer *ConvertPixelBufferForFlutter(size_t width, size_t height);

        flutter::TextureRegistrar *texture_registrar_;
        int64_t texture_id_ = -1;
        std::unique_ptr<flutter::TextureVariant> texture_;
        std::unique_ptr<FlutterDesktopPixelBuffer> flutter_desktop_pixel_buffer_;

        std::mutex buffer_mutex_;
        std::vector<unsigned char> source_buffer_; // RGBA8888
        uint32_t frame_width_ = 0;
        uint32_t frame_height_ = 0;
    };

} // namespace flutter_lite_camera

#endif // TEXTURE_HANDLER_H
