#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <UIKit/UIKit.h>

#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>

#import "CangHuiHost.h"
#import "CangHuiNativeSurface.h"
#import "CangHuiRuntimeBootstrap.h"

static const int64_t CangHuiProbeTimeoutNanos = 5000000000LL;

typedef struct CangHuiSurfaceSnapshot {
    int64_t generation;
    int64_t attached;
    int64_t attaches;
    int64_t resizes;
    int64_t detaches;
    int64_t frames;
    int64_t touches;
} CangHuiSurfaceSnapshot;

static void *read_canghui_abi(void *unused) {
    (void)unused;
    return (void *)(intptr_t)canghui_ios_host_abi_version();
}

static void *read_canghui_surface(void *rawSnapshot) {
    CangHuiSurfaceSnapshot *snapshot = rawSnapshot;
    snapshot->generation = canghui_ios_surface_generation();
    snapshot->attached = canghui_ios_surface_is_attached();
    snapshot->attaches = canghui_ios_surface_attach_count();
    snapshot->resizes = canghui_ios_surface_resize_count();
    snapshot->detaches = canghui_ios_surface_detach_count();
    snapshot->frames = canghui_ios_surface_frame_count();
    snapshot->touches = canghui_ios_surface_touch_count();
    return rawSnapshot;
}

static void *write_canghui_probe_touch(void *rawGeneration) {
    int64_t generation = (int64_t)(intptr_t)rawGeneration;
    return (void *)(intptr_t)canghui_ios_surface_touch(
        CANGHUI_IOS_TOUCH_BEGAN, 1, 120000, 180000, 1000, generation);
}

@interface CangHuiMetalSurfaceView : UIView
- (int64_t)canghuiSurfaceGeneration;
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@property(nonatomic, strong) UIViewController *rootController;
@property(nonatomic, strong) UILabel *statusLabel;
@property(nonatomic, strong) CangHuiMetalSurfaceView *surfaceView;
@property(nonatomic, assign) BOOL drawableObserved;
@end

@implementation AppDelegate

- (void)runBootstrapProbe {
    const char *executableName =
        NSBundle.mainBundle.executableURL.lastPathComponent.UTF8String;
    CangHuiRuntimeBootstrapResult bootstrap =
        canghui_runtime_bootstrap_start(executableName, CangHuiProbeTimeoutNanos);
    CangHuiRuntimeTaskResult task =
        canghui_runtime_run_task(read_canghui_abi, NULL, CangHuiProbeTimeoutNanos);
    int64_t abi = task.status == 0 ? (int64_t)(intptr_t)task.value : -1;
    BOOL passed = bootstrap.runtime_status == 0 &&
        bootstrap.scheduler_ready == 1 && bootstrap.library_status == 0 &&
        task.status == 0 && abi == 1;

    fprintf(stderr,
        "CANGHUI_IOS_PROBE result runtime=%d scheduler=%s library=%d task=%d abi=%" PRId64 "\n",
        bootstrap.runtime_status,
        bootstrap.scheduler_ready == 1 ? "ready" : "null",
        bootstrap.library_status,
        task.status,
        abi);
    fflush(stderr);

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!passed) {
            self.statusLabel.textColor = UIColor.systemRedColor;
            self.statusLabel.text = @"CangHui iOS runtime bootstrap failed";
            return;
        }
        [self installSurfaceView];
        [self scheduleDetachReattachReplay];
    });
}

- (void)installSurfaceView {
    if (self.surfaceView == nil) {
        self.surfaceView = [[CangHuiMetalSurfaceView alloc] initWithFrame:CGRectZero];
        self.surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    }
    [self.rootController.view insertSubview:self.surfaceView atIndex:0];
    [NSLayoutConstraint activateConstraints:@[
        [self.surfaceView.leadingAnchor constraintEqualToAnchor:self.rootController.view.leadingAnchor],
        [self.surfaceView.trailingAnchor constraintEqualToAnchor:self.rootController.view.trailingAnchor],
        [self.surfaceView.topAnchor constraintEqualToAnchor:self.rootController.view.topAnchor],
        [self.surfaceView.bottomAnchor constraintEqualToAnchor:self.rootController.view.bottomAnchor]
    ]];
    [self.rootController.view layoutIfNeeded];
}

- (void)scheduleDetachReattachReplay {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500000000), dispatch_get_main_queue(), ^{
        int64_t generation = self.surfaceView.canghuiSurfaceGeneration;
        (void)canghui_runtime_run_task(
            write_canghui_probe_touch,
            (void *)(intptr_t)generation,
            CangHuiProbeTimeoutNanos);
        [self.surfaceView removeFromSuperview];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 150000000), dispatch_get_main_queue(), ^{
            [self installSurfaceView];
            [self reportSurfaceWhenReadyWithAttempts:100];
        });
    });
}

- (void)reportSurfaceWhenReadyWithAttempts:(NSInteger)attempts {
    CangHuiSurfaceSnapshot snapshot = {0};
    CangHuiRuntimeTaskResult readback = canghui_runtime_run_task(
        read_canghui_surface, &snapshot, CangHuiProbeTimeoutNanos);
    CAMetalLayer *layer = [self.surfaceView.layer isKindOfClass:CAMetalLayer.class]
        ? (CAMetalLayer *)self.surfaceView.layer
        : nil;
    BOOL metalReady = layer != nil && layer.device != nil;
    if (!self.drawableObserved && metalReady) {
        self.drawableObserved = [layer nextDrawable] != nil;
    }
    BOOL passed = readback.status == 0 && metalReady && self.drawableObserved &&
        snapshot.attached == 1 && snapshot.attaches >= 2 && snapshot.detaches >= 1 &&
        snapshot.generation >= 2 && snapshot.resizes >= 1 && snapshot.frames >= 1 &&
        snapshot.touches >= 1;
    if (!passed && attempts > 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100000000), dispatch_get_main_queue(), ^{
            [self reportSurfaceWhenReadyWithAttempts:attempts - 1];
        });
        return;
    }

    fprintf(stderr,
        "CANGHUI_IOS_SURFACE result passed=%d metal=%s drawable=%s attached=%" PRId64
        " attaches=%" PRId64 " resizes=%" PRId64 " detaches=%" PRId64
        " generation=%" PRId64 " frames=%" PRId64 " touches=%" PRId64 "\n",
        passed ? 1 : 0,
        metalReady ? "ready" : "null",
        self.drawableObserved ? "ready" : "null",
        snapshot.attached,
        snapshot.attaches,
        snapshot.resizes,
        snapshot.detaches,
        snapshot.generation,
        snapshot.frames,
        snapshot.touches);
    fflush(stderr);

    self.statusLabel.textColor = passed ? UIColor.whiteColor : UIColor.systemRedColor;
    self.statusLabel.text = passed
        ? @"CangHui iOS native surface\nMetal + lifecycle + frame + touch"
        : @"CangHui iOS native surface probe failed";
}

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)application;
    (void)launchOptions;

    self.rootController = [UIViewController new];
    self.rootController.view.backgroundColor = UIColor.systemBackgroundColor;

    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont monospacedSystemFontOfSize:18 weight:UIFontWeightSemibold];
    label.textColor = UIColor.labelColor;
    label.text = @"CangHui iOS native surface\nstarting";
    self.statusLabel = label;
    [self.rootController.view addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:self.rootController.view.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:self.rootController.view.centerYAnchor],
        [label.leadingAnchor constraintGreaterThanOrEqualToAnchor:
            self.rootController.view.leadingAnchor constant:24],
        [label.trailingAnchor constraintLessThanOrEqualToAnchor:
            self.rootController.view.trailingAnchor constant:-24]
    ]];

    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = self.rootController;
    [self.window makeKeyAndVisible];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [self runBootstrapProbe];
    });
    return YES;
}

@end

int main(int argc, char **argv) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(AppDelegate.class));
    }
}
