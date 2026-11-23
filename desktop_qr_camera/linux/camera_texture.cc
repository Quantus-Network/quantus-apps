#include "camera_texture.h"

#include "camera_texture_buffer.h"

// The buffer is behind a pointer because GObject instance memory is
// zero-initialized and C++ member constructors would not run.
struct _CameraTexture
{
    FlPixelBufferTexture parent_instance;
    CameraTextureBuffer *buffer;
};

G_DEFINE_TYPE(CameraTexture, camera_texture, fl_pixel_buffer_texture_get_type())

// Called on the Flutter raster thread.
static gboolean camera_texture_copy_pixels(FlPixelBufferTexture *texture,
                                           const uint8_t **out_buffer,
                                           uint32_t *width, uint32_t *height,
                                           GError **error)
{
    const PresentedFrame frame = CAMERA_TEXTURE(texture)->buffer->Present();
    *out_buffer = frame.rgba;
    *width = frame.width;
    *height = frame.height;
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
    texture->buffer->Update(rgba, width, height);
}
