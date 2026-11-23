#include "texture_handler.h"

#include <algorithm>

namespace desktop_qr_camera
{

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

    void TextureHandler::Retire(std::shared_ptr<TextureHandler> handler)
    {
        int64_t texture_id;
        {
            // Waits for a paint in progress. Later paints find no texture.
            const std::lock_guard<std::mutex> lock(handler->buffer_mutex_);
            texture_id = handler->texture_id_;
            handler->texture_id_ = -1;
        }
        if (texture_id < 0)
        {
            return;
        }

        // Outside the lock: the registrar runs the callback at once when the
        // engine has stopped.
        handler->texture_registrar_->UnregisterTexture(texture_id, [handler]() {});
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

} // namespace desktop_qr_camera
