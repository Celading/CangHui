#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <UIKit/UIKit.h>

#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>

#import "CangHuiHost.h"
#import "CangHuiNativeSurface.h"
#import "CangHuiRuntimeBootstrap.h"
#import "CangHuiUIKitHostView.h"

static const int64_t CangHuiProbeTimeoutNanos = 5000000000LL;

typedef struct CangHuiSurfaceSnapshot {
    int64_t generation;
    int64_t attached;
    int64_t attaches;
    int64_t resizes;
    int64_t detaches;
    int64_t frames;
    int64_t touches;
    int64_t pointers;
    int64_t traits;
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
    snapshot->pointers = canghui_ios_surface_pointer_count();
    snapshot->traits = canghui_ios_surface_trait_count();
    return rawSnapshot;
}

static void *write_canghui_probe_touch(void *rawGeneration) {
    int64_t generation = (int64_t)(intptr_t)rawGeneration;
    return (void *)(intptr_t)canghui_ios_surface_touch(
        CANGHUI_IOS_TOUCH_BEGAN, 1, 120000, 180000, 1000, generation);
}

static void *write_canghui_probe_pointer(void *rawGeneration) {
    int64_t generation = (int64_t)(intptr_t)rawGeneration;
    return (void *)(intptr_t)canghui_ios_surface_pointer(
        CANGHUI_IOS_POINTER_BEGAN, 2, 220000, 320000, 1200,
        CANGHUI_IOS_POINTER_KIND_PENCIL, generation);
}

static void *write_canghui_probe_traits(void *unused) {
    (void)unused;
    return (void *)(intptr_t)canghui_ios_surface_traits(
        CANGHUI_IOS_TRAIT_STYLE_DARK,
        CANGHUI_IOS_TRAIT_SIZE_REGULAR,
        CANGHUI_IOS_TRAIT_SIZE_REGULAR,
        2000);
}

typedef struct CangHuiFrameProbeArguments {
    int64_t generation;
    int64_t baseNanos;
} CangHuiFrameProbeArguments;

static int64_t run_canghui_int_task(void *(*task)(void *), void *argument) {
    CangHuiRuntimeTaskResult result =
        canghui_runtime_run_task(task, argument, CangHuiProbeTimeoutNanos);
    return result.status == 0 ? (int64_t)(intptr_t)result.value : -100;
}

static void *write_canghui_stale_resize(void *rawGeneration) {
    int64_t generation = (int64_t)(intptr_t)rawGeneration;
    return (void *)(intptr_t)canghui_ios_surface_resize(
        360000, 640000, 720, 1280, 2000, generation);
}

static void *write_canghui_stale_touch(void *rawGeneration) {
    int64_t generation = (int64_t)(intptr_t)rawGeneration;
    return (void *)(intptr_t)canghui_ios_surface_touch(
        CANGHUI_IOS_TOUCH_BEGAN, 3, 1000, 1000, 2000, generation);
}

static void *write_canghui_stale_pointer(void *rawGeneration) {
    int64_t generation = (int64_t)(intptr_t)rawGeneration;
    return (void *)(intptr_t)canghui_ios_surface_pointer(
        CANGHUI_IOS_POINTER_BEGAN, 3, 1000, 1000, 2000,
        CANGHUI_IOS_POINTER_KIND_PENCIL, generation);
}

static void *write_canghui_stale_frame(void *rawGeneration) {
    int64_t generation = (int64_t)(intptr_t)rawGeneration;
    return (void *)(intptr_t)canghui_ios_surface_frame(1000, 2000, generation);
}

static void *write_canghui_invalid_handle(void *unused) {
    (void)unused;
    return (void *)(intptr_t)canghui_ios_surface_attach(
        -1, 320000, 480000, 640, 960, 2000, 1);
}

static void *write_canghui_future_frame(void *rawArguments) {
    CangHuiFrameProbeArguments *arguments = rawArguments;
    return (void *)(intptr_t)canghui_ios_surface_frame(
        arguments->baseNanos + 1000, arguments->baseNanos + 2000,
        arguments->generation);
}

static void *write_canghui_stale_future_frame(void *rawArguments) {
    CangHuiFrameProbeArguments *arguments = rawArguments;
    return (void *)(intptr_t)canghui_ios_surface_frame(
        arguments->baseNanos + 500, arguments->baseNanos + 1500,
        arguments->generation);
}

typedef struct CangHuiProfileSnapshot {
    int64_t idiom;
    int64_t deviceClass;
    int64_t breakpoint;
    int32_t profileStatus;
    int64_t profileLength;
} CangHuiProfileSnapshot;

static void *read_canghui_profile(void *rawSnapshot) {
    CangHuiProfileSnapshot *snapshot = rawSnapshot;
    snapshot->idiom = canghui_ios_surface_idiom();
    snapshot->deviceClass = canghui_ios_surface_device_class();
    snapshot->breakpoint = canghui_ios_surface_layout_breakpoint();
    int64_t required = 0;
    snapshot->profileStatus = canghui_ios_surface_device_profile(NULL, 0, &required);
    snapshot->profileLength = required;
    return rawSnapshot;
}

@interface CangHuiMetalSurfaceView : UIView
- (int64_t)canghuiSurfaceGeneration;
- (void)canghuiReplayCurrentResize;
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@property(nonatomic, strong) UIViewController *rootController;
@property(nonatomic, strong) UIView *statusPanel;
@property(nonatomic, strong) UILabel *statusLabel;
@property(nonatomic, strong) CangHuiMetalSurfaceView *surfaceView;
@property(nonatomic, strong) CangHuiUIKitHostView *inputHost;
@property(nonatomic, assign) BOOL drawableObserved;
@property(nonatomic, assign) BOOL negativePassed;
@property(nonatomic, assign) BOOL inputProbePassed;
@property(nonatomic, assign) BOOL profileProbePassed;
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
            self.statusLabel.text = @"CangHui iOS native surface\n"
                "Runtime bootstrap failed\n"
                "Probe only - CangHui scene not mounted";
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

- (BOOL)runNegativeProbeWithOldGeneration:(int64_t)oldGeneration {
    int64_t currentGeneration = canghui_ios_surface_generation();
    int64_t staleResize = run_canghui_int_task(
        write_canghui_stale_resize, (void *)(intptr_t)oldGeneration);
    int64_t staleTouch = run_canghui_int_task(
        write_canghui_stale_touch, (void *)(intptr_t)oldGeneration);
    int64_t stalePointer = run_canghui_int_task(
        write_canghui_stale_pointer, (void *)(intptr_t)oldGeneration);
    int64_t staleFrame = run_canghui_int_task(
        write_canghui_stale_frame, (void *)(intptr_t)oldGeneration);
    int64_t invalidHandle = run_canghui_int_task(write_canghui_invalid_handle, NULL);
    CangHuiFrameProbeArguments frameArguments = {
        .generation = currentGeneration,
        .baseNanos = canghui_ios_surface_last_frame_nanos() + 3600000000000LL,
    };
    int64_t futureFrame = run_canghui_int_task(
        write_canghui_future_frame, &frameArguments);
    int64_t staleFutureFrame = run_canghui_int_task(
        write_canghui_stale_future_frame, &frameArguments);
    BOOL passed =
        staleResize == CANGHUI_IOS_BRIDGE_STALE_GENERATION &&
        staleTouch == CANGHUI_IOS_BRIDGE_STALE_GENERATION &&
        stalePointer == CANGHUI_IOS_BRIDGE_STALE_GENERATION &&
        staleFrame == CANGHUI_IOS_BRIDGE_STALE_GENERATION &&
        invalidHandle == CANGHUI_IOS_BRIDGE_INVALID_ARGUMENT &&
        futureFrame == CANGHUI_IOS_BRIDGE_ACCEPTED &&
        staleFutureFrame == CANGHUI_IOS_BRIDGE_REJECTED;
    fprintf(stderr,
        "CANGHUI_IOS_NEGATIVE result passed=%d stale_resize=%" PRId64
        " stale_touch=%" PRId64 " stale_pointer=%" PRId64
        " stale_frame=%" PRId64 " invalid_handle=%" PRId64
        " future_frame=%" PRId64 " stale_future_frame=%" PRId64 "\n",
        passed ? 1 : 0,
        staleResize,
        staleTouch,
        stalePointer,
        staleFrame,
        invalidHandle,
        futureFrame,
        staleFutureFrame);
    fflush(stderr);
    return passed;
}

- (BOOL)runInputProbeWithGeneration:(int64_t)generation {
    if (self.inputHost == nil) {
        self.inputHost = [[CangHuiUIKitHostView alloc]
            initWithFrame:CGRectMake(0.0, 0.0, 10.0, 10.0)];
        self.inputHost.alpha = 0.01;
        [self.rootController.view addSubview:self.inputHost];
    }
    self.inputHost.canghuiInputGeneration = generation;
    [self.inputHost canghuiForwardKeyWithPhase:0 keyCode:4 modifiers:0 repeat:NO];
    [self.inputHost canghuiForwardKeyWithPhase:1 keyCode:4 modifiers:0 repeat:NO];
    [self.inputHost canghuiBeginTextInput];
    [self.inputHost canghuiSetTextInputText:@"仓绘" selectionStart:0 selectionEnd:2];
    [self.inputHost canghuiEndTextInput];
    [self.inputHost canghuiSetAccessibilityNodes:@[
        @{@"label": @"CangHui scene", @"identifier": @"scene",
          @"traits": @(UIAccessibilityTraitStaticText),
          @"x": @0, @"y": @0, @"width": @100, @"height": @20},
        @{@"label": @"Open", @"identifier": @"open",
          @"traits": @(UIAccessibilityTraitButton),
          @"x": @0, @"y": @30, @"width": @100, @"height": @44},
    ]];
    uint8_t text[256] = {0};
    int64_t textLength = 0;
    int32_t textResult = canghui_ios_surface_last_ime_text(
        text, (int64_t)sizeof(text), &textLength);
    NSString *imeText = textResult == 0
        ? [[NSString alloc] initWithBytes:text
            length:(NSUInteger)textLength encoding:NSUTF8StringEncoding]
        : nil;
    int64_t keyCount = canghui_ios_surface_key_count();
    int64_t keyCode = canghui_ios_surface_last_key_code();
    int64_t imeCount = canghui_ios_surface_ime_count();
    int64_t selectionStart = canghui_ios_surface_last_ime_selection_start();
    int64_t selectionEnd = canghui_ios_surface_last_ime_selection_end();
    NSInteger accessibilityCount = self.inputHost.canghuiAccessibilityElementCount;
    BOOL passed = keyCount == 2 && keyCode == 4 && imeCount >= 1 &&
        [imeText isEqualToString:@"仓绘"] &&
        selectionStart == 0 && selectionEnd == 2 && accessibilityCount == 2;
    fprintf(stderr,
        "CANGHUI_IOS_INPUT result passed=%d key_count=%" PRId64
        " key_code=%" PRId64 " ime_count=%" PRId64
        " selection=%" PRId64 ":%" PRId64 " ime_text=%s accessibility=%ld\n",
        passed ? 1 : 0,
        keyCount,
        keyCode,
        imeCount,
        selectionStart,
        selectionEnd,
        imeText.UTF8String ?: "",
        (long)accessibilityCount);
    fflush(stderr);
    return passed;
}

- (BOOL)runProfileProbe {
    CangHuiProfileSnapshot snapshot = {0};
    CangHuiRuntimeTaskResult readback = canghui_runtime_run_task(
        read_canghui_profile, &snapshot, CangHuiProbeTimeoutNanos);
    BOOL passed = readback.status == 0 &&
        snapshot.idiom >= 1 && snapshot.idiom <= 2 &&
        snapshot.deviceClass >= 1 && snapshot.deviceClass <= 4 &&
        snapshot.breakpoint >= 1 && snapshot.breakpoint <= 3 &&
        snapshot.profileStatus == -2 && snapshot.profileLength > 32;
    fprintf(stderr,
        "CANGHUI_IOS_PROFILE result passed=%d idiom=%" PRId64 " device=%" PRId64
        " breakpoint=%" PRId64 " json_bytes=%" PRId64 "\n",
        passed ? 1 : 0, snapshot.idiom, snapshot.deviceClass,
        snapshot.breakpoint, snapshot.profileLength);
    fflush(stderr);
    return passed;
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
            [self.surfaceView canghuiReplayCurrentResize];
            (void)canghui_runtime_run_task(
                write_canghui_probe_traits, NULL, CangHuiProbeTimeoutNanos);
            (void)canghui_runtime_run_task(
                write_canghui_probe_pointer,
                (void *)(intptr_t)self.surfaceView.canghuiSurfaceGeneration,
                CangHuiProbeTimeoutNanos);
            self.negativePassed = [self runNegativeProbeWithOldGeneration:generation];
            self.inputProbePassed =
                [self runInputProbeWithGeneration:self.surfaceView.canghuiSurfaceGeneration];
            self.profileProbePassed = [self runProfileProbe];
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
    BOOL passed = self.negativePassed && self.inputProbePassed && self.profileProbePassed &&
        readback.status == 0 && metalReady && self.drawableObserved &&
        snapshot.attached == 1 && snapshot.attaches >= 2 && snapshot.detaches >= 1 &&
        snapshot.generation >= 2 && snapshot.resizes >= 1 && snapshot.frames >= 1 &&
        snapshot.touches >= 1 && snapshot.pointers >= 1 && snapshot.traits >= 1;
    if (!passed && attempts > 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100000000), dispatch_get_main_queue(), ^{
            [self reportSurfaceWhenReadyWithAttempts:attempts - 1];
        });
        return;
    }

    fprintf(stderr,
        "CANGHUI_IOS_SURFACE result passed=%d negative=%s input=%s profile=%s metal=%s drawable=%s attached=%" PRId64
        " attaches=%" PRId64 " resizes=%" PRId64 " detaches=%" PRId64
        " generation=%" PRId64 " frames=%" PRId64 " touches=%" PRId64
        " pointers=%" PRId64 " traits=%" PRId64 "\n",
        passed ? 1 : 0,
        self.negativePassed ? "ready" : "null",
        self.inputProbePassed ? "ready" : "null",
        self.profileProbePassed ? "ready" : "null",
        metalReady ? "ready" : "null",
        self.drawableObserved ? "ready" : "null",
        snapshot.attached,
        snapshot.attaches,
        snapshot.resizes,
        snapshot.detaches,
        snapshot.generation,
        snapshot.frames,
        snapshot.touches,
        snapshot.pointers,
        snapshot.traits);
    fflush(stderr);

    self.statusLabel.textColor = passed ? UIColor.whiteColor : UIColor.systemRedColor;
    self.statusLabel.text = passed
        ? [NSString stringWithFormat:
            @"CangHui iOS native surface\n"
             "PASS - Metal + lifecycle + frames (%lld)\n"
             "Probe only - CangHui scene not mounted",
            (long long)snapshot.frames]
        : @"CangHui iOS native surface\n"
           "Probe failed\n"
           "CangHui scene not mounted";
}

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)application;
    (void)launchOptions;

    self.rootController = [UIViewController new];
    self.rootController.view.backgroundColor = UIColor.systemBackgroundColor;

    UIView *panel = [UIView new];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    panel.backgroundColor = [UIColor colorWithWhite:0.06 alpha:0.90];
    panel.layer.cornerRadius = 12.0;
    panel.layer.borderWidth = 1.0;
    panel.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;
    self.statusPanel = panel;
    [self.rootController.view addSubview:panel];

    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont monospacedSystemFontOfSize:16 weight:UIFontWeightSemibold];
    label.textColor = UIColor.whiteColor;
    label.text = @"CangHui iOS native surface\n"
        "Starting runtime...\n"
        "Probe only - CangHui scene not mounted";
    label.accessibilityLabel = @"CangHui iOS native surface diagnostic probe";
    self.statusLabel = label;
    [panel addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [panel.centerXAnchor constraintEqualToAnchor:self.rootController.view.centerXAnchor],
        [panel.centerYAnchor constraintEqualToAnchor:self.rootController.view.centerYAnchor],
        [panel.leadingAnchor constraintGreaterThanOrEqualToAnchor:
            self.rootController.view.safeAreaLayoutGuide.leadingAnchor constant:24],
        [panel.trailingAnchor constraintLessThanOrEqualToAnchor:
            self.rootController.view.safeAreaLayoutGuide.trailingAnchor constant:-24],
        [label.topAnchor constraintEqualToAnchor:panel.topAnchor constant:18],
        [label.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-18],
        [label.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:22],
        [label.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-22]
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
