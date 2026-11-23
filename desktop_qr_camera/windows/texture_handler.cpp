#include "texture_handler.h"

#include <algorithm>

namespace flutter_lite_camera
{

    TextureHandler::~TextureHandler()
    {
        // The texture might still be processed by the raster thread while the
        // destructor is called. Lock the mutex for safe destruction.
        const std::lock_guard<std::mutex> lock(buffer_mutex_);
        if (texture_registrar_ && texture_id_ >= 0)
        {
            texture_registrar_->UnregisterTexture(texture_id_);
        }
        texture_id_ = -1;
        texture_ = nullptr;
        texture_registrar_ = nullptr;
    }

    int64_t TextureHandler::RegisterTexture()
    {
        if (!texture_registrar_ || TextureRegistered())
        {
            return -1;
        }

        texture_ = std::make_unique<flutter::TextureVariant>(flutter::PixelBufferTexture(
            [this](size_t width, size_t height) -> const FlutterDesktopPixelBuffer *
            {
                return this->ConvertPixelBufferForFlutter(width, height);
            }));

        texture_id_ = texture_registrar_->RegisterTexture(texture_.get());
        return texture_id_;
    }

    void TextureHandler::UnregisterTexture()
    {
        const std::lock_guard<std::mutex> lock(buffer_mutex_);
        if (texture_registrar_ && texture_id_ >= 0)
        {
            texture_registrar_->UnregisterTexture(texture_id_);
        }
        texture_id_ = -1;
        texture_ = nullptr;
    }

    void TextureHandler::UpdateBuffer(const unsigned char *rgbaData, int width, int height)
    {
        {
            const std::lock_guard<std::mutex> lock(buffer_mutex_);
            if (!TextureRegistered())
                return;

            size_t size = static_cast<size_t>(width) * height * 4;
            if (source_buffer_.size() != size)
            {
                source_buffer_.resize(size);
            }
            std::copy(rgbaData, rgbaData + size, source_buffer_.data());
            frame_width_ = static_cast<uint32_t>(width);
            frame_height_ = static_cast<uint32_t>(height);
        }

        if (TextureRegistered())
        {
            texture_registrar_->MarkTextureFrameAvailable(texture_id_);
        }
    }

    const FlutterDesktopPixelBuffer *TextureHandler::ConvertPixelBufferForFlutter(size_t target_width, size_t target_height)
    {
        // Lock the buffer mutex to protect texture processing. It is unlocked
        // by the release callback once Flutter is done with the buffer.
        std::unique_lock<std::mutex> buffer_lock(buffer_mutex_);
        if (!TextureRegistered() || source_buffer_.empty())
        {
            return nullptr;
        }

        if (!flutter_desktop_pixel_buffer_)
        {
            flutter_desktop_pixel_buffer_ = std::make_unique<FlutterDesktopPixelBuffer>();
            flutter_desktop_pixel_buffer_->release_callback = [](void *release_context)
            {
                auto mutex = reinterpret_cast<std::mutex *>(release_context);
                mutex->unlock();
            };
        }

        flutter_desktop_pixel_buffer_->buffer = source_buffer_.data();
        flutter_desktop_pixel_buffer_->width = frame_width_;
        flutter_desktop_pixel_buffer_->height = frame_height_;

        // Release the unique_lock and hand the mutex to the release callback.
        flutter_desktop_pixel_buffer_->release_context = buffer_lock.release();

        return flutter_desktop_pixel_buffer_.get();
    }

} // namespace flutter_lite_camera
