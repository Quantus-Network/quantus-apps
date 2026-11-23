#include "include/Camera.h"
#include "include/flutter_lite_camera/flutter_lite_camera_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>

#include "flutter_lite_camera_plugin_private.h"
#include "camera_texture.h"

#define FLUTTER_LITE_CAMERA_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), flutter_lite_camera_plugin_get_type(), \
                              FlutterLiteCameraPlugin))

struct _FlutterLiteCameraPlugin
{
  GObject parent_instance;
  Camera *camera;
  FlTextureRegistrar *texture_registrar;
  CameraTexture *texture;
  int64_t texture_id;
  gint mark_pending;
};

G_DEFINE_TYPE(FlutterLiteCameraPlugin, flutter_lite_camera_plugin, g_object_get_type())

// Runs on the main thread; scheduled from the capture thread via g_idle_add.
static gboolean mark_frame_available_cb(gpointer user_data)
{
  FlutterLiteCameraPlugin *self = FLUTTER_LITE_CAMERA_PLUGIN(user_data);
  if (self->texture_registrar != nullptr && self->texture != nullptr)
  {
    fl_texture_registrar_mark_texture_frame_available(self->texture_registrar, FL_TEXTURE(self->texture));
  }
  g_atomic_int_set(&self->mark_pending, 0);
  return G_SOURCE_REMOVE;
}

static void stop_preview(FlutterLiteCameraPlugin *self)
{
  // Join the capture thread first so no frame callback can run while the
  // texture is being torn down.
  self->camera->StopCaptureLoop();

  if (self->texture_registrar != nullptr && self->texture != nullptr)
  {
    fl_texture_registrar_unregister_texture(self->texture_registrar, FL_TEXTURE(self->texture));
    self->texture_id = -1;
  }
  g_clear_object(&self->texture);
}

// Called when a method call is received from Flutter.
static void flutter_lite_camera_plugin_handle_method_call(
    FlutterLiteCameraPlugin *self,
    FlMethodCall *method_call)
{
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar *method = fl_method_call_get_name(method_call);

  if (strcmp(method, "getPlatformVersion") == 0)
  {
    response = get_platform_version();
  }
  else if (strcmp(method, "getDeviceList") == 0)
  {
    std::vector<CaptureDeviceInfo> devices = ListCaptureDevices();
    FlValue *deviceList = fl_value_new_list();
    for (const auto &device : devices)
    {
      FlValue *deviceName = fl_value_new_string(device.friendlyName);
      fl_value_append_take(deviceList, deviceName);
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(deviceList));
  }

  else if (strcmp(method, "saveJpeg") == 0)
  {
    FlValue *args = fl_method_call_get_args(method_call);
    if (fl_value_get_type(args) == FL_VALUE_TYPE_LIST && fl_value_get_length(args) == 4)
    {
      FlValue *filename = fl_value_get_list_value(args, 0);
      FlValue *width = fl_value_get_list_value(args, 1);
      FlValue *height = fl_value_get_list_value(args, 2);
      FlValue *data = fl_value_get_list_value(args, 3);

      if (fl_value_get_type(filename) == FL_VALUE_TYPE_STRING &&
          fl_value_get_type(width) == FL_VALUE_TYPE_INT &&
          fl_value_get_type(height) == FL_VALUE_TYPE_INT &&
          fl_value_get_type(data) == FL_VALUE_TYPE_UINT8_LIST)
      {
        const char *filename_str = fl_value_get_string(filename);
        int width_int = fl_value_get_int(width);
        int height_int = fl_value_get_int(height);
        const uint8_t *bytes = fl_value_get_uint8_list(data);

        saveFrameAsJPEG(bytes, width_int, height_int, filename_str);
        response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
      }
      else
      {
        response = FL_METHOD_RESPONSE(fl_method_error_response_new("INVALID_ARGUMENTS", "Arguments have incorrect types", nullptr));
      }
    }
    else
    {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new("INVALID_ARGUMENTS", "Expected a list with 4 elements", nullptr));
    }
  }

  else if (strcmp(method, "open") == 0)
  {
    FlValue *args = fl_method_call_get_args(method_call);
    FlValue *index = fl_value_get_list_value(args, 0);

    if (index)
    {
      int index_int = fl_value_get_int(index);
      stop_preview(self);
      bool success = self->camera->Open(index_int);
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(success)));
    }
    else
    {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new("INVALID_ARGUMENTS", "Expected camera index", nullptr));
    }
  }
  else if (strcmp(method, "listMediaTypes") == 0)
  {
    auto mediaTypes = self->camera->ListSupportedMediaTypes();
    g_autoptr(FlValue) mediaTypeList = fl_value_new_list();

    for (const auto &mediaType : mediaTypes)
    {
      g_autoptr(FlValue) mediaTypeMap = fl_value_new_map();
      fl_value_set_string_take(mediaTypeMap, "width", fl_value_new_int(mediaType.width));
      fl_value_set_string_take(mediaTypeMap, "height", fl_value_new_int(mediaType.height));
      fl_value_set_string_take(mediaTypeMap, "format", fl_value_new_string(mediaType.subtypeName));
      fl_value_append_take(mediaTypeList, mediaTypeMap);
    }

    response = FL_METHOD_RESPONSE(fl_method_success_response_new(mediaTypeList));
  }
  else if (strcmp(method, "setResolution") == 0)
  {
    FlValue *args = fl_method_call_get_args(method_call);
    int width_int = 0;
    int height_int = 0;
    bool have_size = false;

    // Accept the standard [width, height] list used by every other platform,
    // and the legacy {width, height} map for backward compatibility.
    if (fl_value_get_type(args) == FL_VALUE_TYPE_LIST && fl_value_get_length(args) == 2)
    {
      width_int = fl_value_get_int(fl_value_get_list_value(args, 0));
      height_int = fl_value_get_int(fl_value_get_list_value(args, 1));
      have_size = true;
    }
    else if (fl_value_get_type(args) == FL_VALUE_TYPE_MAP)
    {
      FlValue *width = fl_value_lookup_string(args, "width");
      FlValue *height = fl_value_lookup_string(args, "height");
      if (width && height)
      {
        width_int = fl_value_get_int(width);
        height_int = fl_value_get_int(height);
        have_size = true;
      }
    }

    if (have_size)
    {
      bool success = self->camera->SetResolution(width_int, height_int);
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(success)));
    }
    else
    {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new("INVALID_ARGUMENTS", "Expected width and height", nullptr));
    }
  }
  else if (strcmp(method, "startPreview") == 0)
  {
    if (self->texture != nullptr && self->texture_id >= 0)
    {
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_int(self->texture_id)));
    }
    else
    {
      self->texture = camera_texture_new();
      if (!fl_texture_registrar_register_texture(self->texture_registrar, FL_TEXTURE(self->texture)))
      {
        g_clear_object(&self->texture);
        response = FL_METHOD_RESPONSE(fl_method_error_response_new("TEXTURE_ERROR", "Failed to register texture", nullptr));
      }
      else
      {
        self->texture_id = fl_texture_get_id(FL_TEXTURE(self->texture));

        FlutterLiteCameraPlugin *plugin = self;
        bool started = self->camera->StartCaptureLoop(
            [plugin](const unsigned char *rgbaData, int width, int height)
            {
              camera_texture_update_frame(plugin->texture, rgbaData,
                                          static_cast<uint32_t>(width),
                                          static_cast<uint32_t>(height));
              // fl_texture_registrar_* must be called on the main thread.
              if (g_atomic_int_compare_and_exchange(&plugin->mark_pending, 0, 1))
              {
                g_idle_add(mark_frame_available_cb, plugin);
              }
            });

        if (!started)
        {
          fl_texture_registrar_unregister_texture(self->texture_registrar, FL_TEXTURE(self->texture));
          g_clear_object(&self->texture);
          self->texture_id = -1;
          response = FL_METHOD_RESPONSE(fl_method_error_response_new("CAMERA_ERROR", "Failed to start preview. Is the camera open?", nullptr));
        }
        else
        {
          response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_int(self->texture_id)));
        }
      }
    }
  }
  else if (strcmp(method, "stopPreview") == 0)
  {
    stop_preview(self);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }
  else if (strcmp(method, "captureFrame") == 0)
  {
    FrameData frame = self->camera->CaptureFrame();
    if (frame.rgbData == nullptr)
    {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new("CAPTURE_FAILED", "No frame data available", nullptr));
    }
    else
    {
      FlValue *frameData = fl_value_new_map();
      fl_value_set_take(frameData, fl_value_new_string("width"), fl_value_new_int(frame.width));
      fl_value_set_take(frameData, fl_value_new_string("height"), fl_value_new_int(frame.height));

      FlValue *rgbData = fl_value_new_uint8_list(frame.rgbData, frame.size);
      fl_value_set_take(frameData, fl_value_new_string("data"), rgbData);
      ReleaseFrame(frame);
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(frameData));
    }
  }
  else if (strcmp(method, "release") == 0)
  {
    stop_preview(self);
    self->camera->Release();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }
  else if (strcmp(method, "getWidth") == 0)
  {
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_int(self->camera->frameWidth)));
  }
  else if (strcmp(method, "getHeight") == 0)
  {
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_int(self->camera->frameHeight)));
  }
  else if (strcmp(method, "getRotation") == 0)
  {
    // Desktop cameras are exposed in landscape window orientation; no
    // rotation is needed.
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_int(0)));
  }
  else
  {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  if (response == nullptr)
  {
    response = FL_METHOD_RESPONSE(fl_method_error_response_new("INTERNAL_ERROR", "Unexpected error", nullptr));
  }

  fl_method_call_respond(method_call, response, nullptr);
}

FlMethodResponse *get_platform_version()
{
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar *version = g_strdup_printf("Linux %s", uname_data.version);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static void flutter_lite_camera_plugin_dispose(GObject *object)
{
  FlutterLiteCameraPlugin *self = FLUTTER_LITE_CAMERA_PLUGIN(object);
  stop_preview(self);
  delete self->camera;
  g_clear_object(&self->texture_registrar);
  G_OBJECT_CLASS(flutter_lite_camera_plugin_parent_class)->dispose(object);
}

static void flutter_lite_camera_plugin_class_init(FlutterLiteCameraPluginClass *klass)
{
  G_OBJECT_CLASS(klass)->dispose = flutter_lite_camera_plugin_dispose;
}

static void flutter_lite_camera_plugin_init(FlutterLiteCameraPlugin *self)
{
  self->camera = new Camera();
  self->texture_registrar = nullptr;
  self->texture = nullptr;
  self->texture_id = -1;
  self->mark_pending = 0;
}

static void method_call_cb(FlMethodChannel *channel, FlMethodCall *method_call,
                           gpointer user_data)
{
  FlutterLiteCameraPlugin *plugin = FLUTTER_LITE_CAMERA_PLUGIN(user_data);
  flutter_lite_camera_plugin_handle_method_call(plugin, method_call);
}

void flutter_lite_camera_plugin_register_with_registrar(FlPluginRegistrar *registrar)
{
  FlutterLiteCameraPlugin *plugin = FLUTTER_LITE_CAMERA_PLUGIN(
      g_object_new(flutter_lite_camera_plugin_get_type(), nullptr));

  plugin->texture_registrar = FL_TEXTURE_REGISTRAR(
      g_object_ref(fl_plugin_registrar_get_texture_registrar(registrar)));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "flutter_lite_camera",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
