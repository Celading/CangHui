package chui.core

public let IOS_IDIOM_UNSPECIFIED: Int64 = 0
public let IOS_IDIOM_PHONE: Int64 = 1
public let IOS_IDIOM_PAD: Int64 = 2

/**
 * Stable iOS device grouping for layout decisions.
 *
 * The classifier uses the public interface idiom and the logical viewport, not
 * marketing names. A phone-idiom viewport that is wide and near-square is
 * treated as an unfolded foldable ("Duo"); a pad below 800 pt on its short edge
 * is treated as the mini class.
 */
public enum IOSDeviceClass <: Equatable<IOSDeviceClass> {
    | Unspecified
    | IPhone
    | IPhoneDuo
    | IPadMini
    | IPadLarge

    public operator func ==(other: IOSDeviceClass): Bool {
        match ((this, other)) {
            case (IOSDeviceClass.Unspecified, IOSDeviceClass.Unspecified) => true
            case (IOSDeviceClass.IPhone, IOSDeviceClass.IPhone) => true
            case (IOSDeviceClass.IPhoneDuo, IOSDeviceClass.IPhoneDuo) => true
            case (IOSDeviceClass.IPadMini, IOSDeviceClass.IPadMini) => true
            case (IOSDeviceClass.IPadLarge, IOSDeviceClass.IPadLarge) => true
            case _ => false
        }
    }

    public operator func !=(other: IOSDeviceClass): Bool { !(this == other) }

    public func code(): Int64 {
        match (this) {
            case IOSDeviceClass.Unspecified => 0
            case IOSDeviceClass.IPhone => 1
            case IOSDeviceClass.IPhoneDuo => 2
            case IOSDeviceClass.IPadMini => 3
            case IOSDeviceClass.IPadLarge => 4
        }
    }

    public func name(): String {
        match (this) {
            case IOSDeviceClass.Unspecified => "unspecified"
            case IOSDeviceClass.IPhone => "iphone"
            case IOSDeviceClass.IPhoneDuo => "iphone-duo"
            case IOSDeviceClass.IPadMini => "ipad-mini"
            case IOSDeviceClass.IPadLarge => "ipad-large"
        }
    }
}

/** Width breakpoint shared by iOS consumers; thresholds match `ViewportClass`. */
public enum IOSLayoutBreakpoint <: Equatable<IOSLayoutBreakpoint> {
    | Compact
    | Medium
    | Expanded

    public operator func ==(other: IOSLayoutBreakpoint): Bool {
        match ((this, other)) {
            case (IOSLayoutBreakpoint.Compact, IOSLayoutBreakpoint.Compact) => true
            case (IOSLayoutBreakpoint.Medium, IOSLayoutBreakpoint.Medium) => true
            case (IOSLayoutBreakpoint.Expanded, IOSLayoutBreakpoint.Expanded) => true
            case _ => false
        }
    }

    public operator func !=(other: IOSLayoutBreakpoint): Bool { !(this == other) }

    public func code(): Int64 {
        match (this) {
            case IOSLayoutBreakpoint.Compact => 1
            case IOSLayoutBreakpoint.Medium => 2
            case IOSLayoutBreakpoint.Expanded => 3
        }
    }

    public func name(): String {
        match (this) {
            case IOSLayoutBreakpoint.Compact => "compact"
            case IOSLayoutBreakpoint.Medium => "medium"
            case IOSLayoutBreakpoint.Expanded => "expanded"
        }
    }
}

public enum IOSDeviceOrientation <: Equatable<IOSDeviceOrientation> {
    | Unspecified
    | Portrait
    | Landscape

    public operator func ==(other: IOSDeviceOrientation): Bool {
        match ((this, other)) {
            case (IOSDeviceOrientation.Unspecified, IOSDeviceOrientation.Unspecified) => true
            case (IOSDeviceOrientation.Portrait, IOSDeviceOrientation.Portrait) => true
            case (IOSDeviceOrientation.Landscape, IOSDeviceOrientation.Landscape) => true
            case _ => false
        }
    }

    public operator func !=(other: IOSDeviceOrientation): Bool { !(this == other) }

    public func name(): String {
        match (this) {
            case IOSDeviceOrientation.Unspecified => "unspecified"
            case IOSDeviceOrientation.Portrait => "portrait"
            case IOSDeviceOrientation.Landscape => "landscape"
        }
    }
}

/** One immutable layout input that consumers can cache per resize/orientation. */
public struct IOSDeviceProfile {
    public let deviceClass: IOSDeviceClass
    public let breakpoint: IOSLayoutBreakpoint
    public let orientation: IOSDeviceOrientation
    public let width: Float32
    public let height: Float32
    public let scale: Float32
    public let horizontalSizeClass: Int64
    public let verticalSizeClass: Int64
    public let usesSidebar: Bool

    public init(
        deviceClass: IOSDeviceClass,
        breakpoint: IOSLayoutBreakpoint,
        orientation: IOSDeviceOrientation,
        width: Float32,
        height: Float32,
        scale: Float32,
        horizontalSizeClass: Int64,
        verticalSizeClass: Int64
    ) {
        this.deviceClass = deviceClass
        this.breakpoint = breakpoint
        this.orientation = orientation
        this.width = width
        this.height = height
        this.scale = scale
        this.horizontalSizeClass = horizontalSizeClass
        this.verticalSizeClass = verticalSizeClass
        this.usesSidebar = (deviceClass == IOSDeviceClass.IPadMini ||
            deviceClass == IOSDeviceClass.IPadLarge ||
            deviceClass == IOSDeviceClass.IPhoneDuo) &&
            breakpoint != IOSLayoutBreakpoint.Compact
    }

    public func recommendedColumns(): Int64 {
        match (breakpoint) {
            case IOSLayoutBreakpoint.Compact => 1
            case IOSLayoutBreakpoint.Medium => 2
            case IOSLayoutBreakpoint.Expanded => 3
        }
    }

    public func isCompact(): Bool { breakpoint == IOSLayoutBreakpoint.Compact }

    /** Machine-readable readback for probes and receipts; contains no user data. */
    public func json(): String {
        "{\"deviceClass\":\"" + deviceClass.name() +
            "\",\"breakpoint\":\"" + breakpoint.name() +
            "\",\"orientation\":\"" + orientation.name() +
            "\",\"width\":" + width.toString() +
            ",\"height\":" + height.toString() +
            ",\"scale\":" + scale.toString() +
            ",\"horizontalSizeClass\":" + horizontalSizeClass.toString() +
            ",\"verticalSizeClass\":" + verticalSizeClass.toString() +
            ",\"usesSidebar\":" + usesSidebar.toString() +
            ",\"recommendedColumns\":" + recommendedColumns().toString() +
            "}"
    }
}

public func classifyIOSLayoutBreakpoint(width: Float32): IOSLayoutBreakpoint {
    if (width <= 0.0) {
        throw IllegalArgumentException("iOS layout width must be positive")
    }
    if (width < 600.0) {
        IOSLayoutBreakpoint.Compact
    } else if (width < 1024.0) {
        IOSLayoutBreakpoint.Medium
    } else {
        IOSLayoutBreakpoint.Expanded
    }
}

/**
 * Classifies one iOS viewport.
 *
 * `idiom` is `UIDevice.userInterfaceIdiom` (0 unspecified, 1 phone, 2 pad).
 * The foldable and mini rules are documented heuristics over public viewport
 * facts; callers that know a more exact model may keep their own override.
 */
public func classifyIOSDevice(
    idiom: Int64,
    width: Float32,
    height: Float32,
    scale!: Float32 = 1.0,
    horizontalSizeClass!: Int64 = 0,
    verticalSizeClass!: Int64 = 0
): IOSDeviceProfile {
    if (idiom < 0 || idiom > 6) {
        throw IllegalArgumentException("iOS interface idiom is out of range")
    }
    if (width <= 0.0 || height <= 0.0 || scale <= 0.0) {
        throw IllegalArgumentException("iOS device dimensions and scale must be positive")
    }
    if (horizontalSizeClass < 0 || horizontalSizeClass > 2 ||
        verticalSizeClass < 0 || verticalSizeClass > 2) {
        throw IllegalArgumentException("iOS size classes are out of range")
    }
    let shortSide = min(width, height)
    let longSide = max(width, height)
    let ratio = longSide / shortSide
    let deviceClass = if (idiom == IOS_IDIOM_PHONE) {
        if (shortSide >= 500.0 && ratio <= 1.4) {
            IOSDeviceClass.IPhoneDuo
        } else {
            IOSDeviceClass.IPhone
        }
    } else if (idiom == IOS_IDIOM_PAD) {
        if (shortSide < 800.0) {
            IOSDeviceClass.IPadMini
        } else {
            IOSDeviceClass.IPadLarge
        }
    } else {
        IOSDeviceClass.Unspecified
    }
    IOSDeviceProfile(
        deviceClass,
        classifyIOSLayoutBreakpoint(width),
        if (width >= height) { IOSDeviceOrientation.Landscape } else { IOSDeviceOrientation.Portrait },
        width,
        height,
        scale,
        horizontalSizeClass,
        verticalSizeClass
    )
}
