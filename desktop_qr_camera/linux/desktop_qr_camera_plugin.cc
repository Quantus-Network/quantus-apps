#include "include/desktop_qr_camera/desktop_qr_camera_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <cstring>

#include "camera.h"
#include "camera_texture.h"

using desktop_qr_camera::Camera;
using desktop_qr_camera::CameraStatus;
using desktop_qr_camera::CameraStatusCode;
using desktop_qr_camera::LumaFrame;

#define DESKTOP_QR_CAMERA_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), desktop_qr_camera_plugin_get_type(), DesktopQrCameraPlugin))

struct _DesktopQrCameraPlugin {
  GObject parent_instance;
  Camera* camera;
  FlTextureRegistrar* texture_registrar;
  // Reused by every preview and never freed. The raster thread reads a texture
  // without holding a reference and Linux offers no way to wait for it, so
  // freeing one after unregistering could pull it out from under a paint.
  CameraTexture* texture;
  gboolean texture_registered;
  gint mark_pending;
};

G_DEFINE_TYPE(DesktopQrCameraPlugin, desktop_qr_camera_plugin, g_object_get_type())

// Runs on the main thread; scheduled from the capture thread via g_idle_add,
// which holds a reference to the plugin until it has run.
static gboolean mark_frame_available_cb(gpointer user_data) {
  DesktopQrCameraPlugin* self = DESKTOP_QR_CAMERA_PLUGIN(user_data);
  if (self->texture_registrar != nullptr && self->texture_registered) {
    fl_texture_registrar_mark_texture_frame_available(self->texture_registrar, FL_TEXTURE(self->texture));
  }
  g_atomic_int_set(&self->mark_pending, 0);
  return G_SOURCE_REMOVE;
}

static void release_camera(DesktopQrCameraPlugin* self) {
  // The capture thread ends first, so no frame can reach a texture being torn
  // down.
  if (self->camera != nullptr) self->camera->Release();

  if (self->texture_registrar != nullptr && self->texture_registered) {
    fl_texture_registrar_unregister_texture(self->texture_registrar, FL_TEXTURE(self->texture));
    self->texture_registered = FALSE;
  }
}

static FlMethodResponse* error_response(CameraStatus status, const char* message = nullptr) {
  return FL_METHOD_RESPONSE(fl_method_error_response_new(CameraStatusCode(status), message, nullptr));
}

static FlMethodResponse* start_preview(DesktopQrCameraPlugin* self) {
  if (self->texture_registered) {
    return error_response(CameraStatus::kFailed, "The preview is already running");
  }

  // Set before the capture thread starts, which reads it through the plugin.
  if (self->texture == nullptr) self->texture = camera_texture_new();
  camera_texture_reset(self->texture);
  if (!fl_texture_registrar_register_texture(self->texture_registrar, FL_TEXTURE(self->texture))) {
    return error_response(CameraStatus::kFailed, "Failed to register texture");
  }
  self->texture_registered = TRUE;

  CameraTexture* frames = self->texture;
  DesktopQrCameraPlugin* plugin = self;
  const bool started = self->camera->StartCaptureLoop([plugin, frames](const uint8_t* rgba, uint32_t width,
                                                                       uint32_t height) {
    camera_texture_update_frame(frames, rgba, width, height);
    // fl_texture_registrar_* must be called on the main thread.
    if (g_atomic_int_compare_and_exchange(&plugin->mark_pending, 0, 1)) {
      g_idle_add_full(G_PRIORITY_DEFAULT_IDLE, mark_frame_available_cb, g_object_ref(plugin), g_object_unref);
    }
  });
  if (!started) {
    fl_texture_registrar_unregister_texture(self->texture_registrar, FL_TEXTURE(self->texture));
    self->texture_registered = FALSE;
    return error_response(CameraStatus::kFailed, "The camera is not open");
  }

  g_autoptr(FlValue) id = fl_value_new_int(fl_texture_get_id(FL_TEXTURE(self->texture)));
  return FL_METHOD_RESPONSE(fl_method_success_response_new(id));
}

static FlMethodResponse* capture_frame(DesktopQrCameraPlugin* self) {
  LumaFrame frame = self->camera->CaptureFrame();
  if (frame.status != CameraStatus::kOk) return error_response(frame.status);
  if (frame.luma.empty()) return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));

  g_autoptr(FlValue) answer = fl_value_new_map();
  fl_value_set_string_take(answer, "width", fl_value_new_int(frame.width));
  fl_value_set_string_take(answer, "height", fl_value_new_int(frame.height));
  fl_value_set_string_take(answer, "luma", fl_value_new_uint8_list(frame.luma.data(), frame.luma.size()));
  return FL_METHOD_RESPONSE(fl_method_success_response_new(answer));
}

// Called when a method call is received from Flutter.
static void desktop_qr_camera_plugin_handle_method_call(DesktopQrCameraPlugin* self, FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;
  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "open") == 0) {
    release_camera(self);
    const CameraStatus status = self->camera->Open();
    response = status == CameraStatus::kOk ? FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr))
                                           : error_response(status);
  } else if (strcmp(method, "startPreview") == 0) {
    response = start_preview(self);
  } else if (strcmp(method, "captureFrame") == 0) {
    response = capture_frame(self);
  } else if (strcmp(method, "release") == 0) {
    release_camera(self);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void desktop_qr_camera_plugin_dispose(GObject* object) {
  DesktopQrCameraPlugin* self = DESKTOP_QR_CAMERA_PLUGIN(object);
  release_camera(self);
  delete self->camera;
  self->camera = nullptr;
  g_clear_object(&self->texture_registrar);
  G_OBJECT_CLASS(desktop_qr_camera_plugin_parent_class)->dispose(object);
}

static void desktop_qr_camera_plugin_class_init(DesktopQrCameraPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = desktop_qr_camera_plugin_dispose;
}

static void desktop_qr_camera_plugin_init(DesktopQrCameraPlugin* self) {
  self->camera = new Camera();
  self->texture_registrar = nullptr;
  self->texture = nullptr;
  self->texture_registered = FALSE;
  self->mark_pending = 0;
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call, gpointer user_data) {
  DesktopQrCameraPlugin* plugin = DESKTOP_QR_CAMERA_PLUGIN(user_data);
  desktop_qr_camera_plugin_handle_method_call(plugin, method_call);
}

void desktop_qr_camera_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  DesktopQrCameraPlugin* plugin =
      DESKTOP_QR_CAMERA_PLUGIN(g_object_new(desktop_qr_camera_plugin_get_type(), nullptr));

  plugin->texture_registrar = FL_TEXTURE_REGISTRAR(g_object_ref(fl_plugin_registrar_get_texture_registrar(registrar)));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                                                             "desktop_qr_camera", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb, g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}
