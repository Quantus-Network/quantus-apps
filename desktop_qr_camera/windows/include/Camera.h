#ifndef CAMERA_H
#define CAMERA_H

#include <vector>
#include <string>
#include <iostream>
#include <cstdint>
#include <atomic>
#include <functional>
#include <mutex>
#include <thread>

// Export macro for shared library
#ifdef _WIN32
#define CAMERA_API
#elif defined(__linux__) || defined(__APPLE__)
#define CAMERA_API __attribute__((visibility("default")))
#else
#define CAMERA_API
#endif

// Platform-specific includes
#ifdef _WIN32
#include <windows.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfobjects.h>
#include <mfreadwrite.h>
#include <wrl/client.h>
#include <dshow.h>

using Microsoft::WRL::ComPtr;
#elif __linux__
#include <linux/videodev2.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/mman.h>

struct Buffer
{
    void *start;
    size_t length;
};
#endif

// Struct definitions
struct CAMERA_API FrameData
{
    unsigned char *rgbData; // RGB pixel data
    int width;              // Frame width
    int height;             // Frame height
    size_t size;
};

struct CAMERA_API MediaTypeInfo
{
    uint32_t width;
    uint32_t height;
#ifdef _WIN32
    wchar_t subtypeName[512]; // Wide characters for Windows
#else
    char subtypeName[512]; // Narrow characters for Linux/macOS
#endif
};

struct CAMERA_API CaptureDeviceInfo
{

#ifdef _WIN32
    wchar_t friendlyName[512];
#else
    char friendlyName[512]; // Narrow characters for Linux/macOS
#endif
};

// Exported functions
CAMERA_API std::vector<CaptureDeviceInfo> ListCaptureDevices();
CAMERA_API void ReleaseFrame(FrameData &frame);
CAMERA_API void saveFrameAsJPEG(const unsigned char *data, int width, int height, const std::string &filename);

// Called from the capture thread for every streamed frame.
// rgbaData is RGBA8888 (4 bytes per pixel) and is only valid for the duration
// of the call.
typedef std::function<void(const unsigned char *rgbaData, int width, int height)> FrameCallback;

// Camera class
class CAMERA_API Camera
{
public:
#ifdef _WIN32
    Camera();
    ~Camera();
#elif __linux__
    Camera() : frameWidth(640), frameHeight(480), fd(-1), buffers(nullptr), bufferCount(0) {}
    ~Camera() { Release(); }
#elif __APPLE__
    Camera() noexcept; // Add noexcept to match the implementation
    ~Camera();
#endif

    bool Open(int cameraIndex);
    void Release();

    std::vector<MediaTypeInfo> ListSupportedMediaTypes();
    FrameData CaptureFrame();
    bool SetResolution(int width, int height);

    // Starts a background thread that continuously grabs frames, caches the
    // latest one for CaptureFrame(), and forwards every frame as RGBA to the
    // given callback. Returns false if the camera is not open.
    bool StartCaptureLoop(FrameCallback callback);
    void StopCaptureLoop();
    bool IsStreaming() const { return streaming.load(); }

    uint32_t frameWidth;
    uint32_t frameHeight;

private:
    void CaptureLoop();

    std::thread captureThread;
    std::atomic<bool> streaming{false};
    FrameCallback frameCallback;
    std::mutex cacheMutex;
    std::vector<unsigned char> cachedRgba; // Latest frame, RGBA8888

#ifdef _WIN32
    void *reader;
    ComPtr<IMFMediaSource> ms;
    bool initialized;
    void InitializeMediaFoundation();
    void ShutdownMediaFoundation();
#endif

#ifdef __linux__
    int fd;
    Buffer *buffers;
    unsigned int bufferCount;

    bool InitDevice();
    void UninitDevice();
    bool StartCapture();
    void StopCapture();
#endif

#ifdef __APPLE__
    void *captureSession; // AVFoundation session object
    void *videoOutput;
#endif
};

#endif // CAMERA_H
