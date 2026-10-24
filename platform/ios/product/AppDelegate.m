#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <UIKit/UIKit.h>

#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#import "CangHuiNativeSceneSurfaceView.h"
#import "CangHuiProductScene.h"
#import "CangHuiRuntimeBootstrap.h"

static const int64_t CangHuiProductTimeoutNanos = 5000000000LL;

static int32_t CangHuiProductRender(
    int64_t widthMilli,
    int64_t heightMilli,
    int64_t eventKind,
    int64_t xMilli,
    int64_t yMilli,
    uint8_t * _Nullable output,
    int64_t outputCapacity,
    int64_t * _Nonnull outputLength) {
    return canghui_ios_product_render(widthMilli, heightMilli, eventKind,
        xMilli, yMilli, output, outputCapacity, outputLength);
}

typedef struct CangHuiProductTextArguments {
    char text[4096];
    int64_t length;
} CangHuiProductTextArguments;

typedef struct CangHuiProductKeyArguments {
    int64_t phase;
    int64_t keyCode;
} CangHuiProductKeyArguments;

static void *CangHuiProductSetTextTask(void *rawArguments) {
    CangHuiProductTextArguments *arguments = rawArguments;
    return (void *)(intptr_t)canghui_ios_product_set_text(
        (const uint8_t *)arguments->text, arguments->length);
}

static void *CangHuiProductKeyTask(void *rawArguments) {
    CangHuiProductKeyArguments *arguments = rawArguments;
    return (void *)(intptr_t)canghui_ios_product_key(
        arguments->phase, arguments->keyCode);
}

static NSString *CangHuiProductReadString(
    int32_t (*reader)(uint8_t *, int64_t, int64_t *)) {
    int64_t required = 0;
    if (reader(NULL, 0, &required) != -2 || required <= 0) {
        return nil;
    }
    NSMutableData *buffer = [NSMutableData dataWithLength:(NSUInteger)required];
    int64_t copied = 0;
    if (reader(buffer.mutableBytes, required, &copied) != 0 || copied <= 0) {
        return nil;
    }
    return [[NSString alloc] initWithBytes:buffer.bytes
        length:(NSUInteger)copied encoding:NSUTF8StringEncoding];
}

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@property(nonatomic, strong) UIViewController *rootController;
@property(nonatomic, strong) CangHuiNativeSceneSurfaceView *sceneView;
@property(nonatomic, strong) UILabel *failureLabel;
@property(nonatomic, assign) BOOL reported;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)application;
    (void)launchOptions;

    self.rootController = [UIViewController new];
    self.rootController.view.backgroundColor = [UIColor colorWithRed:12.0 / 255.0
        green:18.0 / 255.0 blue:28.0 / 255.0 alpha:1.0];

    UILabel *failure = [UILabel new];
    failure.translatesAutoresizingMaskIntoConstraints = NO;
    failure.numberOfLines = 0;
    failure.textAlignment = NSTextAlignmentCenter;
    failure.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightSemibold];
    failure.textColor = UIColor.systemRedColor;
    failure.hidden = YES;
    self.failureLabel = failure;
    [self.rootController.view addSubview:failure];

    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = self.rootController;
    [self.window makeKeyAndVisible];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [self bootRuntime];
    });
    return YES;
}

- (void)bootRuntime {
    const char *executableName =
        NSBundle.mainBundle.executableURL.lastPathComponent.UTF8String;
    CangHuiRuntimeBootstrapResult bootstrap =
        canghui_runtime_bootstrap_start(executableName, CangHuiProductTimeoutNanos);
    BOOL ready = bootstrap.runtime_status == 0 &&
        bootstrap.scheduler_ready == 1 && bootstrap.library_status == 0;
    fprintf(stderr,
        "CANGHUI_IOS_PRODUCT runtime=%d scheduler=%s library=%d\n",
        bootstrap.runtime_status,
        bootstrap.scheduler_ready == 1 ? "ready" : "null",
        bootstrap.library_status);
    fflush(stderr);

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!ready) {
            [self showFailure:@"CangHui 运行时启动失败"];
            fprintf(stderr, "CANGHUI_IOS_PRODUCT result passed=0 reason=runtime\n");
            fflush(stderr);
            return;
        }
        [self installSceneView];
        [self beginProductFlowWithAttempts:100];
    });
}

- (void)installSceneView {
    if (self.sceneView == nil) {
        self.sceneView = [[CangHuiNativeSceneSurfaceView alloc]
            initWithFrame:CGRectZero renderFunction:CangHuiProductRender];
        self.sceneView.translatesAutoresizingMaskIntoConstraints = NO;
    }
    [self.rootController.view insertSubview:self.sceneView atIndex:0];
    [NSLayoutConstraint activateConstraints:@[
        [self.sceneView.leadingAnchor constraintEqualToAnchor:self.rootController.view.leadingAnchor],
        [self.sceneView.trailingAnchor constraintEqualToAnchor:self.rootController.view.trailingAnchor],
        [self.sceneView.topAnchor constraintEqualToAnchor:self.rootController.view.topAnchor],
        [self.sceneView.bottomAnchor constraintEqualToAnchor:self.rootController.view.bottomAnchor]
    ]];
    [self.rootController.view layoutIfNeeded];
    self.failureLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.failureLabel.centerXAnchor constraintEqualToAnchor:self.rootController.view.centerXAnchor],
        [self.failureLabel.centerYAnchor constraintEqualToAnchor:self.rootController.view.centerYAnchor],
        [self.failureLabel.leadingAnchor constraintEqualToAnchor:
            self.rootController.view.safeAreaLayoutGuide.leadingAnchor constant:24],
        [self.failureLabel.trailingAnchor constraintEqualToAnchor:
            self.rootController.view.safeAreaLayoutGuide.trailingAnchor constant:-24]
    ]];
}

- (void)beginProductFlowWithAttempts:(NSInteger)attempts {
    if (self.reported) {
        return;
    }
    int64_t generation = self.sceneView.canghuiSurfaceGeneration;
    if (generation <= 0 && attempts > 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100000000),
            dispatch_get_main_queue(), ^{
                [self beginProductFlowWithAttempts:attempts - 1];
            });
        return;
    }
    self.sceneView.canghuiInputGeneration = generation;
    [self.sceneView canghuiMarkNativeSceneDirty];
    [self runProductActions];
    [self verifyProductWithAttempts:100];
}

- (void)runProductActions {
    [self.sceneView canghuiReplayNativeSceneTapAtPoint:CGPointMake(99.0, 296.0)];

    CangHuiProductTextArguments textArguments = {0};
    const char *text = "仓绘 iOS";
    size_t textLength = strlen(text);
    if (textLength > sizeof(textArguments.text)) {
        textLength = sizeof(textArguments.text);
    }
    memcpy(textArguments.text, text, textLength);
    textArguments.length = (int64_t)textLength;
    (void)canghui_runtime_run_task(
        CangHuiProductSetTextTask, &textArguments, CangHuiProductTimeoutNanos);

    CangHuiProductKeyArguments keyArguments = {.phase = 1, .keyCode = 40};
    (void)canghui_runtime_run_task(
        CangHuiProductKeyTask, &keyArguments, CangHuiProductTimeoutNanos);

    [self.sceneView canghuiSetAccessibilityNodes:@[
        @{@"label": @"仓绘 iOS", @"identifier": @"header",
          @"traits": @(UIAccessibilityTraitHeader),
          @"x": @24, @"y": @28, @"width": @160, @"height": @36},
        @{@"label": @"交互计数", @"value": @"1", @"identifier": @"counter",
          @"traits": @(UIAccessibilityTraitStaticText),
          @"x": @44, @"y": @162, @"width": @160, @"height": @60},
        @{@"label": @"加一", @"identifier": @"increment",
          @"traits": @(UIAccessibilityTraitButton),
          @"x": @24, @"y": @272, @"width": @150, @"height": @48},
        @{@"label": @"输入内容", @"value": @"仓绘 iOS", @"identifier": @"input",
          @"traits": @(UIAccessibilityTraitStaticText),
          @"x": @44, @"y": @376, @"width": @240, @"height": @34}
    ]];
    [self.sceneView canghuiMarkNativeSceneDirty];
}

- (void)verifyProductWithAttempts:(NSInteger)attempts {
    if (self.reported) {
        return;
    }
    NSString *stateString = CangHuiProductReadString(canghui_ios_product_state);
    NSDictionary *state = nil;
    if (stateString != nil) {
        state = [NSJSONSerialization JSONObjectWithData:
            [stateString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    }
    int64_t generation = self.sceneView.canghuiSurfaceGeneration;
    NSInteger sceneFrames = self.sceneView.canghuiPresentedSceneFrameCount;
    NSInteger accessibility = self.sceneView.canghuiAccessibilityElementCount;
    NSString *inputText = CangHuiProductReadString(canghui_ios_product_input_text);
    int64_t counter = canghui_ios_product_counter();
    int64_t keyCount = canghui_ios_product_key_count();
    int64_t imeCount = canghui_ios_product_ime_count();
    int64_t renderCount = canghui_ios_product_render_count();
    int64_t commands = [state[@"commandCount"] longLongValue];
    int64_t actions = [state[@"actionCount"] longLongValue];
    BOOL textLayout = [state[@"textLayout"] boolValue];
    BOOL textMatches = [inputText isEqualToString:@"仓绘 iOS"];
    BOOL protocolOk = [state[@"protocol"] isEqualToString:@"canghui.native-scene.v0"];

    BOOL ready = state != nil && protocolOk && generation > 0 && sceneFrames >= 1 &&
        renderCount > 0 && commands >= 10 && actions == 2 && textLayout &&
        counter == 1 && keyCount >= 1 && imeCount >= 1 && textMatches &&
        accessibility == 4;
    if (!ready && attempts > 0) {
        [self.sceneView canghuiMarkNativeSceneDirty];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100000000),
            dispatch_get_main_queue(), ^{
                [self verifyProductWithAttempts:attempts - 1];
            });
        return;
    }
    self.reported = YES;

    BOOL passed = ready;
    fprintf(stderr,
        "CANGHUI_IOS_PRODUCT result passed=%d frames=%ld generation=%" PRId64
        " renders=%" PRId64 " commands=%" PRId64 " actions=%" PRId64
        " counter=%" PRId64 " keys=%" PRId64 " ime=%" PRId64
        " accessibility=%ld text_ok=%d text_layout=%d protocol=%s\n",
        passed ? 1 : 0,
        (long)sceneFrames,
        generation,
        renderCount,
        commands,
        actions,
        counter,
        keyCount,
        imeCount,
        (long)accessibility,
        textMatches ? 1 : 0,
        textLayout ? 1 : 0,
        protocolOk ? "ready" : "null");
    fflush(stderr);

    if (!passed) {
        [self showFailure:[NSString stringWithFormat:
            @"仓绘 iOS 产品场景未通过\nframes=%ld counter=%" PRId64
            " keys=%" PRId64 " ime=%" PRId64 " a11y=%ld",
            (long)sceneFrames, counter, keyCount, imeCount, (long)accessibility]];
    }
}

- (void)showFailure:(NSString *)message {
    self.failureLabel.text = message;
    self.failureLabel.hidden = NO;
}

@end

int main(int argc, char **argv) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(AppDelegate.class));
    }
}
