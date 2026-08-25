package chui.core

import sdl.{Rect, Size, UiEvent}

/**
 * A three-slot information row with stable leading, content and trailing ownership.
 *
 * The leading and trailing slots hug their content. The middle slot receives the
 * remaining width, so metadata and actions stay at the trailing edge instead of
 * drifting into the title. Default padding and minimum height provide a usable row
 * even when application code does not add its own chrome.
 *
 * This is a layout recipe, not a list-selection control. Wrap it in `Button` or
 * `InteractionSurface` when the entire row owns one action; keep nested controls out
 * of that wrapper so interaction ownership remains unambiguous.
 */
public class ContentRow <: Widget {
    private let row: Stack
    private let minimumHeight: Length

    public init(
        spacing!: Length = 8.vp,
        padding!: LengthInsets = LengthInsets(12.vp, 8.vp),
        minHeight!: Length = 44.vp,
        leading!: () -> Unit,
        content!: () -> Unit,
        trailing!: () -> Unit
    ) {
        let leadingChild = buildChild(leading)
        let contentChild = buildChild(content)
        let trailingChild = buildChild(trailing)
        let flexibleContent = buildChild({=>
            Flexible {
                emit(contentChild)
            }
        })
        row = Stack(
            Axis.Horizontal,
            [leadingChild, flexibleContent, trailingChild],
            spacing: spacing,
            padding: padding,
            flexible: false
        )
        row.setCrossAlignment(CrossAxisAlignment.Center)
        minimumHeight = minHeight
        emit(this)
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let measured = row.measure(ctx, available)
        Size(measured.w, min(available.h, max(ctx.resolve(minimumHeight), measured.h)))
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        row.layout(ctx, rect)
    }

    public func draw(ctx: UiContext): Unit {
        row.draw(ctx)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        row.handle(ctx, event)
    }

    /** Information rows fill available width but do not inherit an unrelated tall parent. */
    public func acceptsStretch(axis: Axis): Bool {
        match (axis) {
            case Axis.Horizontal => true
            case Axis.Vertical => false
        }
    }

    public func focusableIds(): Array<String> {
        row.focusableIds()
    }

    public func interactionOwnerIds(): Array<String> {
        row.interactionOwnerIds()
    }
}
