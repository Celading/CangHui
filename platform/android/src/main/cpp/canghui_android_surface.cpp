#include <android/native_window.h>
#include <android/native_window_jni.h>
#include <jni.h>

#include <cstdint>
#include <mutex>
#include <new>

namespace {

struct SurfaceHost final {
    std::mutex mutex;
    ANativeWindow* window = nullptr;
    std::int64_t generation = 0;
    std::int32_t width = 0;
    std::int32_t height = 0;

    ~SurfaceHost() {
        if (window != nullptr) {
            ANativeWindow_release(window);
        }
    }
};

SurfaceHost* surfaceHost(jlong handle) {
    return reinterpret_cast<SurfaceHost*>(handle);
}

jlong currentGeneration(SurfaceHost* host) {
    if (host == nullptr) {
        return 0;
    }
    std::lock_guard<std::mutex> lock(host->mutex);
    return static_cast<jlong>(host->generation);
}

}  // namespace

extern "C" JNIEXPORT jlong JNICALL
Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativeCreate(
    JNIEnv*, jclass) {
    return reinterpret_cast<jlong>(new (std::nothrow) SurfaceHost());
}

extern "C" JNIEXPORT jlong JNICALL
Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativeAttachSurface(
    JNIEnv* env, jclass, jlong handle, jobject surface) {
    SurfaceHost* host = surfaceHost(handle);
    if (host == nullptr || surface == nullptr) {
        return 0;
    }

    ANativeWindow* nextWindow = ANativeWindow_fromSurface(env, surface);
    if (nextWindow == nullptr) {
        return 0;
    }

    std::lock_guard<std::mutex> lock(host->mutex);
    if (host->window != nullptr) {
        ANativeWindow_release(host->window);
    }
    host->window = nextWindow;
    host->width = ANativeWindow_getWidth(nextWindow);
    host->height = ANativeWindow_getHeight(nextWindow);
    host->generation += 1;
    return static_cast<jlong>(host->generation);
}

extern "C" JNIEXPORT jlong JNICALL
Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativeDetachSurface(
    JNIEnv*, jclass, jlong handle, jlong expectedGeneration) {
    SurfaceHost* host = surfaceHost(handle);
    if (host == nullptr) {
        return 0;
    }

    std::lock_guard<std::mutex> lock(host->mutex);
    if (expectedGeneration != static_cast<jlong>(host->generation)) {
        return static_cast<jlong>(host->generation);
    }
    if (host->window != nullptr) {
        ANativeWindow_release(host->window);
        host->window = nullptr;
        host->width = 0;
        host->height = 0;
        host->generation += 1;
    }
    return static_cast<jlong>(host->generation);
}

extern "C" JNIEXPORT void JNICALL
Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativeDestroy(
    JNIEnv*, jclass, jlong handle) {
    delete surfaceHost(handle);
}

extern "C" JNIEXPORT jlong JNICALL
Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativeGeneration(
    JNIEnv*, jclass, jlong handle) {
    return currentGeneration(surfaceHost(handle));
}

extern "C" JNIEXPORT jint JNICALL
Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativeWidth(
    JNIEnv*, jclass, jlong handle) {
    SurfaceHost* host = surfaceHost(handle);
    if (host == nullptr) {
        return 0;
    }
    std::lock_guard<std::mutex> lock(host->mutex);
    return static_cast<jint>(host->width);
}

extern "C" JNIEXPORT jint JNICALL
Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativeHeight(
    JNIEnv*, jclass, jlong handle) {
    SurfaceHost* host = surfaceHost(handle);
    if (host == nullptr) {
        return 0;
    }
    std::lock_guard<std::mutex> lock(host->mutex);
    return static_cast<jint>(host->height);
}
