#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <UIKit/UIKit.h>

#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#import "CangHuiDesktopScene.h"
#import "CangHuiNativeSceneSurfaceView.h"
#import "CangHuiNativeSurface.h"
#import "CangHuiRuntimeBootstrap.h"

/*
 * iPad desktop shell. The product owns the surface host: hover, hardware keys,
 * IME and accessibility go through this file, while Cangjie owns every pixel
 * of the scene. The acceptance flow below drives the same entry points UIKit
 * uses and then reports one machine-readable line.
 */
static const int64_t CangHuiDesktopTimeoutNanos = 5000000000LL;

static int32_t CangHuiDesktopRender(
    int64_t widthMilli,
    int64_t heightMilli,
    int64_t eventKind,
    int64_t xMilli,
    int64_t yMilli,
    uint8_t * _Nullable output,
    int64_t outputCapacity,
    int64_t * _Nonnull outputLength) {
    return canghui_ios_desktop_render(widthMilli, heightMilli, eventKind,
        xMilli, yMilli, output, outputCapacity, outputLength);
}

static NSString *CangHuiDesktopReadString(
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

static NSDictionary *CangHuiDesktopReadJSON(
    int32_t (*reader)(uint8_t *, int64_t, int64_t *)) {
    NSString *text = CangHuiDesktopReadString(reader);
    if (text == nil) {
        return nil;
    }
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    id value = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

/** Scene view that also owns the hardware-key path. */
@interface CangHuiDesktopSceneView : CangHuiNativeSceneSurfaceView
- (BOOL)canghuiForwardKeyPhase:(int64_t)phase
    keyCode:(int64_t)keyCode
    modifiers:(int64_t)modifiers
    repeat:(BOOL)repeat;
@end

@implementation CangHuiDesktopSceneView

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (BOOL)canghuiForwardKeyPhase:(int64_t)phase
    keyCode:(int64_t)keyCode
    modifiers:(int64_t)modifiers
    repeat:(BOOL)repeat {
    if (phase < 0 || phase > 1 || keyCode < 0) {
        return NO;
    }
    if (canghui_ios_desktop_key(phase, keyCode, modifiers, repeat ? 1 : 0) != 1) {
        return NO;
    }
    if (phase == 1) {
        [self canghuiMarkNativeSceneDirty];
    }
    return YES;
}

- (void)forwardPresses:(NSSet<UIPress *> *)presses phase:(int64_t)phase {
    if (@available(iOS 13.4, *)) {
        BOOL handled = NO;
        for (UIPress *press in presses) {
            UIKey *key = press.key;
            if (key == nil) {
                continue;
            }
            int64_t modifiers = (int64_t)key.modifierFlags;
            handled = [self canghuiForwardKeyPhase:phase
                keyCode:(int64_t)key.keyCode
                modifiers:modifiers
                repeat:press.phase == UIPressPhaseChanged] || handled;
        }
        if (handled) {
            [self canghuiMarkNativeSceneDirty];
        }
    }
}

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    [self forwardPresses:presses phase:0];
    [super pressesBegan:presses withEvent:event];
}

- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    [self forwardPresses:presses phase:1];
    [super pressesEnded:presses withEvent:event];
}

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate, UITextFieldDelegate>
@property(nonatomic, strong) UIWindow *window;
@property(nonatomic, strong) UIViewController *rootController;
@property(nonatomic, strong) CangHuiDesktopSceneView *sceneView;
@property(nonatomic, strong) UITextField *searchField;
@property(nonatomic, strong) UILabel *failureLabel;
@property(nonatomic, assign) BOOL reported;
@property(nonatomic, assign) BOOL profilePushed;

- (void)handleHover:(UIHoverGestureRecognizer *)recognizer;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)application;
    (void)launchOptions;

    self.rootController = [UIViewController new];
    self.rootController.view.backgroundColor = [UIColor colorWithRed:11.0 / 255.0
        green:14.0 / 255.0 blue:19.0 / 255.0 alpha:1.0];

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

    [self requestOrientationFromEnvironment];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [self bootRuntime];
    });
    return YES;
}

/*
 * The surface is normally driven by the device orientation. Acceptance runs
 * that need the wide three-pane layout ask for it explicitly through
 * CANGHUI_IOS_DESKTOP_ORIENTATION=landscape; launch without it to keep the
 * device's own orientation.
 */
- (void)requestOrientationFromEnvironment {
    NSString *requested = NSProcessInfo.processInfo.environment[
        @"CANGHUI_IOS_DESKTOP_ORIENTATION"];
    BOOL landscape = [requested isEqualToString:@"landscape"];
    BOOL portrait = [requested isEqualToString:@"portrait"];
    if (!landscape && !portrait) {
        return;
    }
    UIInterfaceOrientationMask mask = landscape
        ? UIInterfaceOrientationMaskLandscape
        : UIInterfaceOrientationMaskPortrait;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 400000000),
        dispatch_get_main_queue(), ^{
            if (@available(iOS 16.0, *)) {
                UIWindowScene *scene = self.window.windowScene;
                if (scene == nil) {
                    return;
                }
                UIWindowSceneGeometryPreferencesIOS *preferences =
                    [[UIWindowSceneGeometryPreferencesIOS alloc]
                        initWithInterfaceOrientations:mask];
                [scene requestGeometryUpdateWithPreferences:preferences
                    errorHandler:^(NSError *error) {
                        fprintf(stderr, "CANGHUI_IOS_DESKTOP orientation=unavailable %s\n",
                            error.localizedDescription.UTF8String ?: "");
                    }];
            }
        });
}

- (BOOL)desktopWantsLandscape {
    return [NSProcessInfo.processInfo.environment[
        @"CANGHUI_IOS_DESKTOP_ORIENTATION"] isEqualToString:@"landscape"];
}

- (BOOL)desktopWantsPortrait {
    return [NSProcessInfo.processInfo.environment[
        @"CANGHUI_IOS_DESKTOP_ORIENTATION"] isEqualToString:@"portrait"];
}

- (void)bootRuntime {
    const char *executableName =
        NSBundle.mainBundle.executableURL.lastPathComponent.UTF8String;
    CangHuiRuntimeBootstrapResult bootstrap =
        canghui_runtime_bootstrap_start(executableName, CangHuiDesktopTimeoutNanos);
    BOOL ready = bootstrap.runtime_status == 0 &&
        bootstrap.scheduler_ready == 1 && bootstrap.library_status == 0;
    fprintf(stderr, "CANGHUI_IOS_DESKTOP runtime=%d scheduler=%s library=%d\n",
        bootstrap.runtime_status,
        bootstrap.scheduler_ready == 1 ? "ready" : "null",
        bootstrap.library_status);
    fflush(stderr);

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!ready) {
            [self showFailure:@"CangHui 运行时启动失败"];
            fprintf(stderr, "CANGHUI_IOS_DESKTOP result passed=0 reason=runtime\n");
            fflush(stderr);
            return;
        }
        [self installScene];
        [self beginAcceptanceWithAttempts:120];
    });
}

- (void)installScene {
    if (self.sceneView == nil) {
        self.sceneView = [[CangHuiDesktopSceneView alloc]
            initWithFrame:CGRectZero renderFunction:CangHuiDesktopRender];
        self.sceneView.translatesAutoresizingMaskIntoConstraints = NO;
    }
    [self.rootController.view insertSubview:self.sceneView atIndex:0];
    // The desktop window must sit inside the safe area so the system status
    // bar and home indicator keep their own space, as they do on the Mac.
    UILayoutGuide *safe = self.rootController.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.sceneView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [self.sceneView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [self.sceneView.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [self.sceneView.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor]
    ]];
    self.failureLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.failureLabel.centerXAnchor constraintEqualToAnchor:self.rootController.view.centerXAnchor],
        [self.failureLabel.centerYAnchor constraintEqualToAnchor:self.rootController.view.centerYAnchor],
        [self.failureLabel.leadingAnchor constraintEqualToAnchor:
            self.rootController.view.safeAreaLayoutGuide.leadingAnchor constant:24],
        [self.failureLabel.trailingAnchor constraintEqualToAnchor:
            self.rootController.view.safeAreaLayoutGuide.trailingAnchor constant:-24]
    ]];

    if (@available(iOS 13.0, *)) {
        UIHoverGestureRecognizer *hover = [[UIHoverGestureRecognizer alloc]
            initWithTarget:self action:@selector(handleHover:)];
        [self.sceneView addGestureRecognizer:hover];
    }
    [self installSearchField];
    [self.sceneView becomeFirstResponder];
    [self.rootController.view layoutIfNeeded];
}

- (void)installSearchField {
    UITextField *field = [[UITextField alloc] initWithFrame:CGRectMake(-2.0, -2.0, 1.0, 1.0)];
    field.alpha = 0.01;
    field.backgroundColor = UIColor.clearColor;
    field.textColor = UIColor.clearColor;
    field.tintColor = UIColor.clearColor;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.spellCheckingType = UITextSpellCheckingTypeNo;
    field.returnKeyType = UIReturnKeyDone;
    field.delegate = self;
    [field addTarget:self action:@selector(searchFieldChanged:)
        forControlEvents:UIControlEventEditingChanged];
    self.searchField = field;
    [self.rootController.view insertSubview:field atIndex:0];
}

- (void)searchFieldChanged:(UITextField *)field {
    NSData *data = [(field.text ?: @"") dataUsingEncoding:NSUTF8StringEncoding];
    (void)canghui_ios_desktop_set_text((const uint8_t *)data.bytes, (int64_t)data.length);
    [self.sceneView canghuiMarkNativeSceneDirty];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    (void)textField;
    [self.searchField resignFirstResponder];
    [self.sceneView becomeFirstResponder];
    return YES;
}

- (void)handleHover:(UIHoverGestureRecognizer *)recognizer {
    int64_t phase = recognizer.state == UIGestureRecognizerStateBegan
        ? 1
        : recognizer.state == UIGestureRecognizerStateEnded ||
            recognizer.state == UIGestureRecognizerStateCancelled
            ? 2
            : 1;
    CGPoint point = [recognizer locationInView:self.sceneView];
    if (canghui_ios_desktop_hover(phase,
        (int64_t)llround(point.x * 1000.0), (int64_t)llround(point.y * 1000.0)) == 1) {
        [self.sceneView canghuiMarkNativeSceneDirty];
    }
}

- (void)pushDeviceProfile {
    NSDictionary *profile = CangHuiDesktopReadJSON(canghui_ios_surface_device_profile);
    if (profile == nil) {
        return;
    }
    NSNumber *deviceClass = profile[@"deviceClassCode"];
    NSNumber *breakpoint = profile[@"breakpointCode"];
    NSNumber *scaleMilli = profile[@"scaleMilli"];
    if (![deviceClass isKindOfClass:NSNumber.class] ||
        ![breakpoint isKindOfClass:NSNumber.class]) {
        // Older host readback publishes names only; map the two enums here.
        NSString *deviceName = profile[@"deviceClass"];
        NSString *breakpointName = profile[@"breakpoint"];
        int64_t deviceCode = [deviceName isEqualToString:@"ipad-mini"] ? 3
            : [deviceName isEqualToString:@"ipad-large"] ? 4
            : [deviceName isEqualToString:@"iphone"] ? 1
            : [deviceName isEqualToString:@"iphone-duo"] ? 2 : 0;
        int64_t breakpointCode = [breakpointName isEqualToString:@"compact"] ? 1
            : [breakpointName isEqualToString:@"medium"] ? 2 : 3;
        deviceClass = @(deviceCode);
        breakpoint = @(breakpointCode);
    }
    BOOL usesSidebar = [profile[@"usesSidebar"] boolValue];
    int64_t scale = [scaleMilli isKindOfClass:NSNumber.class]
        ? scaleMilli.longLongValue
        : (int64_t)llround(NSProcessInfo.processInfo.environment[@"SIMULATOR_MAINSCREEN_SCALE"]
            .doubleValue * 1000.0);
    if (scale <= 0) {
        scale = 2000;
    }
    int64_t idiom = canghui_ios_surface_idiom();
    (void)canghui_ios_desktop_set_profile(idiom, deviceClass.longLongValue,
        breakpoint.longLongValue, usesSidebar ? 1 : 0, scale);
    self.profilePushed = YES;
    [self.sceneView canghuiMarkNativeSceneDirty];
}

- (NSDictionary *)actionRect:(NSString *)identifier {
    NSData *report = self.sceneView.canghuiLatestSceneReport;
    if (report.length == 0) {
        return nil;
    }
    NSDictionary *root = [NSJSONSerialization JSONObjectWithData:report options:0 error:nil];
    NSArray *frames = [root isKindOfClass:NSDictionary.class] ? root[@"frames"] : nil;
    NSDictionary *frame = [frames isKindOfClass:NSArray.class] ? frames.lastObject : nil;
    NSArray *actions = [frame isKindOfClass:NSDictionary.class] ? frame[@"actions"] : nil;
    for (NSDictionary *action in actions) {
        if ([action[@"id"] isEqualToString:identifier]) {
            return action;
        }
    }
    return nil;
}

- (BOOL)replayTapOnAction:(NSString *)identifier {
    NSDictionary *rect = [self actionRect:identifier];
    if (rect == nil) {
        return NO;
    }
    CGPoint point = CGPointMake([rect[@"x"] doubleValue] + [rect[@"width"] doubleValue] / 2.0,
        [rect[@"y"] doubleValue] + [rect[@"height"] doubleValue] / 2.0);
    [self.sceneView canghuiReplayNativeSceneTapAtPoint:point];
    return YES;
}

- (void)beginAcceptanceWithAttempts:(NSInteger)attempts {
    if (self.reported) {
        return;
    }
    if (([self desktopWantsLandscape] &&
        self.sceneView.bounds.size.width <= self.sceneView.bounds.size.height) ||
        ([self desktopWantsPortrait] &&
        self.sceneView.bounds.size.width > self.sceneView.bounds.size.height)) {
        if (attempts > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100000000),
                dispatch_get_main_queue(), ^{
                    [self beginAcceptanceWithAttempts:attempts - 1];
                });
        }
        return;
    }
    if (self.sceneView.canghuiSurfaceGeneration <= 0 ||
        self.sceneView.canghuiLatestSceneReport.length == 0) {
        if (attempts > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100000000),
                dispatch_get_main_queue(), ^{
                    [self beginAcceptanceWithAttempts:attempts - 1];
                });
        }
        return;
    }
    if (!self.profilePushed) {
        [self pushDeviceProfile];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 300000000),
            dispatch_get_main_queue(), ^{
                [self beginAcceptanceWithAttempts:attempts];
            });
        return;
    }
    self.sceneView.canghuiInputGeneration = self.sceneView.canghuiSurfaceGeneration;
    [self.sceneView becomeFirstResponder];
    [self runDesktopActions];
    [self verifyWithAttempts:120];
}

- (void)runDesktopActions {
    // Pointer: a replay tap on the second sidebar row.
    (void)[self replayTapOnAction:@"section.1"];
    // Keyboard: Command-3 selects the third section through the real key path.
    [self.sceneView canghuiForwardKeyPhase:1 keyCode:32
        modifiers:(int64_t)UIKeyModifierCommand repeat:NO];
    // Hover: the indirect pointer rests on the fourth sidebar row.
    NSDictionary *hoverRect = [self actionRect:@"section.3"];
    if (hoverRect != nil) {
        (void)canghui_ios_desktop_hover(1,
            (int64_t)llround(([hoverRect[@"x"] doubleValue] +
                [hoverRect[@"width"] doubleValue] / 2.0) * 1000.0),
            (int64_t)llround(([hoverRect[@"y"] doubleValue] +
                [hoverRect[@"height"] doubleValue] / 2.0) * 1000.0));
    }
    // IME: committed text reaches the scene through the same call the field uses.
    const char *text = "仓绘";
    (void)canghui_ios_desktop_set_text((const uint8_t *)text, (int64_t)strlen(text));
    self.searchField.text = @"仓绘";
    // Pointer: the hero play control toggles transport.
    (void)[self replayTapOnAction:@"play.toggle"];

    [self.sceneView canghuiSetAccessibilityNodes:@[
        @{@"label": @"资料库", @"identifier": @"sidebar.library",
          @"traits": @(UIAccessibilityTraitButton), @"x": @24, @"y": @110,
          @"width": @220, @"height": @38},
        @{@"label": @"最近播放", @"identifier": @"sidebar.recent",
          @"traits": @(UIAccessibilityTraitButton), @"x": @24, @"y": @150,
          @"width": @220, @"height": @38},
        @{@"label": @"搜索资料库", @"value": @"仓绘", @"identifier": @"toolbar.search",
          @"traits": @(UIAccessibilityTraitSearchField), @"x": @900, @"y": @30,
          @"width": @196, @"height": @28},
        @{@"label": @"播放", @"identifier": @"hero.play",
          @"traits": @(UIAccessibilityTraitButton), @"x": @700, @"y": @190,
          @"width": @44, @"height": @44},
        @{@"label": @"正在播放", @"value": @"夜间飞行", @"identifier": @"inspector.now",
          @"traits": @(UIAccessibilityTraitStaticText), @"x": @1060, @"y": @120,
          @"width": @200, @"height": @24}
    ]];
    [self.sceneView canghuiMarkNativeSceneDirty];
}

- (void)verifyWithAttempts:(NSInteger)attempts {
    if (self.reported) {
        return;
    }
    NSDictionary *state = CangHuiDesktopReadJSON(canghui_ios_desktop_state);
    NSDictionary *profile = CangHuiDesktopReadJSON(canghui_ios_surface_device_profile);
    NSString *hover = CangHuiDesktopReadString(canghui_ios_desktop_hover_id);
    NSString *searchText = CangHuiDesktopReadString(canghui_ios_desktop_search_text);
    NSString *lastAction = CangHuiDesktopReadString(canghui_ios_desktop_last_action);
    int64_t section = canghui_ios_desktop_section();
    BOOL playing = canghui_ios_desktop_playing() == 1;
    int64_t keys = canghui_ios_desktop_key_count();
    int64_t ime = canghui_ios_desktop_ime_count();
    NSInteger frames = self.sceneView.canghuiPresentedSceneFrameCount;
    NSInteger accessibility = self.sceneView.canghuiAccessibilityElementCount;
    NSString *layout = state[@"layout"];
    NSNumber *commands = state[@"commands"];
    NSNumber *actions = state[@"actions"];
    BOOL textLayout = [state[@"textLayout"] boolValue];
    BOOL usesSidebar = [state[@"usesSidebar"] boolValue];
    BOOL usesInspector = [state[@"usesInspector"] boolValue];
    NSNumber *cardsPerRow = state[@"cardsPerRow"];
    NSString *breakpoint = profile[@"breakpoint"];
    NSString *deviceName = profile[@"deviceClass"];
    NSString *orientation = state[@"orientation"];

    BOOL layoutOk = [layout isEqualToString:@"three-pane-desktop"] ||
        [layout isEqualToString:@"two-pane-desktop"];
    BOOL ready = state != nil && layoutOk && frames >= 1 && commands.longLongValue >= 40 &&
        actions.longLongValue >= 14 && textLayout && section == 2 && playing &&
        [hover isEqualToString:@"section.3"] && [searchText isEqualToString:@"仓绘"] &&
        keys >= 1 && ime >= 1 && accessibility >= 5 &&
        breakpoint.length > 0 && deviceName.length > 0;
    if (!ready && attempts > 0) {
        [self.sceneView canghuiMarkNativeSceneDirty];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100000000),
            dispatch_get_main_queue(), ^{
                [self verifyWithAttempts:attempts - 1];
            });
        return;
    }
    self.reported = YES;
    fprintf(stderr,
        "CANGHUI_IOS_DESKTOP result passed=%d layout=%s breakpoint=%s device=%s"
        " orientation=%s sidebar=%d inspector=%d cards=%lld commands=%lld actions=%lld"
        " section=%" PRId64 " play=%d hover=%s keys=%" PRId64 " ime=%" PRId64
        " a11y=%ld frames=%ld text_layout=%d last=%s bounds=%.0fx%.0f\n",
        ready ? 1 : 0,
        layout.UTF8String ?: "null",
        breakpoint.UTF8String ?: "null",
        deviceName.UTF8String ?: "null",
        orientation.UTF8String ?: "null",
        usesSidebar ? 1 : 0,
        usesInspector ? 1 : 0,
        cardsPerRow.longLongValue,
        commands.longLongValue,
        actions.longLongValue,
        section,
        playing ? 1 : 0,
        hover.UTF8String ?: "",
        keys,
        ime,
        (long)accessibility,
        (long)frames,
        textLayout ? 1 : 0,
        lastAction.UTF8String ?: "",
        self.sceneView.bounds.size.width,
        self.sceneView.bounds.size.height);
    fflush(stderr);

    if (!ready) {
        [self showFailure:[NSString stringWithFormat:
            @"仓绘 iPad 桌面壳未通过\nlayout=%@ section=%" PRId64 " play=%d"
            " hover=%@ search=%@ a11y=%ld",
            layout, section, playing ? 1 : 0, hover, searchText, (long)accessibility]];
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
