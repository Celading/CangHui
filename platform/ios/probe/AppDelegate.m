#import <UIKit/UIKit.h>

#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>

#import "CangHuiHost.h"
#import "CangHuiRuntimeBootstrap.h"

static void *read_canghui_abi(void *unused) {
    (void)unused;
    return (void *)(intptr_t)canghui_ios_host_abi_version();
}

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@property(nonatomic, strong) UILabel *statusLabel;
@end

@implementation AppDelegate

- (void)runBootstrapProbe {
    const char *executable_name =
        NSBundle.mainBundle.executableURL.lastPathComponent.UTF8String;
    CangHuiRuntimeBootstrapResult bootstrap =
        canghui_runtime_bootstrap_start(executable_name, 5000000000LL);
    CangHuiRuntimeTaskResult task =
        canghui_runtime_run_task(read_canghui_abi, NULL, 5000000000LL);
    int64_t abi = task.status == 0 ? (int64_t)(intptr_t)task.value : -1;
    const char *scheduler = bootstrap.scheduler_ready == 1 ? "ready" : "null";

    fprintf(stderr,
        "CANGHUI_IOS_PROBE result runtime=%d scheduler=%s library=%d task=%d abi=%" PRId64 "\n",
        bootstrap.runtime_status,
        scheduler,
        bootstrap.library_status,
        task.status,
        abi);
    fflush(stderr);

    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL passed = bootstrap.runtime_status == 0 &&
            bootstrap.scheduler_ready == 1 &&
            bootstrap.library_status == 0 && task.status == 0 && abi == 1;
        self.statusLabel.textColor = passed
            ? UIColor.systemGreenColor
            : UIColor.systemRedColor;
        self.statusLabel.text = [NSString stringWithFormat:
            @"CangHui iOS bootstrap\nruntime=%d scheduler=%s\nlibrary=%d task=%d abi=%lld",
            bootstrap.runtime_status,
            scheduler,
            bootstrap.library_status,
            task.status,
            (long long)abi];
    });
}

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)application;
    (void)launchOptions;

    UIViewController *controller = [UIViewController new];
    controller.view.backgroundColor = UIColor.systemBackgroundColor;

    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont monospacedSystemFontOfSize:18
                                           weight:UIFontWeightSemibold];
    label.text = @"CangHui iOS bootstrap\nstarting";
    self.statusLabel = label;
    [controller.view addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:controller.view.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:controller.view.centerYAnchor],
        [label.leadingAnchor constraintGreaterThanOrEqualToAnchor:
            controller.view.leadingAnchor constant:24],
        [label.trailingAnchor constraintLessThanOrEqualToAnchor:
            controller.view.trailingAnchor constant:-24]
    ]];

    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = controller;
    [self.window makeKeyAndVisible];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [self runBootstrapProbe];
    });
    return YES;
}

@end

int main(int argc, char **argv) {
    @autoreleasepool {
        return UIApplicationMain(
            argc, argv, nil, NSStringFromClass(AppDelegate.class));
    }
}
