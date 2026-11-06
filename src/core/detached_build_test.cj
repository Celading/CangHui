package chui.core

import sdl.Size

@Test
func detachedChildIsEmittedOnlyWhenTheOwnerEmitsIt(): Unit {
    let stack = VStack(spacing: Length(0.0, LengthUnit.Vp)) {
        let detached = buildDetachedChild({=>
            emit(SizedLayoutProbe(Size(50.0, 40.0)))
        })
        emit(detached)
    }
    let measured = stack.measure(testContext(), Size(100.0, 100.0))
    @Expect(measured.h, Float32(40.0))
}
