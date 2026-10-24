package chui.host

import chui.core.{UiOwnerQueue, UiOwnerTaskStatus, IOSDeviceProfile, classifyIOSDevice}
import std.collection.ArrayList
import std.sync.Mutex

private let IOS_BRIDGE_ACCEPTED: Int64 = 0
private let IOS_BRIDGE_INVALID_ARGUMENT: Int64 = -1
private let IOS_BRIDGE_STALE_GENERATION: Int64 = -2
private let IOS_BRIDGE_REJECTED: Int64 = -3
private let IOS_MAX_LOGICAL_MILLI: Int64 = 65535000
private let IOS_MAX_PIXEL_DIMENSION: Int64 = 65535
private let IOS_MIN_SCALE_MILLI: Int64 = 100
private let IOS_MAX_SCALE_MILLI: Int64 = 16000
private let IOS_MAX_KEY_CODE: Int64 = 65535
private let IOS_MAX_MODIFIERS: Int64 = 4294967295

/**
 * Integer-only iOS host seam. Native callbacks enqueue immutable values here; framework state is
 * changed only while the UI owner queue drains the callback.
 */
public class IOSNativeSurfaceBridge {
    private let ownerQueue = UiOwnerQueue()
    private let stateMutex = Mutex()
    private var attached = false
    private var generation: Int64 = 0
    private var handle: Int64 = 0
    private var logicalWidthMilli: Int64 = 0
    private var logicalHeightMilli: Int64 = 0
    private var pixelWidth: Int64 = 0
    private var pixelHeight: Int64 = 0
    private var scaleMilli: Int64 = 1000
    private var safeTopMilli: Int64 = 0
    private var safeRightMilli: Int64 = 0
    private var safeBottomMilli: Int64 = 0
    private var safeLeftMilli: Int64 = 0
    private var lifecycleState: Int64 = 0
    private var lastTouchPhase: Int64 = -1
    private var lastTouchId: Int64 = -1
    private var lastTouchXMilli: Int64 = 0
    private var lastTouchYMilli: Int64 = 0
    private var lastTouchTimestampMillis: Int64 = 0
    private var lastPointerPhase: Int64 = -1
    private var lastPointerKind: Int64 = -1
    private var lastPointerId: Int64 = -1
    private var lastPointerXMilli: Int64 = 0
    private var lastPointerYMilli: Int64 = 0
    private var lastPointerTimestampMillis: Int64 = 0
    private var traitStyle: Int64 = 0
    private var traitHorizontalSizeClass: Int64 = 0
    private var traitVerticalSizeClass: Int64 = 0
    private var traitScaleMilli: Int64 = 1000
    private var deviceIdiom: Int64 = 0
    private var lastFrameTimestampNanos: Int64 = 0
    private var lastFrameTargetNanos: Int64 = 0
    private var attachCount: Int64 = 0
    private var resizeCount: Int64 = 0
    private var detachCount: Int64 = 0
    private var frameCount: Int64 = 0
    private var touchCount: Int64 = 0
    private var pointerCount: Int64 = 0
    private var traitCount: Int64 = 0
    private var lastKeyPhase: Int64 = -1
    private var lastKeyCode: Int64 = -1
    private var lastKeyScanCode: Int64 = -1
    private var lastKeyRepeat: Int64 = 0
    private var lastKeyModifiers: Int64 = 0
    private var keyCount: Int64 = 0
    private var lastImePhase: Int64 = -1
    private var lastImeText: String = ""
    private var lastImeSelectionStart: Int64 = 0
    private var lastImeSelectionEnd: Int64 = 0
    private var imeCount: Int64 = 0

    public func attach(
        handle: Int64,
        logicalWidthMilli: Int64,
        logicalHeightMilli: Int64,
        pixelWidth: Int64,
        pixelHeight: Int64,
        scaleMilli: Int64,
        generation: Int64
    ): Int64 {
        if (handle <= 0 || !validDimensions(logicalWidthMilli, logicalHeightMilli,
            pixelWidth, pixelHeight, scaleMilli) || generation <= 0) {
            return IOS_BRIDGE_INVALID_ARGUMENT
        }
        let monotonic = synchronized(stateMutex) { generation > this.generation }
        if (!monotonic) {
            return IOS_BRIDGE_STALE_GENERATION
        }
        ownerQueue.setSurfaceGeneration(Some(generation))
        submit(Some(generation), {=>
            synchronized(stateMutex) {
                this.attached = true
                this.generation = generation
                this.handle = handle
                this.logicalWidthMilli = logicalWidthMilli
                this.logicalHeightMilli = logicalHeightMilli
                this.pixelWidth = pixelWidth
                this.pixelHeight = pixelHeight
                this.scaleMilli = scaleMilli
                this.attachCount += 1
                this.lastFrameTimestampNanos = 0
                this.lastFrameTargetNanos = 0
            }
        })
    }

    public func resize(
        logicalWidthMilli: Int64,
        logicalHeightMilli: Int64,
        pixelWidth: Int64,
        pixelHeight: Int64,
        scaleMilli: Int64,
        generation: Int64
    ): Int64 {
        if (!validDimensions(logicalWidthMilli, logicalHeightMilli,
            pixelWidth, pixelHeight, scaleMilli)) {
            return IOS_BRIDGE_INVALID_ARGUMENT
        }
        if (!isAttachedGeneration(generation)) {
            return IOS_BRIDGE_STALE_GENERATION
        }
        submit(Some(generation), {=>
            synchronized(stateMutex) {
                this.logicalWidthMilli = logicalWidthMilli
                this.logicalHeightMilli = logicalHeightMilli
                this.pixelWidth = pixelWidth
                this.pixelHeight = pixelHeight
                this.scaleMilli = scaleMilli
                this.resizeCount += 1
            }
        })
    }

    public func detach(generation: Int64): Int64 {
        if (!isAttachedGeneration(generation)) {
            return IOS_BRIDGE_STALE_GENERATION
        }
        let result = submit(Some(generation), {=>
            synchronized(stateMutex) {
                this.attached = false
                this.handle = 0
                this.detachCount += 1
            }
        })
        if (result == IOS_BRIDGE_ACCEPTED) {
            ownerQueue.setSurfaceGeneration(None)
        }
        result
    }

    public func updateSafeArea(
        topMilli: Int64,
        rightMilli: Int64,
        bottomMilli: Int64,
        leftMilli: Int64
    ): Int64 {
        if (topMilli < 0 || rightMilli < 0 || bottomMilli < 0 || leftMilli < 0) {
            return IOS_BRIDGE_INVALID_ARGUMENT
        }
        submit(None, {=>
            synchronized(stateMutex) {
                safeTopMilli = topMilli
                safeRightMilli = rightMilli
                safeBottomMilli = bottomMilli
                safeLeftMilli = leftMilli
            }
        })
    }

    public func updateLifecycle(state: Int64): Int64 {
        if (state < 0 || state > 5) {
            return IOS_BRIDGE_INVALID_ARGUMENT
        }
        submit(None, {=> synchronized(stateMutex) { lifecycleState = state }})
    }

    public func touch(
        phase: Int64,
        id: Int64,
        xMilli: Int64,
        yMilli: Int64,
        timestampMillis: Int64,
        generation: Int64
    ): Int64 {
        if (phase < 0 || phase > 3 || id < 0 || timestampMillis < 0) {
            return IOS_BRIDGE_INVALID_ARGUMENT
        }
        if (!isAttachedGeneration(generation)) {
            return IOS_BRIDGE_STALE_GENERATION
        }
        submit(Some(generation), {=>
            synchronized(stateMutex) {
                lastTouchPhase = phase
                lastTouchId = id
                lastTouchXMilli = xMilli
                lastTouchYMilli = yMilli
                lastTouchTimestampMillis = timestampMillis
                touchCount += 1
            }
        })
    }

    public func pointer(
        phase: Int64,
        id: Int64,
        xMilli: Int64,
        yMilli: Int64,
        timestampMillis: Int64,
        kind: Int64,
        generation: Int64
    ): Int64 {
        if (phase < 0 || phase > 2 || id < 0 || timestampMillis < 0 || kind < 0 || kind > 1) {
            return IOS_BRIDGE_INVALID_ARGUMENT
        }
        if (!isAttachedGeneration(generation)) {
            return IOS_BRIDGE_STALE_GENERATION
        }
        submit(Some(generation), {=>
            synchronized(stateMutex) {
                lastPointerPhase = phase
                lastPointerKind = kind
                lastPointerId = id
                lastPointerXMilli = xMilli
                lastPointerYMilli = yMilli
                lastPointerTimestampMillis = timestampMillis
                pointerCount += 1
            }
        })
    }

    public func updateTraits(
        style: Int64,
        horizontalSizeClass: Int64,
        verticalSizeClass: Int64,
        scaleMilli: Int64
    ): Int64 {
        if (style < 0 || style > 2 || horizontalSizeClass < 0 || horizontalSizeClass > 2 ||
            verticalSizeClass < 0 || verticalSizeClass > 2 || scaleMilli <= 0) {
            return IOS_BRIDGE_INVALID_ARGUMENT
        }
        submit(None, {=>
            synchronized(stateMutex) {
                traitStyle = style
                traitHorizontalSizeClass = horizontalSizeClass
                traitVerticalSizeClass = verticalSizeClass
                traitScaleMilli = scaleMilli
                traitCount += 1
            }
        })
    }

    public func updateIdiom(idiom: Int64): Int64 {
        if (idiom < 0 || idiom > 6) { return IOS_BRIDGE_INVALID_ARGUMENT }
        submit(None, {=> synchronized(stateMutex) { deviceIdiom = idiom }})
    }

    public func frame(timestampNanos: Int64, targetTimestampNanos: Int64, generation: Int64): Int64 {
        if (timestampNanos < 0 || targetTimestampNanos < timestampNanos) {
            return IOS_BRIDGE_INVALID_ARGUMENT
        }
        if (!isAttachedGeneration(generation)) {
            return IOS_BRIDGE_STALE_GENERATION
        }
        let monotonic = synchronized(stateMutex) { timestampNanos >= lastFrameTimestampNanos }
        if (!monotonic) {
            return IOS_BRIDGE_REJECTED
        }
        submit(Some(generation), {=>
            synchronized(stateMutex) {
                lastFrameTimestampNanos = timestampNanos
                lastFrameTargetNanos = targetTimestampNanos
                frameCount += 1
            }
        })
    }

    public func key(
        phase: Int64,
        keyCode: Int64,
        scanCode: Int64,
        repeat: Int64,
        modifiers: Int64,
        generation: Int64
    ): Int64 {
        if (phase < 0 || phase > 1 || keyCode < 0 || keyCode > IOS_MAX_KEY_CODE ||
            scanCode < 0 || scanCode > IOS_MAX_KEY_CODE || repeat < 0 || repeat > 1 ||
            modifiers < 0 || modifiers > IOS_MAX_MODIFIERS) {
            return IOS_BRIDGE_INVALID_ARGUMENT
        }
        if (!isAttachedGeneration(generation)) {
            return IOS_BRIDGE_STALE_GENERATION
        }
        submit(Some(generation), {=>
            synchronized(stateMutex) {
                lastKeyPhase = phase
                lastKeyCode = keyCode
                lastKeyScanCode = scanCode
                lastKeyRepeat = repeat
                lastKeyModifiers = modifiers
                keyCount += 1
            }
        })
    }

    public func ime(
        phase: Int64,
        text: String,
        selectionStart: Int64,
        selectionEnd: Int64,
        generation: Int64
    ): Int64 {
        if (phase < 0 || phase > 2 || selectionStart < 0 || selectionEnd < selectionStart) {
            return IOS_BRIDGE_INVALID_ARGUMENT
        }
        if (!isAttachedGeneration(generation)) {
            return IOS_BRIDGE_STALE_GENERATION
        }
        submit(Some(generation), {=>
            synchronized(stateMutex) {
                lastImePhase = phase
                lastImeText = text
                lastImeSelectionStart = selectionStart
                lastImeSelectionEnd = selectionEnd
                imeCount += 1
            }
        })
    }

    public func currentGeneration(): Int64 { synchronized(stateMutex) { generation } }
    public func currentHandle(): Int64 { synchronized(stateMutex) { handle } }
    public func isAttached(): Bool { synchronized(stateMutex) { attached } }
    public func currentLogicalWidthMilli(): Int64 { synchronized(stateMutex) { logicalWidthMilli } }
    public func currentLogicalHeightMilli(): Int64 { synchronized(stateMutex) { logicalHeightMilli } }
    public func currentPixelWidth(): Int64 { synchronized(stateMutex) { pixelWidth } }
    public func currentPixelHeight(): Int64 { synchronized(stateMutex) { pixelHeight } }
    public func currentScaleMilli(): Int64 { synchronized(stateMutex) { scaleMilli } }
    public func currentSafeTopMilli(): Int64 { synchronized(stateMutex) { safeTopMilli } }
    public func currentSafeRightMilli(): Int64 { synchronized(stateMutex) { safeRightMilli } }
    public func currentSafeBottomMilli(): Int64 { synchronized(stateMutex) { safeBottomMilli } }
    public func currentSafeLeftMilli(): Int64 { synchronized(stateMutex) { safeLeftMilli } }
    public func currentLifecycleState(): Int64 { synchronized(stateMutex) { lifecycleState } }
    public func currentTouchPhase(): Int64 { synchronized(stateMutex) { lastTouchPhase } }
    public func currentTouchId(): Int64 { synchronized(stateMutex) { lastTouchId } }
    public func currentTouchXMilli(): Int64 { synchronized(stateMutex) { lastTouchXMilli } }
    public func currentTouchYMilli(): Int64 { synchronized(stateMutex) { lastTouchYMilli } }
    public func currentTouchTimestampMillis(): Int64 { synchronized(stateMutex) { lastTouchTimestampMillis } }
    public func currentPointerPhase(): Int64 { synchronized(stateMutex) { lastPointerPhase } }
    public func currentPointerKind(): Int64 { synchronized(stateMutex) { lastPointerKind } }
    public func currentPointerId(): Int64 { synchronized(stateMutex) { lastPointerId } }
    public func currentPointerXMilli(): Int64 { synchronized(stateMutex) { lastPointerXMilli } }
    public func currentPointerYMilli(): Int64 { synchronized(stateMutex) { lastPointerYMilli } }
    public func currentPointerTimestampMillis(): Int64 { synchronized(stateMutex) { lastPointerTimestampMillis } }
    public func currentTraitStyle(): Int64 { synchronized(stateMutex) { traitStyle } }
    public func currentTraitHorizontalSizeClass(): Int64 { synchronized(stateMutex) { traitHorizontalSizeClass } }
    public func currentTraitVerticalSizeClass(): Int64 { synchronized(stateMutex) { traitVerticalSizeClass } }
    public func currentTraitScaleMilli(): Int64 { synchronized(stateMutex) { traitScaleMilli } }
    public func currentIdiom(): Int64 { synchronized(stateMutex) { deviceIdiom } }

    /** Classified viewport for framework consumers; safe before the first attach. */
    public func deviceProfile(): IOSDeviceProfile {
        synchronized(stateMutex) {
            if (logicalWidthMilli <= 0 || logicalHeightMilli <= 0) {
                return classifyIOSDevice(deviceIdiom, 1.0, 1.0, scale: 1.0)
            }
            let resolvedScale = if (scaleMilli > 0) {
                Float32(scaleMilli) / Float32(1000)
            } else {
                Float32(1.0)
            }
            classifyIOSDevice(
                deviceIdiom,
                Float32(logicalWidthMilli) / Float32(1000),
                Float32(logicalHeightMilli) / Float32(1000),
                scale: resolvedScale,
                horizontalSizeClass: traitHorizontalSizeClass,
                verticalSizeClass: traitVerticalSizeClass)
        }
    }
    public func currentFrameTimestampNanos(): Int64 { synchronized(stateMutex) { lastFrameTimestampNanos } }
    public func currentFrameTargetNanos(): Int64 { synchronized(stateMutex) { lastFrameTargetNanos } }
    public func totalAttachCount(): Int64 { synchronized(stateMutex) { attachCount } }
    public func totalResizeCount(): Int64 { synchronized(stateMutex) { resizeCount } }
    public func totalDetachCount(): Int64 { synchronized(stateMutex) { detachCount } }
    public func totalFrameCount(): Int64 { synchronized(stateMutex) { frameCount } }
    public func totalTouchCount(): Int64 { synchronized(stateMutex) { touchCount } }
    public func totalPointerCount(): Int64 { synchronized(stateMutex) { pointerCount } }
    public func totalTraitCount(): Int64 { synchronized(stateMutex) { traitCount } }
    public func currentKeyPhase(): Int64 { synchronized(stateMutex) { lastKeyPhase } }
    public func currentKeyCode(): Int64 { synchronized(stateMutex) { lastKeyCode } }
    public func currentKeyScanCode(): Int64 { synchronized(stateMutex) { lastKeyScanCode } }
    public func currentKeyRepeat(): Int64 { synchronized(stateMutex) { lastKeyRepeat } }
    public func currentKeyModifiers(): Int64 { synchronized(stateMutex) { lastKeyModifiers } }
    public func totalKeyCount(): Int64 { synchronized(stateMutex) { keyCount } }
    public func currentImePhase(): Int64 { synchronized(stateMutex) { lastImePhase } }
    public func currentImeText(): String { synchronized(stateMutex) { lastImeText } }
    public func currentImeSelectionStart(): Int64 { synchronized(stateMutex) { lastImeSelectionStart } }
    public func currentImeSelectionEnd(): Int64 { synchronized(stateMutex) { lastImeSelectionEnd } }
    public func totalImeCount(): Int64 { synchronized(stateMutex) { imeCount } }

    /** Primary-blue idle color; touch-down uses a brighter Cangjie-selected state. */
    public func clearColorArgb(): Int64 {
        synchronized(stateMutex) {
            if (lastTouchPhase == 0) { 4290054911 } else { 4281633014 }
        }
    }

    private func validDimensions(
        logicalWidthMilli: Int64,
        logicalHeightMilli: Int64,
        pixelWidth: Int64,
        pixelHeight: Int64,
        scaleMilli: Int64
    ): Bool {
        logicalWidthMilli > 0 && logicalWidthMilli <= IOS_MAX_LOGICAL_MILLI &&
            logicalHeightMilli > 0 && logicalHeightMilli <= IOS_MAX_LOGICAL_MILLI &&
            pixelWidth > 0 && pixelWidth <= IOS_MAX_PIXEL_DIMENSION &&
            pixelHeight > 0 && pixelHeight <= IOS_MAX_PIXEL_DIMENSION &&
            scaleMilli >= IOS_MIN_SCALE_MILLI && scaleMilli <= IOS_MAX_SCALE_MILLI
    }

    private func isAttachedGeneration(generation: Int64): Bool {
        synchronized(stateMutex) { attached && generation > 0 && this.generation == generation }
    }

    private func submit(generation: ?Int64, action: () -> Unit): Int64 {
        let ticket = ownerQueue.post(action, surfaceGeneration: generation)
        let _ = ownerQueue.drain()
        match (ticket.receipt()) {
            case Some(receipt) =>
                if (receipt.status == UiOwnerTaskStatus.Committed) {
                    IOS_BRIDGE_ACCEPTED
                } else if (receipt.status == UiOwnerTaskStatus.RejectedSurfaceGeneration) {
                    IOS_BRIDGE_STALE_GENERATION
                } else {
                    IOS_BRIDGE_REJECTED
                }
            case None => IOS_BRIDGE_REJECTED
        }
    }
}

private let iosNativeSurfaceBridge = IOSNativeSurfaceBridge()

@C
public func canghui_ios_surface_attach(
    handle: Int64,
    logicalWidthMilli: Int64,
    logicalHeightMilli: Int64,
    pixelWidth: Int64,
    pixelHeight: Int64,
    scaleMilli: Int64,
    generation: Int64
): Int64 {
    iosNativeSurfaceBridge.attach(handle, logicalWidthMilli, logicalHeightMilli,
        pixelWidth, pixelHeight, scaleMilli, generation)
}

@C
public func canghui_ios_surface_resize(
    logicalWidthMilli: Int64,
    logicalHeightMilli: Int64,
    pixelWidth: Int64,
    pixelHeight: Int64,
    scaleMilli: Int64,
    generation: Int64
): Int64 {
    iosNativeSurfaceBridge.resize(logicalWidthMilli, logicalHeightMilli,
        pixelWidth, pixelHeight, scaleMilli, generation)
}

@C
public func canghui_ios_surface_detach(generation: Int64): Int64 {
    iosNativeSurfaceBridge.detach(generation)
}

@C
public func canghui_ios_surface_safe_area(
    topMilli: Int64,
    rightMilli: Int64,
    bottomMilli: Int64,
    leftMilli: Int64
): Int64 {
    iosNativeSurfaceBridge.updateSafeArea(topMilli, rightMilli, bottomMilli, leftMilli)
}

@C
public func canghui_ios_surface_lifecycle(state: Int64): Int64 {
    iosNativeSurfaceBridge.updateLifecycle(state)
}

@C
public func canghui_ios_surface_touch(
    phase: Int64,
    id: Int64,
    xMilli: Int64,
    yMilli: Int64,
    timestampMillis: Int64,
    generation: Int64
): Int64 {
    iosNativeSurfaceBridge.touch(phase, id, xMilli, yMilli, timestampMillis, generation)
}

@C
public func canghui_ios_surface_pointer(
    phase: Int64,
    id: Int64,
    xMilli: Int64,
    yMilli: Int64,
    timestampMillis: Int64,
    kind: Int64,
    generation: Int64
): Int64 {
    iosNativeSurfaceBridge.pointer(phase, id, xMilli, yMilli, timestampMillis, kind, generation)
}

@C
public func canghui_ios_surface_traits(
    style: Int64,
    horizontalSizeClass: Int64,
    verticalSizeClass: Int64,
    scaleMilli: Int64
): Int64 {
    iosNativeSurfaceBridge.updateTraits(style, horizontalSizeClass, verticalSizeClass, scaleMilli)
}

@C
public func canghui_ios_surface_frame(
    timestampNanos: Int64,
    targetTimestampNanos: Int64,
    generation: Int64
): Int64 {
    iosNativeSurfaceBridge.frame(timestampNanos, targetTimestampNanos, generation)
}

private func iosUtf8String(text: CPointer<UInt8>, length: Int64): ?String {
    if (text.isNull() || length <= 0) {
        return Some("")
    }
    let bytes = ArrayList<UInt8>()
    unsafe {
        for (i in 0..length) {
            bytes.add(text.read(i))
        }
    }
    try {
        Some(String.fromUtf8(bytes.toArray()))
    } catch (error: Exception) {
        None
    }
}

@C
public func canghui_ios_surface_key(
    phase: Int64,
    keyCode: Int64,
    scanCode: Int64,
    repeat: Int64,
    modifiers: Int64,
    generation: Int64
): Int64 {
    iosNativeSurfaceBridge.key(phase, keyCode, scanCode, repeat, modifiers, generation)
}

@C
public func canghui_ios_surface_ime(
    text: CPointer<UInt8>,
    length: Int64,
    phase: Int64,
    selectionStart: Int64,
    selectionEnd: Int64,
    generation: Int64
): Int64 {
    if (let Some(value) <- iosUtf8String(text, length)) {
        iosNativeSurfaceBridge.ime(phase, value, selectionStart, selectionEnd, generation)
    } else {
        IOS_BRIDGE_INVALID_ARGUMENT
    }
}

@C public func canghui_ios_surface_key_count(): Int64 { iosNativeSurfaceBridge.totalKeyCount() }
@C public func canghui_ios_surface_last_key_phase(): Int64 { iosNativeSurfaceBridge.currentKeyPhase() }
@C public func canghui_ios_surface_last_key_code(): Int64 { iosNativeSurfaceBridge.currentKeyCode() }
@C public func canghui_ios_surface_last_key_scan_code(): Int64 { iosNativeSurfaceBridge.currentKeyScanCode() }
@C public func canghui_ios_surface_last_key_repeat(): Int64 { iosNativeSurfaceBridge.currentKeyRepeat() }
@C public func canghui_ios_surface_last_key_modifiers(): Int64 { iosNativeSurfaceBridge.currentKeyModifiers() }
@C public func canghui_ios_surface_ime_count(): Int64 { iosNativeSurfaceBridge.totalImeCount() }
@C public func canghui_ios_surface_last_ime_phase(): Int64 { iosNativeSurfaceBridge.currentImePhase() }
@C public func canghui_ios_surface_last_ime_selection_start(): Int64 {
    iosNativeSurfaceBridge.currentImeSelectionStart()
}
@C public func canghui_ios_surface_last_ime_selection_end(): Int64 {
    iosNativeSurfaceBridge.currentImeSelectionEnd()
}
@C
public func canghui_ios_surface_last_ime_text(
    output: CPointer<UInt8>,
    capacity: Int64,
    length: CPointer<Int64>
): Int32 {
    let value = iosNativeSurfaceBridge.currentImeText()
    unsafe {
        if (length.isNull() || capacity < 0) { return -1 }
        let bytes = value.toArray()
        length.write(Int64(bytes.size))
        if (output.isNull() || capacity < Int64(bytes.size)) { return -2 }
        for (i in 0..bytes.size) {
            output.write(i, UInt8(bytes[i]))
        }
        0
    }
}

@C public func canghui_ios_surface_generation(): Int64 { iosNativeSurfaceBridge.currentGeneration() }
@C public func canghui_ios_surface_is_attached(): Int64 { if (iosNativeSurfaceBridge.isAttached()) { 1 } else { 0 } }
@C public func canghui_ios_surface_handle(): Int64 { iosNativeSurfaceBridge.currentHandle() }
@C public func canghui_ios_surface_attach_count(): Int64 { iosNativeSurfaceBridge.totalAttachCount() }
@C public func canghui_ios_surface_resize_count(): Int64 { iosNativeSurfaceBridge.totalResizeCount() }
@C public func canghui_ios_surface_detach_count(): Int64 { iosNativeSurfaceBridge.totalDetachCount() }
@C public func canghui_ios_surface_frame_count(): Int64 { iosNativeSurfaceBridge.totalFrameCount() }
@C public func canghui_ios_surface_touch_count(): Int64 { iosNativeSurfaceBridge.totalTouchCount() }
@C public func canghui_ios_surface_last_touch_phase(): Int64 { iosNativeSurfaceBridge.currentTouchPhase() }
@C public func canghui_ios_surface_pointer_count(): Int64 { iosNativeSurfaceBridge.totalPointerCount() }
@C public func canghui_ios_surface_last_pointer_phase(): Int64 { iosNativeSurfaceBridge.currentPointerPhase() }
@C public func canghui_ios_surface_last_pointer_kind(): Int64 { iosNativeSurfaceBridge.currentPointerKind() }
@C public func canghui_ios_surface_trait_count(): Int64 { iosNativeSurfaceBridge.totalTraitCount() }
@C public func canghui_ios_surface_last_trait_style(): Int64 { iosNativeSurfaceBridge.currentTraitStyle() }
@C public func canghui_ios_surface_last_trait_horizontal_size_class(): Int64 {
    iosNativeSurfaceBridge.currentTraitHorizontalSizeClass()
}
@C public func canghui_ios_surface_last_trait_vertical_size_class(): Int64 {
    iosNativeSurfaceBridge.currentTraitVerticalSizeClass()
}
@C public func canghui_ios_surface_last_trait_scale_milli(): Int64 {
    iosNativeSurfaceBridge.currentTraitScaleMilli()
}
@C public func canghui_ios_surface_set_idiom(idiom: Int64): Int64 {
    iosNativeSurfaceBridge.updateIdiom(idiom)
}
@C public func canghui_ios_surface_idiom(): Int64 { iosNativeSurfaceBridge.currentIdiom() }
@C public func canghui_ios_surface_device_class(): Int64 {
    iosNativeSurfaceBridge.deviceProfile().deviceClass.code()
}
@C public func canghui_ios_surface_layout_breakpoint(): Int64 {
    iosNativeSurfaceBridge.deviceProfile().breakpoint.code()
}
@C
public func canghui_ios_surface_device_profile(
    output: CPointer<UInt8>,
    capacity: Int64,
    length: CPointer<Int64>
): Int32 {
    if (length.isNull() || capacity < 0) { return -1 }
    let bytes = iosNativeSurfaceBridge.deviceProfile().json().toArray()
    unsafe {
        length.write(Int64(bytes.size))
        if (output.isNull() || capacity < Int64(bytes.size)) { return -2 }
        for (i in 0..bytes.size) {
            output.write(i, UInt8(bytes[i]))
        }
    }
    0
}
@C public func canghui_ios_surface_last_frame_nanos(): Int64 { iosNativeSurfaceBridge.currentFrameTimestampNanos() }
@C public func canghui_ios_surface_clear_color_argb(): Int64 { iosNativeSurfaceBridge.clearColorArgb() }
