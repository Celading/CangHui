package chui.core

import sdl.Renderer
import sdl.input.Keyboard

@Test
func eventModifierScopeRestoresNestedAndFailedDispatchWithoutGlobalMutation(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let peer = UiContext(Renderer.headless(), Theme.light())
    let actual = Keyboard.modifiers().raw
    let _ = ctx.withEventModifiers(Some(UInt16(1)), {=>
        @Expect(ctx.keyModifiers().shift)
        @Expect(peer.keyModifiers().raw, actual)
        @Expect(Keyboard.modifiers().raw, actual)
        let _ = ctx.withEventModifiers(Some(UInt16(0)), {=>
            @Expect(!ctx.keyModifiers().shift)
            @Expect(!ctx.keyModifiers().command)
            false
        })
        @Expect(ctx.keyModifiers().shift)
        try {
            let _ = ctx.withEventModifiers(Some(UInt16(64)), {=>
                @Expect(ctx.keyModifiers().ctrl)
                throw IllegalStateException("dispatch-test")
            })
        } catch (_: IllegalStateException) { () }
        @Expect(ctx.keyModifiers().shift)
        let _ = ctx.withEventModifiers(None, {=>
            @Expect(ctx.keyModifiers().raw, actual)
            false
        })
        @Expect(ctx.keyModifiers().shift)
        true
    })
    @Expect(ctx.keyModifiers().raw, actual)
    @Expect(Keyboard.modifiers().raw, actual)
}
