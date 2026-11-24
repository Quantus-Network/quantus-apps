// How the Windows preview texture is torn down while Flutter's raster thread may
// still be painting it. It runs anywhere, under the sanitizers:
//
//   c++ -std=c++17 -Wall -Wextra -Wno-unused-parameter -Werror -pthread \
//     -fsanitize=address,undefined -fno-sanitize-recover=undefined -I test/native/fake_flutter -I windows \
//     test/native/texture_handler_test.cpp windows/texture_handler.cpp \
//     -o /tmp/texture_handler_test && /tmp/texture_handler_test
#include <cstdint>
#include <cstdio>
#include <functional>
#include <memory>
#include <thread>
#include <utility>
#include <vector>

#include "texture_handler.h"

using desktop_qr_camera::TextureHandler;

static int failures = 0;

#define CHECK(condition)                                          \
  do {                                                            \
    if (!(condition)) {                                           \
      std::printf("FAILED %s:%d: %s\n", __FILE__, __LINE__, #condition); \
      failures++;                                                 \
    }                                                             \
  } while (false)

namespace {

const int64_t kTextureId = 7;

// Stands in for the engine, which keeps the texture's address and only lets go
// of it in a task on the raster thread.
class FakeRegistrar : public flutter::TextureRegistrar {
 public:
  explicit FakeRegistrar(bool engine_is_running = true) : engine_is_running_(engine_is_running) {}

  int64_t RegisterTexture(flutter::TextureVariant* texture) override {
    texture_ = texture;
    return kTextureId;
  }

  bool MarkTextureFrameAvailable(int64_t) override { return true; }

  void UnregisterTexture(int64_t texture_id, std::function<void()> callback) override {
    unregistered_id = texture_id;
    if (engine_is_running_) {
      pending_ = std::move(callback);
    } else {
      callback();
    }
  }

  bool UnregisterTexture(int64_t) override {
    calls_without_callback++;
    return true;
  }

  const FlutterDesktopPixelBuffer* Paint() {
    return std::get<flutter::PixelBufferTexture>(*texture_).CopyPixelBuffer(1, 1);
  }

  void FinishOnRasterThread() {
    std::function<void()> callback = std::move(pending_);
    pending_ = nullptr;
    callback();
  }

  int64_t unregistered_id = -1;
  int calls_without_callback = 0;

 private:
  bool engine_is_running_;
  flutter::TextureVariant* texture_ = nullptr;
  std::function<void()> pending_;
};

std::shared_ptr<TextureHandler> ShowingAFrame(FakeRegistrar* registrar) {
  auto handler = std::make_shared<TextureHandler>(registrar);
  handler->RegisterTexture();
  const std::vector<unsigned char> frame = {1, 2, 3, 4};
  handler->UpdateBuffer(frame.data(), 1, 1);
  return handler;
}

void TestAPaintAfterRetiringIsSafeAndShowsNothing() {
  FakeRegistrar registrar;
  auto handler = ShowingAFrame(&registrar);
  TextureHandler::Retire(std::move(handler));
  CHECK(registrar.Paint() == nullptr);
  registrar.FinishOnRasterThread();
}

void TestTheHandlerLivesUntilFlutterIsDoneWithTheTexture() {
  FakeRegistrar registrar;
  auto handler = ShowingAFrame(&registrar);
  std::weak_ptr<TextureHandler> watched = handler;
  TextureHandler::Retire(std::move(handler));
  CHECK(registrar.unregistered_id == kTextureId);
  CHECK(registrar.calls_without_callback == 0);
  CHECK(!watched.expired());
  registrar.FinishOnRasterThread();
  CHECK(watched.expired());
}

void TestAPaintInProgressFinishesBeforeRetiringGoesOn() {
  FakeRegistrar registrar;
  auto handler = ShowingAFrame(&registrar);
  const FlutterDesktopPixelBuffer* painting = registrar.Paint();
  CHECK(painting != nullptr);
  CHECK(painting->buffer[0] == 1);

  std::thread stopping([&handler] { TextureHandler::Retire(std::move(handler)); });
  painting->release_callback(painting->release_context);
  stopping.join();

  CHECK(registrar.unregistered_id == kTextureId);
  registrar.FinishOnRasterThread();
}

// The registrar runs the callback at once when it cannot reach the raster thread.
void TestWithTheEngineStoppedTheHandlerIsFreedAtOnce() {
  FakeRegistrar registrar(false);
  auto handler = ShowingAFrame(&registrar);
  std::weak_ptr<TextureHandler> watched = handler;
  TextureHandler::Retire(std::move(handler));
  CHECK(registrar.unregistered_id == kTextureId);
  CHECK(watched.expired());
}

void TestAHandlerThatNeverRegisteredIsJustFreed() {
  FakeRegistrar registrar;
  auto handler = std::make_shared<TextureHandler>(&registrar);
  std::weak_ptr<TextureHandler> watched = handler;
  TextureHandler::Retire(std::move(handler));
  CHECK(registrar.unregistered_id == -1);
  CHECK(watched.expired());
}

}  // namespace

int main() {
  TestAPaintAfterRetiringIsSafeAndShowsNothing();
  TestTheHandlerLivesUntilFlutterIsDoneWithTheTexture();
  TestAPaintInProgressFinishesBeforeRetiringGoesOn();
  TestWithTheEngineStoppedTheHandlerIsFreedAtOnce();
  TestAHandlerThatNeverRegisteredIsJustFreed();
  if (failures > 0) {
    std::printf("%d check(s) failed\n", failures);
    return 1;
  }
  std::printf("All texture handler checks passed\n");
  return 0;
}
