package chui.media

import std.collection.ArrayList
import sdl.{Rect, Size, Texture, UiEvent}
import chui.core.{DesignComputedCategory, DesignComputedFact, DesignComputedProvenance,
    DesignComputedValueKind, Length, LengthUnit, UiContext, Widget, emit}
import chui.system.{ApplicationResourceReceipt, applicationResourceRoleName}

public enum ImageFit {
    | Stretch
    | Contain
    | Cover
}

/*
 * Displays an image loaded from a file. Decoded textures live in the shared, path-keyed
 * texture cache (see texture_cache.cj), so an ImageView is declared inline like any other
 * widget — the per-frame rebuild costs one cache lookup, not a disk load. After overwriting
 * an image file, call `invalidateImage(path)` to refresh it.
 *
 * The class still implements `Resource` for source compatibility with the earlier
 * hoist-and-`manage` pattern; `close()` only retires this view (the cache owns the texture).
 */
public class ImageView <: Widget & Resource {
    private let path: String
    private var imageFit: ImageFit
    private let preferredWidth: ?Length
    private let preferredHeight: Length
    private let logicalResourceName: String
    private let logicalResourceRole: String
    private let logicalResourceProvenance: String
    private var frame = Rect.zero()
    private var closed = false

    public init(
        path: String,
        fit!: ImageFit = ImageFit.Contain,
        preferredWidth!: ?Length = None,
        preferredHeight!: Length = Length(96.0, LengthUnit.Vp),
        logicalResourceName!: String = "",
        logicalResourceRole!: String = "",
        logicalResourceProvenance!: String = ""
    ) {
        this.path = path
        this.imageFit = fit
        this.preferredWidth = preferredWidth
        this.preferredHeight = preferredHeight
        this.logicalResourceName = logicalResourceName
        this.logicalResourceRole = logicalResourceRole
        this.logicalResourceProvenance = logicalResourceProvenance
        emit(this)
    }

    /** Builds a path-private image view from an ApplicationResources receipt. */
    public static func fromResource(
        receipt: ApplicationResourceReceipt,
        fit!: ImageFit = ImageFit.Contain,
        preferredWidth!: ?Length = None,
        preferredHeight!: Length = Length(96.0, LengthUnit.Vp)
    ): ImageView {
        ImageView(receipt.path, fit: fit, preferredWidth: preferredWidth, preferredHeight: preferredHeight,
            logicalResourceName: receipt.name,
            logicalResourceRole: applicationResourceRoleName(receipt.role),
            logicalResourceProvenance: receipt.provenance())
    }

    /** Selects how image pixels are fitted into the assigned frame. */
    public func fit(value: ImageFit): ImageView {
        imageFit = value
        this
    }

    // Without a preferred width an image fills the space it is offered (a full-width block);
    // with one it hugs that box, which is what lets it sit inline beside other controls.
    public func measure(ctx: UiContext, available: Size): Size {
        let width = match (preferredWidth) {
            case Some(value) => min(available.w, max(0.0, ctx.resolve(value)))
            case None => available.w
        }
        Size(width, min(available.h, max(0.0, ctx.resolve(preferredHeight))))
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        if (closed) {
            return
        }
        if (!logicalResourceName.isEmpty()) {
            ctx.renderer.recordImageResource(logicalResourceName, logicalResourceRole,
                logicalResourceProvenance, frame, imageFitName(imageFit))
        }
        match (sharedTexture(ctx.renderer, path)) {
            case Some(image) =>
                let destination = fittedRect(Size(image.width, image.height), frame, imageFit)
                match (imageFit) {
                    case ImageFit.Cover =>
                        ctx.renderer.pushClip(frame)
                        ctx.renderer.texture(image, destination)
                        ctx.renderer.popClip()
                    case _ => ctx.renderer.texture(image, destination)
                }
            case None => () // missing/undecodable image: draw nothing rather than crash the frame loop
        }
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    /** Exposes fit and logical resource identity without serializing an absolute filesystem path. */
    public func designComputedFacts(ctx: UiContext): Array<DesignComputedFact> {
        let result = ArrayList<DesignComputedFact>()
        result.add(DesignComputedFact(DesignComputedCategory.Resource, "image.fit",
            DesignComputedValueKind.Token, imageFitName(imageFit), provenance: DesignComputedProvenance.Semantic))
        result.add(DesignComputedFact(DesignComputedCategory.Layout, "image.preferred-height",
            DesignComputedValueKind.Length, ctx.resolve(preferredHeight).toString(), unit: "logical-pixel",
            sourceValue: preferredHeight.toString(), provenance: DesignComputedProvenance.Semantic))
        match (preferredWidth) {
            case Some(value) => result.add(DesignComputedFact(DesignComputedCategory.Layout,
                "image.preferred-width", DesignComputedValueKind.Length, ctx.resolve(value).toString(),
                unit: "logical-pixel", sourceValue: value.toString(),
                provenance: DesignComputedProvenance.Semantic))
            case None => ()
        }
        if (!logicalResourceName.isEmpty()) {
            result.add(DesignComputedFact(DesignComputedCategory.Resource, "resource.name",
                DesignComputedValueKind.Token, logicalResourceName,
                provenance: DesignComputedProvenance.Semantic))
            result.add(DesignComputedFact(DesignComputedCategory.Resource, "resource.role",
                DesignComputedValueKind.Token, logicalResourceRole,
                provenance: DesignComputedProvenance.Semantic))
            result.add(DesignComputedFact(DesignComputedCategory.Resource, "resource.provenance",
                DesignComputedValueKind.Token, logicalResourceProvenance,
                provenance: DesignComputedProvenance.Semantic))
        }
        result.toArray()
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        closed = true
    }
}

private func imageFitName(value: ImageFit): String {
    match (value) {
        case ImageFit.Stretch => "stretch"
        case ImageFit.Contain => "contain"
        case ImageFit.Cover => "cover"
    }
}

private func fittedRect(image: Size, frame: Rect, fit: ImageFit): Rect {
    if (image.w <= 0.0 || image.h <= 0.0 || frame.w <= 0.0 || frame.h <= 0.0) {
        return Rect(frame.x, frame.y, 0.0, 0.0)
    }
    match (fit) {
        case ImageFit.Stretch => frame
        case ImageFit.Contain => scaledRect(image, frame, min(frame.w / image.w, frame.h / image.h))
        case ImageFit.Cover => scaledRect(image, frame, max(frame.w / image.w, frame.h / image.h))
    }
}

private func scaledRect(image: Size, frame: Rect, scale: Float32): Rect {
    let w = image.w * scale
    let h = image.h * scale
    Rect(frame.centerX() - w / 2.0, frame.centerY() - h / 2.0, w, h)
}
