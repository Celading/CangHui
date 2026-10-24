#ifndef CANGHUI_UIKIT_HOST_VIEW_H
#define CANGHUI_UIKIT_HOST_VIEW_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/** UIKit ingress shared by CangHui-owned iOS surfaces. */
@interface CangHuiUIKitHostView : UIView <UITextFieldDelegate>
/** Surface generation used by keyboard/IME ingress; set by the owning surface host. */
@property(nonatomic, assign) int64_t canghuiInputGeneration;
- (int64_t)canghuiSurfaceGeneration;
- (void)canghuiForwardTraits;
- (void)canghuiBeginTextInput;
- (void)canghuiEndTextInput;
- (void)canghuiSetTextInputText:(NSString *)text
    selectionStart:(NSInteger)selectionStart
    selectionEnd:(NSInteger)selectionEnd;
- (void)canghuiForwardKeyWithPhase:(int64_t)phase
    keyCode:(int64_t)keyCode
    modifiers:(int64_t)modifiers
    repeat:(BOOL)repeat;
- (void)canghuiSetAccessibilityNodes:(NSArray<NSDictionary *> *)nodes;
@property(nonatomic, readonly) NSInteger canghuiAccessibilityElementCount;
@end

NS_ASSUME_NONNULL_END

#endif
