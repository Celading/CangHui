#import <UIKit/UIKit.h>

#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <sys/utsname.h>

#import "CangHuiNativeSceneSurfaceView.h"
#import "CangHuiRuntimeBootstrap.h"

static const int64_t CangHuiWidgetsTimeoutNanos = 5000000000LL;

extern int64_t canghui_ios_widgets_start(void);
extern int64_t canghui_ios_widgets_set_family(int64_t family);
extern int32_t canghui_ios_widgets_render(int64_t width_milli, int64_t height_milli,
    int64_t event_kind, int64_t x_milli, int64_t y_milli, uint8_t *output,
    int64_t output_capacity, int64_t *output_length);
extern int64_t canghui_ios_widgets_counter(void);
extern int64_t canghui_ios_widgets_render_count(void);
extern int32_t canghui_ios_widgets_profile(uint8_t *output, int64_t capacity, int64_t *length);

static int32_t CangHuiWidgetsRender(int64_t width, int64_t height, int64_t kind,
    int64_t x, int64_t y, uint8_t *output, int64_t capacity, int64_t *length) {
    return canghui_ios_widgets_render(width, height, kind, x, y, output, capacity, length);
}

typedef struct CangHuiWidgetsFamily {
    int64_t family;
    int64_t status;
} CangHuiWidgetsFamily;

static void *CangHuiWidgetsStartTask(void *unused) {
    (void)unused;
    return (void *)(intptr_t)canghui_ios_widgets_start();
}

static void *CangHuiWidgetsFamilyTask(void *raw) {
    CangHuiWidgetsFamily *arguments = raw;
    arguments->status = canghui_ios_widgets_set_family(arguments->family);
    return raw;
}

static int64_t CangHuiWidgetsHostFamily(void) {
    NSString *machine = nil;
#if TARGET_OS_SIMULATOR
    machine = NSProcessInfo.processInfo.environment[@"SIMULATOR_MODEL_IDENTIFIER"];
#endif
    if (machine.length == 0) {
        struct utsname info;
        if (uname(&info) == 0) {
            machine = [NSString stringWithUTF8String:info.machine];
        }
    }
    if ([machine hasPrefix:@"iPad"]) { return 2; }
    if ([machine hasPrefix:@"iPhone"] || [machine hasPrefix:@"iPod"]) { return 1; }
    int64_t idiom = (int64_t)UIDevice.currentDevice.userInterfaceIdiom;
    if (idiom == 1 || idiom == 2) { return idiom; }
    return 0;
}

static NSString *CangHuiWidgetsReadProfile(void) {
    int64_t required = 0;
    if (canghui_ios_widgets_profile(NULL, 0, &required) != -2 || required <= 0) {
        return nil;
    }
    NSMutableData *buffer = [NSMutableData dataWithLength:(NSUInteger)required];
    int64_t copied = 0;
    if (canghui_ios_widgets_profile(buffer.mutableBytes, required, &copied) != 0 ||
        copied <= 0) {
        return nil;
    }
    return [[NSString alloc] initWithBytes:buffer.bytes length:(NSUInteger)copied
        encoding:NSUTF8StringEncoding];
}

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@property(nonatomic, strong) CangHuiNativeSceneSurfaceView *surface;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)application;
    (void)launchOptions;
    UIViewController *root = [UIViewController new];
    root.view.backgroundColor = UIColor.systemBackgroundColor;
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = root;
    [self.window makeKeyAndVisible];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        CangHuiRuntimeBootstrapResult bootstrap = canghui_runtime_bootstrap_start(
            NSBundle.mainBundle.executableURL.lastPathComponent.UTF8String,
            CangHuiWidgetsTimeoutNanos);
        CangHuiWidgetsFamily family = {.family = CangHuiWidgetsHostFamily(), .status = -1};
        CangHuiRuntimeTaskResult familyResult = canghui_runtime_run_task(
            CangHuiWidgetsFamilyTask, &family, CangHuiWidgetsTimeoutNanos);
        CangHuiRuntimeTaskResult startResult = canghui_runtime_run_task(
            CangHuiWidgetsStartTask, NULL, CangHuiWidgetsTimeoutNanos);
        fprintf(stderr,
            "CANGHUI_IOS_WIDGETS bootstrap runtime=%d scheduler=%d library=%d family=%" PRId64
            " family_status=%" PRId64 " start=%d\n",
            bootstrap.runtime_status, bootstrap.scheduler_ready, bootstrap.library_status,
            family.family, family.status, startResult.status);
        fflush(stderr);
        dispatch_async(dispatch_get_main_queue(), ^{
            self.surface = [[CangHuiNativeSceneSurfaceView alloc] initWithFrame:CGRectZero
                renderFunction:CangHuiWidgetsRender];
            self.surface.translatesAutoresizingMaskIntoConstraints = NO;
            [root.view addSubview:self.surface];
            [NSLayoutConstraint activateConstraints:@[
                [self.surface.leadingAnchor constraintEqualToAnchor:root.view.leadingAnchor],
                [self.surface.trailingAnchor constraintEqualToAnchor:root.view.trailingAnchor],
                [self.surface.topAnchor constraintEqualToAnchor:root.view.topAnchor],
                [self.surface.bottomAnchor constraintEqualToAnchor:root.view.bottomAnchor]]];
            [root.view layoutIfNeeded];
            [self.surface canghuiMarkNativeSceneDirty];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 800000000), dispatch_get_main_queue(), ^{
                [self.surface canghuiReplayNativeSceneTapAtPoint:CGPointMake(60.0, 36.0)];
            });
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1800000000), dispatch_get_main_queue(), ^{
                int64_t counter = canghui_ios_widgets_counter();
                int64_t renders = canghui_ios_widgets_render_count();
                NSString *profileString = CangHuiWidgetsReadProfile();
                NSDictionary *profile = profileString != nil
                    ? [NSJSONSerialization JSONObjectWithData:
                        [profileString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil]
                    : nil;
                NSString *device = [profile[@"deviceClass"] isKindOfClass:NSString.class]
                    ? profile[@"deviceClass"] : @"null";
                NSString *breakpoint = [profile[@"breakpoint"] isKindOfClass:NSString.class]
                    ? profile[@"breakpoint"] : @"null";
                NSInteger frames = self.surface.canghuiPresentedSceneFrameCount;
                BOOL passed = counter == 1 && renders >= 2 &&
                    ![device isEqualToString:@"null"] && ![breakpoint isEqualToString:@"null"];
                fprintf(stderr,
                    "CANGHUI_IOS_WIDGETS result passed=%d counter=%" PRId64
                    " renders=%" PRId64 " frames=%ld device=%s breakpoint=%s\n",
                    passed ? 1 : 0, counter, renders, (long)frames,
                    device.UTF8String, breakpoint.UTF8String);
                fflush(stderr);
            });
        });
    });
    return YES;
}

@end

int main(int argc, char **argv) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(AppDelegate.class));
    }
}
