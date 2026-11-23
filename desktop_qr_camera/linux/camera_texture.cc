#include "camera_texture.h"

#include <cstring>

struct _CameraTexture
{
    FlPixelBufferTexture parent_instance;
    CameraTextureBuffer *buffer;
};

G_DEFINE_TYPE(CameraTexture, camera_texture, fl_pixel_buffer_texture_get_type())

// Called on the Flutter raster thread. The returned buffer must stay valid
// until the next copy_pixels call, so pixels are copied into a dedicated
// presentation buffer that the capture thread never touches.
static gboolean camera_texture_copy_pixels(FlPixelBufferTexture *texture,
                                           const uint8_t **out_buffer,
                                           uint32_t *width, uint32_t *height,
                                           GError **error)
{
    CameraTexture *self = CAMERA_TEXTURE(texture);
    CameraTextureBuffer *fb = self->buffer;

    std::lock_guard<std::mutex> lock(fb->mutex);
    if (!fb->has_frame)
    {
        return FALSE;
    }

    fb->present = fb->latest;
    *out_buffer = fb->present.data();
    *width = fb->width;
    *height = fb->height;
    return TRUE;
}

static void camera_texture_dispose(GObject *object)
{
    CameraTexture *self = CAMERA_TEXTURE(object);
    delete self->buffer;
    self->buffer = nullptr;
    G_OBJECT_CLASS(camera_texture_parent_class)->dispose(object);
}

static void camera_texture_class_init(CameraTextureClass *klass)
{
    G_OBJECT_CLASS(klass)->dispose = camera_texture_dispose;
    FL_PIXEL_BUFFER_TEXTURE_CLASS(klass)->copy_pixels = camera_texture_copy_pixels;
}

static void camera_texture_init(CameraTexture *self)
{
    self->buffer = new CameraTextureBuffer();
}

CameraTexture *camera_texture_new()
{
    return CAMERA_TEXTURE(g_object_new(camera_texture_get_type(), nullptr));
}

void camera_texture_update_frame(CameraTexture *texture, const uint8_t *rgba, uint32_t width, uint32_t height)
{
    CameraTextureBuffer *fb = texture->buffer;
    std::lock_guard<std::mutex> lock(fb->mutex);

    size_t size = static_cast<size_t>(width) * height * 4;
    if (fb->latest.size() != size)
    {
        fb->latest.resize(size);
    }
    std::memcpy(fb->latest.data(), rgba, size);
    fb->width = width;
    fb->height = height;
    fb->has_frame = true;
}
