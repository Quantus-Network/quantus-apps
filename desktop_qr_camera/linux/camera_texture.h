#ifndef CAMERA_TEXTURE_H
#define CAMERA_TEXTURE_H

#include <flutter_linux/flutter_linux.h>

#include <cstdint>

G_BEGIN_DECLS

#define CAMERA_TYPE_TEXTURE (camera_texture_get_type())
G_DECLARE_FINAL_TYPE(CameraTexture, camera_texture, CAMERA, TEXTURE, FlPixelBufferTexture)

CameraTexture *camera_texture_new();

G_END_DECLS

// Thread-safe; called from the camera capture thread.
void camera_texture_update_frame(CameraTexture *texture, const uint8_t *rgba, uint32_t width, uint32_t height);

// Forgets the last frame, so a new preview starts black.
void camera_texture_reset(CameraTexture *texture);

#endif // CAMERA_TEXTURE_H
