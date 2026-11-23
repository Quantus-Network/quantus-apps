#include "include/Camera.h"
#include <iostream>
#include <vector>
#include <string>
#include <map>
#include <cstring>
#include <poll.h>

unsigned char clamp(double value, double min, double max)
{
    if (value < min)
        return static_cast<unsigned char>(min);
    if (value > max)
        return static_cast<unsigned char>(max);
    return static_cast<unsigned char>(value);
}

void ConvertYUY2ToRGB(const unsigned char *yuy2Data, unsigned char *rgbData, int width, int height)
{
    int rgbIndex = 0;
    for (int i = 0; i < width * height * 2; i += 4)
    {
        // Extract YUV values
        unsigned char y1 = yuy2Data[i];
        unsigned char u = yuy2Data[i + 1];
        unsigned char y2 = yuy2Data[i + 2];
        unsigned char v = yuy2Data[i + 3];

        rgbData[rgbIndex++] = clamp(y1 + 1.402 * (v - 128), 0.0, 255.0);
        rgbData[rgbIndex++] = clamp(y1 - 0.344136 * (u - 128) - 0.714136 * (v - 128), 0.0, 255.0);
        rgbData[rgbIndex++] = clamp(y1 + 1.772 * (u - 128), 0.0, 255.0);

        // Convert second pixel (Y2, U, V) to RGB
        rgbData[rgbIndex++] = clamp(y2 + 1.402 * (v - 128), 0.0, 255.0);
        rgbData[rgbIndex++] = clamp(y2 - 0.344136 * (u - 128) - 0.714136 * (v - 128), 0.0, 255.0);
        rgbData[rgbIndex++] = clamp(y2 + 1.772 * (u - 128), 0.0, 255.0);
    }
}

void ConvertYUY2ToRGBA(const unsigned char *yuy2Data, unsigned char *rgbaData, int width, int height)
{
    int rgbaIndex = 0;
    for (int i = 0; i < width * height * 2; i += 4)
    {
        unsigned char y1 = yuy2Data[i];
        unsigned char u = yuy2Data[i + 1];
        unsigned char y2 = yuy2Data[i + 2];
        unsigned char v = yuy2Data[i + 3];

        rgbaData[rgbaIndex++] = clamp(y1 + 1.402 * (v - 128), 0.0, 255.0);
        rgbaData[rgbaIndex++] = clamp(y1 - 0.344136 * (u - 128) - 0.714136 * (v - 128), 0.0, 255.0);
        rgbaData[rgbaIndex++] = clamp(y1 + 1.772 * (u - 128), 0.0, 255.0);
        rgbaData[rgbaIndex++] = 255;

        rgbaData[rgbaIndex++] = clamp(y2 + 1.402 * (v - 128), 0.0, 255.0);
        rgbaData[rgbaIndex++] = clamp(y2 - 0.344136 * (u - 128) - 0.714136 * (v - 128), 0.0, 255.0);
        rgbaData[rgbaIndex++] = clamp(y2 + 1.772 * (u - 128), 0.0, 255.0);
        rgbaData[rgbaIndex++] = 255;
    }
}

bool Camera::Open(int cameraIndex)
{
    std::string devicePath = "/dev/video" + std::to_string(cameraIndex);
    fd = open(devicePath.c_str(), O_RDWR);
    if (fd < 0)
    {
        perror("Error opening video device");
        return false;
    }

    struct v4l2_capability cap;
    if (ioctl(fd, VIDIOC_QUERYCAP, &cap) < 0)
    {
        perror("Error querying device capabilities");
        close(fd);
        return false;
    }

    std::cout << "Driver: " << cap.driver << "\nCard: " << cap.card << std::endl;

    struct v4l2_format fmt;
    memset(&fmt, 0, sizeof(fmt));
    fmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    fmt.fmt.pix.width = frameWidth;
    fmt.fmt.pix.height = frameHeight;
    fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_YUYV;

    if (ioctl(fd, VIDIOC_S_FMT, &fmt) < 0)
    {
        perror("Error setting resolution");
        return false;
    }

    // The driver may negotiate a different resolution than requested; keep
    // the members in sync with what was actually granted.
    frameWidth = fmt.fmt.pix.width;
    frameHeight = fmt.fmt.pix.height;

    if (!InitDevice() || !StartCapture())
    {
        Release();
        return false;
    }

    return true;
}

void Camera::Release()
{
    StopCaptureLoop();

    {
        std::lock_guard<std::mutex> lock(cacheMutex);
        cachedRgba.clear();
        cachedRgba.shrink_to_fit();
    }

    StopCapture();
    UninitDevice();
    if (fd >= 0)
    {
        close(fd);
        fd = -1;
    }
}

bool Camera::StartCaptureLoop(FrameCallback callback)
{
    if (fd < 0 || streaming.load())
        return false;

    frameCallback = std::move(callback);
    streaming.store(true);
    captureThread = std::thread(&Camera::CaptureLoop, this);
    return true;
}

void Camera::StopCaptureLoop()
{
    streaming.store(false);
    if (captureThread.joinable())
    {
        captureThread.join();
    }
    frameCallback = nullptr;
}

void Camera::CaptureLoop()
{
    std::vector<unsigned char> rgba(static_cast<size_t>(frameWidth) * frameHeight * 4);

    while (streaming.load())
    {
        // Wait for a frame with a timeout so StopCaptureLoop() stays responsive.
        struct pollfd pfd;
        pfd.fd = fd;
        pfd.events = POLLIN;
        pfd.revents = 0;

        int ready = poll(&pfd, 1, 200);
        if (ready <= 0 || !(pfd.revents & POLLIN))
            continue;

        struct v4l2_buffer buf;
        memset(&buf, 0, sizeof(buf));
        buf.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
        buf.memory = V4L2_MEMORY_MMAP;

        if (ioctl(fd, VIDIOC_DQBUF, &buf) < 0)
        {
            if (streaming.load())
            {
                perror("Capture loop: failed to dequeue buffer");
            }
            break;
        }

        ConvertYUY2ToRGBA(reinterpret_cast<unsigned char *>(buffers[buf.index].start), rgba.data(), frameWidth, frameHeight);

        if (ioctl(fd, VIDIOC_QBUF, &buf) < 0)
        {
            perror("Capture loop: failed to queue buffer");
        }

        {
            std::lock_guard<std::mutex> lock(cacheMutex);
            cachedRgba = rgba;
        }

        if (frameCallback)
        {
            frameCallback(rgba.data(), (int)frameWidth, (int)frameHeight);
        }
    }

    streaming.store(false);
}

bool Camera::SetResolution(int width, int height)
{
    if (fd == -1)
    {
        std::cerr << "Device not opened." << std::endl;
        return false;
    }

    // Changing the format while buffers are queued and the stream is on is
    // unsafe: the mmap'd buffers are sized for the old format and the
    // capture loop converts with frameWidth/frameHeight, so a mid-stream
    // switch reads/writes out of bounds. Tear the pipeline down first and
    // rebuild it at the new size.
    bool wasStreaming = streaming.load();
    FrameCallback savedCallback = frameCallback;
    if (wasStreaming)
    {
        StopCaptureLoop();
    }

    uint32_t oldWidth = frameWidth;
    uint32_t oldHeight = frameHeight;

    StopCapture();  // STREAMOFF
    UninitDevice(); // munmap

    // Free the driver-side buffers; most drivers require this before S_FMT
    // with a different size.
    struct v4l2_requestbuffers req;
    memset(&req, 0, sizeof(req));
    req.count = 0;
    req.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    req.memory = V4L2_MEMORY_MMAP;
    ioctl(fd, VIDIOC_REQBUFS, &req);

    struct v4l2_format fmt;
    memset(&fmt, 0, sizeof(fmt));
    fmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    fmt.fmt.pix.width = width;
    fmt.fmt.pix.height = height;
    fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_YUYV;

    bool success = false;
    if (ioctl(fd, VIDIOC_S_FMT, &fmt) == 0)
    {
        // Save the actual resolution set by the device
        frameWidth = fmt.fmt.pix.width;
        frameHeight = fmt.fmt.pix.height;
        success = InitDevice() && StartCapture();
    }

    if (!success)
    {
        // Roll back to the previous format so the camera keeps working.
        memset(&fmt, 0, sizeof(fmt));
        fmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
        fmt.fmt.pix.width = oldWidth;
        fmt.fmt.pix.height = oldHeight;
        fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_YUYV;
        if (ioctl(fd, VIDIOC_S_FMT, &fmt) == 0)
        {
            frameWidth = fmt.fmt.pix.width;
            frameHeight = fmt.fmt.pix.height;
            if (InitDevice() && StartCapture() && wasStreaming)
            {
                StartCaptureLoop(savedCallback);
            }
        }
        return false;
    }

    {
        std::lock_guard<std::mutex> lock(cacheMutex);
        cachedRgba.clear(); // discard stale frames at the old size
    }

    if (wasStreaming)
    {
        StartCaptureLoop(savedCallback);
    }

    return true;
}

FrameData Camera::CaptureFrame()
{
    // While the preview stream is running, serve the latest cached frame
    // instead of dequeuing a new buffer.
    if (streaming.load())
    {
        FrameData frame;
        frame.width = frameWidth;
        frame.height = frameHeight;
        frame.rgbData = nullptr;

        std::lock_guard<std::mutex> lock(cacheMutex);
        if (cachedRgba.empty())
        {
            return frame;
        }

        frame.size = static_cast<size_t>(frameWidth) * frameHeight * 3;
        frame.rgbData = new unsigned char[frame.size];

        const unsigned char *src = cachedRgba.data();
        unsigned char *dst = frame.rgbData;
        for (size_t i = 0, j = 0; j < frame.size; i += 4, j += 3)
        {
            dst[j] = src[i];
            dst[j + 1] = src[i + 1];
            dst[j + 2] = src[i + 2];
        }
        return frame;
    }

    struct v4l2_buffer buf;
    memset(&buf, 0, sizeof(buf));
    buf.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    buf.memory = V4L2_MEMORY_MMAP;

    // Dequeue a buffer from the video capture queue
    if (ioctl(fd, VIDIOC_DQBUF, &buf) < 0)
    {
        perror("Failed to dequeue buffer");
        return {};
    }

    // FILE *file = fopen("raw_frame.yuyv", "wb");
    // fwrite(buffers[buf.index].start, 1, buffers[buf.index].length, file);
    // fclose(file);

    // Prepare FrameData structure
    FrameData frame;
    frame.width = frameWidth;
    frame.height = frameHeight;
    frame.size = frameWidth * frameHeight * 3; // 3 bytes per pixel (RGB)
    frame.rgbData = new unsigned char[frame.size];

    // Convert YUYV to RGB
    ConvertYUY2ToRGB(reinterpret_cast<unsigned char *>(buffers[buf.index].start), frame.rgbData, frameWidth, frameHeight);

    // Requeue the buffer
    if (ioctl(fd, VIDIOC_QBUF, &buf) < 0)
    {
        perror("Failed to queue buffer");
    }

    return frame;
}

bool Camera::InitDevice()
{
    struct v4l2_requestbuffers req;
    memset(&req, 0, sizeof(req));
    req.count = 4;
    req.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    req.memory = V4L2_MEMORY_MMAP;

    if (ioctl(fd, VIDIOC_REQBUFS, &req) < 0)
    {
        perror("Failed to request buffers");
        return false;
    }

    buffers = new Buffer[req.count];
    bufferCount = req.count;

    for (unsigned int i = 0; i < bufferCount; ++i)
    {
        struct v4l2_buffer buf;
        memset(&buf, 0, sizeof(buf));
        buf.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
        buf.memory = V4L2_MEMORY_MMAP;
        buf.index = i;

        if (ioctl(fd, VIDIOC_QUERYBUF, &buf) < 0)
        {
            perror("Failed to query buffer");
            return false;
        }

        buffers[i].length = buf.length;
        buffers[i].start = mmap(nullptr, buf.length, PROT_READ | PROT_WRITE, MAP_SHARED, fd, buf.m.offset);

        if (buffers[i].start == MAP_FAILED)
        {
            perror("Failed to map buffer");
            return false;
        }

        if (ioctl(fd, VIDIOC_QBUF, &buf) < 0)
        {
            perror("Failed to queue buffer");
            return false;
        }
    }
    return true;
}

void Camera::UninitDevice()
{
    if (buffers)
    {
        for (unsigned int i = 0; i < bufferCount; ++i)
        {
            munmap(buffers[i].start, buffers[i].length);
        }
        delete[] buffers;
        buffers = nullptr;
    }
}

bool Camera::StartCapture()
{
    enum v4l2_buf_type type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    return ioctl(fd, VIDIOC_STREAMON, &type) >= 0;
}

void Camera::StopCapture()
{
    enum v4l2_buf_type type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    ioctl(fd, VIDIOC_STREAMOFF, &type);
}

std::vector<MediaTypeInfo> Camera::ListSupportedMediaTypes()
{
    std::vector<MediaTypeInfo> mediaTypes;

    if (fd == -1)
    {
        std::cerr << "Device not opened.\n";
        return mediaTypes;
    }

    struct v4l2_fmtdesc fmt;
    memset(&fmt, 0, sizeof(fmt));
    fmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;

    while (ioctl(fd, VIDIOC_ENUM_FMT, &fmt) == 0)
    {
        struct v4l2_frmsizeenum frmsize;
        memset(&frmsize, 0, sizeof(frmsize));
        frmsize.pixel_format = fmt.pixelformat;

        // Iterate over supported frame sizes for this format
        while (ioctl(fd, VIDIOC_ENUM_FRAMESIZES, &frmsize) == 0)
        {
            MediaTypeInfo info = {};
            info.width = 0;
            info.height = 0;

            // Handle discrete frame sizes
            if (frmsize.type == V4L2_FRMSIZE_TYPE_DISCRETE)
            {
                info.width = frmsize.discrete.width;
                info.height = frmsize.discrete.height;
            }
            // Handle stepwise frame sizes
            else if (frmsize.type == V4L2_FRMSIZE_TYPE_STEPWISE)
            {
                // Use the minimum resolution as an example
                info.width = frmsize.stepwise.min_width;
                info.height = frmsize.stepwise.min_height;
            }

            // Copy the format description
            strncpy(info.subtypeName, reinterpret_cast<const char *>(fmt.description), sizeof(info.subtypeName) - 1);
            info.subtypeName[sizeof(info.subtypeName) - 1] = '\0'; // Ensure null-termination

            mediaTypes.push_back(info);
            frmsize.index++;
        }

        fmt.index++;
    }

    if (mediaTypes.empty())
    {
        std::cerr << "No supported media types found.\n";
    }

    return mediaTypes;
}

std::vector<CaptureDeviceInfo> ListCaptureDevices()
{
    std::vector<CaptureDeviceInfo> devices;

    // Scan for /dev/videoX devices
    for (int i = 0; i < 10; ++i) // Check first 10 devices (can be increased if needed)
    {
        std::string devicePath = "/dev/video" + std::to_string(i);

        // Open the device
        int fd = open(devicePath.c_str(), O_RDWR | O_NONBLOCK, 0);
        if (fd == -1)
        {
            continue; // Skip if the device cannot be opened
        }

        // Query device capabilities
        struct v4l2_capability cap;
        if (ioctl(fd, VIDIOC_QUERYCAP, &cap) == 0)
        {
            // Check if it's a video capture device
            if (cap.capabilities & V4L2_CAP_VIDEO_CAPTURE)
            {
                CaptureDeviceInfo deviceInfo = {};

                // Copy the friendly name directly into the `friendlyName` buffer
                strncpy(deviceInfo.friendlyName, reinterpret_cast<const char *>(cap.card), sizeof(deviceInfo.friendlyName) - 1);

                // Null-terminate the friendlyName string
                deviceInfo.friendlyName[sizeof(deviceInfo.friendlyName) - 1] = '\0';

                devices.push_back(deviceInfo);
            }
        }

        // Close the device
        close(fd);
    }

    return devices;
}

void ReleaseFrame(FrameData &frame)
{
    if (frame.rgbData)
    {
        delete[] frame.rgbData;
        frame.rgbData = nullptr;
        frame.size = 0;
    }
}

///////////////////////////////////////////////////////////////////////////////
// Save a frame as a JPEG image using the STB library
// https://github.com/nothings/stb/blob/master/stb_image_write.h
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "include/stb_image_write.h"
void saveFrameAsJPEG(const unsigned char *data, int width, int height, const std::string &filename)
{
    // Simple image saving using STB library or another JPEG encoding method
    if (stbi_write_jpg(filename.c_str(), width, height, 3, data, 90))
    {
        std::cout << "Saved frame to " << filename << std::endl;
    }
    else
    {
        std::cerr << "Error saving frame as JPEG." << std::endl;
    }
}
///////////////////////////////////////////////////////////////////////////////