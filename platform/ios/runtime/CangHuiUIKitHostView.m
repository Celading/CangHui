#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <sys/utsname.h>

#import "CangHuiNativeSurface.h"
#import "CangHuiRuntimeBootstrap.h"
#import "CangHuiUIKitHostView.h"

#include <math.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

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

typedef struct CangHuiPointerArguments {
    int64_t phase;
    int64_t identifier;
    int64_t x;
    int64_t y;
    int64_t timestamp;
    int64_t kind;
    int64_t generation;
} CangHuiPointerArguments;

typedef struct CangHuiTraitArguments {
    int64_t style;
    int64_t horizontalSizeClass;
    int64_t verticalSizeClass;
    int64_t scale;
} CangHuiTraitArguments;

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

static void *CangHuiPointerTask(void *rawArguments) {
    CangHuiPointerArguments *arguments = rawArguments;
    return (void *)(intptr_t)canghui_ios_surface_pointer(
        arguments->phase,
        arguments->identifier,
        arguments->x,
        arguments->y,
        arguments->timestamp,
        arguments->kind,
        arguments->generation);
}

static void *CangHuiTraitTask(void *rawArguments) {
    CangHuiTraitArguments *arguments = rawArguments;
    return (void *)(intptr_t)canghui_ios_surface_traits(
        arguments->style,
        arguments->horizontalSizeClass,
        arguments->verticalSizeClass,
        arguments->scale);
}

static void *CangHuiIdiomTask(void *rawIdiom) {
    return (void *)(intptr_t)canghui_ios_surface_set_idiom((int64_t)(intptr_t)rawIdiom);
}

/*
 * Manually packaged bundles can report `.unspecified` or even the phone family
 * on an iPad simulator. Prefer the simulated/real machine identifier, then the
 * public idiom and model string.
 */
static NSString *CangHuiHostMachine(void) {
#if TARGET_OS_SIMULATOR
    NSString *simulated = NSProcessInfo.processInfo.environment[@"SIMULATOR_MODEL_IDENTIFIER"];
    if (simulated.length > 0) {
        return simulated;
    }
#endif
    struct utsname info;
    if (uname(&info) == 0) {
        NSString *machine = [NSString stringWithUTF8String:info.machine];
        if (machine.length > 0) {
            return machine;
        }
    }
    return @"";
}

static int64_t CangHuiHostDeviceFamily(void) {
    NSString *machine = CangHuiHostMachine();
    if ([machine hasPrefix:@"iPad"]) {
        return 2;
    }
    if ([machine hasPrefix:@"iPhone"] || [machine hasPrefix:@"iPod"]) {
        return 1;
    }
    int64_t idiom = (int64_t)UIDevice.currentDevice.userInterfaceIdiom;
    if (idiom == 1 || idiom == 2) {
        return idiom;
    }
    NSString *model = UIDevice.currentDevice.model;
    if ([model hasPrefix:@"iPad"]) {
        return 2;
    }
    if ([model hasPrefix:@"iPhone"] || [model hasPrefix:@"iPod"]) {
        return 1;
    }
    return idiom;
}

typedef struct CangHuiKeyArguments {
    int64_t phase;
    int64_t keyCode;
    int64_t scanCode;
    int64_t repeat;
    int64_t modifiers;
    int64_t generation;
} CangHuiKeyArguments;

typedef struct CangHuiImeArguments {
    char text[4096];
    int64_t length;
    int64_t phase;
    int64_t selectionStart;
    int64_t selectionEnd;
    int64_t generation;
} CangHuiImeArguments;

static void *CangHuiKeyTask(void *rawArguments) {
    CangHuiKeyArguments *arguments = rawArguments;
    return (void *)(intptr_t)canghui_ios_surface_key(
        arguments->phase,
        arguments->keyCode,
        arguments->scanCode,
        arguments->repeat,
        arguments->modifiers,
        arguments->generation);
}

static void *CangHuiImeTask(void *rawArguments) {
    CangHuiImeArguments *arguments = rawArguments;
    return (void *)(intptr_t)canghui_ios_surface_ime(
        (const uint8_t *)arguments->text,
        arguments->length,
        arguments->phase,
        arguments->selectionStart,
        arguments->selectionEnd,
        arguments->generation);
}

@implementation CangHuiUIKitHostView {
    UITextField *_canghuiTextInputField;
    NSArray<UIAccessibilityElement *> *_canghuiAccessibilityElements;
}

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
    self.isAccessibilityElement = NO;
    _canghuiTextInputField = [[UITextField alloc] initWithFrame:CGRectMake(0.0, 0.0, 1.0, 1.0)];
    _canghuiTextInputField.alpha = 0.01;
    _canghuiTextInputField.backgroundColor = UIColor.clearColor;
    _canghuiTextInputField.textColor = UIColor.clearColor;
    _canghuiTextInputField.tintColor = UIColor.clearColor;
    _canghuiTextInputField.autocorrectionType = UITextAutocorrectionTypeNo;
    _canghuiTextInputField.spellCheckingType = UITextSpellCheckingTypeNo;
    _canghuiTextInputField.delegate = self;
    [_canghuiTextInputField addTarget:self
        action:@selector(canghuiTextInputChanged:)
        forControlEvents:UIControlEventEditingChanged];
    [self addSubview:_canghuiTextInputField];
    if (@available(iOS 13.0, *)) {
        UIHoverGestureRecognizer *hover = [[UIHoverGestureRecognizer alloc]
            initWithTarget:self action:@selector(canghuiHandleHover:)];
        [self addGestureRecognizer:hover];
    }
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
    return self.canghuiInputGeneration;
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

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self canghuiForwardTraits];
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
        if (touch.type == UITouchTypePencil) {
            [self canghuiForwardPointerForTouch:touch phase:phase];
        }
    }
}

- (void)canghuiForwardPointerForTouch:(UITouch *)touch phase:(int64_t)touchPhase {
    int64_t generation = self.canghuiSurfaceGeneration;
    if (generation <= 0) {
        return;
    }
    int64_t pointerPhase = touchPhase == CANGHUI_IOS_TOUCH_BEGAN
        ? CANGHUI_IOS_POINTER_BEGAN
        : touchPhase == CANGHUI_IOS_TOUCH_ENDED || touchPhase == CANGHUI_IOS_TOUCH_CANCELLED
            ? CANGHUI_IOS_POINTER_ENDED
            : CANGHUI_IOS_POINTER_MOVED;
    CGPoint point = [touch locationInView:self];
    CangHuiPointerArguments arguments = {
        .phase = pointerPhase,
        .identifier = (int64_t)(intptr_t)(__bridge void *)touch,
        .x = llround(point.x * 1000.0),
        .y = llround(point.y * 1000.0),
        .timestamp = llround(touch.timestamp * 1000.0),
        .kind = CANGHUI_IOS_POINTER_KIND_PENCIL,
        .generation = generation,
    };
    (void)canghui_runtime_run_task(CangHuiPointerTask, &arguments, CangHuiTaskTimeoutNanos);
}

- (void)canghuiHandleHover:(UIHoverGestureRecognizer *)recognizer {
    int64_t generation = self.canghuiSurfaceGeneration;
    if (generation <= 0) {
        return;
    }
    int64_t pointerPhase = recognizer.state == UIGestureRecognizerStateBegan
        ? CANGHUI_IOS_POINTER_BEGAN
        : recognizer.state == UIGestureRecognizerStateEnded ||
            recognizer.state == UIGestureRecognizerStateCancelled
            ? CANGHUI_IOS_POINTER_ENDED
            : CANGHUI_IOS_POINTER_MOVED;
    int64_t pointerKind = CANGHUI_IOS_POINTER_KIND_INDIRECT;
    if (@available(iOS 16.1, *)) {
        if (recognizer.zOffset > 0.0) {
            pointerKind = CANGHUI_IOS_POINTER_KIND_PENCIL;
        }
    }
    if (@available(iOS 16.4, *)) {
        if (recognizer.altitudeAngle > 0.0) {
            pointerKind = CANGHUI_IOS_POINTER_KIND_PENCIL;
        }
    }
    CGPoint point = [recognizer locationInView:self];
    CangHuiPointerArguments arguments = {
        .phase = pointerPhase,
        .identifier = (int64_t)(intptr_t)(__bridge void *)recognizer,
        .x = llround(point.x * 1000.0),
        .y = llround(point.y * 1000.0),
        .timestamp = llround(CACurrentMediaTime() * 1000.0),
        .kind = pointerKind,
        .generation = generation,
    };
    (void)canghui_runtime_run_task(CangHuiPointerTask, &arguments, CangHuiTaskTimeoutNanos);
}

- (void)canghuiForwardTraits {
    (void)canghui_runtime_run_task(CangHuiIdiomTask,
        (void *)(intptr_t)CangHuiHostDeviceFamily(), CangHuiTaskTimeoutNanos);
    UIUserInterfaceStyle style = UIUserInterfaceStyleUnspecified;
    if (@available(iOS 12.0, *)) {
        style = self.traitCollection.userInterfaceStyle;
    }
    NSInteger horizontal = self.traitCollection.horizontalSizeClass;
    NSInteger vertical = self.traitCollection.verticalSizeClass;
    CGFloat scale = self.window.screen.scale;
    if (scale <= 0.0) {
        scale = UIScreen.mainScreen.scale;
    }
    CangHuiTraitArguments arguments = {
        .style = style == UIUserInterfaceStyleLight
            ? CANGHUI_IOS_TRAIT_STYLE_LIGHT
            : style == UIUserInterfaceStyleDark
                ? CANGHUI_IOS_TRAIT_STYLE_DARK
                : CANGHUI_IOS_TRAIT_STYLE_UNSPECIFIED,
        .horizontalSizeClass = horizontal == UIUserInterfaceSizeClassCompact
            ? CANGHUI_IOS_TRAIT_SIZE_COMPACT
            : horizontal == UIUserInterfaceSizeClassRegular
                ? CANGHUI_IOS_TRAIT_SIZE_REGULAR
                : CANGHUI_IOS_TRAIT_SIZE_UNSPECIFIED,
        .verticalSizeClass = vertical == UIUserInterfaceSizeClassCompact
            ? CANGHUI_IOS_TRAIT_SIZE_COMPACT
            : vertical == UIUserInterfaceSizeClassRegular
                ? CANGHUI_IOS_TRAIT_SIZE_REGULAR
                : CANGHUI_IOS_TRAIT_SIZE_UNSPECIFIED,
        .scale = llround(scale * 1000.0),
    };
    (void)canghui_runtime_run_task(CangHuiTraitTask, &arguments, CangHuiTaskTimeoutNanos);
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

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)canghuiBeginTextInput {
    [_canghuiTextInputField becomeFirstResponder];
}

- (void)canghuiEndTextInput {
    [_canghuiTextInputField resignFirstResponder];
}

- (void)canghuiSetTextInputText:(NSString *)text
    selectionStart:(NSInteger)selectionStart
    selectionEnd:(NSInteger)selectionEnd {
    _canghuiTextInputField.text = text ?: @"";
    NSInteger length = (NSInteger)_canghuiTextInputField.text.length;
    NSInteger start = MIN(MAX(0, selectionStart), length);
    NSInteger end = MIN(MAX(start, selectionEnd), length);
    UITextPosition *startPosition = [_canghuiTextInputField
        positionFromPosition:_canghuiTextInputField.beginningOfDocument offset:start];
    UITextPosition *endPosition = startPosition == nil ? nil : [_canghuiTextInputField
        positionFromPosition:startPosition offset:end - start];
    if (startPosition != nil && endPosition != nil) {
        _canghuiTextInputField.selectedTextRange = [_canghuiTextInputField
            textRangeFromPosition:startPosition toPosition:endPosition];
    }
    [self canghuiForwardTextInputWithPhase:1];
}

- (void)canghuiTextInputChanged:(UITextField *)textField {
    [self canghuiForwardTextInputWithPhase:textField.markedTextRange == nil ? 1 : 0];
}

- (void)textFieldDidChangeSelection:(UITextField *)textField {
    [self canghuiForwardTextInputWithPhase:textField.markedTextRange == nil ? 1 : 0];
}

- (NSRange)canghuiSelectedRange {
    UITextRange *range = _canghuiTextInputField.selectedTextRange;
    if (range == nil) {
        return NSMakeRange(_canghuiTextInputField.text.length, 0);
    }
    UITextPosition *beginning = _canghuiTextInputField.beginningOfDocument;
    NSInteger start = [_canghuiTextInputField offsetFromPosition:beginning toPosition:range.start];
    NSInteger end = [_canghuiTextInputField offsetFromPosition:beginning toPosition:range.end];
    if (start < 0) { start = 0; }
    if (end < start) { end = start; }
    return NSMakeRange((NSUInteger)start, (NSUInteger)(end - start));
}

- (void)canghuiForwardTextInputWithPhase:(int64_t)phase {
    int64_t generation = self.canghuiSurfaceGeneration;
    if (generation <= 0) {
        return;
    }
    NSString *text = _canghuiTextInputField.text ?: @"";
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    if (data == nil) {
        return;
    }
    CangHuiImeArguments arguments = {0};
    NSUInteger copyLength = MIN(data.length, sizeof(arguments.text));
    if (copyLength > 0) {
        memcpy(arguments.text, data.bytes, copyLength);
    }
    NSRange selection = [self canghuiSelectedRange];
    arguments.length = (int64_t)copyLength;
    arguments.phase = phase;
    arguments.selectionStart = (int64_t)selection.location;
    arguments.selectionEnd = (int64_t)(selection.location + selection.length);
    arguments.generation = generation;
    (void)canghui_runtime_run_task(CangHuiImeTask, &arguments, CangHuiTaskTimeoutNanos);
}

- (void)canghuiForwardKeyWithPhase:(int64_t)phase
    keyCode:(int64_t)keyCode
    modifiers:(int64_t)modifiers
    repeat:(BOOL)repeat {
    int64_t generation = self.canghuiSurfaceGeneration;
    if (generation <= 0) {
        return;
    }
    CangHuiKeyArguments arguments = {
        .phase = phase,
        .keyCode = keyCode,
        .scanCode = 0,
        .repeat = repeat ? 1 : 0,
        .modifiers = modifiers,
        .generation = generation,
    };
    (void)canghui_runtime_run_task(CangHuiKeyTask, &arguments, CangHuiTaskTimeoutNanos);
}

- (void)canghuiForwardPresses:(NSSet<UIPress *> *)presses phase:(int64_t)phase {
    if (@available(iOS 13.4, *)) {
        for (UIPress *press in presses) {
            UIKey *key = press.key;
            if (key == nil) {
                continue;
            }
            [self canghuiForwardKeyWithPhase:phase
                keyCode:(int64_t)key.keyCode
                modifiers:(int64_t)key.modifierFlags
                repeat:press.phase == UIPressPhaseChanged];
        }
    }
}

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    [self canghuiForwardPresses:presses phase:0];
    [super pressesBegan:presses withEvent:event];
}

- (void)pressesChanged:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    [self canghuiForwardPresses:presses phase:0];
    [super pressesChanged:presses withEvent:event];
}

- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    [self canghuiForwardPresses:presses phase:1];
    [super pressesEnded:presses withEvent:event];
}

- (void)pressesCancelled:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    [self canghuiForwardPresses:presses phase:1];
    [super pressesCancelled:presses withEvent:event];
}

- (void)canghuiSetAccessibilityNodes:(NSArray<NSDictionary *> *)nodes {
    NSMutableArray<UIAccessibilityElement *> *elements = [NSMutableArray array];
    for (NSDictionary *node in nodes) {
        if (![node isKindOfClass:NSDictionary.class]) {
            continue;
        }
        UIAccessibilityElement *element = [[UIAccessibilityElement alloc]
            initWithAccessibilityContainer:self];
        element.accessibilityLabel = [node[@"label"] isKindOfClass:NSString.class]
            ? node[@"label"] : nil;
        element.accessibilityValue = [node[@"value"] isKindOfClass:NSString.class]
            ? node[@"value"] : nil;
        element.accessibilityIdentifier = [node[@"identifier"] isKindOfClass:NSString.class]
            ? node[@"identifier"] : nil;
        element.accessibilityTraits = [node[@"traits"] unsignedLongLongValue];
        element.accessibilityFrameInContainerSpace = CGRectMake(
            [node[@"x"] doubleValue],
            [node[@"y"] doubleValue],
            [node[@"width"] doubleValue],
            [node[@"height"] doubleValue]);
        [elements addObject:element];
    }
    _canghuiAccessibilityElements = elements.copy;
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
}

- (NSInteger)canghuiAccessibilityElementCount {
    return (NSInteger)_canghuiAccessibilityElements.count;
}

- (NSInteger)accessibilityElementCount {
    return (NSInteger)_canghuiAccessibilityElements.count;
}

- (id)accessibilityElementAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)_canghuiAccessibilityElements.count) {
        return nil;
    }
    return _canghuiAccessibilityElements[(NSUInteger)index];
}

- (NSInteger)indexOfAccessibilityElement:(id)element {
    return (NSInteger)[_canghuiAccessibilityElements indexOfObject:element];
}

@end
