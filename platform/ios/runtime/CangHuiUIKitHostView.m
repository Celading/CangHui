#import <UIKit/UIKit.h>

#import "CangHuiNativeSurface.h"
#import "CangHuiRuntimeBootstrap.h"

#include <math.h>
#include <stdint.h>

static const int64_t CangHuiTaskTimeoutNanos = 5000000000LL;

typedef struct CangHuiSafeAreaArguments {
    int64_t top;
    int64_t right;
    int64_t bottom;
    int64_t left;
} CangHuiSafeAreaArguments;

typedef struct CangHuiTouchArguments {
    int64_t phase;
    int64_t identifier;
    int64_t x;
    int64_t y;
    int64_t timestamp;
    int64_t generation;
} CangHuiTouchArguments;

static void *CangHuiSafeAreaTask(void *rawArguments) {
    CangHuiSafeAreaArguments *arguments = rawArguments;
    return (void *)(intptr_t)canghui_ios_surface_safe_area(
        arguments->top, arguments->right, arguments->bottom, arguments->left);
}

static void *CangHuiLifecycleTask(void *rawState) {
    return (void *)(intptr_t)canghui_ios_surface_lifecycle((int64_t)(intptr_t)rawState);
}

static void *CangHuiTouchTask(void *rawArguments) {
    CangHuiTouchArguments *arguments = rawArguments;
    return (void *)(intptr_t)canghui_ios_surface_touch(
        arguments->phase,
        arguments->identifier,
        arguments->x,
        arguments->y,
        arguments->timestamp,
        arguments->generation);
}

@interface CangHuiUIKitHostView : UIView
- (int64_t)canghuiSurfaceGeneration;
@end

@implementation CangHuiUIKitHostView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        [self canghuiConfigureInputAndLifecycle];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self != nil) {
        [self canghuiConfigureInputAndLifecycle];
    }
    return self;
}

- (void)canghuiConfigureInputAndLifecycle {
    self.multipleTouchEnabled = YES;
    self.userInteractionEnabled = YES;
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(canghuiApplicationDidBecomeActive:)
        name:UIApplicationDidBecomeActiveNotification object:nil];
    [center addObserver:self selector:@selector(canghuiApplicationWillResignActive:)
        name:UIApplicationWillResignActiveNotification object:nil];
    [center addObserver:self selector:@selector(canghuiApplicationDidEnterBackground:)
        name:UIApplicationDidEnterBackgroundNotification object:nil];
    [center addObserver:self selector:@selector(canghuiApplicationWillTerminate:)
        name:UIApplicationWillTerminateNotification object:nil];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (int64_t)canghuiSurfaceGeneration {
    return 0;
}

- (void)safeAreaInsetsDidChange {
    [super safeAreaInsetsDidChange];
    UIEdgeInsets insets = self.safeAreaInsets;
    CangHuiSafeAreaArguments arguments = {
        .top = llround(insets.top * 1000.0),
        .right = llround(insets.right * 1000.0),
        .bottom = llround(insets.bottom * 1000.0),
        .left = llround(insets.left * 1000.0),
    };
    (void)canghui_runtime_run_task(CangHuiSafeAreaTask, &arguments, CangHuiTaskTimeoutNanos);
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self canghuiForwardTouches:touches phase:CANGHUI_IOS_TOUCH_BEGAN];
    [super touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self canghuiForwardTouches:touches phase:CANGHUI_IOS_TOUCH_MOVED];
    [super touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self canghuiForwardTouches:touches phase:CANGHUI_IOS_TOUCH_ENDED];
    [super touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self canghuiForwardTouches:touches phase:CANGHUI_IOS_TOUCH_CANCELLED];
    [super touchesCancelled:touches withEvent:event];
}

- (void)canghuiForwardTouches:(NSSet<UITouch *> *)touches phase:(int64_t)phase {
    int64_t generation = self.canghuiSurfaceGeneration;
    if (generation <= 0) {
        return;
    }
    for (UITouch *touch in touches) {
        CGPoint point = [touch locationInView:self];
        CangHuiTouchArguments arguments = {
            .phase = phase,
            .identifier = (int64_t)(intptr_t)(__bridge void *)touch,
            .x = llround(point.x * 1000.0),
            .y = llround(point.y * 1000.0),
            .timestamp = llround(touch.timestamp * 1000.0),
            .generation = generation,
        };
        (void)canghui_runtime_run_task(CangHuiTouchTask, &arguments, CangHuiTaskTimeoutNanos);
    }
}

- (void)canghuiApplicationDidBecomeActive:(NSNotification *)notification {
    (void)notification;
    [self canghuiSendLifecycle:CANGHUI_IOS_LIFECYCLE_ACTIVE];
}

- (void)canghuiApplicationWillResignActive:(NSNotification *)notification {
    (void)notification;
    [self canghuiSendLifecycle:CANGHUI_IOS_LIFECYCLE_INACTIVE];
}

- (void)canghuiApplicationDidEnterBackground:(NSNotification *)notification {
    (void)notification;
    [self canghuiSendLifecycle:CANGHUI_IOS_LIFECYCLE_BACKGROUND];
}

- (void)canghuiApplicationWillTerminate:(NSNotification *)notification {
    (void)notification;
    [self canghuiSendLifecycle:CANGHUI_IOS_LIFECYCLE_TERMINATING];
}

- (void)canghuiSendLifecycle:(int64_t)state {
    (void)canghui_runtime_run_task(
        CangHuiLifecycleTask, (void *)(intptr_t)state, CangHuiTaskTimeoutNanos);
}

@end
