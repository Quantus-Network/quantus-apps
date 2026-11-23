#ifndef CAMERA_TEXTURE_H
#define CAMERA_TEXTURE_H

#include <flutter_linux/flutter_linux.h>

#include <cstdint>
#include <mutex>
#include <vector>

G_BEGIN_DECLS

#define CAMERA_TYPE_TEXTURE (camera_texture_get_type())
G_DECLARE_FINAL_TYPE(CameraTexture, camera_texture, CAMERA, TEXTURE, FlPixelBufferTexture)

CameraTexture *camera_texture_new();

G_END_DECLS

// C++ side of the texture. Kept behind a pointer because GObject instance
// memory is zero-initialized and C++ member constructors would not run.
struct CameraTextureBuffer
{
    std::mutex mutex;
    std::vector<uint8_t> latest;  // Written by the capture thread, RGBA8888
    std::vector<uint8_t> present; // Handed to Flutter in copy_pixels
    uint32_t width = 0;
    uint32_t height = 0;
    bool has_frame = false;
};

// Thread-safe; called from the camera capture thread.
void camera_texture_update_frame(CameraTexture *texture, const uint8_t *rgba, uint32_t width, uint32_t height);

#endif // CAMERA_TEXTURE_H
