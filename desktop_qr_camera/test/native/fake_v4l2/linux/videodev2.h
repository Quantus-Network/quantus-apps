// The part of the kernel's V4L2 header that CameraLinux.cpp uses, so that opening
// a camera can be tested on any platform. CI's Linux build compiles it against
// the real header.
#ifndef FAKE_VIDEODEV2_H
#define FAKE_VIDEODEV2_H

#include <stdint.h>

#define V4L2_CAP_VIDEO_CAPTURE 0x00000001u
#define V4L2_CAP_STREAMING 0x04000000u
#define V4L2_CAP_DEVICE_CAPS 0x80000000u
#define V4L2_PIX_FMT_YUYV 0x56595559u
#define V4L2_PIX_FMT_GREY 0x59455247u
#define V4L2_BUF_FLAG_ERROR 0x00000040u

enum v4l2_buf_type { V4L2_BUF_TYPE_VIDEO_CAPTURE = 1 };
enum v4l2_field { V4L2_FIELD_NONE = 1 };
enum v4l2_memory { V4L2_MEMORY_MMAP = 1 };

struct v4l2_capability {
  uint32_t capabilities;
  uint32_t device_caps;
};

struct v4l2_pix_format {
  uint32_t width;
  uint32_t height;
  uint32_t pixelformat;
  uint32_t field;
  uint32_t bytesperline;
};

struct v4l2_format {
  uint32_t type;
  union {
    struct v4l2_pix_format pix;
  } fmt;
};

struct v4l2_requestbuffers {
  uint32_t count;
  uint32_t type;
  uint32_t memory;
};

struct v4l2_buffer {
  uint32_t index;
  uint32_t type;
  uint32_t bytesused;
  uint32_t flags;
  uint32_t memory;
  union {
    uint32_t offset;
  } m;
  uint32_t length;
};

#define VIDIOC_QUERYCAP 1UL
#define VIDIOC_S_FMT 2UL
#define VIDIOC_REQBUFS 3UL
#define VIDIOC_QUERYBUF 4UL
#define VIDIOC_QBUF 5UL
#define VIDIOC_DQBUF 6UL
#define VIDIOC_STREAMON 7UL
#define VIDIOC_STREAMOFF 8UL

#endif  // FAKE_VIDEODEV2_H
