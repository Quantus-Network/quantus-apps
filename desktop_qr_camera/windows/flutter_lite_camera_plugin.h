#ifndef FLUTTER_PLUGIN_FLUTTER_LITE_CAMERA_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_LITE_CAMERA_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/texture_registrar.h>

#include <memory>
#include "include/Camera.h"
#include "texture_handler.h"
namespace flutter_lite_camera
{

    class FlutterLiteCameraPlugin : public flutter::Plugin
    {
    public:
        static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

        explicit FlutterLiteCameraPlugin(flutter::TextureRegistrar *texture_registrar);

        virtual ~FlutterLiteCameraPlugin();

        // Disallow copy and assign.
        FlutterLiteCameraPlugin(const FlutterLiteCameraPlugin &) = delete;
        FlutterLiteCameraPlugin &operator=(const FlutterLiteCameraPlugin &) = delete;

        // Called when a method is called on this plugin's channel from Dart.
        void HandleMethodCall(
            const flutter::MethodCall<flutter::EncodableValue> &method_call,
            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    private:
        void StopPreview();

        Camera *camera;
        flutter::TextureRegistrar *texture_registrar_;
        std::unique_ptr<TextureHandler> texture_handler_;
    };

} // namespace flutter_lite_camera

#endif // FLUTTER_PLUGIN_FLUTTER_LITE_CAMERA_PLUGIN_H_
