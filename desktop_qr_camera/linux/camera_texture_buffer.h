#ifndef CAMERA_TEXTURE_BUFFER_H
#define CAMERA_TEXTURE_BUFFER_H

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <mutex>
#include <vector>

struct PresentedFrame
{
    const uint8_t *rgba;
    uint32_t width;
    uint32_t height;
};

// Holds the newest camera frame for the texture. Free of GTK so it can be
// tested without a display.
class CameraTextureBuffer
{
public:
    // Thread-safe; called from the camera capture thread.
    void Update(const uint8_t *rgba, uint32_t width, uint32_t height)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        const size_t size = static_cast<size_t>(width) * height * 4;
        if (latest_.size() != size)
        {
            latest_.resize(size);
        }
        std::memcpy(latest_.data(), rgba, size);
        width_ = width;
        height_ = height;
        has_frame_ = true;
    }

    // Forgets the last frame so a new preview does not start on it. Leaves the
    // presented pixels alone, as the raster thread may still be reading them.
    void Reset()
    {
        std::lock_guard<std::mutex> lock(mutex_);
        has_frame_ = false;
    }

    // Called on the Flutter raster thread. The returned pixels stay valid until
    // the next call, because the capture thread never touches them. Flutter
    // paints before the first camera frame and crashes on a texture that reports
    // no pixels without an error, so until then this is one black pixel.
    PresentedFrame Present()
    {
        std::lock_guard<std::mutex> lock(mutex_);
        if (!has_frame_)
        {
            present_.assign({0, 0, 0, 255});
            return {present_.data(), 1, 1};
        }
        present_ = latest_;
        return {present_.data(), width_, height_};
    }

private:
    std::mutex mutex_;
    std::vector<uint8_t> latest_;  // Written by the capture thread, RGBA8888
    std::vector<uint8_t> present_; // Handed to Flutter
    uint32_t width_ = 0;
    uint32_t height_ = 0;
    bool has_frame_ = false;
};

#endif // CAMERA_TEXTURE_BUFFER_H
