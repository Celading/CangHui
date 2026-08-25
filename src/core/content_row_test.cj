package chui.core

import sdl.{IconName, Rect, Size}

@Test
func contentRowPinsTrailingSlotAndGivesMiddleTheRemainingWidth(): Unit {
    let ctx = testContext()
    let leading = SizedLayoutProbe(Size(20.0, 20.0))
    let content = SizedLayoutProbe(Size(80.0, 16.0))
    let trailing = SizedLayoutProbe(Size(40.0, 18.0))
    let row = ContentRow(
        leading: {=> emit(leading)},
        content: {=> emit(content)},
        trailing: {=> emit(trailing)}
    )

    let measured = row.measure(ctx, Size(300.0, 120.0))
    @Expect(measured.h, Float32(44.0))

    row.layout(ctx, Rect(0.0, 0.0, 300.0, 44.0))
    @Expect(leading.rect.x, Float32(12.0))
    @Expect(leading.rect.w, Float32(20.0))
    @Expect(content.rect.x, Float32(40.0))
    @Expect(content.rect.w, Float32(200.0))
    @Expect(trailing.rect.x, Float32(248.0))
    @Expect(trailing.rect.right(), Float32(288.0))
}

@Test
func buttonsKeepIntrinsicHeightInTallHorizontalRows(): Unit {
    let ctx = testContext()
    let slot = SizedLayoutProbe(Size(50.0, 18.0))
    let button = Button(onClick: {=> ()}) {
        emit(slot)
    }
    let row = HStack {
        emit(button)
    }

    row.layout(ctx, Rect(0.0, 0.0, 240.0, 120.0))

    @Expect(slot.rect.h, Float32(38.0))
    @Expect(!button.acceptsStretch(Axis.Vertical))
    @Expect(button.acceptsStretch(Axis.Horizontal))
}

@Test
func explicitFillHeightStillOverridesButtonIntrinsicHeight(): Unit {
    let ctx = testContext()
    let slot = SizedLayoutProbe(Size(50.0, 18.0))
    let button = Button(onClick: {=> ()}) {
        emit(slot)
    }
    let row = HStack {
        emit(button)
        button.fillHeight()
    }

    row.layout(ctx, Rect(0.0, 0.0, 240.0, 72.0))

    @Expect(slot.rect.h, Float32(72.0))
}

@Test
func iconButtonKeepsIntrinsicVerticalStretchPolicy(): Unit {
    let button = IconButton(IconName.Save, onClick: {=> ()})
    @Expect(!button.acceptsStretch(Axis.Vertical))
    @Expect(button.acceptsStretch(Axis.Horizontal))
}
